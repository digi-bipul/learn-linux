===========================================
2.4 Text Processing Toolchest
===========================================

.. sidebar:: In This Section

   * ``grep`` — pattern matching and regular expressions
   * ``sort`` — ordering lines
   * ``uniq`` — deduplication and counting
   * ``wc`` — line/word/character counting
   * ``cut`` — column extraction
   * ``tr`` — character translation
   * ``diff``, ``comm`` — comparing files
   * ``join``, ``paste`` — merging files
   * ``split`` — breaking files apart

---

The Unix toolchest is a set of small, focused programs that each do one thing
well and can be combined via pipes. This section is not a dry man-page
recitation — it is a curated guide to the options and patterns you will use
every day, with emphasis on *why* certain flags exist and when to reach for
each tool.

.. _grep:

``grep`` — Global Regular Expression Print
============================================

``grep`` searches text for lines matching a pattern and prints them. Its name
comes from the ``ed`` editor command ``g/re/p`` (globally search for a regular
expression and print). It is arguably the single most-used command in a
sysadmin's arsenal.

Basic Usage
------------

.. code-block:: bash

    $ grep pattern file.txt                # search a file
    $ grep pattern file1.txt file2.txt     # search multiple files
    $ grep -r pattern /etc/                # recursive search
    $ command | grep pattern               # filter pipeline output

Essential Options
------------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Option
     - Purpose and Notes
   * - ``-i``
     - Case-insensitive matching. ``grep -i error log`` matches ERROR,
       Error, error.
   * - ``-v``
     - **Invert match.** Print lines that do NOT match. The single most
       useful filter: ``ps aux | grep -v grep`` removes the grep process
       itself from results.
   * - ``-n``
     - Prefix each match with its line number.
   * - ``-c``
     - Print only the **count** of matching lines, not the lines themselves.
   * - ``-l``
     - Print only **filenames** containing matches (not the matching lines).
   * - ``-w``
     - Match **whole words** only. ``grep -w 'port'`` matches "port" but not
       "report" or "support".
   * - ``-x``
     - Match **whole lines** only. The entire line must match the pattern.
   * - ``-r`` / ``-R``
     - Recursive directory search. ``-R`` follows symlinks.
   * - ``--color=auto``
     - Highlight matched text (often aliased by default in modern distros).
   * - ``-A N``
     - Print N lines of context **after** each match.
   * - ``-B N``
     - Print N lines of context **before** each match.
   * - ``-C N``
     - Print N lines of context **before and after** each match.
   * - ``-E``
     - Use **extended** regular expressions (ERE). Equivalent to ``egrep``.
   * - ``-F``
     - Treat pattern as a **fixed string** (no regex metacharacters).
       Equivalent to ``fgrep``. Faster and safer for literal strings.
   * - ``-P``
     - Use **Perl-compatible** regular expressions (PCRE). GNU grep only.
       Supports lookahead/lookbehind, ``\d``, ``\w``, and more.

.. code-block:: bash

    # Practical examples
    $ grep -rn "TODO" src/                         # find all TODOs with filenames and line numbers
    $ grep -A2 -B2 "ERROR" /var/log/syslog         # show errors with surrounding context
    $ grep -F "special.chars[" config.ini          # literal search; no escaping needed
    $ grep -c "200 OK" access.log                  # count successful requests
    $ ssh host ps aux | grep -v grep | grep nginx  # find nginx but not the grep command

Regular Expression Variants in ``grep``
-----------------------------------------

``grep`` understands three regex dialects, selected by flag:

.. list-table::
   :header-rows: 1
   :widths: 20 30 50

   * - Dialect
     - Flag
     - Features
   * - Basic (BRE)
     - (default)
     - ``. * ^ $ [ ] \``; ``\+``, ``\?``, ``\|``, ``\( \)`` need
       backslash-escape
   * - Extended (ERE)
     - ``-E``
     - ``+ ? | ( ) { }`` work without backslash. Most readable for
       complex patterns.
   * - Perl (PCRE)
     - ``-P``
     - ``\d \w \s``, lookahead ``(?=...)``, lookbehind ``(?<=...)``,
       non-greedy ``*?``, ``+?``

.. code-block:: bash

    # BRE: backslashes required
    $ grep 'foo\|bar' file.txt

    # ERE: no backslashes needed
    $ grep -E 'foo|bar' file.txt

    # PCRE: lookbehind
    $ grep -P '(?<=status: )\d+' log.txt     # digits after "status: "

.. _grep-practical:

Practical Patterns
--------------------

.. code-block:: bash

    # Match IP addresses (rough):
    $ grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' access.log

    # Find non-empty, non-comment lines in a config:
    $ grep -Ev '^\s*(#|$)' nginx.conf

    # Count occurrences across many files:
    $ grep -rc "FIXME" src/ | grep -v ':0$'

.. _sort:

``sort`` — Ordering Lines
============================

``sort`` reads lines from stdin (or files), sorts them according to specified
criteria, and writes the result to stdout.

.. code-block:: bash

    $ sort file.txt                     # lexical (dictionary) sort
    $ sort -n file.txt                  # numeric sort
    $ sort -r file.txt                  # reverse
    $ sort -u file.txt                  # unique (remove duplicates)
    $ sort -t':' -k3 -n /etc/passwd     # sort by UID (third colon-delimited field, numeric)

Essential Options
------------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Option
     - Purpose
   * - ``-n``
     - Numeric sort. Without this, ``10`` sorts before ``2`` (lexical order).
   * - ``-h``
     - Human-numeric sort: ``1K`` < ``2M`` < ``1G``. Invaluable for ``du -h``.
   * - ``-r``
     - Reverse order.
   * - ``-u``
     - Unique: output only the first of equal lines.
   * - ``-t CHAR``
     - Field delimiter (default: whitespace). Essential for CSV/TSV/passwd.
   * - ``-k POS1[,POS2]``
     - Sort key: sort by field(s) starting at POS1, ending at POS2. POS is
       ``F[.C][OPTS]`` where F is field number (1-based), C is character
       offset, and OPTS are ``n``, ``r``, etc.
   * - ``-s``
     - Stable sort: preserve original order of equal keys. Important for
       multi-pass sorts.
   * - ``-S SIZE``
     - Buffer size for sorting (e.g., ``-S 50%``). Large files may exceed
       memory; sort handles this by using temporary files.
   * - ``--parallel=N``
     - Use N threads for sorting (GNU sort).
   * - ``-V``
     - Version sort: ``file1.9.txt`` < ``file1.10.txt``.

.. code-block:: bash

    # Sort processes by memory usage (RSS), descending:
    $ ps aux | sort -k6 -nr | head

    # Sort by multiple keys: department (field 1), then salary (field 3, numeric, descending):
    $ sort -t',' -k1,1 -k3,3nr employees.csv

    # Sort IP addresses numerically (each octet):
    $ sort -t. -k1,1n -k2,2n -k3,3n -k4,4n ips.txt

.. _uniq:

``uniq`` — Report or Omit Repeated Lines
===========================================

.. important::

   ``uniq`` only detects **adjacent** duplicate lines. It is almost always
   used in combination with ``sort``: ``sort | uniq``, or more compactly
   ``sort -u``.

.. code-block:: bash

    $ uniq file.txt          # remove adjacent duplicates
    $ sort file.txt | uniq   # remove ALL duplicates
    $ sort -u file.txt       # shorter equivalent

    $ uniq -c file.txt       # prefix lines with occurrence count
    $ uniq -d file.txt       # print ONLY duplicate lines
    $ uniq -u file.txt       # print ONLY unique (non-duplicate) lines

.. code-block:: bash

    # Find the most common lines in a log:
    $ sort access.log | uniq -c | sort -nr | head -10

    # Show only lines that appear 3+ times:
    $ sort data.txt | uniq -c | awk '$1 >= 3'

.. _wc:

``wc`` — Word, Line, Character, and Byte Count
================================================

.. code-block:: bash

    $ wc file.txt
      47   312  2409 file.txt
    #  ^     ^     ^
    # lines  words bytes

    $ wc -l file.txt          # lines only
    $ wc -w file.txt          # words only
    $ wc -c file.txt          # bytes only (use -m for characters; different in UTF-8)
    $ wc -L file.txt          # length of longest line (GNU wc)

    # Count files in a directory:
    $ ls | wc -l

    # Count lines of code:
    $ find src/ -name '*.py' -exec cat {} + | wc -l

.. _cut:

``cut`` — Extract Columns of Text
====================================

``cut`` removes sections from each line of input. It is simple, fast, and
limited — for anything beyond basic column extraction, reach for ``awk``.

.. code-block:: bash

    $ cut -d':' -f1,7 /etc/passwd          # username and shell (colon-delimited)
    $ cut -c1-10 file.txt                  # first 10 characters of each line
    $ cut -d',' -f2- employees.csv         # second comma-separated field onwards

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Option
     - Purpose
   * - ``-d DELIM``
     - Use DELIM as field delimiter (default: tab).
   * - ``-f LIST``
     - Select fields: ``-f1``, ``-f1,3``, ``-f2-5``, ``-f-3`` (first
       three), ``-f3-`` (from third to end).
   * - ``-c LIST``
     - Select characters instead of fields.
   * - ``-s``
     - Suppress lines that do not contain the delimiter (GNU cut).
   * - ``--complement``
     - Select everything EXCEPT the specified fields (GNU cut).

.. warning::

   ``cut`` treats **each occurrence** of the delimiter as a field boundary.
   ``a,,b`` has three fields, with the second being empty. Multiple
   consecutive delimiters are NOT collapsed (unlike ``awk``).

.. _tr:

``tr`` — Translate or Delete Characters
=========================================

``tr`` operates on individual characters, not strings. It reads stdin, performs
the operation, and writes to stdout. It is the fastest tool for
character-level transformations.

.. code-block:: bash

    $ tr 'a-z' 'A-Z' < file.txt            # uppercase
    $ tr '[:lower:]' '[:upper:]' < file   # same, using character classes
    $ tr -d '\r' < dosfile.txt            # delete carriage returns (DOS → Unix)
    $ tr -s ' ' < file.txt                # squeeze repeated spaces into single space
    $ tr -s '\n' < file.txt               # squeeze blank lines
    $ tr -d '[:punct:]' < file.txt        # delete all punctuation
    $ tr ',' '\t' < data.csv              # convert CSV to TSV

Character Classes
-------------------

``tr`` supports POSIX character classes, which are more portable than manual
ranges:

.. code-block:: bash

    $ tr '[:upper:]' '[:lower:]'    # portable across locales
    $ tr '[:space:]' '\n'           # convert all whitespace (space, tab, newline) to newlines
    $ tr -d '[:cntrl:]'             # strip control characters
    $ tr '[:graph:]' ' '            # replace printable non-space chars with space
    $ tr -cd '[:print:]'            # delete everything except printable characters

.. note::

   ``tr`` does **not** accept filename arguments — it reads strictly from
   stdin. Always use redirection: ``tr ... < input > output``.

.. _diff:

``diff`` — Compare Files Line by Line
========================================

``diff`` compares two files and produces a set of instructions (a *patch*)
that transforms the first file into the second.

.. code-block:: bash

    $ diff file1.txt file2.txt              # normal diff
    $ diff -u file1.txt file2.txt           # unified format (standard for patches)
    $ diff -y file1.txt file2.txt           # side-by-side
    $ diff -y --suppress-common-lines f1 f2 # side-by-side, only differences
    $ diff -r dir1/ dir2/                   # recursive directory comparison
    $ diff -q file1.txt file2.txt           # only report whether files differ
    $ diff -w file1.txt file2.txt           # ignore whitespace differences

Understanding Unified Diff Output
-----------------------------------

.. code-block:: diff

    --- file1.txt  2026-01-15 10:00:00.000000000 +0000
    +++ file2.txt  2026-01-15 10:01:00.000000000 +0000
    @@ -1,4 +1,4 @@
     Line 1 (unchanged)
    -Line 2 (removed)
    +Line 2 (modified)
     Line 3 (unchanged)

- ``---`` and ``+++`` identify the original and new files.
- ``@@ -1,4 +1,4 @@`` is a *hunk header*: starting at line 1, showing 4 lines
  in the old file; starting at line 1, showing 4 lines in the new file.
- Lines prefixed with ``-`` are removed; ``+`` are added; space are context.

``patch`` applies a diff to a file:

.. code-block:: bash

    $ diff -u original.txt modified.txt > changes.patch
    $ patch original.txt < changes.patch      # apply the patch

.. _comm:

``comm`` — Compare Two Sorted Files
======================================

``comm`` compares two **sorted** files and outputs three columns:
lines only in file 1, lines only in file 2, and lines in both.

.. code-block:: bash

    $ comm file1.txt file2.txt
    # Column 1: lines only in file1
    # Column 2: lines only in file2
    # Column 3: lines in both

    $ comm -1 file1.txt file2.txt       # suppress column 1 (unique to file1)
    $ comm -2 file1.txt file2.txt       # suppress column 2 (unique to file2)
    $ comm -3 file1.txt file2.txt       # suppress column 3 (common lines)
    $ comm -12 file1.txt file2.txt      # show ONLY common lines
    $ comm -23 file1.txt file2.txt      # show ONLY lines unique to file2

.. code-block:: bash

    # Find users added since last check:
    $ comm -13 <(sort old_users.txt) <(sort new_users.txt)

.. _join:

``join`` — Relational Join on Sorted Files
============================================

``join`` performs an equi-join (like SQL's ``INNER JOIN``) on two sorted files
based on a common field.

.. code-block:: bash

    $ join employees.txt departments.txt
    # Default: join on first whitespace-delimited field

    $ join -t',' -1 2 -2 1 employees.csv dept.csv
    # -t',' = comma delimiter
    # -1 2  = join on field 2 of file 1
    # -2 1  = join on field 1 of file 2

    $ join -a 1 file1.txt file2.txt      # left outer join (include unpairable lines from file1)
    $ join -v 1 file1.txt file2.txt      # anti-join: lines in file1 with NO match in file2

.. warning::

   Both files must be **sorted** on the join field. Use ``sort`` first or
   process substitution: ``join <(sort -k2 file1) <(sort -k1 file2)``.

.. _paste:

``paste`` — Merge Lines of Files Side by Side
================================================

``paste`` concatenates corresponding lines of files horizontally. Think of it
as the horizontal counterpart to ``cat``.

.. code-block:: bash

    $ paste file1.txt file2.txt           # tab-separated columns
    $ paste -d',' file1.txt file2.txt     # comma delimiter
    $ paste -d'\n' file1.txt file2.txt    # interleave lines (alternating)
    $ paste -s file.txt                   # serialize: join all lines into one (with tabs)
    $ paste -sd',' file.txt               # serialize with custom delimiter (comma-separated)

.. code-block:: bash

    # Convert a column of numbers to a comma-separated list:
    $ seq 10 | paste -sd,
    1,2,3,4,5,6,7,8,9,10

.. _split:

``split`` — Break Files into Pieces
======================================

``split`` divides a large file into smaller files of a specified size.

.. code-block:: bash

    $ split -l 1000 bigfile.csv chunk_          # 1000 lines per chunk → chunk_aa, chunk_ab, ...
    $ split -b 1M large.bin part_               # 1 megabyte chunks
    $ split -n 4 bigfile.txt part_              # exactly 4 equal chunks (GNU split)
    $ split -d -l 500 data.txt chunk_           # numeric suffixes: chunk_00, chunk_01, ...

    # Reassemble:
    $ cat chunk_* > bigfile_restored.csv

.. _text-processing-design:

Philosophy: When to Use Which Tool
====================================

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Task
     - Best Tool(s)
   * - Filter lines by pattern
     - ``grep``
   * - Extract specific columns
     - ``cut`` (simple), ``awk`` (powerful)
   * - Character substitution/deletion
     - ``tr``
   * - Sort / deduplicate
     - ``sort``, ``uniq``
   * - Count lines or occurrences
     - ``wc``, ``grep -c``, ``sort | uniq -c``
   * - Compare two files
     - ``diff`` (detailed changes), ``comm`` (set operations on sorted
       content)
   * - Merge two files on a key
     - ``join``
   * - Side-by-side concatenation
     - ``paste``

.. admonition:: Key Takeaway

   The text-processing toolchest embodies the Unix philosophy: tools that
   are composable, pipe-friendly, and free of unnecessary output decoration.
   The mark of proficiency is not memorising every flag, but knowing the
   **shape** of each tool — what it consumes, what it produces, and how it
   connects to its neighbours in a pipeline.
