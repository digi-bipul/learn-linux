.. _first-steps-terminal:

First Steps: The Terminal
=========================

The terminal is the primary interface between a professional Linux user
and the machine.  It may look austere — a black rectangle with a blinking
cursor — but it is arguably the most powerful user interface ever
invented.  This section explains what the terminal actually *is*,
dissects the prompt, teaches you how to get help, and introduces the
essential keyboard shortcuts that will save you thousands of keystrokes
over your career.

.. contents::
   :local:
   :depth: 1


Terminal, Shell, Console: Clearing Up the Vocabulary
------------------------------------------------------

These three words are often used interchangeably, but they refer to
distinct layers:

.. glossary::

   Terminal (Terminal Emulator)
      A *graphical window* that mimics a physical hardware terminal
      from the 1970s.  It draws text on screen, accepts keystrokes, and
      communicates with the shell.  Examples: **GNOME Terminal**,
      **Konsole**, **Alacritty**, **iTerm2** (macOS), **Windows
      Terminal**, **Termux** (Android).

      When you press a key, the terminal emulator sends that character
      to the shell.  When the shell produces output, the terminal
      emulator renders it — handling colours, fonts, and cursor
      positioning.

   Shell
      A *command interpreter* that runs inside the terminal.  The shell
      reads your typed commands, parses them, locates the requested
      program on disk, launches it, and waits for it to finish.  The
      most common shells are:

      * **Bash** (Bourne-Again Shell) — the default on most Linux
        distributions and macOS.
      * **Zsh** (Z Shell) — default on macOS since Catalina; highly
        customisable.
      * **Fish** (Friendly Interactive Shell) — modern, with
        syntax-highlighting and autosuggestions out of the box.
      * **Dash** — a minimal POSIX shell used for system scripts on
        Debian/Ubuntu.
      * **Ash / BusyBox sh** — the default shell on Alpine Linux.

      This book assumes **Bash**, which is universally available.
      Commands will work identically in Zsh and (with minor exceptions)
      in Fish.

   Console (Virtual Console)
      The text-only interface you see when you press
      :kbd:`Ctrl+Alt+F1` through :kbd:`F6` on a Linux machine without a
      graphical desktop.  It is *not* a terminal emulator — it is a
      native kernel-provided text mode.  You rarely need it, but it is a
      lifesaver when the graphical environment crashes.


How to Open a Terminal
------------------------

Ubuntu / GNOME
   Press :kbd:`Ctrl+Alt+T`, or click **Activities** → type
   "Terminal" → press :kbd:`Enter`.

Linux Mint (Cinnamon)
   Click the terminal icon in the panel (it looks like a small
   monitor with ``>_``), or press :kbd:`Ctrl+Alt+T`.

Fedora (GNOME)
   Same as Ubuntu: :kbd:`Ctrl+Alt+T` or search "Terminal" from
   Activities.

KDE Plasma
   Press :kbd:`Ctrl+Alt+T`, or find **Konsole** in the application
   menu.

macOS
   Open **Terminal.app** from ``/Applications/Utilities/``, or
   search "Terminal" in Spotlight (:kbd:`Cmd+Space`).

Windows (WSL2)
   Open **Windows Terminal** and select your installed Linux
   distribution from the dropdown, or type ``wsl`` in a PowerShell
   or Command Prompt window.

Alpine / Server (no GUI)
   You are already looking at the console.  Just log in.


Anatomy of the Prompt
----------------------

When you open a terminal, you see something like this:

.. code-block:: text

   alice@thinkpad:~$

Let us dissect this piece by piece:

.. describe:: ``alice``

   Your **username**.  Whoever you logged in as.

.. describe:: ``@``

   A separator.  Pronounced "at."

.. describe:: ``thinkpad``

   The **hostname** of the machine.  Useful when you have multiple
   terminal windows open to different servers — the prompt tells you at
   a glance *where* you are.

.. describe:: ``:``

   Another separator.  Not pronounced.

.. describe:: ``~``

   Your **current working directory**.  The tilde (``~``) is a shorthand
   for your home directory, typically ``/home/alice``.  If you navigate
   elsewhere — say, ``/etc`` — the prompt updates:

   .. code-block:: text

      alice@thinkpad:/etc$

.. describe:: ``$``

   The **prompt terminator**.  A dollar sign (``$``) means you are a
   normal user.  A hash sign (``#``) means you are the **root**
   superuser.  This is an important visual safety cue:

   .. code-block:: text

      root@thinkpad:~#

   Seeing ``#`` should make you pause; you hold absolute power and can
   destroy the system with a single mistyped command.

.. tip::

   The prompt is not hardcoded.  It is controlled by the ``PS1``
   environment variable, and you can customise it to show the time, Git
   branch, exit code of the last command, and much more.  We will cover
   prompt customisation in a later chapter.


The Structure of a Shell Command
----------------------------------

Almost every shell command follows this pattern:

.. code-block:: text

   command [OPTIONS] [ARGUMENTS]

.. describe:: ``command``

   The name of the program to run.  It might be a built-in shell command
   (like ``cd`` or ``echo``) or an external executable stored somewhere
   on disk (like ``/usr/bin/ls``).

.. describe:: ``[OPTIONS]`` (also called flags or switches)

   Modifiers that change the command's behaviour.  Options come in two
   flavours:

   .. describe:: Short options

      A single dash followed by a single letter: ``-l``, ``-a``, ``-h``.
      Multiple short options can be combined behind a single dash:
      ``ls -l -a -h`` is equivalent to ``ls -lah``.

   .. describe:: Long options

      Two dashes followed by a descriptive word: ``--all``,
      ``--human-readable``, ``--help``.  Long options cannot be combined
      and must be written out individually.

   Most commands support both styles.  ``ls -a`` and ``ls --all`` are
   synonymous.

.. describe:: ``[ARGUMENTS]``

   The targets the command operates on — typically file or directory
   names.  ``cat report.txt`` — ``report.txt`` is the argument.

   Arguments are *positional*: the first argument means something
   different from the second argument.  Options (which are named) can
   appear in any order; arguments usually cannot.

.. code-block:: bash
   :caption: A concrete example

   $ ls -l --human-readable /home/alice/Documents

   └─┬─┘ └────────┬────────┘ └──────────┬──────────┘
   command        options              argument


How to Get Help
-----------------

The single most important skill in Linux is **knowing how to find
answers without leaving the terminal**.  Four mechanisms are always
available:

.. rubric:: 1. ``--help`` (the quick reference)

Almost every command-line program supports ``--help`` or ``-h``:

.. code-block:: bash

   $ ls --help
   Usage: ls [OPTION]... [FILE]...
   List information about the FILEs (the current directory by default).
   ...

It dumps a concise summary of all options and arguments directly into
the terminal.  It is fast, but terse.

.. rubric:: 2. ``man`` (the manual)

The **manual pager** is the canonical documentation system inherited from
Unix.  Every installed program, every system call, every configuration
file format has a man page:

.. code-block:: bash

   $ man ls

This opens the manual in a pager (usually ``less``).  Use the following
keys to navigate:

.. list-table:: Man Page Navigation
   :header-rows: 1

   * - Key
     - Action
   * - :kbd:`Space` / :kbd:`Page Down`
     - Scroll forward one screen
   * - :kbd:`b` / :kbd:`Page Up`
     - Scroll backward one screen
   * - :kbd:`/` followed by a search term
     - Search forward
   * - :kbd:`n`
     - Jump to the next search match
   * - :kbd:`N`
     - Jump to the previous search match
   * - :kbd:`q`
     - Quit the man page

Man pages are divided into **sections** (1 through 9).  The most
commonly encountered sections are:

.. list-table:: Man Page Sections
   :header-rows: 1

   * - Section
     - Content
     - Example
   * - 1
     - User commands
     - ``man 1 ls``
   * - 5
     - File formats / config files
     - ``man 5 crontab``
   * - 7
     - Miscellaneous (overviews, conventions)
     - ``man 7 signal``
   * - 8
     - System administration commands
     - ``man 8 iptables``

If a topic exists in multiple sections, specify the section number:
``man 5 crontab`` shows the config-file format; ``man 1 crontab`` shows
the command.

.. rubric:: 3. ``info`` (the GNU hypertext manual)

GNU projects often ship more detailed documentation in **Info** format,
which supports hyperlinks between nodes:

.. code-block:: bash

   $ info coreutils

Navigate with :kbd:`n` (next), :kbd:`p` (previous), :kbd:`u` (up),
:kbd:`Enter` (follow link), and :kbd:`q` (quit).

.. rubric:: 4. ``tldr`` and ``cheat`` (community cheat-sheets)

These are not installed by default but are invaluable.  They provide
curated, example-driven summaries:

.. code-block:: bash

   # Install on Debian/Ubuntu:
   $ sudo apt install tldr

   # Install on Fedora/RHEL:
   $ sudo dnf install tldr

   # Install on Alpine:
   $ sudo apk add tldr

   # Use it:
   $ tldr tar

.. code-block:: text
   :caption: Output of ``tldr tar`` (excerpt)

   tar

   Archiving utility.
   Often combined with a compression method, such as gzip or bzip2.
   More information: https://www.gnu.org/software/tar.

   - [c]reate an archive and write it to a [f]ile:
     tar cf path/to/target.tar path/to/file1 path/to/file2 ...

   - [c]reate a g[z]ipped archive and write it to a [f]ile:
     tar czf path/to/target.tar.gz path/to/file1 path/to/file2 ...

   - [x]tract a (compressed) archive [f]ile into the current directory:
     tar xf path/to/source.tar[.gz|.bz2|.xz]


Essential Terminal Keyboard Shortcuts
---------------------------------------

These shortcuts work in Bash (with the default ``emacs`` editing mode)
and most other readline-based programs.  Memorising even half of them
will dramatically increase your speed.

.. list-table:: Cursor Movement
   :header-rows: 1

   * - Shortcut
     - Action
   * - :kbd:`Ctrl+A`
     - Jump to **beginning** of line
   * - :kbd:`Ctrl+E`
     - Jump to **end** of line
   * - :kbd:`Ctrl+F` / :kbd:`→`
     - Forward one character
   * - :kbd:`Ctrl+B` / :kbd:`←`
     - Backward one character
   * - :kbd:`Alt+F`
     - Forward one **word**
   * - :kbd:`Alt+B`
     - Backward one **word**

.. list-table:: Editing
   :header-rows: 1

   * - Shortcut
     - Action
   * - :kbd:`Ctrl+W`
     - Delete (cut) the word **before** the cursor
   * - :kbd:`Alt+D`
     - Delete (cut) the word **after** the cursor
   * - :kbd:`Ctrl+U`
     - Delete (cut) from cursor to **beginning** of line
   * - :kbd:`Ctrl+K`
     - Delete (cut) from cursor to **end** of line
   * - :kbd:`Ctrl+Y`
     - **Yank** (paste) the last cut text
   * - :kbd:`Ctrl+_`
     - **Undo** the last edit

.. list-table:: Process Control
   :header-rows: 1

   * - Shortcut
     - Action
   * - :kbd:`Ctrl+C`
     - **Interrupt** (kill) the foreground process.  Sends the SIGINT
       signal.
   * - :kbd:`Ctrl+D`
     - Send **end-of-file** (EOF) on standard input.  If typed at an
       empty prompt, it closes the shell (logs you out).
   * - :kbd:`Ctrl+Z`
     - **Suspend** the foreground process.  Sends SIGTSTP.  Resume with
       ``fg`` (foreground) or ``bg`` (background).
   * - :kbd:`Ctrl+L`
     - **Clear** the screen (same as the ``clear`` command).

.. list-table:: History
   :header-rows: 1

   * - Shortcut
     - Action
   * - :kbd:`Ctrl+R`
     - **Reverse search** through command history.  Start typing and
       Bash shows the most recent matching command.  Press
       :kbd:`Ctrl+R` again to cycle backward.
   * - :kbd:`↑` / :kbd:`↓`
     - Scroll through previous / next commands.
   * - ``!!``
     - Re-run the **last command** (type this as a command).
   * - ``!$``
     - Expand to the **last argument** of the previous command.

.. tip::

   If you prefer Vim-style keybindings (``Esc`` to enter normal mode,
   ``hjkl`` for movement), run ``set -o vi`` in Bash.  To make it
   permanent, add that line to ``~/.bashrc``.  We cover shell
   configuration in a later chapter.


Distro-Agnostic First Commands
-------------------------------

Let us type a few commands to get comfortable.  Open a terminal and
follow along:

.. code-block:: bash

   $ whoami
   alice

``whoami`` prints your username.  Simple and useful in scripts.

.. code-block:: bash

   $ date
   Thu Jul 10 11:54:17 UTC 2026

``date`` prints the current date and time as the system understands it.

.. code-block:: bash

   $ uptime
   11:54:17 up 3 days,  2:15,  2 users,  load average: 0.08, 0.03, 0.01

``uptime`` tells you how long the system has been running, how many
users are logged in, and the system load averages for the last 1, 5, and
15 minutes.

.. code-block:: bash

   $ echo "Hello, Linux!"
   Hello, Linux!

``echo`` prints whatever you give it.  It seems trivial, but it is
indispensable in scripts and for inspecting shell variables:

.. code-block:: bash

   $ echo $HOME
   /home/alice

   $ echo $SHELL
   /bin/bash

The ``$`` before ``HOME`` and ``SHELL`` tells the shell to *expand* the
variable — that is, replace it with its current value.  ``echo`` then
prints the result.  We will explore shell variables in depth later.

.. code-block:: bash

   # What distribution am I running?  (works on most)
   $ cat /etc/os-release

   # On Alpine:
   $ cat /etc/alpine-release

.. code-block:: bash

   # What kernel version?
   $ uname -r
   6.1.0-25-amd64

   # All kernel details:
   $ uname -a
   Linux thinkpad 6.1.0-25-amd64 #1 SMP PREEMPT_DYNAMIC ... x86_64 GNU/Linux


Chapter Summary
---------------

* A **terminal emulator** is a graphical window; a **shell** interprets
  your commands inside it.
* The **prompt** shows ``user@host:directory$`` — learn to read it at a
  glance.
* Commands take the form ``command [OPTIONS] [ARGUMENTS]``.
* Use ``--help`` for quick reference, ``man`` for full documentation.
* Mastering keyboard shortcuts (:kbd:`Ctrl+A`, :kbd:`Ctrl+E`,
  :kbd:`Ctrl+R`, etc.) pays compounding dividends.

You now have the vocabulary and the environment.  Next, we map the
territory: the Linux filesystem tree.
