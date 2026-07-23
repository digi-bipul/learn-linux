#!/usr/bin/env fish
# check_headings.fish
# Scans ~/learn-linux/docs/source/chapter_*/*.rst for H1 titles that still
# contain a leading numeric pattern (e.g. "1.1 What is Linux"), and also
# flags files where the H1 underline length doesn't match the title text
# (which makes Sphinx silently fail to register the title at all).
#
# Usage:
#   fish check_headings.fish
#   fish check_headings.fish ~/some/other/source/root

set -l root $argv[1]
if test -z "$root"
    set root ~/learn-linux/docs/source
end

if not test -d $root
    echo "Root not found: $root"
    exit 1
end

set -l flagged_numbered 0
set -l flagged_no_title 0
set -l flagged_bad_underline 0

for f in $root/chapter_*/*.rst
    set -l line1 (sed -n '1p' $f)
    set -l line2 (sed -n '2p' $f)

    # No content at all
    if test -z "$line1"
        echo "[EMPTY]        $f"
        continue
    end

    # Underline must be =, -, ~, ^, " (Sphinx heading chars) and >= title length
    set -l underline_char (string sub -l 1 -- "$line2")
    if not string match -qr '^[=\-~^"]+$' -- "$line2"
        echo "[NO TITLE?]    $f  (line 2 isn't an underline: '$line2')"
        set flagged_no_title (math $flagged_no_title + 1)
        continue
    end

    set -l title_len (string length -- "$line1")
    set -l underline_len (string length -- "$line2")
    if test $underline_len -lt $title_len
        echo "[BAD UNDERLINE] $f  (title=$title_len chars, underline=$underline_len chars)"
        set flagged_bad_underline (math $flagged_bad_underline + 1)
    end

    # Leading number pattern like "1.1 " or "1.1_" or "1. "
    if string match -qr '^\s*\d+(\.\d+)*[\._ ]' -- "$line1"
        echo "[NUMBERED]     $f  -> '$line1'"
        set flagged_numbered (math $flagged_numbered + 1)
    end
end

echo ""
echo "Summary:"
echo "  Numbered H1s found:      $flagged_numbered"
echo "  Bad/missing underlines:  $flagged_bad_underline"
echo "  Possible missing titles: $flagged_no_title"
