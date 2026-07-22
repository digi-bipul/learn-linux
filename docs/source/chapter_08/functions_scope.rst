.. highlight:: bash

========================================
8.5 — Functions & Scope
========================================

Functions are the shell's mechanism for code reuse.  Unlike external scripts,
functions execute **in the current shell process** — they can modify variables,
change directories, and set traps that affect the calling environment.

--------------------------------
8.5.1 Defining Functions
--------------------------------

.. code-block:: bash

   # POSIX-compatible form (preferred)
   my_function() {
       commands
   }

   # Bash-specific form
   function my_function {
       commands
   }

--------------------------------
8.5.2 Function Arguments
--------------------------------

Inside a function, ``$1``, ``$2``, ..., ``$9`` (use ``${10}`` for 10+) are the
positional arguments.  ``$@`` is all arguments, ``$#`` is the count.

.. code-block:: bash

   greet() {
       echo "Hello, $1"
   }
   greet "World"    # Output: Hello, World

--------------------------------
8.5.3 The ``local`` Keyword and Variable Scope
--------------------------------

By default, **all variables in a function are global**.  Always declare
function-internal variables as ``local``.

.. code-block:: bash

   # WRONG — leaks into global scope
   count_files() {
       i=0   # Modifies global i!
       ...
   }

   # CORRECT
   count_files() {
       local i=0
       ...
   }

**``local -n`` — name references (Bash 4.3+):** Pass variables by reference.

.. code-block:: bash

   increment() {
       local -n ref="$1"
       ((ref++))
   }
   myvar=5
   increment myvar    # Pass the NAME, not $myvar
   echo "$myvar"      # 6

--------------------------------
8.5.4 Return Codes vs Echoing Output
--------------------------------

Functions communicate results in two ways:

1. **Return code** — for status (``return 0`` = success, ``return 1`` =
   failure).  Range 0–255.

2. **Standard output** — for data (``echo "data"``).

.. code-block:: bash

   # Return code for status
   is_root() {
       [[ $EUID -eq 0 ]]
   }

   # Stdout for data
   get_username() {
       grep ":${1}:" /etc/passwd | cut -d: -f1
   }

   # Combine both
   divide() {
       local dividend=$1 divisor=$2
       if (( divisor == 0 )); then
           echo "ERROR: Division by zero" >&2
           return 1
       fi
       echo $(( dividend / divisor ))
   }

**Key principle:** Send error messages to ``>&2`` so they do not contaminate
captured output.

--------------------------------
8.5.5 Sourcing Libraries
--------------------------------

.. code-block:: bash

   # lib/utils.sh
   die() { echo "FATAL: $*" >&2; exit 1; }

   # main script
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/lib/utils.sh"

Always use ``BASH_SOURCE`` for reliable path resolution in sourced scripts.

--------------------------------
8.5.6 What NOT to Do — Function Pitfalls
--------------------------------

**Antipattern 1:** Not using ``local`` — variables leak into global scope.

**Antipattern 2:** Using ``return`` for data — ``return`` is for exit codes
(0–255).  Use ``echo`` for data.

**Antipattern 3:** Not quoting function arguments when calling.

**Antipattern 4:** Confusing ``$*`` and ``$@`` inside a function.

--------------------------------
8.5.7 Summary
--------------------------------

+------------------------+-------------------------------------------------+
| Concept                | Key Takeaway                                    |
+========================+=================================================+
| Function declaration   | ``funcname() { ... }`` — POSIX, preferred       |
+------------------------+-------------------------------------------------+
| Arguments              | ``$1``–``$9``, ``${10}``+, ``"$@"``, ``$#``    |
+------------------------+-------------------------------------------------+
| Variable scope         | **Always use ``local``** for function variables |
+------------------------+-------------------------------------------------+
| Return vs output       | ``return`` for exit code; ``echo`` for data     |
+------------------------+-------------------------------------------------+
| Sourcing libraries     | Use ``BASH_SOURCE`` for reliable path resolution |
+------------------------+-------------------------------------------------+
