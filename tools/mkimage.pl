#!/usr/bin/perl
# =============================================================================
# KSDOS - Disk Image Builder
# Creates a 1.44MB FAT12 floppy image with:
#   Sector 0:    bootsect.bin (boot sector with FAT12 BPB)
#   Sectors 1-9: FAT1
#   Sectors 10-18: FAT2
#   Sectors 19-32: Root directory
#   Sector 33+:  KSDOS.SYS kernel
#
# Usage: perl mkimage.pl <bootsect.bin> <ksdos.bin> <output.img>
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

my ($bootsect_file, $kernel_file, $output_file) = @ARGV;
die "Usage: $0 <bootsect.bin> <kernel.bin> <output.img>\n" unless @ARGV == 3;

# --------------------------------------------------------------------------
# Read input files
# --------------------------------------------------------------------------
my $bootsect = read_file($bootsect_file, SECTOR_SIZE, 0x00);
my $kernel   = read_file($kernel_file);

die "Boot sector must be exactly 512 bytes (got " . length($bootsect) . ")\n"
    unless length($bootsect) == SECTOR_SIZE;
die "Boot sector missing signature 0xAA55\n"
    unless substr($bootsect, 510, 2) eq "\x55\xAA";

my $kernel_size    = length($kernel);
my $kernel_sectors = int(($kernel_size + SECTOR_SIZE - 1) / SECTOR_SIZE);
my $kernel_clusters = $kernel_sectors;  # spc=1

printf "Boot sector: %d bytes\n", length($bootsect);
printf "Kernel:      %d bytes (%d sectors / clusters)\n", $kernel_size, $kernel_sectors;
printf "Data area starts at sector %d\n", DATA_LBA;

# --------------------------------------------------------------------------
# Build FAT (FAT12, 512 bytes per cluster = 1 sector)
# FAT occupies 9 sectors = 4608 bytes
# Cluster 0: media byte 0xF0 + 0xFF (high nibble)
# Cluster 1: 0xFF (reserved)
# Clusters 2..2+N-2: chain
# Cluster 2+N-1: 0xFFF (end of chain)
# --------------------------------------------------------------------------
my $fat_bytes = 9 * SECTOR_SIZE;  # 4608 bytes
my @fat = (0) x $fat_bytes;

# Entry 0: media descriptor + 0xFF
set_fat12(\@fat, 0, 0xFF0 | MEDIA_BYTE);
# Entry 1: end-of-chain marker
set_fat12(\@fat, 1, 0xFFF);

# Cluster chain for KSDOS.SYS starting at cluster 2
for my $i (0 .. $kernel_clusters - 1) {
    my $clus = $i + 2;
    if ($i == $kernel_clusters - 1) {
        set_fat12(\@fat, $clus, 0xFFF);  # end of chain
    } else {
        set_fat12(\@fat, $clus, $clus + 1);
    }
}

my $fat_data = pack("C*", @fat);

# --------------------------------------------------------------------------
# Build Root Directory (14 sectors = 7168 bytes)
# Entry 0: Volume label "KSDOS      "
# Entry 1: KSDOS   SYS
# --------------------------------------------------------------------------
my $root_size = ROOT_DIR_SECTORS * SECTOR_SIZE;  # 7168
my $root = "\x00" x $root_size;

# Volume label entry (attribute 0x08 = volume label)
my $vol_entry = "KSDOS      " .  # 11 bytes
                "\x08" .         # attribute: volume label
                "\x00" x 10 .    # reserved
                pack("vv", 0, 0) . # time, date
                pack("vV", 0, 0);  # start cluster, size
$root = $vol_entry . substr($root, 32);

# KSDOS.SYS directory entry
my $date = encode_date(2024, 1, 1);  # Jan 1, 2024
my $time = encode_time(0, 0, 0);     # 00:00:00
my $kern_entry =
    "KSDOS   SYS" .                  # 11 bytes 8+3 name
    "\x27" .                         # attribute: archive+system+hidden
    "\x00" x 8 .                     # reserved + time tenths + access date
    pack("v", 0) .                   # extended attr cluster (high word - FAT12=0)
    pack("v", $time) .               # write time
    pack("v", $date) .               # write date
    pack("v", 2) .                   # starting cluster = 2
    pack("V", $kernel_size);         # file size

# Insert kern_entry at offset 32 (after volume label)
substr($root, 32, 32) = $kern_entry;

# --------------------------------------------------------------------------
# SYSTEM32 directory
# Cluster immediately after the kernel occupies one cluster (512 bytes)
# --------------------------------------------------------------------------
my $sys32_cluster = 2 + $kernel_clusters;   # first free cluster after kernel

# Mark SYSTEM32 dir cluster as end-of-chain in FAT
set_fat12(\@fat, $sys32_cluster, 0xFFF);

# Build the SYSTEM32 directory cluster (512 bytes = 16 entries)
my $sys32_dir = "\x00" x SECTOR_SIZE;

# Helper: build a 32-byte directory entry
# name8_3 = 11 chars, attr, start_cluster, size
sub make_entry {
    my ($name, $attr, $cluster, $size) = @_;
    return substr($name . (" " x 11), 0, 11) .  # 11-byte name
           chr($attr) .                           # attribute
           "\x00" x 8 .                           # reserved
           pack("v", 0) .                         # ext attr cluster (hi word)
           pack("v", encode_time(0, 0, 0)) .      # write time
           pack("v", encode_date(2024, 1, 1)) .   # write date
           pack("v", $cluster) .                  # start cluster
           pack("V", $size);                      # file size
}

# "." and ".." entries
my $dot_entry   = make_entry(".          ", 0x10, $sys32_cluster, 0);
my $dotdot_entry = make_entry("..         ", 0x10, 0, 0);

# System file stubs (size = 0, cluster = 0 => empty files)
my $ksdos_sys  = make_entry("KSDOS   SYS", 0x27, 2, $kernel_size);  # ref to kernel
my $command_sys = make_entry("COMMAND SYS", 0x27, 2, $kernel_size); # alias
my $himem_sys  = make_entry("HIMEM   SYS", 0x06, 0, 0);
my $emm386_sys = make_entry("EMM386  SYS", 0x06, 0, 0);
my $cc_exe     = make_entry("CC      EXE", 0x20, 0, 0);
my $cpp_exe    = make_entry("CPP     EXE", 0x20, 0, 0);
my $masm_exe   = make_entry("MASM    EXE", 0x20, 0, 0);
my $csc_exe    = make_entry("CSC     EXE", 0x20, 0, 0);

# Pack entries into the 512-byte sector
my @sys32_entries = (
    $dot_entry, $dotdot_entry,
    $ksdos_sys, $command_sys,
    $himem_sys, $emm386_sys,
    $cc_exe, $cpp_exe, $masm_exe, $csc_exe,
);
my $sys32_data = join("", @sys32_entries);
# Pad/truncate to 512 bytes
$sys32_data = substr($sys32_data . ("\x00" x SECTOR_SIZE), 0, SECTOR_SIZE);

# SYSTEM32 directory entry in root (attr 0x10 = directory)
my $sys32_root_entry =
    "SYSTEM32   " .                  # 11 bytes name
    "\x10" .                         # attribute: directory
    "\x00" x 8 .                     # reserved
    pack("v", 0) .                   # ext attr cluster
    pack("v", encode_time(0,0,0)) .  # write time
    pack("v", encode_date(2024,1,1)) . # write date
    pack("v", $sys32_cluster) .      # starting cluster
    pack("V", 0);                    # size (directories = 0)

# Insert at offset 64 (3rd root entry, after vol label and KSDOS.SYS)
substr($root, 64, 32) = $sys32_root_entry;

# --------------------------------------------------------------------------
# Assemble disk image
# --------------------------------------------------------------------------
my $img_size = TOTAL_SECTORS * SECTOR_SIZE;  # 1,474,560 bytes
my $img = "\x00" x $img_size;

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

# Write SYSTEM32 directory cluster (immediately after kernel)
my $sys32_lba = DATA_LBA + $kernel_sectors;
substr($img, $sys32_lba * SECTOR_SIZE, SECTOR_SIZE) = $sys32_data;

# Rebuild fat_data with SYSTEM32 cluster included
$fat_data = pack("C*", @fat);
# Rewrite FAT1 and FAT2
substr($img, FAT_LBA * SECTOR_SIZE, 9 * SECTOR_SIZE) = $fat_data;
substr($img, (FAT_LBA + SECTORS_PER_FAT) * SECTOR_SIZE, 9 * SECTOR_SIZE) = $fat_data;

# Write output
open(my $fh, '>', $output_file) or die "Cannot write $output_file: $!";
binmode $fh;
print $fh $img;
close $fh;

printf "Disk image written: %s (%d bytes)\n", $output_file, length($img);
printf "  Sector 0:    Boot sector\n";
printf "  Sectors 1-9: FAT1\n";
printf "  Sectors 10-18: FAT2\n";
printf "  Sectors 19-32: Root directory (vol label + KSDOS.SYS + SYSTEM32)\n";
printf "  Sector 33+:  KSDOS.SYS (%d sectors, cluster 2)\n", $kernel_sectors;
printf "  Sector %d:    SYSTEM32\\ directory (cluster %d)\n", $sys32_lba, $sys32_cluster;

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

# Set a FAT12 entry
sub set_fat12 {
    my ($fat, $cluster, $value) = @_;
    my $offset = int($cluster * 3 / 2);
    if ($cluster % 2 == 0) {
        # Even: lower 12 bits
        $fat->[$offset]     = $value & 0xFF;
        $fat->[$offset + 1] = ($fat->[$offset + 1] & 0xF0) | (($value >> 8) & 0x0F);
    } else {
        # Odd: upper 12 bits
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
