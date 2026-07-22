.. highlight:: bash

=============================
8.4 — Loops
=============================

Loops automate repetition.  Whether iterating over files, retrying a network
operation, or processing each line of a log file, the shell provides ``for``,
``while``, and ``until``.

--------------------------------
8.4.1 The ``for`` Loop
--------------------------------

**Form 1: Iterating over a list of words**

.. code-block:: bash

   for fruit in apple banana cherry; do
       echo "Fruit: $fruit"
   done

   # Array iteration — ALWAYS quote
   for fruit in "${fruits[@]}"; do
       echo "Fruit: $fruit"
   done

   # Glob expansion — SAFE, even with spaces
   for file in /var/log/*.log; do
       if [[ -f $file ]]; then
           echo "Processing: $file"
       fi
   done

**Form 2: C-style ``for`` (Bash 4.2+)**

.. code-block:: bash

   for (( i=0; i<10; i++ )); do
       echo "$i"
   done

**Form 3: Implicit ``in "$@"``**

.. code-block:: bash

   for arg; do
       echo "Argument: $arg"
   done

--------------------------------
8.4.2 The ``while`` Loop
--------------------------------

.. code-block:: bash

   # Read a file line by line (ROBUST pattern)
   while IFS= read -r line; do
       echo "Line: $line"
   done < "/path/to/file"

   # Countdown
   count=5
   while (( count > 0 )); do
       echo "T-minus $count"
       ((count--))
   done

   # Infinite loop (with break condition)
   while true; do
       read -p "Enter a number (0 to quit): " num
       [[ $num == "0" ]] && break
       echo "You entered: $num"
   done

**The ``while read`` pattern — anatomy:**

.. code-block:: text

   while IFS= read -r line; do ... done < file

   │      │    │   │                │       └── Input redirected from file
   │      │    │   │                └── Loop body
   │      │    │   └── -r: raw mode — backslashes are literal
   │      │    └── read: reads one line from stdin
   │      └── IFS=: empties IFS so read doesn't strip whitespace
   └── while: continues as long as read finds data (exit 0)

.. _antipattern_for_loop_read:

**Antipattern — using ``for`` to read a file:**
``for line in $(cat file)`` splits on IFS (space/tab/newline), not lines.
Always use ``while IFS= read -r line``.

--------------------------------
8.4.3 The ``until`` Loop
--------------------------------

.. code-block:: bash

   # Wait for a file to appear
   until [[ -f /tmp/ready.lock ]]; do
       echo "Waiting..."
       sleep 2
   done

--------------------------------
8.4.4 ``break`` and ``continue``
--------------------------------

.. code-block:: bash

   for i in {1..100}; do
       (( i > 5 )) && break      # Exit loop
       (( i % 2 == 0 )) && continue  # Skip evens
       echo "$i"
   done

``break N`` and ``continue N`` break/continue N levels of nested loops.

--------------------------------
8.4.5 Safe File Iteration — The Glob Idiom
--------------------------------

.. code-block:: bash

   shopt -s nullglob   # Unmatched globs → empty, not literal pattern
   for file in /var/log/*.log; do
       echo "Processing: $file"
   done
   shopt -u nullglob

--------------------------------
8.4.6 Loop Performance Considerations
--------------------------------

Each external command (``grep``, ``awk``, ``sed``) inside a loop requires a
``fork()``/``exec()``.  Move processing outside the loop when possible:

.. code-block:: bash

   # BAD — forks grep for every file
   for file in *.log; do grep "ERROR" "$file" >> errors.txt; done

   # GOOD — single grep
   grep "ERROR" *.log > errors.txt

--------------------------------
8.4.7 What NOT to Do — Loop Pitfalls
--------------------------------

**Antipattern 1:** Word splitting disaster with ``$(find ...)``
Use ``find -print0`` with ``while IFS= read -r -d ''``.

**Antipattern 2:** Modifying loop variable in pipeline
``cat file | while read x; do sum=$((sum+x)); done`` — the ``while`` runs in a
subshell, so ``$sum`` is lost.  Use ``< file`` redirection instead.

**Antipattern 3:** Infinite loop without escape

--------------------------------
8.4.8 Summary
--------------------------------

+----------+---------------------------------------------+
| Loop     | Best Use Case                               |
+==========+=============================================+
| ``for``  | Known list of items, glob results, arrays   |
+----------+---------------------------------------------+
| ``while``| Unknown iterations, reading files, polling  |
+----------+---------------------------------------------+
| ``until``| Waiting for a condition to become true      |
+----------+---------------------------------------------+
