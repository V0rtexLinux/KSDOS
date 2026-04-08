#!/usr/bin/env python3
"""
add_file.py - Add file to FAT12 image
Usage: python add_file.py --image disk.img --file program.bin --name "PROGRAM.EXE"
"""

import argparse
import struct
import sys
import os

class FAT12Image:
    def __init__(self, image_path):
        self.image_path = image_path
        with open(image_path, 'rb') as f:
            self.data = bytearray(f.read())
        
        # Parse BPB
        self.bytes_per_sector = struct.unpack_from('<H', self.data, 11)[0]
        self.sectors_per_fat = struct.unpack_from('<H', self.data, 22)[0]
        self.max_root_entries = struct.unpack_from('<H', self.data, 17)[0]
        self.fats = self.data[16]
        self.reserved_sectors = struct.unpack_from('<H', self.data, 14)[0]
        
        # Calculate offsets
        self.fat_start = self.reserved_sectors * self.bytes_per_sector
        self.root_start = self.fat_start + (self.fats * self.sectors_per_fat * self.bytes_per_sector)
        self.data_start = self.root_start + (self.max_root_entries * 32)
        
    def save(self):
        """Save image back to file"""
        with open(self.image_path, 'wb') as f:
            f.write(self.data)
    
    def find_free_cluster(self):
        """Find first free cluster in FAT"""
        fat_offset = self.fat_start
        
        for cluster in range(2, 0xFF0):  # FAT12 clusters start at 2
            fat_pos = fat_offset + (cluster * 3 // 2)
            
            if cluster % 2 == 0:
                cluster_value = struct.unpack_from('<H', self.data, fat_pos)[0] & 0x0FFF
            else:
                cluster_value = struct.unpack_from('<H', self.data, fat_pos)[0] >> 4
            
            if cluster_value == 0x000:  # Free cluster
                return cluster
        
        return None
    
    def set_fat_entry(self, cluster, value):
        """Set FAT entry for a cluster"""
        fat_offset = self.fat_start
        fat_pos = fat_offset + (cluster * 3 // 2)
        
        if cluster % 2 == 0:
            # Even cluster: low 12 bits
            current = struct.unpack_from('<H', self.data, fat_pos)[0]
            new_value = (current & 0xF000) | (value & 0x0FFF)
            struct.pack_into('<H', self.data, fat_pos, new_value)
        else:
            # Odd cluster: high 12 bits
            current = struct.unpack_from('<H', self.data, fat_pos)[0]
            new_value = (current & 0x000F) | ((value & 0x0FFF) << 4)
            struct.pack_into('<H', self.data, fat_pos, new_value)
        
        # Update all FAT copies
        for fat_num in range(1, self.fats):
            fat_copy_offset = fat_offset + (fat_num * self.sectors_per_fat * self.bytes_per_sector)
            fat_copy_pos = fat_copy_offset + (cluster * 3 // 2)
            
            if cluster % 2 == 0:
                struct.pack_into('<H', self.data, fat_copy_pos, new_value)
            else:
                struct.pack_into('<H', self.data, fat_copy_pos, new_value)
    
    def find_free_root_entry(self):
        """Find free entry in root directory"""
        for i in range(self.max_root_entries):
            entry_offset = self.root_start + (i * 32)
            first_byte = self.data[entry_offset]
            
            if first_byte == 0x00 or first_byte == 0xE5:
                return i
        
        return None
    
    def add_file(self, file_path, filename):
        """Add a file to the FAT12 image"""
        
        # Read file data
        with open(file_path, 'rb') as f:
            file_data = f.read()
        
        file_size = len(file_data)
        
        # Convert filename to 8.3 format
        if len(filename) > 12:
            print(f"Error: Filename too long: {filename}")
            return False
        
        # Split name and extension
        if '.' in filename:
            name_part, ext_part = filename.upper().split('.', 1)
        else:
            name_part = filename.upper()
            ext_part = ''
        
        # Pad to 8.3 format
        name_part = name_part.ljust(8)[:8]
        ext_part = ext_part.ljust(3)[:3]
        
        filename_83 = name_part + ext_part
        
        # Find free root entry
        root_entry = self.find_free_root_entry()
        if root_entry is None:
            print("Error: No free root directory entries")
            return False
        
        # Calculate clusters needed
        bytes_per_cluster = self.bytes_per_sector  # Assuming 1 sector per cluster
        clusters_needed = (file_size + bytes_per_cluster - 1) // bytes_per_cluster
        
        # Find free clusters
        clusters = []
        for _ in range(clusters_needed):
            cluster = self.find_free_cluster()
            if cluster is None:
                print("Error: Not enough free space")
                return False
            clusters.append(cluster)
        
        # Write file data to clusters
        for i, cluster in enumerate(clusters):
            cluster_offset = self.data_start + ((cluster - 2) * bytes_per_cluster)
            start_pos = i * bytes_per_cluster
            end_pos = min(start_pos + bytes_per_cluster, file_size)
            
            if start_pos < file_size:
                self.data[cluster_offset:cluster_offset + (end_pos - start_pos)] = file_data[start_pos:end_pos]
        
        # Update FAT chain
        for i, cluster in enumerate(clusters):
            if i == len(clusters) - 1:
                # Last cluster - mark as end of chain
                self.set_fat_entry(cluster, 0xFFF)
            else:
                # Point to next cluster
                self.set_fat_entry(cluster, clusters[i + 1])
        
        # Create directory entry
        entry_offset = self.root_start + (root_entry * 32)
        
        # Filename (8.3)
        self.data[entry_offset:entry_offset + 11] = filename_83.encode('ascii')
        
        # Attributes (archive file)
        self.data[entry_offset + 11] = 0x20
        
        # Reserved
        self.data[entry_offset + 12] = 0x00
        
        # Creation time (simplified)
        import time
        now = time.localtime()
        time_val = (now.tm_hour << 11) | (now.tm_min << 5) | (now.tm_sec // 2)
        struct.pack_into('<H', self.data, entry_offset + 14, time_val)
        
        # Creation date
        date_val = ((now.tm_year - 1980) << 9) | (now.tm_mon << 5) | now.tm_mday
        struct.pack_into('<H', self.data, entry_offset + 16, date_val)
        
        # Last access date
        struct.pack_into('<H', self.data, entry_offset + 18, date_val)
        
        # Starting cluster
        struct.pack_into('<H', self.data, entry_offset + 26, clusters[0])
        
        # File size
        struct.pack_into('<L', self.data, entry_offset + 28, file_size)
        
        # Save image
        self.save()
        
        print(f"Added {filename} ({file_size} bytes, {len(clusters)} clusters)")
        return True

def main():
    parser = argparse.ArgumentParser(description='Add file to FAT12 image')
    parser.add_argument('--image', required=True, help='FAT12 image file')
    parser.add_argument('--file', required=True, help='File to add')
    parser.add_argument('--name', required=True, help='Filename in image (8.3 format)')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.file):
        print(f"Error: File not found: {args.file}")
        sys.exit(1)
    
    if not os.path.exists(args.image):
        print(f"Error: Image not found: {args.image}")
        sys.exit(1)
    
    try:
        img = FAT12Image(args.image)
        success = img.add_file(args.file, args.name)
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
