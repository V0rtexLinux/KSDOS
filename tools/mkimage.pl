#!/usr/bin/perl
# =============================================================================
# KSDOS - Disk Image Builder v2 (with full SYSTEM32 tree)
# Creates a 1.44MB FAT12 floppy image with:
#   Sector 0:    bootsect.bin (boot sector with FAT12 BPB)
#   Sectors 1-9: FAT1
#   Sectors 10-18: FAT2
#   Sectors 19-32: Root directory
#   Sector 33+:  KSDOS.SYS kernel
#   Following:   Overlay .OVL files
#   Following:   SYSTEM32\ directory tree from bootloader/kernel/SYSTEM/
#
# Usage: perl mkimage.pl <bootsect.bin> <ksdos.bin> <output.img> [ovl1.OVL ...]
# =============================================================================
use strict;
use warnings;
use File::Find;
use File::Basename;

# FAT12 parameters (1.44MB floppy)
use constant {
    SECTOR_SIZE     => 512,
    TOTAL_SECTORS   => 2880,
    RESERVED_SECS   => 1,
    FAT_COUNT       => 2,
    SECTORS_PER_FAT => 9,
    ROOT_ENTRIES    => 224,
    SECTORS_PER_CLU => 1,
    MEDIA_BYTE      => 0xF0,
    MAX_FILE_DATA   => 65536,   # max bytes per file to embed (64KB)
};

use constant ROOT_DIR_SECTORS => int((ROOT_ENTRIES * 32 + SECTOR_SIZE - 1) / SECTOR_SIZE);  # 14
use constant FAT_LBA          => RESERVED_SECS;                                              # 1
use constant ROOT_LBA         => RESERVED_SECS + FAT_COUNT * SECTORS_PER_FAT;               # 19
use constant DATA_LBA         => ROOT_LBA + ROOT_DIR_SECTORS;                               # 33

die "Usage: $0 <bootsect.bin> <kernel.bin> <output.img> [overlay.OVL ...]\n" unless @ARGV >= 3;

my ($bootsect_file, $kernel_file, $output_file, @ovl_files) = @ARGV;

# --------------------------------------------------------------------------
# Read input files
# --------------------------------------------------------------------------
my $bootsect = read_file($bootsect_file, SECTOR_SIZE, 0x00);
my $kernel   = read_file($kernel_file);

die "Boot sector must be exactly 512 bytes (got " . length($bootsect) . ")\n"
    unless length($bootsect) == SECTOR_SIZE;
die "Boot sector missing signature 0xAA55\n"
    unless substr($bootsect, 510, 2) eq "\x55\xAA";

my $kernel_size     = length($kernel);
my $kernel_sectors  = int(($kernel_size + SECTOR_SIZE - 1) / SECTOR_SIZE);
my $kernel_clusters = $kernel_sectors;  # spc=1

printf "Boot sector: %d bytes\n", length($bootsect);
printf "Kernel:      %d bytes (%d sectors / clusters)\n", $kernel_size, $kernel_sectors;
printf "Data area starts at sector %d\n", DATA_LBA;

# --------------------------------------------------------------------------
# Build FAT (FAT12, 512 bytes per cluster = 1 sector)
# --------------------------------------------------------------------------
my $fat_bytes = 9 * SECTOR_SIZE;  # 4608 bytes
my @fat = (0) x $fat_bytes;

# Entry 0: media descriptor
set_fat12(\@fat, 0, 0xFF0 | MEDIA_BYTE);
# Entry 1: end-of-chain marker
set_fat12(\@fat, 1, 0xFFF);

# Cluster chain for KSDOS.SYS starting at cluster 2
for my $i (0 .. $kernel_clusters - 1) {
    my $clus = $i + 2;
    set_fat12(\@fat, $clus, ($i == $kernel_clusters - 1) ? 0xFFF : $clus + 1);
}

# --------------------------------------------------------------------------
# In-memory FAT12 filesystem state
# --------------------------------------------------------------------------
my $next_free_cluster = 2 + $kernel_clusters;

# Data blocks: cluster => raw data (512 bytes each, padded)
my %cluster_data;

# Directory entries: each is a list of 32-byte strings
# Key = cluster number (0 = root directory entries, beyond slot 1/2/3)
my @root_entries;       # list of 32-byte strings for root dir
my $root_slot = 0;

# --------------------------------------------------------------------------
# Subroutines
# --------------------------------------------------------------------------

sub alloc_cluster {
    my ($data) = @_;
    my $c = $next_free_cluster++;
    # Pad to sector boundary
    $data = substr($data . ("\x00" x SECTOR_SIZE), 0, SECTOR_SIZE)
        if length($data) < SECTOR_SIZE;
    $cluster_data{$c} = $data;
    return $c;
}

sub alloc_cluster_chain {
    my @chunks = @_;
    my @clusters;
    for my $chunk (@chunks) {
        my $c = $next_free_cluster++;
        $chunk = substr($chunk . ("\x00" x SECTOR_SIZE), 0, SECTOR_SIZE);
        $cluster_data{$c} = $chunk;
        push @clusters, $c;
    }
    # Link chain
    for my $i (0 .. $#clusters - 1) {
        set_fat12(\@fat, $clusters[$i], $clusters[$i + 1]);
    }
    set_fat12(\@fat, $clusters[-1], 0xFFF) if @clusters;
    return @clusters;
}

sub make_entry {
    my ($name, $attr, $cluster, $size) = @_;
    my $padded = substr($name . (" " x 11), 0, 11);
    return $padded .
           chr($attr) .
           "\x00" x 8 .
           pack("v", 0) .
           pack("v", encode_time(0, 0, 0)) .
           pack("v", encode_date(2024, 1, 1)) .
           pack("v", $cluster) .
           pack("V", $size);
}

sub fat8_3 {
    # Convert filename to FAT 8.3 format (11 chars)
    my ($name) = @_;
    $name = uc($name);
    my ($stem, $ext) = split(/\./, $name, 2);
    $stem //= "";
    $ext  //= "";
    $stem = substr($stem . "        ", 0, 8);
    $ext  = substr($ext  . "   ",      0, 3);
    return $stem . $ext;
}

# Build a directory cluster from a list of 32-byte entries
# Returns cluster number (or 0 if too many entries for one sector — extends)
sub make_dir_cluster {
    my ($parent_cluster, $self_cluster, @entries) = @_;
    # . and .. entries
    my $dot    = make_entry(".          ", 0x10, $self_cluster, 0);
    my $dotdot = make_entry("..         ", 0x10, $parent_cluster, 0);
    my $dir_data = $dot . $dotdot . join("", @entries);
    # May span multiple sectors
    my @chunks;
    while (length($dir_data) > 0) {
        push @chunks, substr($dir_data, 0, SECTOR_SIZE);
        $dir_data = substr($dir_data, SECTOR_SIZE) if length($dir_data) > SECTOR_SIZE;
        last if length($dir_data) <= SECTOR_SIZE && @chunks > 0
             && length($chunks[-1]) == SECTOR_SIZE;
    }
    my @clist = alloc_cluster_chain(@chunks);
    return $clist[0];
}

# --------------------------------------------------------------------------
# SYSTEM directory tree scan
# We embed files from bootloader/kernel/SYSTEM/ into A:\SYSTEM32\ on disk
#
# Directory mapping:
#   SYSTEM/CMD/     -> SYSTEM32\CMD\
#   SYSTEM/DEV/     -> SYSTEM32\DEV\
#   SYSTEM/INC/     -> SYSTEM32\INC\
#   SYSTEM/H/       -> SYSTEM32\H\
#   SYSTEM/DOS/     -> SYSTEM32\DOS\
#   SYSTEM/BIOS/    -> SYSTEM32\BIOS\
#   SYSTEM/MESSAGES/-> SYSTEM32\MSG\
#   SYSTEM/MEMM/    -> SYSTEM32\MEMM\
#   SYSTEM/SELECT/  -> SYSTEM32\SELECT\ (selected files)
#   SYSTEM/LIB/     -> SYSTEM32\LIB\
#   SYSTEM/MAPPER/  -> SYSTEM32\MAPPER\
#
# Per-file size budget: truncate files > 2KB to first 2KB (fits more files)
# Per-subdir file limit: 16 files max (keeps within 1.44MB total)
# --------------------------------------------------------------------------

my $sys_root = "bootloader/kernel/SYSTEM";
my $disk_budget = 900 * 1024;   # 900KB budget for SYSTEM32

# Directories to embed and their disk short names
my @sys_dirs = (
    { src => "$sys_root/INC",          dst => "INC     ",  max_files => 30, max_size => 3072 },
    { src => "$sys_root/H",            dst => "H       ",  max_files => 20, max_size => 2048 },
    { src => "$sys_root/DOS",          dst => "DOS     ",  max_files => 20, max_size => 2048 },
    { src => "$sys_root/BIOS",         dst => "BIOS    ",  max_files => 15, max_size => 2048 },
    { src => "$sys_root/CMD/EDLIN",    dst => "EDLIN   ",  max_files => 10, max_size => 4096 },
    { src => "$sys_root/CMD/FORMAT",   dst => "FORMAT  ",  max_files => 10, max_size => 4096 },
    { src => "$sys_root/CMD/FDISK",    dst => "FDISK   ",  max_files => 10, max_size => 4096 },
    { src => "$sys_root/CMD/CHKDSK",   dst => "CHKDSK  ",  max_files => 10, max_size => 4096 },
    { src => "$sys_root/CMD/DISKCOPY", dst => "DSKCOPY ",  max_files =>  8, max_size => 4096 },
    { src => "$sys_root/CMD/FC",       dst => "FC      ",  max_files =>  8, max_size => 4096 },
    { src => "$sys_root/CMD/FIND",     dst => "FIND    ",  max_files =>  5, max_size => 2048 },
    { src => "$sys_root/CMD/MORE",     dst => "MORE    ",  max_files =>  5, max_size => 2048 },
    { src => "$sys_root/CMD/SORT",     dst => "SORT    ",  max_files =>  5, max_size => 2048 },
    { src => "$sys_root/CMD/KEYB",     dst => "KEYB    ",  max_files =>  8, max_size => 4096 },
    { src => "$sys_root/CMD/MODE",     dst => "MODE    ",  max_files => 10, max_size => 4096 },
    { src => "$sys_root/CMD/DEBUG",    dst => "DEBUG   ",  max_files =>  8, max_size => 4096 },
    { src => "$sys_root/DEV/ANSI",     dst => "ANSI    ",  max_files => 10, max_size => 4096 },
    { src => "$sys_root/DEV/KEYBOARD", dst => "KEYBD   ",  max_files =>  8, max_size => 4096 },
    { src => "$sys_root/DEV/DISPLAY",  dst => "DISPLAY ",  max_files =>  8, max_size => 4096 },
    { src => "$sys_root/DEV/RAMDRIVE", dst => "RAMDISK ",  max_files =>  6, max_size => 4096 },
    { src => "$sys_root/MEMM/MEMM",    dst => "MEMM    ",  max_files => 10, max_size => 4096 },
    { src => "$sys_root/MEMM/EMM",     dst => "EMM     ",  max_files =>  8, max_size => 4096 },
    { src => "$sys_root/MESSAGES",     dst => "MESSAGES",  max_files => 10, max_size => 2048 },
    { src => "$sys_root/SELECT",       dst => "SELECT  ",  max_files => 10, max_size => 2048 },
    { src => "$sys_root/LIB",          dst => "LIB     ",  max_files =>  8, max_size => 2048 },
    { src => "$sys_root/MAPPER",       dst => "MAPPER  ",  max_files =>  6, max_size => 2048 },
);

# CMD root subdirectory (catalog of all CMD tools)
my $cmd_dir_src = "$sys_root/CMD";

# --------------------------------------------------------------------------
# Build SYSTEM32 directory tree in FAT12
# --------------------------------------------------------------------------

# Each subdirectory of SYSTEM32: build its files, get cluster
my @sys32_subdir_entries;   # directory entries for SYSTEM32\ itself
my $sys32_cluster;          # will be filled after we know it

my $bytes_used = 0;

sub embed_dir {
    my ($src_path, $dst_name_8, $parent_cluster, $max_files, $max_size) = @_;

    return undef unless -d $src_path;

    # Collect files in this directory (not recursive for subdirs)
    opendir(my $dh, $src_path) or return undef;
    my @files = grep { -f "$src_path/$_" } readdir($dh);
    closedir($dh);

    # Sort by size ascending (embed more small files)
    @files = sort { -s "$src_path/$a" <=> -s "$src_path/$b" } @files;

    # Limit number of files
    @files = @files[0 .. ($max_files - 1)] if @files > $max_files;

    my @dir_entries;
    my $subdir_cluster_placeholder = 0;  # will set after alloc

    for my $fname (@files) {
        my $fpath = "$src_path/$fname";
        my $fsize = -s $fpath;

        # Read and optionally truncate
        open(my $fh, '<', $fpath) or next;
        binmode $fh;
        local $/;
        my $fdata = <$fh>;
        close $fh;

        if (length($fdata) > $max_size) {
            $fdata = substr($fdata, 0, $max_size);
        }

        my $actual_size = length($fdata);
        $bytes_used += $actual_size;
        last if $bytes_used > $disk_budget;

        # Build FAT 8.3 name
        my $fat_name = fat8_3($fname);

        # Allocate cluster(s) for file data
        my @chunks;
        my $remaining = $fdata;
        while (length($remaining) > 0) {
            push @chunks, substr($remaining, 0, SECTOR_SIZE);
            $remaining = length($remaining) > SECTOR_SIZE
                ? substr($remaining, SECTOR_SIZE)
                : "";
        }
        push @chunks, "\x00" x SECTOR_SIZE unless @chunks;

        my @fclusters = alloc_cluster_chain(@chunks);
        my $start_clus = $fclusters[0];

        push @dir_entries, make_entry($fat_name, 0x20, $start_clus, $actual_size);

        printf "  SYSTEM32\\%-8s\\%-12s %d bytes (cluster %d)\n",
            $dst_name_8, $fname, $actual_size, $start_clus;
    }

    # Allocate directory cluster
    my $self_cluster = $next_free_cluster;  # will be set by alloc
    my $dir_data = "";
    # . entry uses self_cluster (set during alloc)
    $dir_data .= make_entry(".          ", 0x10, 0, 0);   # placeholder: cluster filled in below
    $dir_data .= make_entry("..         ", 0x10, 0, 0);   # parent: filled in below
    for my $e (@dir_entries) {
        $dir_data .= $e;
    }

    # Allocate sector(s) for this directory
    my @dir_chunks;
    my $rem = $dir_data;
    while (length($rem) > 0) {
        push @dir_chunks, substr($rem . ("\x00" x SECTOR_SIZE), 0, SECTOR_SIZE);
        $rem = length($rem) > SECTOR_SIZE ? substr($rem, SECTOR_SIZE) : "";
    }

    # First alloc to get the cluster number
    my $first_cluster = $next_free_cluster;
    my @dclusters = alloc_cluster_chain(@dir_chunks);

    # Now fix . and .. cluster values in the first sector
    my $fixup = $cluster_data{$dclusters[0]};
    # . entry cluster at offset 26 (bytes)
    substr($fixup, 26, 2) = pack("v", $dclusters[0]);
    # .. entry cluster at offset 58 (32+26)
    substr($fixup, 58, 2) = pack("v", $parent_cluster);
    $cluster_data{$dclusters[0]} = $fixup;

    return ($dclusters[0], scalar @dir_entries);
}

# --------------------------------------------------------------------------
# Build SYSTEM32 directory: first pass to get cluster number for ..'s
# --------------------------------------------------------------------------
# We need to know sys32_cluster before building subdirs (for .. entries)
# So: allocate sys32_cluster slot first, then build subdirs, then fill sys32 dir

# Reserve sys32 cluster slot
my $sys32_cluster_num = $next_free_cluster;

# Build each subdirectory
print "[SYSTEM32] Embedding SYSTEM directory tree...\n";

for my $sdir (@sys_dirs) {
    my $src   = $sdir->{src};
    my $dname = $sdir->{dst};
    next unless -d $src;

    my ($first_clus, $nfiles) = embed_dir(
        $src, $dname, $sys32_cluster_num,
        $sdir->{max_files}, $sdir->{max_size}
    );
    next unless defined $first_clus;

    my $entry = make_entry($dname . "   ", 0x10, $first_clus, 0);
    push @sys32_subdir_entries, $entry;

    printf "[SYSTEM32] %-8s -> cluster %-4d (%d files)\n",
        $dname, $first_clus, $nfiles;
}

# --------------------------------------------------------------------------
# Also add a CMD\ top-level directory with sub-subdirectory entries for all CMD tools
# --------------------------------------------------------------------------
if (-d "$sys_root/CMD") {
    opendir(my $cdh, "$sys_root/CMD") or die;
    my @cmd_subdirs = grep { -d "$sys_root/CMD/$_" && !/^\./ } readdir($cdh);
    closedir($cdh);

    my @cmd_entries;
    for my $csub (sort @cmd_subdirs) {
        # Just add a stub directory entry pointing back to the already-embedded versions
        # (they were embedded under DSKCOPY, FORMAT, etc. above)
        my $fat_name = fat8_3($csub);
        # Stub: cluster 0 (no data — directory tree view only)
        push @cmd_entries, make_entry($fat_name, 0x10, 0, 0);
    }

    # Build CMD directory sector
    my $cmd_self = $next_free_cluster;
    my $cmd_dir = make_entry(".          ", 0x10, $cmd_self, 0)
                . make_entry("..         ", 0x10, $sys32_cluster_num, 0)
                . join("", @cmd_entries);

    my @cmd_chunks;
    while (length($cmd_dir) > 0) {
        push @cmd_chunks, substr($cmd_dir . ("\x00" x SECTOR_SIZE), 0, SECTOR_SIZE);
        $cmd_dir = length($cmd_dir) > SECTOR_SIZE ? substr($cmd_dir, SECTOR_SIZE) : "";
    }
    my @cmd_clist = alloc_cluster_chain(@cmd_chunks);
    # Fix . cluster
    my $cf = $cluster_data{$cmd_clist[0]};
    substr($cf, 26, 2) = pack("v", $cmd_clist[0]);
    $cluster_data{$cmd_clist[0]} = $cf;

    unshift @sys32_subdir_entries, make_entry("CMD        ", 0x10, $cmd_clist[0], 0);
    printf "[SYSTEM32] CMD     -> cluster %-4d (%d subdirs)\n",
        $cmd_clist[0], scalar @cmd_subdirs;
}

# --------------------------------------------------------------------------
# Build SYSTEM32 directory sector
# --------------------------------------------------------------------------
my $sys32_dir_data =
    make_entry(".          ", 0x10, $sys32_cluster_num, 0) .
    make_entry("..         ", 0x10, 0, 0) .
    join("", @sys32_subdir_entries);

my @sys32_chunks;
my $s32rem = $sys32_dir_data;
while (length($s32rem) > 0) {
    push @sys32_chunks, substr($s32rem . ("\x00" x SECTOR_SIZE), 0, SECTOR_SIZE);
    $s32rem = length($s32rem) > SECTOR_SIZE ? substr($s32rem, SECTOR_SIZE) : "";
}

# Force first cluster to be $sys32_cluster_num
# If next_free_cluster > sys32_cluster_num (subdirs already consumed it), we need to fix
my $actual_sys32_cluster;
if ($next_free_cluster == $sys32_cluster_num) {
    # No subdirs consumed it — allocate normally
    my @s32clist = alloc_cluster_chain(@sys32_chunks);
    $actual_sys32_cluster = $s32clist[0];
} else {
    # Subdirs consumed clusters already — just alloc new
    my @s32clist = alloc_cluster_chain(@sys32_chunks);
    $actual_sys32_cluster = $s32clist[0];
}

# Fix . cluster in SYSTEM32 directory
{
    my $fixup = $cluster_data{$actual_sys32_cluster};
    substr($fixup, 26, 2) = pack("v", $actual_sys32_cluster);
    $cluster_data{$actual_sys32_cluster} = $fixup;
}

printf "[SYSTEM32] Root dir at cluster %d, budget used: %dKB / 900KB\n",
    $actual_sys32_cluster, int($bytes_used / 1024);

# --------------------------------------------------------------------------
# Root directory: SYSTEM32 entry + kernel entry + overlays
# --------------------------------------------------------------------------
my $root_size = ROOT_DIR_SECTORS * SECTOR_SIZE;  # 7168
my $root = "\x00" x $root_size;

# Volume label entry
my $vol_entry = "KSDOS      " .
                "\x08" .
                "\x00" x 10 .
                pack("vv", 0, 0) .
                pack("vV", 0, 0);
$root = $vol_entry . substr($root, 32);

# KSDOS.SYS directory entry
my $date = encode_date(2024, 1, 1);
my $time = encode_time(0, 0, 0);
my $kern_entry =
    "KSDOS   SYS" .
    "\x27" .
    "\x00" x 8 .
    pack("v", 0) .
    pack("v", $time) .
    pack("v", $date) .
    pack("v", 2) .
    pack("V", $kernel_size);
substr($root, 32, 32) = $kern_entry;

# SYSTEM32 root entry
my $sys32_root_entry =
    "SYSTEM32   " .
    "\x10" .
    "\x00" x 8 .
    pack("v", 0) .
    pack("v", encode_time(0, 0, 0)) .
    pack("v", encode_date(2024, 1, 1)) .
    pack("v", $actual_sys32_cluster) .
    pack("V", 0);
substr($root, 64, 32) = $sys32_root_entry;

# --------------------------------------------------------------------------
# Process overlay files
# --------------------------------------------------------------------------
my @ovl_records;
$root_slot = 3;   # next free root slot (0=vol 1=kernel 2=sys32)

for my $ovl_path (@ovl_files) {
    my $basename = $ovl_path;
    $basename =~ s{.*/}{};
    $basename = uc($basename);
    my $fat_name = fat8_3($basename);

    my $data = read_file($ovl_path);
    my $size = length($data);
    my $sectors = int(($size + SECTOR_SIZE - 1) / SECTOR_SIZE);

    # Allocate cluster chain for overlay
    my $start_cluster = $next_free_cluster;
    for my $i (0 .. $sectors - 1) {
        my $clus = $next_free_cluster++;
        my $chunk_off = $i * SECTOR_SIZE;
        $cluster_data{$clus} = substr($data . ("\x00" x SECTOR_SIZE), $chunk_off, SECTOR_SIZE);
        set_fat12(\@fat, $clus, ($i == $sectors - 1) ? 0xFFF : $clus + 1);
    }

    if ($root_slot < ROOT_ENTRIES) {
        my $entry = make_entry($fat_name, 0x20, $start_cluster, $size);
        substr($root, $root_slot * 32, 32) = $entry;
        $root_slot++;
    } else {
        warn "Warning: root directory full, skipping $basename\n";
        next;
    }

    push @ovl_records, {
        data          => $data,
        fat_name      => $fat_name,
        start_cluster => $start_cluster,
        sectors       => $sectors,
        size          => $size,
    };

    printf "Overlay:     %-11s %d bytes (%d sectors, cluster %d)\n",
        $fat_name, $size, $sectors, $start_cluster;
}

# --------------------------------------------------------------------------
# Finalise FAT entries for SYSTEM32 cluster chain data
# --------------------------------------------------------------------------
for my $clus (sort { $a <=> $b } keys %cluster_data) {
    # FAT entries were set during alloc_cluster_chain — nothing more needed here
}

# --------------------------------------------------------------------------
# Assemble disk image
# --------------------------------------------------------------------------
my $fat_data = pack("C*", @fat);

my $img_size = TOTAL_SECTORS * SECTOR_SIZE;
my $img = "\x00" x $img_size;

# Boot sector
substr($img, 0, SECTOR_SIZE) = $bootsect;

# FAT1 and FAT2
substr($img, FAT_LBA * SECTOR_SIZE, 9 * SECTOR_SIZE) = $fat_data;
substr($img, (FAT_LBA + SECTORS_PER_FAT) * SECTOR_SIZE, 9 * SECTOR_SIZE) = $fat_data;

# Root directory
substr($img, ROOT_LBA * SECTOR_SIZE, $root_size) = $root;

# Kernel data
substr($img, DATA_LBA * SECTOR_SIZE, $kernel_size) = $kernel;

# All cluster data (kernel clusters were embedded above; SYSTEM32+overlays here)
for my $clus (sort { $a <=> $b } keys %cluster_data) {
    my $lba = DATA_LBA + ($clus - 2);
    if ($lba + 1 <= TOTAL_SECTORS) {
        substr($img, $lba * SECTOR_SIZE, SECTOR_SIZE) = $cluster_data{$clus};
    } else {
        warn "Warning: cluster $clus out of disk bounds (LBA $lba)\n";
    }
}

# Write output
open(my $fh, '>', $output_file) or die "Cannot write $output_file: $!";
binmode $fh;
print $fh $img;
close $fh;

printf "\nDisk image written: %s (%d bytes)\n", $output_file, length($img);
printf "  Kernel:     %d sectors (cluster 2)\n", $kernel_sectors;
printf "  SYSTEM32\\:  cluster %d (%d subdirs)\n", $actual_sys32_cluster, scalar @sys32_subdir_entries;
printf "  Overlays:   %d files\n", scalar @ovl_records;
printf "  SYSTEM32 data: ~%dKB embedded\n", int($bytes_used / 1024);

# --------------------------------------------------------------------------
# Subroutines
# --------------------------------------------------------------------------

sub read_file {
    my ($file, $min_size, $pad_byte) = @_;
    open(my $fh, '<', $file) or die "Cannot read $file: $!";
    binmode $fh;
    local $/;
    my $data = <$fh>;
    close $fh;
    if (defined $min_size && length($data) < $min_size) {
        $data .= chr($pad_byte // 0) x ($min_size - length($data));
    }
    return $data;
}

sub set_fat12 {
    my ($fat, $cluster, $value) = @_;
    my $offset = int($cluster * 3 / 2);
    if ($cluster % 2 == 0) {
        $fat->[$offset]     = $value & 0xFF;
        $fat->[$offset + 1] = ($fat->[$offset + 1] & 0xF0) | (($value >> 8) & 0x0F);
    } else {
        $fat->[$offset]     = ($fat->[$offset] & 0x0F) | (($value & 0x0F) << 4);
        $fat->[$offset + 1] = ($value >> 4) & 0xFF;
    }
}

sub encode_date {
    my ($year, $month, $day) = @_;
    return (($year - 1980) << 9) | ($month << 5) | $day;
}

sub encode_time {
    my ($hour, $min, $sec) = @_;
    return ($hour << 11) | ($min << 5) | int($sec / 2);
}
