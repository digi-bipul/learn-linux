.. highlight:: bash

========================================
8.7 — CLI Argument Parsing
========================================

A professional-quality script accepts command-line arguments just like system
commands: positional arguments for required inputs, flags for optional behavior,
and ``--help`` for usage information.

--------------------------------
8.7.1 Positional Parameters: ``$1``–``$9``, ``${N}``
--------------------------------

.. code-block:: bash

   echo "Script name: $0"
   echo "First arg:   $1"
   echo "Second arg:  $2"
   echo "Total args:  $#"

   # Beyond 9:
   echo "Tenth arg: ${10}"

.. warning::

   When a script is **sourced**, ``$0`` is the **calling shell**, not the
   script path.  Use ``${BASH_SOURCE[0]}`` for reliable self-referencing.

--------------------------------
8.7.2 ``$@`` vs ``$*`` — The Critical Distinction
--------------------------------

+---------------+---------------+-----------------------------------+
| Form          | Behavior      | When to use                       |
+===============+===============+===================================+
| ``"$@"``      | Each arg as   | **Always.** Preserves argument    |
|               | separate word | boundaries. Use for iteration.    |
+---------------+---------------+-----------------------------------+
| ``"$*"``      | Single string | When you want all args merged     |
|               | (space-       | into one word (e.g., log message).|
|               | separated)    |                                   |
+---------------+---------------+-----------------------------------+

The golden rule: Use ``"$@"`` 99% of the time.

--------------------------------
8.7.3 ``shift`` — Consuming Arguments
--------------------------------

.. code-block:: bash

   shift      # Discard $1; $2 becomes $1, etc.
   shift 2    # Discard $1 and $2

--------------------------------
8.7.4 Manual Flag Parsing with ``case`` + ``shift``
--------------------------------

.. code-block:: bash

   verbose=0; output_file=""

   while [[ $# -gt 0 ]]; do
       case "$1" in
           -v|--verbose) verbose=1; shift ;;
           -o|--output)  output_file="$2"; shift 2 ;;
           --)           shift; break ;;
           -*)           echo "Unknown: $1" >&2; exit 1 ;;
           *)            break ;;
       esac
   done

--------------------------------
8.7.5 ``getopts`` — The Standard Option Parser
--------------------------------

.. code-block:: bash

   #!/usr/bin/env bash
   set -euo pipefail

   verbose=0; output_file=""

   while getopts "vo:h" opt; do
       case "$opt" in
           v)  verbose=1 ;;
           o)  output_file="$OPTARG" ;;
           h)  echo "Usage: $0 [-v] [-o output]"; exit 0 ;;
           \?) echo "Invalid: -$OPTARG" >&2; exit 1 ;;
           :)  echo "-$OPTARG needs an arg" >&2; exit 1 ;;
       esac
   done

   shift $((OPTIND - 1))

**Anatomy of the option string ``"vo:h"``:**

.. code-block:: text

   "vo:h"
    │││└── 'h' → flag option, no argument
    ││└─── ':' after 'o' → option 'o' REQUIRES an argument
    │└──── 'o' option
    └───── 'v' flag option

   Prefix with ':' (``":vo:h"``) → suppress getopts's own error messages.

**Key behaviors:**

* ``-abc`` → processed as ``-a -b -c`` automatically
* ``-o value`` and ``-ovalue`` → both set ``$OPTARG = value``
* ``$OPTIND`` tracks the next argument to process
* ``shift $((OPTIND - 1))`` removes all processed options

--------------------------------
8.7.6 Long Options with ``getopts``
--------------------------------

Standard ``getopts`` does not support long options.  Workaround:

.. code-block:: bash

   while [[ $# -gt 0 ]]; do
       case "$1" in
           --verbose) set -- "$@" -v ;;
           --output=*) set -- "$@" -o "${1#*=}" ;;
           --output)   set -- "$@" -o "$2"; shift ;;
           --help)     set -- "$@" -h ;;
           --)         shift; break ;;
           *)          break ;;
       esac
       shift
   done
   # Then normal getopts processes the short options

--------------------------------
8.7.7 What NOT to Do — Argument Parsing Pitfalls
--------------------------------

**Antipattern 1:** Using ``$@`` without quotes — word splitting destroys
argument boundaries.

**Antipattern 2:** Confusing ``$#`` (argument count) with a variable's value.

**Antipattern 3:** Assuming ``$0`` is always the script path — fails when
sourced.

**Antipattern 4:** Not handling ``--`` (end-of-options marker).

**Antipattern 5:** Using ``$OPTARG`` outside the ``getopts`` loop.

--------------------------------
8.7.8 Summary
--------------------------------

+------------------+-------------------------------------------------------+
| Technique        | Best for                                               |
+==================+=======================================================+
| ``$1``..``$9``   | Simple scripts with fixed positional args             |
+------------------+-------------------------------------------------------+
| ``"$@"``         | Iterating over all arguments safely                   |
+------------------+-------------------------------------------------------+
| ``shift``        | Consuming arguments one at a time                     |
+------------------+-------------------------------------------------------+
| ``case``+``shift`` | Manual parsing for small numbers of options         |
+------------------+-------------------------------------------------------+
| ``getopts``      | Robust short-option parsing (standard approach)       |
+------------------+-------------------------------------------------------+
