.. _variables-data-types:

.. highlight:: bash

========================================
— Variables & Data Types
========================================

Variables are the memory of a script.  They store strings, numbers, lists, and
command outputs.  Understanding how bash handles variables — especially its
quirks around typing, quoting, and expansion — is essential for writing
correct scripts.

--------------------------------
Variable Assignment and Naming
--------------------------------

**Assignment syntax — NO spaces around ``=``:**

.. code-block:: bash

   name="John"       # Correct
   count=42          # Correct
   name = "John"     # WRONG — shell interprets "name" as a command

**Naming rules:**

* First character: a letter or underscore (``_``).
* Subsequent characters: letters, digits, or underscores.
* Case-sensitive: ``NAME``, ``name``, and ``Name`` are different variables.
* By convention, **environment variables are UPPERCASE** while **script-local
  variables are lowercase or mixed case**.

**Reading a variable — the ``$`` prefix:**

.. code-block:: bash

   echo "$name"      # Prints: John
   echo "$name"      # Always quote!
   echo ${name}      # Braces optional — needed when concatenating
   echo ${name}smith # Prints: Johnsmith — braces delimit the name

**Unset vs empty:**

.. code-block:: bash

   unset name        # Variable is deleted entirely
   name=""           # Variable exists but is empty
   name=             # Same as name=""

--------------------------------
Strings
--------------------------------

Everything in bash is ultimately a string.

**Single quotes (``'...'``) — literal:** nothing is interpreted.

**Double quotes (``"..."``) — interpolating:** ``$``, ``\``, ``\``, ``!``,
and ``"`` have special meaning.

**Here documents (heredocs) — multi-line strings:**

.. code-block:: bash

   cat <<EOF
   Hello $USER
   EOF

   # Quoted delimiter prevents expansion:
   cat <<'EOF'
   Hello $USER   # Prints literally
   EOF

**Here strings — single-line string input:**

.. code-block:: bash

   grep "error" <<< "$log_data"
   read first last <<< "John Smith"

--------------------------------
Integers and Arithmetic
--------------------------------

Bash has built-in arithmetic using ``$(( ... ))``:

.. code-block:: bash

   a=5; b=3
   sum=$((a + b))          # sum=8
   quot=$((a / b))         # quot=1 (integer division!)
   pow=$((a ** b))         # pow=125

**Common pitfalls:**

* Floating point does NOT exist in bash — use ``bc`` or ``awk``.
* ``let`` is legacy — avoid; use ``((x++))`` instead.

**C-style arithmetic (( )):**

.. code-block:: bash

   ((a++))                 # Increment a by 1
   ((a += 5))              # Add 5 to a
   if ((a > b)); then echo "a is greater"; fi

--------------------------------
Arrays
--------------------------------

**Indexed arrays:**

.. code-block:: bash

   files=("a.txt" "b.txt" "c.txt")
   files+=("d.txt")
   echo "${files[0]}"      # a.txt
   echo "${files[@]}"      # a.txt b.txt c.txt d.txt
   echo "${#files[@]}"     # 4

**Associative arrays (Bash 4.0+):**

.. code-block:: bash

   declare -A user
   user[name]="Alice"
   user[role]="admin"
   echo "${!user[@]}"      # name role

**Antipattern — iterating over ``$(ls ...)`` instead of arrays:**
Parsing ``ls`` breaks when filenames contain spaces or special characters.
Use native globbing instead.

--------------------------------
Parameter Expansion — The ``${}`` Toolbox
--------------------------------

**Default values:**

+-----------------------------------+----------------------------------------------+
| Syntax                            | Meaning                                      |
+===================================+==============================================+
| ``${var:-default}``               | Use ``default`` if ``var`` is unset or empty |
| ``${var-default}``                | Use ``default`` only if ``var`` is **unset** |
| ``${var:=default}``               | Assign ``default`` to ``var`` if unset/empty |
| ``${var:?error message}``         | Exit with error if ``var`` is unset/empty    |
+-----------------------------------+----------------------------------------------+

**String manipulation:**

+-----------------------------------+----------------------------------------------+
| Syntax                            | Effect                                       |
+===================================+==============================================+
| ``${#string}``                    | Length of string                             |
| ``${string:offset:length}``       | Substring                                    |
| ``${string#pattern}``             | Remove shortest prefix match                 |
| ``${string##pattern}``            | Remove longest prefix match                  |
| ``${string%pattern}``             | Remove shortest suffix match                 |
| ``${string%%pattern}``            | Remove longest suffix match                  |
| ``${string/pattern/replacement}`` | Replace first match                          |
| ``${string//pattern/replacement}``| Replace all matches                          |
| ``${string,,}``                   | Lowercase all                                |
| ``${string^^}``                   | Uppercase all                                |
+-----------------------------------+----------------------------------------------+

--------------------------------
Strict Quoting Rules
--------------------------------

**The golden rule: Always double-quote variable expansions.**

.. code-block:: bash

   # WRONG — unquoted variable
   file="My Document.txt"
   cat $file              # Tries to cat "My" then "Document.txt"

   # CORRECT — quoted
   cat "$file"            # Opens "My Document.txt"

**When to use single quotes vs double quotes:**

+--------------------------+----------------------------+
| Data                     | Quote type                 |
+==========================+============================+
| Fixed literal string     | Single ``'...'``           |
+--------------------------+----------------------------+
| String with variables    | Double ``"..."``           |
+--------------------------+----------------------------+
| Glob pattern             | Unquoted for expansion     |
+--------------------------+----------------------------+

**``$@`` vs ``$*`` quoting — critical difference:**

Always use ``"$@"``.  ``"$*"`` concatenates all arguments into a single word.
Unquoted ``$@`` and ``$*`` destroy argument boundaries via word splitting.

--------------------------------
What NOT to Do — Variable & Quoting Pitfalls
--------------------------------

**Antipattern 1:** Unquoted variables in test expressions
``[ $name = "admin" ]`` breaks when ``$name`` is empty or contains spaces.
Use ``[[ $name == "admin" ]]`` instead.

**Antipattern 2:** Using uppercase for local script variables
``PATH="/my/custom/path"`` overwrites the system ``PATH``!
Use lowercase for script-internal variables.

**Antipattern 3:** Assuming ``$var`` gives all array elements
``echo "$arr"`` prints only the first element.  Use ``"${arr[@]}"``.

--------------------------------
Summary
--------------------------------

+------------------+-------------------------------------------------------+
| Concept          | Key Takeaway                                          |
+==================+=======================================================+
| Assignment       | ``name="value"`` — NO spaces around ``=``             |
+------------------+-------------------------------------------------------+
| Strings          | Single quotes = literal; Double quotes = interpolate  |
+------------------+-------------------------------------------------------+
| Integers         | ``$(( a + b ))``; use ``bc`` for floats               |
+------------------+-------------------------------------------------------+
| Arrays           | ``"${arr[@]}"`` for all elements                      |
+------------------+-------------------------------------------------------+
| Parameter Exp.   | ``${var:-default}``, ``${string#prefix}``, etc.       |
+------------------+-------------------------------------------------------+
| Quoting          | **Always** double-quote ``"$var"`` and ``"$@"``       |
+------------------+-------------------------------------------------------+
