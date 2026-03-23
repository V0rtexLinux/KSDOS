#!/usr/bin/env python3
"""
create_fat12.py - Create FAT12 floppy disk image
Usage: python create_fat12.py --size 1474560 --output disk.img --label "MS-DOS 6.22"
"""

import argparse
import struct
import os
import sys

def create_fat12_image(size, output_path, label="MSDOS"):
    """Create a basic FAT12 floppy disk image"""
    
    # FAT12 parameters for 1.44MB floppy
    bytes_per_sector = 512
    sectors_per_fat = 9
    sectors_per_track = 18
    heads = 2
    reserved_sectors = 1
    fats = 2
    max_root_entries = 224
    total_sectors = 2880
    
    # Calculate layout
    fat_start = reserved_sectors * bytes_per_sector
    root_start = fat_start + (fats * sectors_per_fat * bytes_per_sector)
    data_start = root_start + (max_root_entries * 32)
    
    # Create blank image
    image_data = bytearray(b'\xF6') * (total_sectors * bytes_per_sector)
    
    # Create BIOS Parameter Block (BPB)
    bpb = bytearray(62)  # Standard BPB size
    
    # OEM name
    bpb[0:3] = b'MSD'
    
    # Bytes per sector
    struct.pack_into('<H', bpb, 11, bytes_per_sector)
    
    # Sectors per cluster
    bpb[13] = 1
    
    # Reserved sectors
    struct.pack_into('<H', bpb, 14, reserved_sectors)
    
    # Number of FATs
    bpb[16] = fats
    
    # Max root entries
    struct.pack_into('<H', bpb, 17, max_root_entries)
    
    # Total sectors (if < 65536)
    if total_sectors < 65536:
        struct.pack_into('<H', bpb, 19, total_sectors)
    
    # Media descriptor
    bpb[21] = 0xF0
    
    # Sectors per FAT
    struct.pack_into('<H', bpb, 22, sectors_per_fat)
    
    # Sectors per track
    struct.pack_into('<H', bpb, 24, sectors_per_track)
    
    # Number of heads
    struct.pack_into('<H', bpb, 26, heads)
    
    # Hidden sectors (for floppies, usually 0)
    struct.pack_into('<L', bpb, 28, 0)
    
    # Total sectors (large)
    if total_sectors >= 65536:
        struct.pack_into('<L', bpb, 32, total_sectors)
    
    # Drive number
    bpb[36] = 0x00
    
    # Extended boot signature
    bpb[38] = 0x29
    
    # Volume serial number
    import time
    serial = int(time.time()) & 0xFFFFFFFF
    struct.pack_into('<L', bpb, 39, serial)
    
    # Volume label (11 bytes, space padded)
    vol_label = label.upper().ljust(11)[:11]
    bpb[43:54] = vol_label.encode('ascii')
    
    # File system type
    bpb[54:62] = b'FAT12   '
    
    # Write BPB to image
    image_data[0:62] = bpb
    
    # Boot signature
    image_data[510] = 0x55
    image_data[511] = 0xAA
    
    # Initialize FAT tables
    fat_data = bytearray(sectors_per_fat * bytes_per_sector)
    
    # First two FAT entries are special
    fat_data[0] = 0xF0  # Media descriptor
    fat_data[1] = 0xFF  # End of cluster chain marker
    fat_data[2] = 0xFF
    
    # Write FAT tables
    for i in range(fats):
        fat_offset = fat_start + (i * sectors_per_fat * bytes_per_sector)
        image_data[fat_offset:fat_offset + len(fat_data)] = fat_data
    
    # Initialize root directory (all entries empty)
    root_dir_data = bytearray(max_root_entries * 32)
    image_data[root_start:root_start + len(root_dir_data)] = root_dir_data
    
    # Write image to file
    with open(output_path, 'wb') as f:
        f.write(image_data)
    
    print(f"Created FAT12 image: {output_path} ({len(image_data)} bytes)")
    return True

def main():
    parser = argparse.ArgumentParser(description='Create FAT12 floppy disk image')
    parser.add_argument('--size', type=int, default=1474560, help='Image size in bytes')
    parser.add_argument('--output', required=True, help='Output image file')
    parser.add_argument('--label', default='MSDOS', help='Volume label')
    
    args = parser.parse_args()
    
    try:
        create_fat12_image(args.size, args.output, args.label)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
