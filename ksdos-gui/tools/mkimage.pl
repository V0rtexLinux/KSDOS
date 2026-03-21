#!/usr/bin/perl
# =============================================================================
# KSDOS - Disk Image Builder
# Creates a 1.44MB FAT12 floppy image with:
#   Sector 0:    bootsect.bin (boot sector with FAT12 BPB)
#   Sectors 1-9: FAT1
#   Sectors 10-18: FAT2
#   Sectors 19-32: Root directory
#   Sector 33+:  KSDOS.SYS kernel
#   Following:   Overlay .OVL files
#
# Usage: perl mkimage.pl <bootsect.bin> <ksdos.bin> <output.img> [ovl1.OVL ...]
# =============================================================================
use strict;
use warnings;

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

my $fat_data = pack("C*", @fat);

# --------------------------------------------------------------------------
# Build Root Directory
# --------------------------------------------------------------------------
my $root_size = ROOT_DIR_SECTORS * SECTOR_SIZE;  # 7168
my $root = "\x00" x $root_size;

# --------------------------------------------------------------------------
# Helper: build a 32-byte FAT12 directory entry
# --------------------------------------------------------------------------
sub make_entry {
    my ($name, $attr, $cluster, $size) = @_;
    my $n11 = substr($name . (" " x 11), 0, 11);
    return $n11 .
           chr($attr) .
           "\x00" x 8 .
           pack("v", encode_time(0, 0, 0)) .
           pack("v", encode_date(2024, 1, 1)) .
           pack("v", $cluster) .
           pack("V", $size);
}

# ── Root directory entries ─────────────────────────────────────────────────
# Slot 0: Volume label
my $vol_entry =
    "KSDOS      " .         # 11 bytes: volume label
    "\x08" .                # attr: volume label
    "\x00" x 8 .
    pack("vv", 0, 0) .
    pack("vV", 0, 0);
substr($root, 0, 32) = $vol_entry;

# Slot 1: IO.SYS  (hidden + system + read-only = 0x07; boot loader stub)
substr($root, 32, 32) = make_entry("IO      SYS", 0x07, 2, $kernel_size);

# Slot 2: KSDOS.SYS  (hidden + system + read-only + archive = 0x27)
substr($root, 64, 32) = make_entry("KSDOS   SYS", 0x27, 2, $kernel_size);

# Slot 3: COMMAND.COM
substr($root, 96, 32) = make_entry("COMMAND COM", 0x20, 2, $kernel_size);

# Slot 4: CONFIG.SYS  (stub, empty file — cluster 0 means no data)
substr($root, 128, 32) = make_entry("CONFIG  SYS", 0x20, 0, 0);

# Slot 5: AUTOEXEC.BAT
substr($root, 160, 32) = make_entry("AUTOEXECBAT", 0x20, 0, 0);

# --------------------------------------------------------------------------
# DOS directory — cluster immediately after kernel
# --------------------------------------------------------------------------
my $next_free_cluster = 2 + $kernel_clusters;
my $dos_cluster = $next_free_cluster++;

set_fat12(\@fat, $dos_cluster, 0xFFF);

# DOS directory sector: . and .. plus MS-DOS utilities as stub entries
my @dos_entries = (
    make_entry(".          ", 0x10, $dos_cluster, 0),  # .
    make_entry("..         ", 0x10, 0,            0),  # ..
    make_entry("FORMAT  COM", 0x20, 0,            0),
    make_entry("CHKDSK  EXE", 0x20, 0,            0),
    make_entry("FDISK   EXE", 0x20, 0,            0),
    make_entry("EDIT    EXE", 0x20, 0,            0),
    make_entry("XCOPY   EXE", 0x20, 0,            0),
    make_entry("MORE    COM", 0x20, 0,            0),
    make_entry("ATTRIB  EXE", 0x20, 0,            0),
    make_entry("SORT    EXE", 0x20, 0,            0),
    make_entry("FIND    EXE", 0x20, 0,            0),
    make_entry("DEBUG   EXE", 0x20, 0,            0),
    make_entry("DISKCOPY COM", 0x20, 0,           0),
    make_entry("LABEL   COM", 0x20, 0,            0),
    make_entry("MEM     EXE", 0x20, 0,            0),
    make_entry("SCANDISK EXE", 0x20, 0,           0),
);
my $dos_data = join("", @dos_entries);
$dos_data = substr($dos_data . ("\x00" x SECTOR_SIZE), 0, SECTOR_SIZE);

# Slot 6: DOS directory root entry
substr($root, 192, 32) = make_entry("DOS        ", 0x10, $dos_cluster, 0);

printf "DOS dir:     cluster %d (sector %d)\n",
       $dos_cluster, DATA_LBA + ($dos_cluster - 2);

# --------------------------------------------------------------------------
# Process overlay files — allocate clusters and add root directory entries
# --------------------------------------------------------------------------
my @ovl_records;  # each: { data, fat_name, start_cluster, sectors }

my $root_slot = 7;  # next free root entry (slots 0-6 used above)

for my $ovl_path (@ovl_files) {
    # Derive FAT 8.3 name from filename (e.g. "CC.OVL" -> "CC      OVL")
    my $basename = $ovl_path;
    $basename =~ s{.*/}{};          # strip directory
    $basename = uc($basename);
    my ($stem, $ext) = split(/\./, $basename, 2);
    $stem //= "";
    $ext  //= "";
    $stem = substr($stem . "        ", 0, 8);
    $ext  = substr($ext  . "   ",      0, 3);
    my $fat_name = $stem . $ext;    # 11 bytes

    my $data = read_file($ovl_path);
    my $size = length($data);
    my $sectors = int(($size + SECTOR_SIZE - 1) / SECTOR_SIZE);

    # Allocate cluster chain
    my $start_cluster = $next_free_cluster;
    for my $i (0 .. $sectors - 1) {
        my $clus = $next_free_cluster++;
        set_fat12(\@fat, $clus, ($i == $sectors - 1) ? 0xFFF : $clus + 1);
    }

    # Add root directory entry
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
# Assemble disk image
# --------------------------------------------------------------------------
my $img_size = TOTAL_SECTORS * SECTOR_SIZE;
my $img = "\x00" x $img_size;

# Rebuild fat_data with all entries
$fat_data = pack("C*", @fat);

# Write boot sector (sector 0)
substr($img, 0, SECTOR_SIZE) = $bootsect;

# Write FAT1 (sectors 1-9)
substr($img, FAT_LBA * SECTOR_SIZE, 9 * SECTOR_SIZE) = $fat_data;

# Write FAT2 (sectors 10-18) - identical copy
substr($img, (FAT_LBA + SECTORS_PER_FAT) * SECTOR_SIZE, 9 * SECTOR_SIZE) = $fat_data;

# Write Root Directory (sectors 19-32)
substr($img, ROOT_LBA * SECTOR_SIZE, $root_size) = $root;

# Write kernel at data area (sector 33+)
substr($img, DATA_LBA * SECTOR_SIZE, $kernel_size) = $kernel;

# Write C:\DOS directory cluster (immediately after kernel)
my $dos_lba = DATA_LBA + ($dos_cluster - 2);
substr($img, $dos_lba * SECTOR_SIZE, SECTOR_SIZE) = $dos_data;

# Write each overlay at its allocated LBA
for my $rec (@ovl_records) {
    my $lba = DATA_LBA + ($rec->{start_cluster} - 2);
    substr($img, $lba * SECTOR_SIZE, $rec->{size}) = $rec->{data};
}

# Write output
open(my $fh, '>', $output_file) or die "Cannot write $output_file: $!";
binmode $fh;
print $fh $img;
close $fh;

printf "Disk image written: %s (%d bytes)\n", $output_file, length($img);
printf "  Sector 0:    Boot sector\n";
printf "  Sectors 1-9: FAT1\n";
printf "  Sectors 10-18: FAT2\n";
printf "  Sectors 19-32: Root directory\n";
printf "  Sector 33+:  KSDOS.SYS (%d sectors, cluster 2)\n", $kernel_sectors;
printf "  Sector %d:    C:\\DOS\\ directory (cluster %d)\n", $dos_lba, $dos_cluster;
for my $rec (@ovl_records) {
    my $lba = DATA_LBA + ($rec->{start_cluster} - 2);
    printf "  Sector %d:    %-11s (%d sectors, cluster %d)\n",
        $lba, $rec->{fat_name}, $rec->{sectors}, $rec->{start_cluster};
}

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
