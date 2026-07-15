2.3 Environment Variables & Shell Configuration
================================================

.. sidebar:: In This Section

   * ``$HOME``, ``$PATH``, ``$USER``, ``$PS1``, and other key variables
   * ``export``, ``env``, ``printenv``, ``set``
   * Shell startup files: ``.bashrc``, ``.profile``, ``.bash_profile``
   * Login vs. non-login vs. interactive shells
   * ``alias``, ``unalias``, ``source`` (``.``)
   * Configuration best practices

---

The shell, out of the box, is a blank slate. Everything that makes it feel
like *your* environment — the prompt, the colours, the shortcuts, the default
editor — is stored in environment variables and startup scripts. This section
provides a rigorous understanding of both.

.. _what-are-environment-variables:

What Are Environment Variables?
=================================

An **environment variable** is a named string value maintained by the shell and
inherited by child processes. Each process receives a copy of its parent's
*environment block* — an array of ``NAME=VALUE`` strings — at creation time via
the ``execve()`` system call.

Environment variables serve three central purposes:

1. **Configuration:** Tell programs where to find things (``$PATH``, ``$HOME``,
   ``$LD_LIBRARY_PATH``).
2. **User Preferences:** Set default behaviour (``$EDITOR``, ``$PAGER``,
   ``$LANG``).
3. **Inter-Process Communication:** Pass context from parent to child
   (``$SSH_AUTH_SOCK``, ``$DISPLAY``).

.. _shell-vs-environment-variables:

Shell Variables vs. Environment Variables
-------------------------------------------

This distinction trips up beginners and seasoned practitioners alike:

- A **shell variable** exists only within the current shell process. Child
  processes do NOT see it.
- An **environment variable** is a shell variable that has been *exported*
  (marked for inheritance). Child processes receive a copy in their
  environment block.

.. code-block:: bash

    $ MY_SHELL_VAR="hello"         # shell variable only
    $ export MY_ENV_VAR="world"    # environment variable (inheritable)
    $ bash -c 'echo "shell=$MY_SHELL_VAR  env=$MY_ENV_VAR"'
    shell=  env=world              # child sees only the exported one

.. _key-environment-variables:

Key Environment Variables
============================

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Variable
     - Meaning and Common Values
   * - ``HOME``
     - Current user's home directory (e.g., ``/home/alice``). Set at login;
       **never** change this casually.
   * - ``PATH``
     - Colon-separated list of directories searched for executables. See
       Section 2.1 for a full treatment.
   * - ``USER`` / ``LOGNAME``
     - Current username. ``$USER`` is the modern convention; ``$LOGNAME``
       is the historical POSIX variable. Both should be set.
   * - ``SHELL``
     - Path to the user's login shell (e.g., ``/bin/bash``). Set by
       ``chsh`` / ``/etc/passwd``.
   * - ``PWD``
     - Current working directory (maintained automatically by the shell).
   * - ``OLDPWD``
     - Previous working directory. Used by ``cd -``.
   * - ``EDITOR`` / ``VISUAL``
     - Default text editor. ``$VISUAL`` is for full-screen editors (vim,
       emacs); ``$EDITOR`` can also be line-mode (ed, ex). Most programs
       check ``$VISUAL`` first, then ``$EDITOR``.
   * - ``PAGER``
     - Default pager for viewing long output (typically ``less``).
   * - ``LANG`` / ``LC_*``
     - Locale settings controlling language, date formats, collation order.
       ``$LANG`` is the fallback for all ``$LC_*`` variables.
   * - ``PS1``
     - Primary prompt string. See below for a full treatment.
   * - ``PS2``
     - Continuation prompt (default ``>``). Shown when a command spans
       multiple lines.
   * - ``PS4``
     - Debug prompt prefix (used with ``set -x``; default ``+``).
   * - ``HISTSIZE`` / ``HISTFILESIZE``
     - Number of commands kept in memory / in the history file. See
       Section 2.6.
   * - ``IFS``
     - Internal Field Separator. Controls word splitting (default:
       space, tab, newline). **Modify with extreme caution.**
   * - ``TMPDIR``
     - Directory for temporary files. Many programs (``sort``, ``mktemp``)
       respect this.
   * - ``LD_LIBRARY_PATH``
     - Extra directories to search for shared libraries before the default
       system paths. Use sparingly; prefer ``/etc/ld.so.conf.d/`` or
       ``LD_PRELOAD`` for production.

.. _prompt-ps1:

The Prompt: ``$PS1``
======================

``$PS1`` (Prompt String 1) defines your interactive prompt. It is not a static
string but a format string that the shell evaluates before each display. Bash
supports a rich set of backslash-escaped sequences:

.. list-table:: Common PS1 Escape Sequences
   :header-rows: 1
   :widths: 20 80

   * - Sequence
     - Expands To
   * - ``\u``
     - Username
   * - ``\h``
     - Hostname (up to first ``.``)
   * - ``\H``
     - Full hostname (FQDN)
   * - ``\w``
     - Full working directory (``$HOME`` abbreviated as ``~``)
   * - ``\W``
     - Basename of working directory
   * - ``\t``
     - Current time in 24-hour HH:MM:SS format
   * - ``\d``
     - Date in "Weekday Month Date" format
   * - ``\$``
     - ``#`` if root (UID 0), ``$`` otherwise
   * - ``\n``
     - Newline
   * - ``\[ ... \]``
     - Enclose non-printing characters (ANSI colour codes) so line wrapping
       works correctly

.. code-block:: bash

    # In ~/.bashrc:
    PS1='[\u@\h \W]\$ '
    # Produces: [alice@laptop ~]$ 

    # With colours (requires \[  \] around escape codes):
    GREEN='\[\033[01;32m\]'
    RESET='\[\033[00m\]'
    PS1="${GREEN}\u@\h${RESET}:\w\$ "
    # Produces a green user@host and a default-coloured path.

.. note::

   Zsh uses a completely different prompt system based on ``%`` sequences
   (``%n`` for username, ``%m`` for hostname, ``%~`` for path). Bash's ``\``
   sequences do not work in Zsh.

.. _inspecting-environment:

Inspecting the Environment
============================

.. code-block:: bash

    $ env                  # list all environment variables (inheritable)
    $ printenv             # same as env
    $ printenv HOME        # print a specific variable
    $ echo "$HOME"         # shell expands the variable

    $ set                  # list ALL variables (shell + environment) and functions
    $ declare -p           # same, with declare statements (Bash)
    $ declare -p HOME      # inspect a specific variable

.. _export:

``export`` and Variable Attributes
====================================

``export`` marks a variable for inheritance. You can also combine declaration
and export in one step:

.. code-block:: bash

    $ export MYVAR="value"           # declare and export
    $ MYVAR="value"; export MYVAR    # same, two steps
    $ export -n MYVAR                # remove export attribute (becomes shell-only)
    $ export -p                      # list all exported variables

Bash also supports variable attributes via ``declare`` (or ``typeset``, its
synonym):

.. code-block:: bash

    $ declare -i COUNT=5     # integer (assignment does arithmetic)
    $ declare -r PI=3.14     # read-only
    $ declare -a ARR         # indexed array
    $ declare -A MAP         # associative array (Bash ≥4)
    $ declare -x VAR=val     # export (same as export VAR=val)
    $ declare -l LOW         # lowercase on assignment
    $ declare -u UPP         # uppercase on assignment

.. _shell-startup-files:

Shell Startup Files
=====================

Different shells read different startup files depending on whether the shell is
a **login shell** or an **interactive non-login shell**. This distinction is
the single most common source of "my PATH/alias doesn't work" confusion.

.. _login-vs-nonlogin:

Login Shell vs. Interactive Non-Login Shell
---------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Shell Type
     - When Does It Occur?
   * - **Login shell**
     - Console login (``tty1``), SSH login, ``su -``, ``bash --login``.
       The first process after authentication.
   * - **Interactive non-login shell**
     - Opening a terminal emulator (GNOME Terminal, iTerm2), running
       ``bash`` from an existing shell.
   * - **Non-interactive shell**
     - Running a script (``bash script.sh``), remote command
       (``ssh host cmd``).

Bash Startup File Sequence
----------------------------

.. figure:: /_static/bash_startup.svg
   :alt: Bash startup file sequence flowchart

   Flowchart of Bash startup files for login and non-login shells.

.. list-table:: Bash Startup Files in Order
   :header-rows: 1
   :widths: 15 85

   * - Shell Type
     - Files Read (in order; stops at first one found for profile files)
   * - **Login shell**
     - ``/etc/profile`` → ``~/.bash_profile`` OR ``~/.bash_login`` OR
       ``~/.profile`` (first found)
   * - **Interactive non-login**
     - ``/etc/bash.bashrc`` (some distros) → ``~/.bashrc``
   * - **Non-interactive**
     - Reads ``$BASH_ENV`` if set (rare)
   * - **Logout**
     - ``~/.bash_logout`` (on exit of login shell)

.. warning::

   On many distributions, the default ``~/.bash_profile`` explicitly sources
   ``~/.bashrc`` to ensure consistent behaviour across login and non-login
   shells. If you create your own ``~/.bash_profile``, **always** include:

   .. code-block:: bash

       if [ -f ~/.bashrc ]; then
           source ~/.bashrc
       fi

.. _bashrc-vs-profile:

What Goes Where?
------------------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - File
     - Appropriate For
   * - ``~/.bashrc``
     - **Interactive-only settings:** aliases, ``$PS1``, shell options,
       completions, functions, keybindings. Sourced for every interactive
       shell.
   * - ``~/.profile`` / ``~/.bash_profile``
     - **Login-only settings:** ``$PATH`` (but see below), ``$EDITOR``,
       ``$LANG``, ``umask``, ``ssh-agent`` startup, X session variables.
       Sourced **once** at login.
   * - ``~/.bash_logout``
     - Cleanup: clear console on logout, delete temporary files.

.. admonition:: Modern Best Practice

   Many experienced users put **everything** in ``~/.bashrc`` and source it
   from ``~/.bash_profile``. The ``~/.profile`` vs. ``~/.bash_profile``
   distinction exists only for compatibility with non-Bash login shells (e.g.,
   when ``/bin/sh`` is the login shell). If you use Bash exclusively,
   ``~/.bash_profile`` is the canonical login file.

.. _path-in-profile:

The Subtlety of ``$PATH`` in Startup Files
--------------------------------------------

``$PATH`` is typically set in ``/etc/profile`` (by the distribution) and
extended in ``~/.profile`` or ``~/.bashrc``. The trap:

.. code-block:: bash

    # In ~/.bashrc (sourced for EVERY interactive shell):
    export PATH="$HOME/bin:$PATH"

Each nested shell prepends ``$HOME/bin`` again, producing:
``/home/alice/bin:/home/alice/bin:/home/alice/bin:/usr/bin:...``

This is harmless but sloppy. Guard it:

.. code-block:: bash

    # Guard against repeated additions:
    if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
        export PATH="$HOME/bin:$PATH"
    fi

Or, place ``$PATH`` additions in ``~/.profile`` (sourced once) instead.

.. _source:

``source`` and ``.`` (Dot Command)
====================================

``source filename`` (or ``. filename`` in POSIX) reads and executes commands
from ``filename`` **in the current shell** — unlike running a script normally,
which spawns a subshell. This is crucial: it allows scripts to modify the
current environment.

.. code-block:: bash

    $ cat setvars.sh
    export FOO=bar
    alias ll='ls -l'

    $ bash setvars.sh       # runs in a subshell; $FOO and alias lost on exit
    $ echo $FOO
                            # (empty)

    $ source setvars.sh     # run in current shell; changes persist
    $ echo $FOO
    bar
    $ type ll
    ll is aliased to `ls -l`

Common use cases for ``source``:

- Reloading shell configuration after editing ``~/.bashrc``:
  ``source ~/.bashrc``.
- Importing function libraries in scripts.
- Activating Python virtual environments: ``source venv/bin/activate``.

.. _alias:

``alias`` — Command Shortcuts
===============================

Aliases are the simplest form of shell customisation — text substitutions that
the shell expands before executing a command:

.. code-block:: bash

    $ alias ll='ls -alF'
    $ alias gs='git status'
    $ alias ..='cd ..'
    $ alias ...='cd ../..'

    $ alias                     # list all aliases
    alias ll='ls -alF'
    alias gs='git status'

    $ unalias ll                # remove an alias
    $ \ll                       # bypass alias lookup for one command

.. important::

   Aliases have significant limitations:

   - They are **not expanded in scripts** (non-interactive shells).
   - They **do not accept arguments** — ``alias mkcd='mkdir $1 && cd $1'``
     does NOT work. Use a function instead:

     .. code-block:: bash

         mkcd() { mkdir -p "$1" && cd "$1"; }

   - They cannot be exported to subshells (though ``$BASH_ALIASES`` can be
     propagated manually in Bash ≥5).

   **Prefer functions over aliases** for anything involving logic, arguments,
   or multiple commands. Reserve aliases for simple text substitutions.

.. _zsh-config:

Zsh Configuration: A Brief Note
================================

If you use Zsh (default on macOS and Kali Linux), the startup file sequence
differs substantially:

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - File
     - When Read
   * - ``~/.zshenv``
     - Always, for every Zsh invocation (login, interactive, script). Use
       sparingly.
   * - ``~/.zprofile``
     - Login shells only (like ``~/.bash_profile``).
   * - ``~/.zshrc``
     - Interactive shells only (like ``~/.bashrc``).
   * - ``~/.zlogin``
     - Login shells, after ``~/.zshrc``. Rarely used.
   * - ``~/.zlogout``
     - On logout from login shells.

Zsh's configuration ecosystem (Oh My Zsh, Prezto, Zinit) is vast and outside
the scope of this chapter, but the core principles — export environment
variables in profile files, set interactive preferences in rc files — remain
identical.

.. _config-best-practices:

Configuration Best Practices
===============================

1. **Keep it under version control.** Manage your dotfiles with Git. There is
   an entire community dedicated to dotfile management; popular tools include
   GNU Stow, chezmoi, and yadm.

2. **Be idempotent.** Every ``source ~/.bashrc`` should produce the same state.
   Guard ``$PATH`` additions, avoid duplicate ``eval`` calls, and use
   functions that check before redefining.

3. **Separate concerns.** Split configuration into logical files and source
   them:

   .. code-block:: bash

       # ~/.bashrc
       for f in ~/.config/bash/{aliases,functions,exports,prompt}.sh; do
           [ -f "$f" ] && source "$f"
       done

4. **Avoid side effects in configuration.** A new terminal should not
   auto-start a database, mount a filesystem, or connect to a VPN unless the
   user explicitly invokes those actions.

5. **Test portability.** Even if you live in Bash, a ``source`` (``.``) command
   is POSIX. Know which features of your configuration require which shell.

.. admonition:: Key Takeaway

   Your shell configuration is a program that runs every time you open a
   terminal. Treat it with the same discipline you would apply to any other
   software project: keep it modular, idempotent, version-controlled, and
   documented. A well-crafted ``~/.bashrc`` pays back the investment a
   hundredfold over a career.
