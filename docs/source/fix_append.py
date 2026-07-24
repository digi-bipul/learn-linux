import os
import re
from pathlib import Path

# Configuration
ROOT_DIR = os.path.expanduser("~/learn-linux/docs/source")

# The Regex Pattern Explained:
# ^\s*       : Matches start of line + optional indentation spaces
# [A-Z]      : Matches a single uppercase letter (A, B, C, etc.)
# (?:\.\d+)+ : Matches one or more groups of a dot followed by digits (e.g., .1, .2.14)
# \s*        : Matches any trailing spaces
# Example matches: "A.1 ", "B.2.4 ", "C.10.1 "
PATTERN = re.compile(r'^\s*[A-Z](?:\.\d+)+\s*')

# SAFETY SWITCH: Set to True ONLY when you have reviewed the preview!
APPLY_CHANGES = True

def process_appendix_files():
    root_path = Path(ROOT_DIR)
    
    if not root_path.exists():
        print(f"Error: Directory {root_path} does not exist.")
        return

    # Find all .rst files, but ONLY if they are inside an "appendix" or "app_" folder
    all_rst_files = root_path.rglob("*.rst")
    appendix_files = [
        f for f in all_rst_files 
        if "appendix" in str(f.parent).lower() or "app_" in str(f.parent).lower()
    ]
    
    print(f"Found {len(appendix_files)} .rst files in appendix folders.")
    print("Scanning for A.1.x / B.1.x numbering...\n")

    total_changes = 0

    for file_path in appendix_files:
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except UnicodeDecodeError:
            continue

        new_lines = []
        file_modified = False

        for line_num, line in enumerate(lines, 1):
            if PATTERN.match(line):
                # Replace the matched A.x.x prefix with nothing
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

        # Overwrite the file only if the safety switch is ON
        if file_modified and APPLY_CHANGES:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)

    if not APPLY_CHANGES:
        print(f"--- DRY RUN COMPLETE ---")
        print(f"Found {total_changes} lines to modify.")
        print("To apply these changes, change 'APPLY_CHANGES = True' in the script and run it again.")
    else:
        print(f"--- MODIFICATIONS SAVED ---")
        print(f"Successfully cleaned up {total_changes} lines across your appendix files.")

if __name__ == "__main__":
    process_appendix_files()
