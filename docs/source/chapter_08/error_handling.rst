.. highlight:: bash

========================================
8.6 — Error Handling & Robustness
========================================

The difference between a toy script and a production-grade tool is how it
handles failure.  A robust shell script stops on unexpected errors, provides
meaningful error messages, cleans up temporary resources, and is debuggable.

--------------------------------
8.6.1 The Golden Trifecta: ``set -euo pipefail``
--------------------------------

Place this immediately after the shebang:

.. code-block:: bash

   #!/usr/bin/env bash
   set -euo pipefail

**What each does:**

* ``set -e`` (``errexit``): Exit immediately if any command returns non-zero.
* ``set -u`` (``nounset``): Treat undefined variables as fatal errors.
* ``set -o pipefail``: Propagate failure if *any* command in a pipeline fails.

**Exceptions** — ``set -e`` does NOT fire inside:

* Conditionals (``if``, ``while``, ``until``)
* Commands after ``&&`` or ``||``
* Commands whose exit code is inverted with ``!``

--------------------------------
8.6.2 The ``trap`` Statement
--------------------------------

.. code-block:: bash

   trap 'rm -rf "$WORKDIR"' EXIT        # Cleanup on exit
   trap 'log_error $LINENO' ERR         # Log on error
   trap '' INT TERM                     # Ignore Ctrl+C and kill

**Practical example:**

.. code-block:: bash

   cleanup() {
       local exit_code=$?
       echo "Cleanup: removing $WORKDIR" >&2
       rm -rf "$WORKDIR"
       return $exit_code
   }
   trap cleanup EXIT

   WORKDIR=$(mktemp -d)   # Created, will be cleaned up on any exit

**Error handler with line numbers:**

.. code-block:: bash

   error_handler() {
       local line=$1 command="$2"
       echo "ERROR: '$command' failed at line $line" >&2
   }
   trap 'error_handler $LINENO "$BASH_COMMAND"' ERR

--------------------------------
8.6.3 Robust Logging Functions
--------------------------------

.. code-block:: bash

   log() {
       local level="$1" msg="$2"
       local ts; ts="$(date '+%Y-%m-%d %H:%M:%S')"
       echo "[$ts] $level: $msg" >&2
   }

   die() { log "FATAL" "$*"; exit 1; }
   info() { log "INFO" "$*"; }
   warn() { log "WARN" "$*"; }

--------------------------------
8.6.4 Debugging with ``bash -x``
--------------------------------

.. code-block:: bash

   bash -x myscript.sh           # Trace execution
   bash -n myscript.sh           # Syntax check only

   # Inside a script:
   set -x      # Enable trace
   # ... code to debug ...
   set +x      # Disable trace

   # Custom PS4 for context:
   export PS4='+ [${BASH_SOURCE[0]}:${LINENO}] '

--------------------------------
8.6.5 Exit Codes and Conventions
--------------------------------

.. code-block:: text

   0   — Success
   1   — General error
   2   — Misuse of shell built-in
   126 — Command found but not executable
   127 — Command not found
   130 — Script terminated by Ctrl+C

Use named constants in your scripts:

.. code-block:: bash

   E_SUCCESS=0; E_INVALID_ARGS=2
   [[ -n "${1:-}" ]] || exit $E_INVALID_ARGS

--------------------------------
8.6.6 Defensive Programming Checklist
--------------------------------

1. ``set -euo pipefail`` at the top
2. ``IFS=$'\n\t'`` to prevent word-splitting surprises
3. ``umask 077`` if creating files
4. Check prerequisites with ``command -v``
5. Validate arguments early
6. Quote every variable expansion
7. Use ``trap cleanup EXIT``
8. Send errors to stderr (``>&2``)
9. Log with timestamps
10. Test with ``bash -n`` after editing

--------------------------------
8.6.7 What NOT to Do — Error Handling Pitfalls
--------------------------------

**Antipattern 1:** Masking errors with ``|| true`` without logging.

**Antipattern 2:** Exit code in a pipeline without ``pipefail`` — only the
last command's exit code is visible.

**Antipattern 3:** Not checking ``command -v`` before using a tool.

**Antipattern 4:** Catching SIGKILL — ``trap '' KILL`` is impossible (SIGKILL
cannot be caught).

**Antipattern 5:** Using ``exit`` inside a sourced script — kills the calling
shell.  Use ``return`` instead.

--------------------------------
8.6.8 Summary
--------------------------------

+------------------------+-------------------------------------------------+
| Technique              | Purpose                                         |
+========================+=================================================+
| ``set -euo pipefail``  | Stop on errors, undefined vars, pipeline fails  |
+------------------------+-------------------------------------------------+
| ``trap 'cmd' EXIT``    | Guaranteed cleanup on script exit               |
+------------------------+-------------------------------------------------+
| ``bash -x`` / ``set -x`` | Trace execution with expanded values          |
+------------------------+-------------------------------------------------+
| ``bash -n``            | Syntax check without running                    |
+------------------------+-------------------------------------------------+
| Logging functions      | Structured, timestamped, leveled output          |
+------------------------+-------------------------------------------------+
