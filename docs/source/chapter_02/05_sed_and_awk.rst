sed & awk Fundamentals
===========================================

.. sidebar:: In This Section

   * ``sed`` — stream editor: substitution, deletion, addressing
   * ``sed`` scripting basics: hold space, branching
   * ``awk`` — pattern scanning and processing language
   * ``awk`` fields, patterns, BEGIN/END blocks
   * ``awk`` arrays, associative arrays, and practical idioms

---

When ``grep`` is not enough, but Python feels like overkill, ``sed`` and
``awk`` occupy the sweet spot. Together they form a miniature programming
environment for stream processing — ``sed`` edits lines; ``awk`` computes on
records. This section teaches you enough of each to be dangerous.

.. _sed:

``sed`` — Stream Editor
=========================

``sed`` (Stream EDitor) reads text line by line, applies editing commands, and
writes the result to stdout. It does NOT modify the input file unless you
use ``-i`` (in-place editing). Its design is inspired by the ``ed`` line
editor, but applied non-interactively to a stream.

.. code-block:: bash

    $ sed 's/old/new/' file.txt          # substitute first 'old' on each line
    $ sed 's/old/new/g' file.txt         # substitute ALL 'old' on each line (g = global)
    $ sed '3s/old/new/' file.txt         # substitute only on line 3
    $ sed '/pattern/s/old/new/' file.txt # substitute only on lines matching pattern

.. _sed-substitution:

Substitution (The ``s`` Command)
----------------------------------

The ``s`` command is the workhorse of ``sed`` — probably 80% of all sed usage
is ``s``:

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Flag
     - Meaning
   * - ``g``
     - Replace ALL occurrences on the line (global).
   * - ``N`` (number)
     - Replace only the Nth occurrence (e.g., ``s/:/|/2`` replaces second
       colon).
   * - ``p``
     - Print the line if a substitution was made (useful with ``-n``).
   * - ``i``
     - Case-insensitive matching (GNU sed extension).
   * - ``e``
     - Execute the replacement as a shell command (GNU sed; dangerous).

The **delimiter** does not have to be ``/`` — any character works. This
eliminates "leaning toothpick syndrome" when the pattern itself contains
slashes:

.. code-block:: bash

    $ sed 's|/usr/local/bin|/opt/bin|g' paths.txt
    $ sed 's#http://#https://#g' urls.txt

**Capture groups** use ``\(...\)`` in BRE (basic regex, sed default) or
``(...)`` with ``-E`` (extended regex):

.. code-block:: bash

    # Swap first two words (BRE: backslash-parens required)
    $ echo "hello world" | sed 's/^\([^ ]*\) \([^ ]*\)/\2 \1/'
    world hello

    # Same with ERE (cleaner):
    $ echo "hello world" | sed -E 's/^([^ ]+) ([^ ]+)/\2 \1/'
    world hello

    # Reformat date: 2026-07-15 → 15/07/2026
    $ echo "2026-07-15" | sed -E 's/([0-9]{4})-([0-9]{2})-([0-9]{2})/\3\/\2\/\1/'
    15/07/2026

.. _sed-addressing:

Addressing — Which Lines to Act On
------------------------------------

Commands can be prefixed with an **address** that selects which lines the
command applies to:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Address Syntax
     - Meaning
   * - ``N``
     - Line number N (e.g., ``5s/foo/bar/`` — line 5 only).
   * - ``N,M``
     - Lines N through M (inclusive).
   * - ``N,+K``
     - Line N and the next K lines (GNU extension).
   * - ``$``
     - Last line.
   * - ``/regex/``
     - Lines matching the regex.
   * - ``/regex1/,/regex2/``
     - From first line matching regex1 through first line matching regex2.
   * - ``N~STEP``
     - Every STEP'th line starting at N (GNU: ``1~2`` = odd lines,
       ``2~2`` = even lines).
   * - ``!`` (negation)
     - ``5!s/foo/bar/`` applies to all lines EXCEPT line 5.

.. code-block:: bash

    $ sed -n '10,20p' file.txt                # print lines 10-20 (p = print; -n suppresses default output)
    $ sed '/^#/d' config.conf                 # delete comment lines
    $ sed '/^$/{N;/^\n$/d}' file.txt          # delete consecutive blank lines
    $ sed -n '/start/,/end/p' log.txt         # print everything between 'start' and 'end' markers

.. _sed-commands:

Other Essential ``sed`` Commands
-----------------------------------

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Command
     - Purpose
   * - ``d``
     - Delete the line (do not output it).
   * - ``p``
     - Print the line (usually with ``-n`` to suppress default output).
   * - ``a TEXT``
     - Append TEXT after the line.
   * - ``i TEXT``
     - Insert TEXT before the line.
   * - ``c TEXT``
     - Change (replace) the line with TEXT.
   * - ``y/SRC/DST/``
     - Transliterate characters (like ``tr``; always global).
   * - ``=``
     - Print the current line number.
   * - ``r FILE``
     - Read and insert contents of FILE after the line.
   * - ``w FILE``
     - Write the line to FILE.

.. code-block:: bash

    # Insert a header before line 1:
    $ sed '1i\# This file was generated automatically' file.txt

    # Append a line after every line containing 'Chapter':
    $ sed '/Chapter/a\----' book.txt

    # In-place edit with backup:
    $ sed -i.bak 's/old/new/g' *.txt            # creates .bak files
    $ sed -i '' 's/old/new/g' *.txt              # macOS: no backup (empty extension)

.. _sed-hold-space:

The Hold Space — Advanced ``sed``
------------------------------------

``sed`` maintains two buffers: the **pattern space** (the current line being
processed) and the **hold space** (temporary storage). Commands to manipulate
them enable multi-line processing:

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Command
     - Action
   * - ``h``
     - Copy pattern space → hold space
   * - ``H``
     - Append pattern space → hold space
   * - ``g``
     - Copy hold space → pattern space
   * - ``G``
     - Append hold space → pattern space
   * - ``x``
     - Exchange pattern space and hold space
   * - ``n``
     - Read next line into pattern space (auto-print current if ``-n`` not set)
   * - ``N``
     - Append next line to pattern space (with embedded ``\n``)

.. code-block:: bash

    # Join every two lines with a tab:
    $ seq 6 | sed 'N;s/\n/\t/'
    1	2
    3	4
    5	6

    # Reverse the lines of a file (tac replacement):
    $ sed '1!G;h;$!d' file.txt

.. note::

   For most users, the hold space is strictly advanced territory. If you find
   yourself reaching for ``N``, ``h``, or ``G``, consider whether ``awk``
   might be a better fit — its programming model is more natural for
   multi-line or record-oriented processing.

.. _awk:

``awk`` — Pattern Scanning and Processing
============================================

``awk`` is a **data-driven programming language** designed for processing
tabular text. It was created by Alfred Aho, Peter Weinberger, and Brian
Kernighan at Bell Labs in 1977. While ``sed`` edits *lines*, ``awk`` processes
*records* (lines, by default) split into *fields* (columns, by default).

An ``awk`` program has the structure:

.. code-block:: text

    pattern { action }
    pattern { action }
    ...

For each record (line), ``awk`` tests each pattern in order. If the pattern
matches, the corresponding action executes. Both pattern and action are
optional: a missing pattern matches every record; a missing action prints the
record (``{ print }``).

.. _awk-fields:

Fields and Records
--------------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Variable
     - Meaning
   * - ``$0``
     - The entire current record (line)
   * - ``$1``, ``$2``, ...

     - Individual fields
   * - ``NF``
     - Number of fields in the current record
   * - ``$NF``
     - The last field
   * - ``NR``
     - Number of records read so far (line number)
   * - ``FNR``
     - Record number within the current file (resets per file)
   * - ``FS``
     - Field separator (default: any whitespace)
   * - ``OFS``
     - Output field separator (default: space)
   * - ``RS``
     - Record separator (default: newline)
   * - ``ORS``
     - Output record separator (default: newline)
   * - ``FILENAME``
     - Name of the current input file

Unlike ``cut``, ``awk`` **collapses** multiple consecutive field separators
(whitespace, by default) into a single separator. This means ``$1`` always
refers to the first non-whitespace token regardless of how much whitespace
precedes it — a massive convenience for processing free-form text.

.. code-block:: bash

    # Print usernames and shells from /etc/passwd (colon-delimited):
    $ awk -F: '{ print $1, $7 }' /etc/passwd

    # Print lines where field 3 ($3) exceeds 1000 (system UIDs):
    $ awk -F: '$3 >= 1000 { print $1 }' /etc/passwd

    # Print the last field of each line:
    $ awk '{ print $NF }' file.txt

    # Print line number alongside content:
    $ awk '{ print NR, $0 }' file.txt

.. _awk-patterns:

Patterns
----------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Pattern Type
     - Example
   * - Regular expression
     - ``/error/ { print }``
   * - Relational expression
     - ``$3 > 100 { print $1 }``
   * - Pattern range
     - ``/start/,/end/ { print }``
   * - ``BEGIN``
     - ``BEGIN { print "Header" }`` — executed once before any input
   * - ``END``
     - ``END { print "Footer" }`` — executed once after all input
   * - Empty (no pattern)
     - ``{ print }`` — matches every record

.. code-block:: bash

    # Print records between START and STOP markers (inclusive):
    $ awk '/START/,/STOP/' log.txt

    # Print only non-empty, non-comment lines:
    $ awk '!/^#/ && NF' config.conf
    # NF is zero for empty lines; !/^#/ excludes comments

.. _awk-begin-end:

BEGIN and END Blocks
----------------------

``BEGIN`` fires before any input is processed — ideal for initialising
variables or printing headers. ``END`` fires after all input — ideal for
summaries and totals.

.. code-block:: bash

    $ awk '
    BEGIN { print "Username\tHome Directory"; print "--------\t--------------" }
    { print $1 "\t" $6 }
    END   { print "--------"; print NR, "users processed" }
    ' FS=':' /etc/passwd

    # Sum a column of numbers:
    $ awk '{ sum += $1 } END { print "Total:", sum }' numbers.txt

    # Calculate average:
    $ awk '{ sum += $1; count++ } END { print sum/count }' numbers.txt

.. _awk-variables:

Variables and Arithmetic
--------------------------

``awk`` variables are dynamically typed (numeric if the value looks like a
number, string otherwise) and do not require declaration:

.. code-block:: bash

    # Running total with line count:
    $ awk '{ total += $3; n++ } END { printf "Sum: %d, Count: %d, Avg: %.2f\n", total, n, total/n }' data.txt

    # Find the maximum value in column 2:
    $ awk '$2 > max { max = $2; maxline = $0 } END { print maxline }' data.txt

.. _awk-arrays:

Arrays and Associative Arrays
--------------------------------

``awk`` arrays are **associative** — keys can be strings or numbers. This makes
them exceptionally powerful for counting, grouping, and deduplication.

.. code-block:: bash

    # Count occurrences of each word:
    $ awk '{ for (i=1; i<=NF; i++) count[$i]++ }
           END { for (word in count) print count[word], word }' file.txt

    # Group sums: sum column 2 by column 1 (like SQL GROUP BY):
    $ awk '{ total[$1] += $2 }
           END { for (key in total) print key, total[key] }' sales.txt

    # Find duplicate lines:
    $ awk '{ count[$0]++ }
           END { for (line in count) if (count[line] > 1) print count[line], line }' file.txt

    # Remove duplicate lines preserving order (idiom):
    $ awk '!seen[$0]++' file.txt
    # This is a famous awk one-liner: 'seen' tracks each line; !seen[$0]++ is
    # true (so the line prints) only the first time each line is encountered.

.. _awk-builtin-functions:

Built-in Functions
--------------------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Function
     - Purpose
   * - ``length(str)``
     - String length; ``length`` (no argument) returns ``$0`` length.
   * - ``substr(str, start, len)``
     - Extract substring (1-indexed).
   * - ``index(str, substr)``
     - Find position of substring (0 if not found).
   * - ``split(str, arr, sep)``
     - Split string into array; returns number of elements.
   * - ``tolower(str)`` / ``toupper(str)``
     - Case conversion.
   * - ``sprintf(fmt, ...)``
     - Format string (like C's ``sprintf``).
   * - ``match(str, regex)``
     - Returns position of regex match; sets ``RSTART`` and ``RLENGTH``.
   * - ``gsub(regex, repl [, target])``
     - Global substitution; returns number of replacements.
   * - ``sub(regex, repl [, target])``
     - Single substitution (first match only).
   * - ``system(cmd)``
     - Execute shell command; returns exit status.

.. code-block:: bash

    # Extract first 10 characters of each line:
    $ awk '{ print substr($0, 1, 10) }' file.txt

    # Convert third field to uppercase:
    $ awk '{ $3 = toupper($3); print }' file.txt

    # Execute external command for each record:
    $ awk '{ system("mkdir -p dir_" $1) }' prefixes.txt

.. _awk-portability:

GNU awk (gawk) vs. Other awk Implementations
-----------------------------------------------

Most Linux distributions ship GNU awk (``gawk``) as the default ``awk``.
It extends POSIX awk with:

- Multidimensional array syntax: ``arr[x][y]`` (true sub-arrays in gawk ≥4).
- ``BEGINFILE`` and ``ENDFILE`` patterns (execute per input file).
- ``@include`` for library files.
- Network extensions via ``/inet`` pseudo-files (if compiled with networking).
- Better time functions: ``strftime()``, ``systime()``.

For portable scripting, stick to POSIX awk features. For one-liners and
personal scripts, the GNU extensions are safe on any Linux system.

.. code-block:: bash

    # GNU awk: print filename before its contents
    $ gawk 'BEGINFILE { print "=== ", FILENAME, " ===" } { print }' *.txt

.. _sed-awk-when:

When to Use ``sed`` vs. ``awk`` vs. Something Else
=====================================================

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Task
     - Best Tool
   * - Simple find-and-replace in text
     - ``sed``
   * - Delete or print lines matching a pattern
     - ``sed`` (``d``, ``p``) or ``grep -v``
   * - Extract specific columns
     - ``awk`` (``cut`` if truly simple)
   * - Compute sums, averages, counts across rows
     - ``awk``
   * - Count unique values, group by field
     - ``awk`` arrays or ``sort | uniq -c``
   * - Multi-line pattern matching
     - ``sed`` (hold space) or ``awk`` (with ``RS`` manipulation)
   * - Complex data transformation with branching/nested logic
     - ``awk`` … or consider Python/Perl
   * - JSON, XML, YAML processing
     - ``jq``, ``xmlstarlet``, ``yq`` — **not** sed/awk

.. admonition:: The Golden Rule for sed/awk

   Both tools excel at **line-oriented text processing**. The moment your data
   has structure (JSON, XML, binary, or records spanning variable numbers of
   lines), reach for a purpose-built parser. The time saved by using ``jq``
   instead of a 40-character ``awk`` one-liner is time you will never
   regret having spent.

.. admonition:: Key Takeaway

   ``sed`` edits *how text looks*; ``awk`` computes *what text means*. Master
   the substitution command in ``sed`` and the ``{ print $N }`` / ``BEGIN-END``
   / associative-array trio in ``awk``, and you will have solved 95% of the
   text-processing problems you will ever encounter on the command line.
