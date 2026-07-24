.. _app-a-flavors:

------------------------------------------------------------------------------
Regex Flavors: BRE, ERE, PCRE/PCRE2
------------------------------------------------------------------------------

Three major regex dialects appear throughout Linux. Knowing which engine a
tool uses — and how escaping rules differ — prevents countless debugging
frustrations.

.. list-table:: Regex Flavor Overview
   :header-rows: 1
   :widths: 18 25 27 30

   * - Feature
     - POSIX Basic (BRE)
     - POSIX Extended (ERE)
     - PCRE / PCRE2
   * - **Used by**
     - ``grep`` (default), ``sed``, ``awk`` (legacy), ``ed``
     - ``grep -E``, ``awk``, ``sed -E``
     - ``grep -P``, ``pcregrep``, ``perl``, ``python``, ``nginx``, ``php``
   * - **Literal vs. Meta**
     - ``? + { } ( ) |`` are **literal**; must backslash to make meta
     - ``? + { } ( ) |`` are **meta**; must backslash to make literal
     - ``? + { } ( ) |`` are **meta**; backslash toggles to literal
   * - **Escaping style**
     - Heavily escaped ``\( \)``
     - Lightly escaped ``( )``
     - Lightly escaped ``( )``, ``\d``, ``\s``, ``\w`` etc.
   * - **Backreferences**
     - ``\1`` through ``\9`` supported
     - ``\1`` through ``\9`` supported
     - ``\1``–``\99``; named groups ``(?<name>...)``
   * - **Lookahead/Lookbehind**
     - Not available
     - Not available
     - ``(?=...)``, ``(?!...)``, ``(?<=...)``, ``(?<!...)``
   * - **Non-capturing groups**
     - Not available
     - Not available
     - ``(?:...)``
   * - **Possessive quantifiers**
     - Not available
     - Not available
     - ``++``, ``?+``, ``*+``
   * - **Atomic groups**
     - Not available
     - Not available
     - ``(?>...)``

------------------------------------------------------------------------------
POSIX Basic Regular Expressions (BRE)
------------------------------------------------------------------------------

BRE is the original Unix regex standard. Its defining property: **metacharacters
must be escaped** to act as operators, otherwise they are literal.

.. rubric:: Meta-chars requiring ``\`` prefix in BRE

.. code-block:: text

   \(            \)            \{            \}
   \+            \?            \|            \^

The **anchor** ``^`` is meta only at the start of a pattern; ``$`` is meta only
at the end; ``.`` is always meta (matches any single character).

.. rubric:: Example: matching a phone number with BRE

.. code-block:: bash
   :caption: BRE — note escaped parentheses and escaped ``+``

   grep '\([0-9]\{3\}\)-[0-9]\{4\}' contacts.txt
   # Also valid (ERE below would not need the backslashes)

------------------------------------------------------------------------------
POSIX Extended Regular Expressions (ERE)
------------------------------------------------------------------------------

ERE removes the escaping burden: ``( ) { } + ? |`` are **metacharacters by
default**. To match them literally, backslash them.

.. rubric:: Key ERE rules

* ``+`` means "one or more" (no backslash needed).
* ``?`` means "zero or one".
* ``|`` means alternation.
* ``( )`` define groups.
* ``{m,n}`` are interval quantifiers.

.. code-block:: bash
   :caption: ERE — minimal escaping

   grep -E '([0-9]{3})-[0-9]{4}' contacts.txt
   sed -E 's/([0-9]{3})/\1-/g' file.txt

.. _pcre2-note:

------------------------------------------------------------------------------
Perl-Compatible Regular Expressions (PCRE / PCRE2)
------------------------------------------------------------------------------

PCRE (now **PCRE2** as of 2015) adds a huge superset of features: lookahead,
lookbehind, non-capturing groups, possessive quantifiers, atomic groups,
backtracking control verbs, and Unicode properties (``\p{...}``).

.. warning::
   Not all Linux tools link against PCRE. ``grep -P`` requires PCRE support at
   compile time. ``pcregrep`` is the dedicated PCRE grep tool. Python, PHP,
   and Nginx all use PCRE internally.

.. rubric:: PCRE-only features essential for administration

.. code-block:: text
   :caption: Lookahead / Lookbehind

   (?=pattern)    Positive lookahead  — match only if followed by pattern
   (?!pattern)    Negative lookahead  — match only if NOT followed
   (?<=pattern)   Positive lookbehind — match only if preceded by pattern
   (?<!pattern)   Negative lookbehind — match only if NOT preceded

.. code-block:: text
   :caption: Non-capturing & Named groups

   (?:abc)        Non-capturing group — groups without back-reference overhead
   (?P<name>...)  Named capture (Python); (?<name>...) in Perl/PCRE

.. code-block:: bash
   :caption: Admin snippet — PCRE lookbehind to extract IP from access log

   grep -oP '(?<=client: )\d+\.\d+\.\d+\.\d+' /var/log/nginx/error.log

.. rubric:: Backtracking control verbs (advanced)

.. code-block:: text

   (*FAIL) or (*F)  Force failure at this point (trick for validation)
   (*SKIP)          Skip to next alternative on failure
   (*COMMIT)        Commit to current match; no backtracking past this point

These are rarely needed for daily sysadmin work but invaluable when writing
strict pattern validators in configuration management.
