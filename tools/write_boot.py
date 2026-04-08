#!/usr/bin/env python3
"""
write_boot.py - Write boot sector to FAT12 image
Usage: python write_boot.py --image disk.img --boot boot.bin
"""

import argparse
import sys

def write_boot_sector(image_path, boot_path):
    """Write boot sector to FAT12 image"""
    
    try:
        # Read boot sector
        with open(boot_path, 'rb') as f:
            boot_data = f.read()
        
        if len(boot_data) != 512:
            print(f"Error: Boot sector must be exactly 512 bytes (got {len(boot_data)})")
            return False
        
        # Read image
        with open(image_path, 'r+b') as f:
            # Write boot sector at beginning
            f.seek(0)
            f.write(boot_data)
            
            # Ensure boot signature
            f.seek(510)
            f.write(b'\x55\xAA')
        
        print(f"Boot sector written to {image_path}")
        return True
        
    except Exception as e:
        print(f"Error writing boot sector: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Write boot sector to FAT12 image')
    parser.add_argument('--image', required=True, help='FAT12 image file')
    parser.add_argument('--boot', required=True, help='Boot sector file')
    
    args = parser.parse_args()
    
    success = write_boot_sector(args.image, args.boot)
    sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
