.. _conditionals:

.. highlight:: bash

================================
— Conditionals
================================

Conditionals allow a script to make decisions based on the state of the system,
the value of a variable, or the outcome of a command.

--------------------------------
The ``if`` Statement — Fundamentals
--------------------------------

.. code-block:: bash

   if command; then
       # run if command succeeded (exit code 0)
   elif command2; then
       # run if command2 succeeded
   else
       # run if none of the above succeeded
   fi

**Critical insight:** ``if`` evaluates the **exit code** of a command, not a
boolean expression.  Exit code 0 = "true" (success); non-zero = "false".

.. code-block:: bash

   if grep -q "error" /var/log/syslog; then
       echo "Errors found in log"
   fi

   # Short-circuit equivalents:
   grep -q "error" /var/log/syslog && echo "Errors found"
   cd /some/directory || { echo "cd failed"; exit 1; }

--------------------------------
The ``test`` Command: ``[ ]`` vs ``[[ ]]``
--------------------------------

**``[ ]`` — POSIX test**: A command (``/usr/bin/[`` exists).  The closing
``]`` is its last required argument.

**``[[ ]]`` — Bash extended test**: A keyword, not a command.  Receives
special parsing treatment.

**Key differences:**

+--------------------------+------------------------------------+--------------------------------------+
| Feature                  | ``[ ]`` (POSIX)                    | ``[[ ]]`` (Bash)                     |
+==========================+====================================+======================================+
| Word splitting           | Yes — unquoted variables split     | No — variables are NOT word-split    |
+--------------------------+------------------------------------+--------------------------------------+
| Pathname expansion       | Yes — globs expand                 | No — globs are literal               |
+--------------------------+------------------------------------+--------------------------------------+
| Empty variable safety    | Must quote: ``[ "$x" = "y" ]``     | Safe unquoted: ``[[ $x == y ]]``     |
+--------------------------+------------------------------------+--------------------------------------+
| Pattern matching         | No                                 | ``[[ $str == *.txt ]]``              |
+--------------------------+------------------------------------+--------------------------------------+
| Regex matching           | No                                 | ``[[ $str =~ ^[0-9]+$ ]]``           |
+--------------------------+------------------------------------+--------------------------------------+
| Logical operators        | ``-a``, ``-o``, ``!``              | ``&&``, ``||``, ``!``                |
+--------------------------+------------------------------------+--------------------------------------+

**The practical rule:** In a bash script, use ``[[ ]]``.  Use ``[ ]`` only
when you need strict POSIX compatibility (``/bin/sh``).

--------------------------------
File Test Operators
--------------------------------

+----------+--------------------------------------------+
| Operator | True if...                                 |
+==========+============================================+
| ``-e``   | File exists (any type)                     |
| ``-f``   | Regular file exists                        |
| ``-d``   | Directory exists                           |
| ``-L``   | Symlink exists                             |
| ``-r``   | File exists and readable                   |
| ``-w``   | File exists and writable                   |
| ``-x``   | File exists and executable                 |
| ``-s``   | File exists and has size > 0               |
| ``-nt``  | File1 is newer than File2                  |
| ``-ot``  | File1 is older than File2                  |
+----------+--------------------------------------------+

--------------------------------
String Tests
--------------------------------

+----------+--------------------------------------------+
| Operator | True if...                                 |
+==========+============================================+
| ``-z``   | String is empty (zero length)              |
| ``-n``   | String is non-empty                        |
| ``==``   | Strings equal (Bash)                       |
| ``!=``   | Strings not equal                          |
| ``<``    | String1 < String2 (lexicographic, [[ ]])   |
| ``>``    | String1 > String2 (lexicographic, [[ ]])   |
+----------+--------------------------------------------+

--------------------------------
Arithmetic Tests
--------------------------------

.. code-block:: bash

   # Method 1: (( )) — preferred
   if (( count > 10 )); then echo "Exceeds threshold"; fi

   # Method 2: -eq, -ne, -lt, -le, -gt, -ge inside [[ ]]
   if [[ $count -gt 10 ]]; then ...

   # Method 3: Legacy POSIX [ ]
   if [ "$count" -gt 10 ]; then ...

--------------------------------
The ``case`` Statement
--------------------------------

.. code-block:: bash

   case "$1" in
       start)
           systemctl start myapp
           ;;
       stop|kill)
           systemctl stop myapp
           ;;
       *)
           echo "Usage: $0 {start|stop}" >&2
           exit 1
           ;;
   esac

--------------------------------
What NOT to Do — Conditional Pitfalls
--------------------------------

**Antipattern 1:** Using ``>`` inside ``[ ]`` for string comparison
(``>`` is output redirection!).  Use ``[[ $a > $b ]]`` or escape ``\>``.

**Antipattern 2:** Forgetting spaces around brackets
``["$x" = "y"]`` — syntax error.  ``[`` is a command, needs spaces.

**Antipattern 3:** Testing exit codes with ``$?``
Fragile — the exit code can be overwritten.  Test the command directly.

**Antipattern 4:** Using ``[[ ]]`` in a ``#!/bin/sh`` script
Fails on systems where ``/bin/sh`` is dash.  Use ``[ ]`` for portability.

--------------------------------
Summary
--------------------------------

+------------------+-------------------------------------------------------+
| Construct        | Best Use Case                                         |
+==================+=======================================================+
| ``if command``   | Testing command exit codes directly                   |
+------------------+-------------------------------------------------------+
| ``[ ]``          | POSIX compatibility; portable scripts under ``/bin/sh``|
+------------------+-------------------------------------------------------+
| ``[[ ]]``        | Bash-specific scripts (preferred when allowed)        |
+------------------+-------------------------------------------------------+
| ``(( ))``        | Integer arithmetic comparisons                        |
+------------------+-------------------------------------------------------+
| ``case``         | Multi-way pattern matching (5+ branches)              |
+------------------+-------------------------------------------------------+
