.. _app-a-syntax:

------------------------------------------------------------------------------
Syntax Core
------------------------------------------------------------------------------

This section is a dense syntax reference. Every construct is shown in **ERE**
notation (the most portable default for modern ``grep -E`` / ``sed -E`` /
``awk``). PCRE extensions are noted explicitly.

------------------------------------------------------------------------------
Character Classes
------------------------------------------------------------------------------

.. list-table:: Character Class Reference
   :header-rows: 1
   :widths: 25 30 45

   * - Expression
     - Matches
     - Notes
   * - ``.``
     - Any single character except newline
     - PCRE: ``/s`` flag includes newline; ``[^]`` in ERE also matches newline
   * - ``[abc]``
     - Any one of ``a``, ``b``, ``c``
     - Order irrelevant
   * - ``[^abc]``
     - Any character *except* ``a``, ``b``, ``c``
     - Caret must be first inside brackets
   * - ``[a-z]``
     - Range from ``a`` to ``z``
     - Locale-sensitive! Use ``[[:lower:]]`` for portability
   * - ``[0-9]``
     - Any digit
     - Same as ``[[:digit:]]``
   * - ``[a-zA-Z0-9]``
     - Alphanumeric
     - Same as ``[[:alnum:]]``
   * - ``[[:alnum:]]``
     - Letters and digits
     - POSIX class — use inside brackets
   * - ``[[:alpha:]]``
     - Alphabetic characters
     - ``A-Z`` and ``a-z``
   * - ``[[:digit:]]``
     - Digits ``0-9``
     - Safer than ``[0-9]`` in some locales
   * - ``[[:lower:]]``
     - Lowercase letters
     - ``[a-z]`` may include non-English letters in some locales
   * - ``[[:upper:]]``
     - Uppercase letters
     - ``[A-Z]`` similarly locale-sensitive
   * - ``[[:space:]]``
     - Any whitespace: space, tab, CR, newline, FF, VT
     - Equivalent to ``[\t\r\n\f\v ]``
   * - ``[[:blank:]]``
     - Space and tab only
     - Narrower than ``[[:space:]]``
   * - ``[[:punct:]]``
     - Punctuation characters
     - ``!"#$%&'()*+,-./:;<=>?@[\]^_``\`{|}~``
   * - ``[[:graph:]]``
     - Visible characters (excludes space)
     - Equivalent to ``[[:alnum:][:punct:]]``
   * - ``[[:print:]]``
     - ``[[:graph:]]`` plus space
     - All printable characters
   * - ``[[:xdigit:]]``
     - Hex digits ``0-9 A-F a-f``
     - Useful for matching colours, hashes

.. rubric:: PCRE shorthand classes (also in ``\d`` mode)

.. list-table:: PCRE Shorthand Classes
   :header-rows: 1
   :widths: 20 25 55

   * - Shorthand
     - Equivalent POSIX
     - Notes
   * - ``\d``
     - ``[0-9]`` or ``[[:digit:]]``
     - PCRE only; not available in BRE/ERE unless using ``-P``
   * - ``\D``
     - ``[^0-9]``
     - Negation of ``\d``
   * - ``\w``
     - ``[[:alnum:]_]``
     - Word character (letter, digit, underscore)
   * - ``\W``
     - ``[^[:alnum:]_]``
     - Non-word character
   * - ``\s``
     - ``[[:space:]]``
     - Any whitespace
   * - ``\S``
     - ``[^[:space:]]``
     - Non-whitespace
   * - ``\h``
     - ``[[:blank:]]``
     - Horizontal whitespace (PCRE 7.2+)
   * - ``\v``
     - ``[\n\r\f\v]``
     - Vertical whitespace (PCRE 7.2+)

------------------------------------------------------------------------------
Anchors
------------------------------------------------------------------------------

Anchors do **not** consume characters — they assert a position.

.. list-table:: Anchor Reference
   :header-rows: 1
   :widths: 20 30 50

   * - Anchor
     - Asserts position at
     - Example
   * - ``^``
     - Start of string (or line in multiline mode)
     - ``^root`` matches lines starting with "root"
   * - ``$``
     - End of string (or line in multiline mode)
     - ``error$`` matches lines ending with "error"
   * - ``\b``
     - Word boundary (PCRE)
     - ``\bword\b`` matches whole word "word" only
   * - ``\B``
     - NOT a word boundary (PCRE)
     - ``\Bword`` matches "word" only when preceded by another word char
   * - ``\A``
     - Absolute start of string (PCRE)
     - ``\A...`` — unaffected by ``/m`` flag
   * - ``\z``
     - Absolute end of string (PCRE)
     - ``...\z`` — unaffected by ``/m`` flag
   * - ``\Z``
     - End of string or optional newline (PCRE)
     - Slightly less strict than ``\z``

------------------------------------------------------------------------------
Quantifiers
------------------------------------------------------------------------------

.. list-table:: Quantifier Reference
   :header-rows: 1
   :widths: 15 20 30 35

   * - Quantifier
     - Meaning
     - Greedy? (default)
     - Lazy version
   * - ``*``
     - Zero or more
     - Yes — consumes as much as possible
     - ``*?``
   * - ``+``
     - One or more
     - Yes
     - ``+?``
   * - ``?``
     - Zero or one
     - Yes
     - ``??``
   * - ``{n}``
     - Exactly ``n`` times
     - N/A
     - N/A
   * - ``{n,}``
     - At least ``n`` times
     - Yes
     - ``{n,}?``
   * - ``{n,m}``
     - ``n`` to ``m`` times
     - Yes
     - ``{n,m}?``
   * - ``{0,m}``
     - Zero to ``m`` times
     - Yes
     - ``{0,m}?``

.. tip::
   **Lazy quantifiers** (with ``?`` suffix) match the *fewest* characters
   possible. Critical for HTML/XML parsing: ``<.*>`` vs ``<.*?>``.

.. rubric:: Possessive quantifiers (PCRE only)

Possessive quantifiers (``++``, ``*+``, ``?+``, ``{n,m}+``) consume as much
as possible and **never give back** — no backtracking. This yields performance
gains and can prevent catastrophic backtracking:

.. code-block:: none

   \d++         # Possessive — all digits, no backtracking
   [^"]*+       # Possessive — all non-quote chars, then expects closing "

------------------------------------------------------------------------------
Capture Groups
------------------------------------------------------------------------------

.. list-table:: Group Types
   :header-rows: 1
   :widths: 25 30 45

   * - Syntax
     - Group Type
     - Use case
   * - ``(pattern)``
     - Capturing group
     - Stores matched text in ``\1``, ``\2``, … (or ``$1``, ``$2`` in replacements)
   * - ``(?:pattern)``
     - Non-capturing group (PCRE)
     - Groups without consuming a backreference slot; more efficient
   * - ``(?<name>pattern)``
     - Named capture (PCRE/Perl)
     - Reference by name, not number; ``\k<name>`` or ``(?P=name)``
   * - ``(?>pattern)``
     - Atomic group (PCRE)
     - No backtracking into the group once matched
   * - ``\1`` through ``\9``
     - Backreference (BRE/ERE)
     - Re-matches whatever was captured by that group
   * - ``\g{1}``, ``\g{name}``
     - Backreference (PCRE)
     - Unambiguous numbered/named backreference

.. rubric:: Backreference examples

.. code-block:: bash
   :caption: Detecting doubled words with backreference

   grep -E '\b([A-Za-z]+) \1\b' text.txt
   # Matches "the the", "is is", etc.

.. code-block:: bash
   :caption: Swapping fields with captured groups in sed

   sed -E 's/([^:]+):([^:]+)/\2: \1/' /etc/passwd
   # swap first two colon-separated fields

------------------------------------------------------------------------------
Alternation
------------------------------------------------------------------------------

Alternation (``|``) matches either the pattern on the left **or** the pattern
on the right. Its scope is bounded by the enclosing group or the pattern ends.

.. list-table:: Alternation Rules
   :header-rows: 1
   :widths: 25 75

   * - Pattern
     - Behaviour
   * - ``abc|def``
     - Matches "abc" or "def"
   * - ``a(b|c)d``
     - Matches "abd" or "acd"
   * - ``^(From|To):``
     - Matches "From:" or "To:" at line start
   * - ``error|warning|critical``
     - Matches any of the three keywords
   * - ``(red|blue) ball``
     - Matches "red ball" or "blue ball"

.. danger::
   Alternation is **not** a character class. ``[abc]`` matches **one** character;
   ``a|b|c`` matches **one** character too but is less efficient. Use character
   classes for single characters; alternation for multi-character words.
