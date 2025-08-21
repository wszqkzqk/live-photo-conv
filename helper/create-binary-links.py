#!/usr/bin/env python3
"""
Cross-platform script to create links/copies of the main binary with different names.
On Windows: creates copies
On Unix-like systems: creates symbolic links
"""

import sys
import shutil
import platform
from pathlib import Path


def create_binary_link(source_binary, target_name):
    """Create a link or copy of the source binary with the target name."""
    source_path = Path(source_binary)
    target_path = Path(target_name)
    
    # Remove target if it already exists
    if target_path.exists():
        target_path.unlink()
    
    try:
        if platform.system() == 'Windows':
            # On Windows, create a copy
            shutil.copy2(source_path, target_path)
            print(f"Created copy: {target_path}")
        else:
            # On Unix-like systems, create a symbolic link
            # Use relative path for the symlink to make it portable
            source_name = source_path.name
            target_path.symlink_to(source_name)
            print(f"Created symlink: {target_path} -> {source_name}")
        
        return True
    except Exception as e:
        print(f"Error creating link/copy {target_path}: {e}", file=sys.stderr)
        return False


def main():
    if len(sys.argv) < 3:
        print("Usage: create_binary_links.py <source_binary> <target1> [target2] ...", file=sys.stderr)
        sys.exit(1)
    
    source_binary = sys.argv[1]
    target_names = sys.argv[2:]

    success = True
    for target_name in target_names:
        if not create_binary_link(source_binary, target_name):
            success = False
    
    if not success:
        sys.exit(1)


if __name__ == '__main__':
    main()
