.. _shell-architecture:

Shell Architecture
===========================================

.. sidebar:: In This Section

   * Builtins vs. external commands
   * How the shell finds executables: ``$PATH``
   * ``type``, ``which``, ``command``, ``hash``
   * Command parsing and the read-eval loop

---

What happens when you press :kbd:`Enter` on a line like ``ls -l /tmp``? The
shell does not simply hand the string to the kernel — the kernel has no idea
what "ls" means. Instead, the shell performs a sophisticated parse,
dispatch, and execution sequence that this section unpacks in full detail.

.. _shell-read-eval-loop:

The Read-Eval-Print Loop (REPL)
================================

Every interactive shell is, at its heart, a REPL: a loop that **reads** a line
of input, **evaluates** (parses and executes) it, **prints** the result, and
**loops** back for more. In pseudocode:

.. code-block:: python

    while True:
        line = read_line()
        parsed = parse(line)        # tokenise, expand, redirect
        result = execute(parsed)    # dispatch builtin or external
        if result is not None:
            print(result)

Step by step through ``ls -l /tmp > out.txt``:

1. **Read:** The shell reads the raw string ``ls -l /tmp > out.txt`` from
   standard input (or a script file).
2. **Lexical analysis (tokenisation):** The line is broken into tokens:
   ``ls``, ``-l``, ``/tmp``, ``>``, ``out.txt``. The shell identifies ``>``
   as a redirection operator, not an argument to ``ls``.
3. **Expansion:** Any variables (``$HOME``), globs (``*.txt``), tilde
   (``~``), or command substitutions (``$(...)``) are expanded *before* the
   command executes.
4. **Redirection setup:** The shell opens ``out.txt`` for writing and
   arranges for file descriptor 1 (stdout) to point to that file.
5. **Execution:** The shell determines whether ``ls`` is a builtin or an
   external binary and dispatches accordingly.
6. **Wait and collect:** The shell waits for the process to finish, collects
   its exit status (``$?``), and displays the next prompt.

.. _shell-builtins-vs-external:

Builtins vs. External Commands
================================

Not all commands are created equal. The shell classifies every command into one
of several categories, and understanding the differences avoids some of the
most common beginner pitfalls.

**External commands** are standalone executable files residing somewhere on the
filesystem. When you run ``ls``, the shell locates ``/usr/bin/ls`` (or
``/bin/ls``), forks a child process, and calls ``execve()`` to replace that
child with the ``ls`` binary. Examples: ``ls``, ``grep``, ``python3``,
``find``, ``tar``.

**Builtin commands** (or *shell builtins*) are implemented inside the shell
process itself. They execute without forking, which makes them faster and gives
them access to the shell's internal state — something an external process can
never have. Consider ``cd``: if it were an external binary, it would change
*its own* working directory and exit, leaving the shell's working directory
unchanged. ``cd`` *must* be a builtin.

.. list-table:: Common Shell Builtins
   :header-rows: 1
   :widths: 30 70

   * - Builtin
     - Purpose
   * - ``cd``
     - Change the shell's working directory
   * - ``echo``
     - Print text (also exists as ``/bin/echo`` on most systems)
   * - ``export``
     - Mark a variable for inheritance by child processes
   * - ``read``
     - Read a line from stdin into a variable
   * - ``alias`` / ``unalias``
     - Create or remove command aliases
   * - ``source`` (``.``)
     - Execute commands from a file in the *current* shell
   * - ``jobs``, ``fg``, ``bg``
     - Job control (Section 2.7)
   * - ``type``
     - Display how the shell would interpret a command name
   * - ``hash``
     - Remember or display command path lookups
   * - ``set``
     - Set shell options and positional parameters
   * - ``exit``
     - Terminate the shell

.. note::

   Some commands exist as **both** a builtin and an external binary. ``echo``
   is the classic example: Bash provides a builtin ``echo`` that is faster and
   supports ``-e`` for escape sequences, but ``/bin/echo`` (GNU coreutils)
   behaves slightly differently. When in doubt, use ``type`` to check or
   ``command`` to force a particular variant.

**Keywords** are reserved words that are part of the shell's grammar, not
commands per se: ``if``, ``then``, ``else``, ``elif``, ``fi``, ``for``,
``while``, ``until``, ``do``, ``done``, ``case``, ``esac``, ``function``,
``time``, ``{``, ``}``, ``!``, ``[[``, ``]]``. You cannot create a command or
alias named ``if``.

.. _shell-path:

The ``$PATH`` Variable
=========================

When you type ``ls``, how does the shell know that the executable lives at
``/usr/bin/ls`` rather than ``/bin/ls`` or ``/usr/local/bin/ls``? The answer
is ``$PATH`` — a colon-separated list of directories that the shell searches in
order.

.. code-block:: bash

    $ echo $PATH
    /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

The search is strictly sequential: the shell checks each directory from left to
right and executes the *first* matching executable it finds. This has profound
implications:

- If you install a custom ``python3`` in ``/usr/local/bin``, it shadows the
  system ``python3`` in ``/usr/bin`` because ``/usr/local/bin`` usually
  precedes ``/usr/bin`` in the path.
- Malware that drops a binary called ``ls`` into a directory earlier in ``PATH``
  can intercept every invocation — a classic local privilege escalation vector.
- If ``.`` (the current directory) appears in ``PATH``, running ``ls`` from a
  directory containing a malicious script named ``ls`` executes that script.
  **Never put ``.`` in your ``PATH``**, especially not at the beginning.

**Modifying PATH:**

.. code-block:: bash

    # Append a directory (lowest priority)
    export PATH="$PATH:/opt/custom/bin"

    # Prepend a directory (highest priority)
    export PATH="$HOME/.local/bin:$PATH"

This is typically done in ``~/.bashrc`` or ``~/.profile`` (see Section 2.3).

.. _shell-command-resolution:

How the Shell Resolves Commands
=================================

The shell's command resolution follows a strict precedence. When you type
``foo bar``, the shell checks, in order:

1. **Aliases:** If ``foo`` is an alias, substitute its definition and restart.
2. **Keywords:** If ``foo`` is a reserved word (``if``, ``for``, etc.), handle
   it as part of shell grammar.
3. **Functions:** If a shell function named ``foo`` exists, execute it.
4. **Builtins:** If ``foo`` is a shell builtin, execute it internally.
5. **External command:** Search ``$PATH`` for an executable file named ``foo``.
   If found, fork and exec.
6. **Command not found:** If nothing matches, print an error and set ``$?`` to
   127.

.. code-block:: bash

    # Demonstrate resolution order
    $ alias ls='ls --color=auto'        # step 1: alias shadows everything
    $ function ls { echo "my ls"; }     # would be step 3 if alias removed
    $ \ls                                # backslash bypasses alias lookup
    $ command ls                         # builtin 'command' skips functions and aliases
    $ builtin ls                         # forces builtin lookup only (Bash)

.. _shell-type-which-command:

Diagnostic Tools: ``type``, ``which``, ``command``, and ``hash``
==================================================================

``type`` — The Definitive Answer
---------------------------------

``type`` is a **shell builtin** that tells you exactly how the shell would
interpret a given name. This is the most reliable diagnostic tool because it
understands the shell's resolution order.

.. code-block:: bash

    $ type ls
    ls is aliased to `ls --color=auto'

    $ type -a ls          # show ALL matches in precedence order
    ls is aliased to `ls --color=auto'
    ls is /usr/bin/ls
    ls is /bin/ls

    $ type cd
    cd is a shell builtin

    $ type -t ls          # single-word type: alias, keyword, function, builtin, or file
    alias

    $ type -P ls          # force PATH search even for builtins/aliases
    /usr/bin/ls

Always prefer ``type`` over ``which`` for diagnostic work.

``which`` — External Path Lookup
---------------------------------

``which`` is an **external command** that searches ``$PATH`` for executables.
It does *not* know about aliases, functions, or builtins, so its results can be
misleading:

.. code-block:: bash

    $ which ls
    /usr/bin/ls               # correct, but misses the alias

    $ alias ls='ls -F'
    $ which ls
    /usr/bin/ls               # still shows disk path; type would show the alias

``which`` is useful in scripts when you need to check if an external tool
exists:

.. code-block:: bash

    if which convert > /dev/null 2>&1; then
        echo "ImageMagick is installed"
    fi

However, ``command -v`` (see below) is more portable and preferred.

``command`` — Controlled Execution
-----------------------------------

The ``command`` builtin serves two purposes:

1. **Suppress alias and function lookup:** Run the "real" command even if
   shadowed.

   .. code-block:: bash

       $ command ls          # run /usr/bin/ls, ignoring any alias or function

2. **Portable existence check (``-v``):** Works across all POSIX shells, unlike
   ``which``.

   .. code-block:: bash

       $ command -v ls
       alias ls='ls --color=auto'

       $ command -v python3
       /usr/bin/python3

       $ if command -v docker > /dev/null 2>&1; then
       >     echo "Docker found"
       > fi

``hash`` — The Command Lookup Cache
--------------------------------------

Every time the shell needs to find an external command, searching ``$PATH``
would be expensive. Bash maintains a **hash table** (in-memory cache) mapping
command names to their full paths:

.. code-block:: bash

    $ hash                     # display entire hash table
    hits    command
       1    /usr/bin/ls
       4    /usr/bin/grep

    $ hash -r                  # clear the hash table (useful after installing new tools)

    $ hash -t ls               # print hashed path for 'ls' without executing it
    /usr/bin/ls

After installing a new program in a ``PATH`` directory, you may need to run
``hash -r`` for the shell to find it if a different version of the same name
was previously cached.

.. _shell-command-parsing:

Command Parsing: A Deeper Look
=================================

The shell's parser is not a simple string splitter. Consider:

.. code-block:: bash

    $ echo "hello world" >    output.txt

The shell must understand that ``"hello world"`` is a single token despite
the space, that ``>`` is a redirection operator, and that ``output.txt`` is
the redirection target, not an argument to ``echo``. This is achieved through a
sequence of processing steps, each applied to the *entire* command line:

.. list-table:: Shell Expansion Order (POSIX)
   :header-rows: 1
   :widths: 5 20 75

   * - Step
     - Name
     - Description
   * - 1
     - Brace expansion
     - ``{a,b,c}`` → ``a b c`` (Bash/Zsh; not POSIX)
   * - 2
     - Tilde expansion
     - ``~`` → ``$HOME``, ``~alice`` → home directory of alice
   * - 3
     - Parameter expansion
     - ``$VAR``, ``${VAR:-default}``
   * - 4
     - Command substitution
     - ``$(cmd)`` or `` `cmd` ``
   * - 5
     - Arithmetic expansion
     - ``$(( 1 + 2 ))``
   * - 6
     - Word splitting
     - Split result of unquoted expansions on ``$IFS``
   * - 7
     - Pathname expansion (globbing)
     - ``*.txt`` → ``a.txt b.txt``
   * - 8
     - Quote removal
     - Remove ``'``, ``"``, and ``\`` characters that were used for quoting

.. warning::

   Word splitting (step 6) is the source of countless bugs. Consider:

   .. code-block:: bash

       $ FILES="file one.txt file two.txt"
       $ cat $FILES          # WRONG: word splitting breaks filenames at spaces

   The unquoted ``$FILES`` undergoes word splitting into four tokens:
   ``file``, ``one.txt``, ``file``, and ``two.txt``. **Always quote variable
   expansions unless you explicitly want word splitting**: ``cat "$FILES"``.

.. _shell-quoting:

Quoting Mechanisms
===================

The shell provides three quoting mechanisms to control expansion:

.. list-table::
   :header-rows: 1
   :widths: 15 30 55

   * - Mechanism
     - Example
     - What gets suppressed
   * - Backslash (``\``)
     - ``\$HOME``
     - Special meaning of the *next* character only
   * - Single quotes (``'...'``)
     - ``'$HOME'``
     - **All** special characters; literal string
   * - Double quotes (``"...")``
     - ``"$HOME"``
     - Most special characters, but ``$``, `` ` ``, ``!``, and ``\`` are still honoured

.. code-block:: bash

    $ echo '$HOME is '"$HOME"
    $HOME is /home/alice

    $ echo "Today is $(date +%A)"
    Today is Wednesday

.. _shell-cross-shell:

Shell Variants and Portability
=================================

Throughout this book we use **Bash** (GNU Bourne-Again SHell) as our reference
shell. It is the default on virtually every Linux distribution and is
backward-compatible with the POSIX ``sh`` standard. However, you will encounter
other shells in the wild:

.. list-table::
   :header-rows: 1
   :widths: 15 35 50

   * - Shell
     - Common Habitat
     - Noteworthy Differences
   * - **Bash**
     - Default on Debian, Ubuntu, Fedora, RHEL, Arch
     - The reference shell. Rich interactive features, ``[[``, arrays,
       ``{1..10}``, coprocesses.
   * - **Zsh**
     - Default on macOS (since Catalina) and Kali Linux
     - Superset of Bash with superior completion, globbing, theming, and
       plugin ecosystem (Oh My Zsh). Most Bash scripts run under Zsh but not
       all.
   * - **Dash / Ash**
     - ``/bin/sh`` on Debian/Ubuntu; Alpine Linux; embedded systems
     - Minimal, fast, POSIX-compliant. No arrays, no ``[[``, no
       ``{1..10}``, no ``<<<``. Used for ``#!/bin/sh`` scripts and initramfs.
   * - **Fish**
     - User-chosen interactive shell
     - Deliberately **not** POSIX-compatible. Unique syntax: no ``$`` for
       variables in most contexts, ``set var value``, ``end`` instead of
       ``fi``/``done``. Excellent defaults but cannot run standard shell
       scripts.

.. admonition:: Best Practice: Script Shebangs

   - Use ``#!/usr/bin/env bash`` for Bash scripts that need Bash features.
   - Use ``#!/bin/sh`` for maximally portable POSIX scripts.
   - Never use ``#!/bin/bash`` directly unless you are certain of the path;
     NixOS and GuixSD put Bash elsewhere.

.. _shell-exit-status:

Exit Status and ``$?``
=========================

Every command — builtin or external — returns an **exit status** (also called
*return code* or *exit code*): an integer between 0 and 255. By convention:

- ``0`` means **success** (no error).
- Any non-zero value means **failure**, with specific values conveying
  different errors.

.. code-block:: bash

    $ ls /exists
    file.txt
    $ echo $?
    0

    $ ls /nonexistent
    ls: cannot access '/nonexistent': No such file or directory
    $ echo $?
    2

    $ true;  echo $?    # always returns 0
    0
    $ false; echo $?    # always returns 1
    1

The exit status is the basis of conditional execution (``&&``, ``||``),
``if`` statements, ``set -e`` in scripts, and CI/CD pipelines:

.. code-block:: bash

    $ make && make install     # run install only if make succeeds
    $ grep pattern file || echo "pattern not found"

.. admonition:: Key Takeaway

   The shell is not just a "command prompt" — it is a programming language
   interpreter with a defined grammar, resolution order, and execution model.
   Understanding how commands are found and dispatched transforms the terminal
   from a mysterious black box into a predictable, programmable tool.
