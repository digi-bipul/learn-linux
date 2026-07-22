.. _app-a-tools:

------------------------------------------------------------------------------
A.3  Tool Differences: grep, sed, awk
------------------------------------------------------------------------------

Even when all three tools appear to "use regex," their parsing rules,
escaping requirements, and supported features differ in ways that routinely
trip up administrators.

------------------------------------------------------------------------------
A.3.1  grep(1) — Pattern Matching
------------------------------------------------------------------------------

.. list-table:: grep regex modes
   :header-rows: 1
   :widths: 15 25 60

   * - Flag
     - Engine
     - Notes
   * - (none)
     - BRE
     - ``( ) + ? { } |`` are literal; must backslash for meta
   * - ``-E``
     - ERE
     - Modern default choice for most sysadmins
   * - ``-P``
     - PCRE
     - Not compiled in by default on some platforms (check ``grep -P`` first)
   * - ``-F``
     - Fixed strings (no regex)
     - Fastest; no metacharacters interpreted at all
   * - ``-w``
     - Whole-word match
     - Implies ``\b`` boundaries; uses ``[[:<:]]`` and ``[[:>:]]`` internally
   * - ``-x``
     - Line-exact match
     - Anchors pattern to ``^...$`` implicitly

.. rubric:: grep output control flags

.. code-block:: bash

   -o       # Print only the matched portion (not the full line)
   -c       # Count matches (line count, not match count)
   -n       # Print line numbers
   -v       # Invert match (print non-matching lines)
   -l       # List filenames with matches (useful in scripts)
   -L       # List filenames WITHOUT matches
   -r / -R  # Recursive (``-R`` follows symlinks)
   -q       # Quiet — exit code only (0 = match found)
   -A n     # Show n lines After match
   -B n     # Show n lines Before match
   -C n     # Show n lines of Context (before + after)

.. rubric:: Trap: grep with pipes

.. code-block:: bash

   # WRONG — colour codes will be piping as raw text
   grep --color=always pattern file | less -R

   # RIGHT — auto detects terminal vs pipe
   grep --color=auto pattern file | less -R
   # Or: alias grep='grep --color=auto'

------------------------------------------------------------------------------
A.3.2  sed(1) — Stream Editing
------------------------------------------------------------------------------

sed uses **BRE** by default and **ERE** with ``-E`` (or ``-r`` on some older
GNU sed versions). Unlike grep, sed operates on **address ranges** and applies
**commands** (s, d, p, a, i, c, y, etc.).

.. list-table:: sed regex commands at a glance
   :header-rows: 1
   :widths: 15 35 50

   * - Command
     - Syntax
     - Notes
   * - Substitute
     - ``s/pattern/replacement/flags``
     - ``g`` = global, ``p`` = print, ``I`` = case-insensitive, ``n`` = nth match
   * - Delete
     - ``/pattern/d``
     - Deletes lines matching pattern
   * - Print
     - ``/pattern/p``
     - Prints lines matching pattern; use with ``-n`` flag
   * - Append after
     - ``/pattern/a\ text``
     - Inserts line after match
   * - Insert before
     - ``/pattern/i\ text``
     - Inserts line before match
   * - Change line
     - ``/pattern/c\ text``
     - Replaces entire matching line
   * - Transform
     - ``y/abc/xyz/``
     - Character-by-character translation (like ``tr``)

.. rubric:: sed address ranges

.. code-block:: bash

   sed '3d' file                  # Delete line 3
   sed '3,5d' file                # Delete lines 3-5
   sed '/ERROR/,/END_ERROR/d'     # Delete range between two patterns
   sed '10,/PATTERN/s/foo/bar/'   # Line 10 through first match of PATTERN

.. rubric:: Critical sed escaping differences

.. code-block:: text

   # In "s/pattern/replacement/" — the replacement side has its own rules:
   &        = the entire matched text in the replacement
   \1-\9    = backreferences (even in BRE mode!)
   \L, \U   = GNU sed extensions: lowercase/uppercase the rest
   \l, \u   = GNU sed: next character lower/uppercased
   \E       = GNU sed: stop case conversion

.. code-block:: bash
   :caption: Practical sed substitution traps

   # Uppercase first letter of each word
   sed -E 's/\b([a-z])/\u\1/g' file.txt

   # Wrap matched text in brackets
   sed 's/error/(&)/g' file.txt

   # Use a different delimiter to avoid "leaning toothpick syndrome"
   sed 's|/usr/local|/opt|g' paths.txt
   sed 's#/var/log/#/var/log/archive/#g' config.txt

------------------------------------------------------------------------------
A.3.3  awk(1) — Pattern Scanning & Processing
------------------------------------------------------------------------------

awk uses **ERE** natively — no ``-E`` flag required. It is fundamentally
different from grep/sed because it automatically **splits each line into
fields** (``$1``, ``$2``, …, ``$NF``) and supports arithmetic, arrays, and
control flow.

.. rubric:: awk regex operators vs. standard regex

.. list-table:: awk-specific regex operators
   :header-rows: 1
   :widths: 25 35 40

   * - Operator
     - Meaning
     - Example
   * - ``~``
     - Match operator
     - ``$1 ~ /^192\.168/``
   * - ``!~``
     - Negative match operator
     - ``$1 !~ /^#/``
   * - ``//``
     - Regex literal
     - ``/error/ { count++ }``
   * - ``match(str, regex)``
     - Returns position of match, sets ``RSTART`` and ``RLENGTH``
     - ``match($0, /[0-9]+/)``
   * - ``sub(regex, repl)``
     - First occurrence substitution
     - ``sub(/old/, "new")``
   * - ``gsub(regex, repl)``
     - Global substitution (like ``sed s///g``)
     - ``gsub(/[[:space:]]/, "")``
   * - ``gensub(regex, repl, which, str)``
     - GNU awk only; more flexible substitution
     - ``gensub(/(.)(.)/, "\\2\\1", "g", $0)``
   * - ``split(str, arr, regex)``
     - Split string on regex into array
     - ``split($0, parts, /,/)``

.. rubric:: Awk field-based patterns (not regex, but essential)

.. code-block:: awk

   $3 > 100     # Third field numeric comparison
   $1 == "root" # String comparison (exact, not regex)
   NF == 5      # Lines with exactly 5 fields
   NR == 1      # First record (line)
   NR % 2 == 0  # Even-numbered lines

.. rubric:: Common awk one-liners for sysadmins

.. code-block:: bash

   # Print lines where field 4 matches a subnet
   awk '$4 ~ /^10\.0\.1\./' /var/log/syslog

   # Sum values in column 2
   awk '{ sum += $2 } END { print "Total:", sum }' data.tsv

   # Extract and count HTTP status codes from Nginx log
   awk '{ print $9 }' access.log | sort | uniq -c | sort -rn

   # Print lines between two markers (non-inclusive)
   awk '/START_MARKER/,/END_MARKER/' file

   # Field separator: colon (for /etc/passwd)
   awk -F: '$3 == 0 { print $1 }' /etc/passwd  # UID 0 users

------------------------------------------------------------------------------
A.3.4  Side-by-Side Comparison Table
------------------------------------------------------------------------------

.. list-table:: grep vs. sed vs. awk: core differences
   :header-rows: 1
   :widths: 20 25 25 30

   * - Dimension
     - grep
     - sed
     - awk
   * - **Primary purpose**
     - Search / filter lines
     - Stream editing / transformation
     - Data extraction & reporting
   * - **Default flavor**
     - BRE
     - BRE
     - ERE
   * - **ERE flag**
     - ``-E``
     - ``-E`` (``-r`` on older GNU)
     - Native (no flag needed)
   * - **PCRE flag**
     - ``-P``
     - Not available
     - Not available (GNU awk has ``\s``, ``\S``, etc. via ``--re-interval``)
   * - **Field awareness**
     - None
     - None (manual with ``\(\)`` capture groups)
     - Native field splitting (``$1``, ``$NF``)
   * - **Line addressing**
     - Indirect via ``-v``, ``-A``, ``-B``, ``-C``
     - Native address ranges (``3,5d``, ``/pat/,/pat/``)
     - Pattern + field/arithmetic conditions
   * - **Output control**
     - ``-o``, ``-c``, ``-l``, ``-L``
     - ``p`` flag, ``-n``
     - ``print``, ``printf``
   * - **In-place editing**
     - Not supported
     - ``-i`` (GNU sed)
     - GNU awk: write to temporary file; ``gawk -i inplace``
   * - **Substitution**
     - Not supported (use sed)
     - ``s/.../.../``
     - ``sub()``, ``gsub()``, ``gensub()``
   * - **Performance on large files**
     - Fastest
     - Fast
     - Moderate (field splitting adds overhead)

.. rubric:: Golden rule of thumb

+ **Just search for lines?** → ``grep``
+ **Simple find-and-replace across files?** → ``sed -i``
+ **Need to work with columns/fields, compute totals, or conditional logic?** → ``awk``
+ **Need PCRE lookahead/lookbehind?** → ``grep -P`` or ``pcregrep``
