import os
import re
from pathlib import Path

# Configuration
# Expands the ~ to your actual home directory path
ROOT_DIR = os.path.expanduser("~/learn-linux/docs/source")

# The Regex Pattern Explained:
# ^\s*       : Matches start of line + optional indentation spaces
# \d+        : Matches one or more starting digits (e.g., 3, 4, 12)
# (?:\.\d+)+ : Matches one or more groups of a dot followed by digits (e.g., .1, .1.0)
# \s*        : Matches any trailing spaces
# Note: This safely matches "3.1.0 " or "4.2 ", but intentionally ignores "1. " (normal lists).
PATTERN = re.compile(r'^\s*\d+(?:\.\d+)+\s*')

# SAFETY SWITCH: Set to True ONLY when you have reviewed the preview and are ready!
APPLY_CHANGES = True

def process_files():
    root_path = Path(ROOT_DIR)
    
    if not root_path.exists():
        print(f"Error: Directory {root_path} does not exist.")
        return

    # Recursively find all .rst files in the directories (chapter_01, appendix_a, etc.)
    rst_files = list(root_path.rglob("*.rst"))
    print(f"Found {len(rst_files)} .rst files. Scanning for hardcoded numbering...\n")

    total_changes = 0

    for file_path in rst_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except UnicodeDecodeError:
            continue

        new_lines = []
        file_modified = False

        for line_num, line in enumerate(lines, 1):
            if PATTERN.match(line):
                # Replace the matched prefix with nothing
                new_line = PATTERN.sub('', line, count=1)
                new_lines.append(new_line)
                file_modified = True
                total_changes += 1
                
                # Print a clean preview of what is changing
                if not APPLY_CHANGES:
                    print(f"File: {file_path.relative_to(root_path)} (Line {line_num})")
                    print(f"  [-] {line.rstrip()}")
                    print(f"  [+] {new_line.rstrip()}\n")
            else:
                new_lines.append(line)

        # Only overwrite the file if the safety switch is ON
        if file_modified and APPLY_CHANGES:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)

    if not APPLY_CHANGES:
        print(f"--- DRY RUN COMPLETE ---")
        print(f"Found {total_changes} lines to modify.")
        print("To apply these changes, open the script, change 'APPLY_CHANGES = True', and run it again.")
    else:
        print(f"--- MODIFICATIONS SAVED ---")
        print(f"Successfully cleaned up {total_changes} lines across your files.")

if __name__ == "__main__":
    process_files()
