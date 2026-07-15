===========================================
2.6 Command History & Efficiency
===========================================

.. sidebar:: In This Section

   * ``history`` command and history expansion (``!!``, ``!$``, ``!*``,
     ``^old^new``)
   * Incremental search with :kbd:`Ctrl+R`
   * Brace expansion: ``{1..10}``, ``{a,b,c}``
   * Globbing extensions: ``extglob``, ``globstar``
   * ``xargs`` — building commands from stdin
   * Keyboard shortcuts and readline productivity

---

Typing is expensive. Thinking is cheap. Every keystroke you save is a
cognitive cycle you can devote to the problem, not the interface. This section
covers the shell's built-in mechanisms for remembering, reusing, and generating
commands — turning the terminal from a typewriter into a power tool.

.. _history-command:

The ``history`` Command
=========================

Bash maintains an in-memory history list during your session and writes it to
``~/.bash_history`` on exit (or on demand). The ``history`` builtin displays
and manipulates this list.

.. code-block:: bash

    $ history                    # display full history (all numbered entries)
    $ history 10                 # last 10 entries
    $ history -c                 # clear the in-memory history
    $ history -w                 # write current history to the history file
    $ history -r                 # read history file into memory
    $ history -d 500             # delete entry 500

Key configuration variables (in ``~/.bashrc``):

.. code-block:: bash

    # Number of commands kept in memory:
    HISTSIZE=10000

    # Number of commands kept in the history FILE:
    HISTFILESIZE=20000

    # Append to history file (don't overwrite — preserves multiple sessions):
    shopt -s histappend

    # Don't save duplicate consecutive commands:
    HISTCONTROL=ignoredups

    # Don't save commands starting with space:
    HISTCONTROL=ignorespace

    # Both combined:
    HISTCONTROL=ignoreboth

    # Don't save specific commands:
    HISTIGNORE="ls:cd:exit:history"

    # Timestamp every entry (useful for auditing):
    HISTTIMEFORMAT="%F %T  "

.. warning::

   History is a **security consideration**. Commands containing passwords
   (``mysql -psecret``, ``curl -u admin:hunter2``) are written to
   ``~/.bash_history`` in plain text. Precede such commands with a space
   (if ``HISTCONTROL=ignorespace``) or use read-prompt tools like
   ``pass`` or environment variables.

.. _history-expansion:

History Expansion (Bang Commands)
===================================

History expansion — colloquially "bang commands" for the ``!`` prefix — is a
quick way to recall and modify previous commands without retyping. It is
enabled by default in interactive Bash.

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Syntax
     - Meaning
   * - ``!!``
     - The entire previous command. The most famous history expansion.
   * - ``!N``
     - Command number N from ``history`` output.
   * - ``!-N``
     - The Nth-from-last command. ``!-1`` = previous, ``!-2`` = two back.
   * - ``!string``
     - Most recent command starting with ``string``.
   * - ``!?string?``
     - Most recent command **containing** ``string``.
   * - ``!$``
     - The **last argument** of the previous command. Invaluable.
   * - ``!*``
     - **All arguments** of the previous command (everything except the
       command name).
   * - ``!^``
     - The **first argument** of the previous command.
   * - ``!:N``
     - The Nth argument (0 = command, 1 = first arg, ...).
   * - ``!:N-M``
     - Arguments N through M.
   * - ``^old^new``
     - Run the previous command with ``old`` replaced by ``new``. Quick
       fix for typos.

.. code-block:: bash

    # Practical examples
    $ mkdir -p /very/long/path/to/project
    $ cd !$                                    # cd /very/long/path/to/project

    $ vim /etc/nginx/nginx.conf
    $ sudo !!                                  # sudo vim /etc/nginx/nginx.conf

    $ grep foobar /var/log/syslog
    $ ^foobar^foobaz^                          # grep foobaz /var/log/syslog

    $ ls -la /some/path
    $ chmod 755 !$                             # chmod 755 /some/path

    $ systemctl status nginx
    $ !sys                                     # re-runs systemctl (most recent starting with 'sys')

    $ git log --oneline --graph --decorate
    $ !git                                     # re-runs the git command

    $ echo file1 file2 file3
    $ cp !* /backup/                           # cp file1 file2 file3 /backup/

.. caution::

   History expansion is **immediate** — the shell expands the ``!`` expression
   and displays the result before executing, but in a fast-paced workflow it's
   easy to overlook. Consider adding ``shopt -s histverify`` to ``~/.bashrc``:
   this makes the shell show the expanded line on the prompt for review before
   you press Enter a second time.

Word Modifiers
---------------

History expansion can be combined with **word modifiers** (after ``:``) to
extract parts of filenames:

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - ``:h``
     - Remove trailing pathname component (head): ``/a/b/c`` → ``/a/b``.
   * - ``:t``
     - Remove all leading pathname components (tail): ``/a/b/c`` → ``c``.
   * - ``:r``
     - Remove extension (root): ``file.tar.gz`` → ``file.tar``.
   * - ``:e``
     - Keep only extension: ``file.tar.gz`` → ``gz``.
   * - ``:p``
     - Print but do not execute.
   * - ``:s/old/new/``
     - Substitute (on the expanded text).

.. code-block:: bash

    $ wget https://example.com/project-v2.0.tar.gz
    $ tar xzf !$:t                    # tar xzf project-v2.0.tar.gz
    $ cd !$:t:r:r                     # cd project (strip .tar.gz)

.. _ctrl-r:

Incremental Search: :kbd:`Ctrl+R`
====================================

Reverse incremental search (``Ctrl+R``) is the single most important keyboard
shortcut in the shell. It searches your history interactively as you type:

1. Press :kbd:`Ctrl+R`.
2. Type a fragment of the command you want.
3. The shell displays the most recent match.
4. Press :kbd:`Ctrl+R` again to cycle to older matches.
5. Press :kbd:`Ctrl+Shift+R` (or :kbd:`Ctrl+S` if ``stty -ixon`` is set) to
   go forward.
6. Press :kbd:`Enter` to execute, or :kbd:`Ctrl+G` to cancel.
7. Press :kbd:`Tab` to select and edit the command before executing.

.. code-block:: bash

    # Enable forward search (Ctrl+S usually suspends output by default):
    $ stty -ixon                  # add to ~/.bashrc to make Ctrl+S work

.. note::

   Zsh offers a more powerful variant: ``Ctrl+R`` invokes
   ``history-incremental-pattern-search-backward``, which supports glob
   patterns. The ``fzf`` tool (fuzzy finder) can enhance history search across
   both Bash and Zsh to an almost magical degree — see
   ``Ctrl+R`` integration in the ``fzf`` documentation.

.. _brace-expansion:

Brace Expansion
=================

Brace expansion generates arbitrary strings. It is performed **before any
other expansion** and does not require the generated strings to correspond to
existing files. This distinguishes it from globbing.

.. code-block:: bash

    $ echo {a,b,c}.txt
    a.txt b.txt c.txt

    $ echo file_{1..5}.txt
    file_1.txt file_2.txt file_3.txt file_4.txt file_5.txt

    $ echo {01..10}               # zero-padded
    01 02 03 04 05 06 07 08 09 10

    $ echo {a..z}                 # character sequences
    a b c d e f g h i j k l m n o p q r s t u v w x y z

    $ echo {Z..A}                 # descending
    Z Y X W V U T S R Q P O N M L K J I H G F E D C B A

    $ echo {1..30..3}             # step (Bash ≥4)
    1 4 7 10 13 16 19 22 25 28

    # Nested brace expansion:
    $ echo {src,test}/{main,util}.py
    src/main.py src/util.py test/main.py test/util.py

    # Create a directory tree in one command:
    $ mkdir -p project/{src/{core,utils,plugins},test,docs,config}

    # Copy to multiple destinations:
    $ cp file.txt{,.bak}          # cp file.txt file.txt.bak

    # Range with variable (needs eval; can't use variable directly in brace):
    $ n=5; eval echo {1..$n}
    1 2 3 4 5

.. warning::

   Brace expansion is a **Bash/Zsh feature**, not POSIX. ``#!/bin/sh`` scripts
   on Debian (where ``/bin/sh`` is Dash) cannot use ``{1..10}``. Use
   ``seq 1 10`` or a loop in portable scripts.

.. _globbing-extensions:

Extended Globbing
===================

The standard glob patterns (``*``, ``?``, ``[...]``) are covered in Chapter 1.
Bash's **extended globbing** (``extglob``) and **recursive globbing**
(``globstar``) add substantial power.

Enable them in ``~/.bashrc``:

.. code-block:: bash

    shopt -s extglob
    shopt -s globstar

Extended Globbing Patterns (``extglob``)
-------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Pattern
     - Meaning
   * - ``?(pattern)``
     - Zero or one occurrence.
   * - ``*(pattern)``
     - Zero or more occurrences.
   * - ``+(pattern)``
     - One or more occurrences.
   * - ``@(pattern1|pattern2)``
     - Exactly one of the given patterns.
   * - ``!(pattern)``
     - Anything that does NOT match the pattern.

.. code-block:: bash

    $ ls *.@(jpg|jpeg|png|gif)     # all image files (specific extensions)
    $ ls !(*.log)                   # everything except .log files
    $ rm -r !(src|build)            # remove everything except src/ and build/
    $ ls +(dir)/*.txt               # all .txt files in directories named 'dir', 'dirdir', etc.

Recursive Globbing (``globstar``)
------------------------------------

With ``globstar`` enabled, ``**`` matches zero or more directories:

.. code-block:: bash

    $ ls **/*.py                    # all .py files anywhere below current directory
    $ grep -r "TODO" **/*.c         # recursive grep without -r (more controllable)
    $ ls src/**/__tests__/          # all __tests__ directories at any depth under src/

.. note::

   Zsh has had ``**`` (recursive globbing) since the 1990s. Bash added it in
   version 4.0 (2009) with ``shopt -s globstar``. Check your Bash version
   (``bash --version``) if ``**`` does not behave as expected.

.. _xargs:

``xargs`` — Build and Execute Commands from stdin
====================================================

``xargs`` reads items from stdin and passes them as arguments to a specified
command. It solves the fundamental problem that many commands accept arguments
only on the command line, not on stdin:

.. code-block:: bash

    $ echo "file1.txt" | rm          # WRONG: rm doesn't read stdin
    $ echo "file1.txt" | xargs rm    # CORRECT: xargs converts stdin to arguments

Why ``xargs`` over Command Substitution?
------------------------------------------

Command substitution (``$(...)``) fails when there are too many arguments
(command-line length limit, typically 2MB on Linux) or when filenames contain
spaces. ``xargs`` handles both:

.. code-block:: bash

    # Command substitution: breaks on spaces and argument length
    $ rm $(find . -name '*.tmp')         # DANGEROUS: spaces in filenames cause havoc

    # xargs: correctly handled
    $ find . -name '*.tmp' -print0 | xargs -0 rm

Essential Options
-------------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Option
     - Purpose
   * - ``-0`` / ``--null``
     - Items are null-delimited (use with ``find -print0``, ``grep -lZ``).
       **The single most important xargs option for safety.**
   * - ``-n N``
     - Pass at most N arguments per command invocation.
   * - ``-I REPL``
     - Replace ``REPL`` in the command with each item (one item per
       invocation). ``-I {}`` is the conventional idiom.
   * - ``-P N``
     - Run up to N processes in **parallel**. GNU xargs only.
   * - ``-p``
     - Prompt before each invocation (interactive confirmation).
   * - ``-t``
     - Print each command before executing (debugging).
   * - ``-r``
     - Do not run the command if the input is empty (GNU default; not POSIX).

.. code-block:: bash

    # Safe deletion of files with spaces:
    $ find /tmp -name '*.tmp' -print0 | xargs -0 rm

    # Process in batches of 100:
    $ cat urls.txt | xargs -n 100 curl -O

    # Rename all .jpeg to .jpg:
    $ find . -name '*.jpeg' -print0 | xargs -0 -I {} mv {} {}.jpg
    # (Better: use rename/prename; this is illustrative)

    # Parallel download (8 concurrent processes):
    $ cat urls.txt | xargs -P 8 -n 1 curl -O

    # Run make in all subdirectories in parallel:
    $ ls -d */ | xargs -P 4 -I {} make -C {}

.. warning::

   ``xargs`` without ``-0`` splits input on **whitespace** and interprets
   **quotes**. This means ``"file name with spaces.txt"`` actually works
   correctly with default ``xargs``, but ``file name with spaces.txt``
   (unquoted) does not. The ``-0`` / ``-print0`` idiom eliminates this
   ambiguity entirely. Use it always.

.. _readline-shortcuts:

Readline Keyboard Shortcuts
==============================

Bash uses the **Readline** library for line editing. These keyboard shortcuts
work in Bash, Zsh (with emacs mode), and many REPLs (Python, ``psql``,
``gdb``). The defaults follow Emacs conventions:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Shortcut
     - Action
   * - :kbd:`Ctrl+A`
     - Move to beginning of line
   * - :kbd:`Ctrl+E`
     - Move to end of line
   * - :kbd:`Ctrl+W`
     - Delete (kill) backward one word
   * - :kbd:`Alt+D` / :kbd:`Esc D`
     - Delete forward one word
   * - :kbd:`Ctrl+K`
     - Delete from cursor to end of line
   * - :kbd:`Ctrl+U`
     - Delete from cursor to beginning of line
   * - :kbd:`Ctrl+Y`
     - Yank (paste) the last killed text
   * - :kbd:`Alt+Y`
     - Cycle through the kill ring (after ``Ctrl+Y``)
   * - :kbd:`Ctrl+_` / :kbd:`Ctrl+X Ctrl+U`
     - Undo
   * - :kbd:`Alt+F` / :kbd:`Esc F`
     - Move forward one word
   * - :kbd:`Alt+B` / :kbd:`Esc B`
     - Move backward one word
   * - :kbd:`Ctrl+L`
     - Clear screen (same as ``clear`` command)
   * - :kbd:`Ctrl+R`
     - Reverse search history (covered above)
   * - :kbd:`Ctrl+D`
     - Delete character under cursor, or exit shell (EOF) on empty line
   * - :kbd:`Alt+.` / :kbd:`Esc .`
     - Insert the last argument of the previous command (like ``!$``)

.. code-block:: bash

    # Switch to vi editing mode:
    $ set -o vi
    # Press Esc to enter command mode, then use vi keys (h,j,k,l,w,b,/, etc.)
    $ set -o emacs    # switch back (default)

    # Persistent preference in ~/.bashrc:
    set -o vi         # or set -o emacs

.. _efficiency-best-practices:

Productivity Philosophy
=========================

Mastery is not about memorising every shortcut, but about developing
**reflexes** for the most common patterns:

1. **Never retype a command you just ran.** ``!!``, ``!$``, or ``^old^new``
   should be muscle memory.
2. **Never retype a command you ran yesterday.** ``Ctrl+R`` is faster than
   scrolling through ``history | grep``.
3. **Generate, don't type.** Brace expansion (``{1..100}``) and ``xargs`` turn
   one line into a thousand actions.
4. **Edit, don't retype.** ``vi`` mode or Readline shortcuts (``Ctrl+W``,
   ``Alt+B``) make the command line an editor, not a typewriter.
5. **Audit your history periodically.** ``history | awk '{print $2}' | sort | uniq -c | sort -rn | head -20``
   reveals your most-used commands — aliases, functions, and shortcuts are
   worth investing in proportionally.

.. admonition:: Key Takeaway

   The command line rewards investment. Every hour spent learning history
   expansion, brace expansion, and ``xargs`` returns thousands of hours over
   a career. The goal is not to type faster, but to type **less** — to make
   the computer do the mechanical work while you focus on intent.
