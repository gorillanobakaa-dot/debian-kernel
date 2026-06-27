#!/usr/bin/env python3
import os
import sys
import shutil
import re

def parse_registry(registry_path):
    registry = {}
    if not os.path.exists(registry_path):
        return registry
    pattern = re.compile(r'(?:\*\s+)?`?([a-zA-Z0-9_\-\.]+)\`?\s*->\s*`?([a-zA-Z0-9_\-\./]+)`?')
    with open(registry_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            match = pattern.match(line)
            if match:
                src, dest = match.groups()
                registry[src] = dest
    return registry

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 universal_freedom_installer.py <path_to_kernel_source_root>")
        sys.exit(1)
        
    kernel_root = os.path.abspath(sys.argv[1])
    if not os.path.isdir(kernel_root):
        print(f"Error: Target directory '{kernel_root}' does not exist or is not a directory.")
        sys.exit(1)
        
    script_dir = os.path.dirname(os.path.abspath(__file__))
    registry_path = os.path.join(script_dir, "PATCHED_FILES_PATH_REGISTRY.txt")
    
    registry = {
        "reg.c": "net/wireless/reg.c",
        "hw.c": "drivers/net/wireless/ath/ath9k/hw.c",
        "tcp.h": "include/net/tcp.h",
        "tcp.c": "net/ipv4/tcp.c",
        "init.c": "drivers/net/wireless/ath/ath9k/init.c",
        "gpio.c": "drivers/net/wireless/ath/ath9k/gpio.c",
        "btcoex.c": "drivers/net/wireless/ath/ath9k/btcoex.c",
        "alc269.c": "sound/hda/codecs/realtek/alc269.c"
    }
    
    parsed = parse_registry(registry_path)
    if parsed:
        registry.update(parsed)
        print(f"Loaded registry from {registry_path}")
    else:
        print("Using built-in registry map.")
        
    print(f"Target Kernel Source Tree: {kernel_root}")
    print("----------------------------------------")
    
    success_count = 0
    for filename, rel_path in registry.items():
        src_file = os.path.join(script_dir, filename)
        dest_file = os.path.join(kernel_root, rel_path)
        
        if not os.path.exists(src_file):
            print(f"⚠️  Skipping: '{filename}' not found in script directory.")
            continue
            
        os.makedirs(os.path.dirname(dest_file), exist_ok=True)
        
        if os.path.exists(dest_file):
            backup_file = dest_file + ".orig_backup"
            if not os.path.exists(backup_file):
                print(f"💾 Backing up original '{rel_path}' to '{rel_path}.orig_backup'")
                shutil.copy2(dest_file, backup_file)
                
        print(f"🚀 Patching '{rel_path}'...")
        try:
            shutil.copy2(src_file, dest_file)
            success_count += 1
        except Exception as e:
            print(f"❌ Failed to copy '{filename}' to '{rel_path}': {e}")
            
    print("----------------------------------------")
    print(f"Patching completed: {success_count}/{len(registry)} files successfully patched.")

if __name__ == '__main__':
    main()
