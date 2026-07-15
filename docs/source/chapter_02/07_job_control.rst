.. _job_control:

===========================================
2.7 Job Control
===========================================

.. sidebar:: In This Section

   * Foreground vs. background processes
   * ``jobs``, ``fg``, ``bg`` — managing shell jobs
   * ``&``, ``Ctrl+Z``, ``Ctrl+C`` — process control keystrokes
   * ``nohup``, ``disown`` — detaching from the shell
   * ``screen``, ``tmux`` — terminal multiplexers
   * Process groups, sessions, and the controlling terminal (theory)

---

A terminal window runs **one foreground process** at a time — the one you are
interacting with. But the shell is also a **job controller**: it can suspend,
resume, background, and detach processes. This section covers both the
day-to-day mechanics (``&``, ``Ctrl+Z``, ``fg``) and the architectural
foundations (process groups, sessions, SIGHUP) that explain *why* things behave
as they do.

.. _job-control-theory:

The Theory: Process Groups, Sessions, and Signals
====================================================

Before diving into keystrokes, we must understand three abstractions the kernel
uses to manage terminal-attached processes:

- **Process Group:** A collection of related processes. A pipeline
  (``ls | sort``) forms a single process group. The kernel can signal an
  entire group atomically (e.g., ``Ctrl+C`` sends ``SIGINT`` to the whole
  foreground process group).
- **Session:** A collection of process groups. Each session has zero or one
  **controlling terminal**. The session leader (usually the login shell)
  manages job control.
- **Controlling Terminal:** The terminal device (``/dev/pts/N``) that "owns"
  the session. Only the **foreground process group** can read from the
  terminal; background processes that attempt to read are stopped by
  ``SIGTTIN``.

When you press ``Ctrl+C``, the terminal driver sends ``SIGINT`` to the
foreground process group — every process in the pipeline receives it
simultaneously. When you close a terminal, the kernel sends ``SIGHUP`` to the
session leader (the shell), which typically propagates it to its children.

Understanding this architecture explains phenomena that mystify beginners:

- Why ``ssh host command &`` sometimes hangs (``SIGTTIN`` on attempted read).
- Why closing a terminal kills your processes (``SIGHUP`` propagation).
- Why ``nohup`` and ``disown`` exist.

.. _background-foreground:

Foreground and Background Processes
=====================================

A **foreground** process has control of the terminal: it receives keyboard
input and its output appears on screen. You wait for it.

A **background** process runs concurrently, does not receive keyboard input
(attempts to read from the terminal are stopped by ``SIGTTIN``), and prints
output that may interleave with your typing. The shell prints a new prompt
immediately after starting a background process.

Starting a Process in the Background: ``&``
----------------------------------------------

.. code-block:: bash

    $ sleep 100 &
    [1] 12345
    # ^   ^
    # job  process
    # number  ID

    $ find / -name "*.log" > logs.txt &
    [2] 12346

    # Running a pipeline in the background:
    $ tar czf backup.tar.gz /data &> backup.log &
    [3] 12347

The shell assigns each background process a **job number** (``[1]``, ``[2]``,
...) and prints the **process ID** (PID). Job numbers are local to the shell;
PIDs are system-wide.

Listing Jobs: ``jobs``
------------------------

.. code-block:: bash

    $ jobs
    [1]   Running                 sleep 100 &
    [2]-  Running                 find / -name "*.log" > logs.txt &
    [3]+  Running                 tar czf backup.tar.gz /data &> backup.log &

The ``+`` marks the **current job** (the most recently backgrounded or
foregrounded). The ``-`` marks the **previous job**. ``%+`` (or ``%%``) refers
to the current job; ``%-`` refers to the previous job.

.. code-block:: bash

    $ jobs -l                    # show PIDs
    $ jobs -p                    # show PIDs only (useful for scripting)
    $ jobs -r                    # running jobs only
    $ jobs -s                    # stopped jobs only

.. _suspend-resume:

Suspending and Resuming
=========================

``Ctrl+Z`` — Suspend (SIGTSTP)
---------------------------------

Pressing :kbd:`Ctrl+Z` sends ``SIGTSTP`` (terminal stop) to the foreground
process group, suspending it. The process is **paused, not terminated** — it
still exists in memory, holding file descriptors, sockets, and all state.

.. code-block:: bash

    $ vim important-file.txt
    # Press Ctrl+Z
    [1]+  Stopped                 vim important-file.txt
    $ # vim is frozen; you're back at the shell

``fg`` — Bring to Foreground
-------------------------------

.. code-block:: bash

    $ fg                         # resume the current job (%+ or %%) in foreground
    $ fg %1                      # resume job number 1
    $ fg %vim                    # resume job whose command starts with 'vim'
    $ fg %?portant               # resume job whose command contains 'portant'

``bg`` — Resume in Background
--------------------------------

.. code-block:: bash

    $ bg                         # resume current job in background
    $ bg %2                      # resume job 2 in background
    # Equivalent to: kill -CONT %2  (sends SIGCONT)

.. _ctrl-c:

``Ctrl+C`` — Interrupt (SIGINT)
---------------------------------

: kbd:`Ctrl+C` sends ``SIGINT`` (interrupt) to the foreground process group. By
default, this terminates the process. Programs can catch or ignore ``SIGINT``
— ``bash`` itself ignores it (so ``Ctrl+C`` doesn't close your shell), and
interactive programs like ``vim`` or ``python`` handle it gracefully.

.. code-block:: bash

    $ sleep 100
    ^C                # Ctrl+C printed; sleep terminates
    $ echo $?
    130               # 128 + signal number (SIGINT = 2; 128 + 2 = 130)

``Ctrl+\`` — Quit (SIGQUIT)
------------------------------

: kbd:`Ctrl+\\` sends ``SIGQUIT``, which by default terminates the process
**and produces a core dump**. It is stronger than ``Ctrl+C`` — most programs
do not catch ``SIGQUIT``.

.. _job-specifiers:

Job Specifiers
================

When you use ``fg``, ``bg``, ``kill``, ``disown``, or ``wait``, you can
reference jobs by more than just job numbers:

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Specifier
     - Meaning
   * - ``%N``
     - Job number N.
   * - ``%str``
     - Job whose command **starts** with ``str``.
   * - ``%?str``
     - Job whose command **contains** ``str``.
   * - ``%+`` / ``%%``
     - Current job (most recently backgrounded or stopped).
   * - ``%-``
     - Previous job.
   * - ``%``
     - Same as ``%+``.

.. code-block:: bash

    $ kill %1                    # terminate job 1
    $ kill -STOP %2              # stop (suspend) job 2
    $ kill -CONT %2              # continue (resume) job 2
    $ wait %3                    # wait for job 3 to finish

.. _nohup-disown:

``nohup`` and ``disown`` — Surviving Shell Exit
==================================================

When you close a terminal (or the shell exits), the kernel sends ``SIGHUP``
(hangup) to the shell's children. By default, this terminates them. Two
mechanisms prevent this.

``nohup`` — Start Immune to SIGHUP
-------------------------------------

``nohup`` runs a command with ``SIGHUP`` ignored. Output that would go to the
terminal is redirected to ``nohup.out``:

.. code-block:: bash

    $ nohup long_running_script.sh &
    nohup: ignoring input and appending output to 'nohup.out'

    $ nohup ./server > server.log 2>&1 &
    # Explicit redirection prevents nohup.out creation

``disown`` — Detach After Starting
------------------------------------

``disown`` removes a job from the shell's job table *without* terminating it.
The process continues running but the shell forgets about it:

.. code-block:: bash

    $ long_running_process &
    [1] 5555

    $ disown                     # disown current job (%+)
    $ disown %1                  # disown job 1
    $ disown -h %1               # mark job 1 so SIGHUP is NOT sent on shell exit
    $ disown -a                  # disown ALL jobs
    $ disown -r                  # disown all RUNNING jobs
    $ disown -ar                 # disown ALL running jobs

After ``disown``, the job no longer appears in ``jobs`` output, but the
process is still visible in ``ps`` and can be signalled by PID.

.. code-block:: bash

    # Common pattern: start, then disown
    $ ./server &
    $ disown
    $ exit                       # shell exits; server keeps running

.. _screen-tmux:

Terminal Multiplexers: ``screen`` and ``tmux``
=================================================

``nohup`` and ``disown`` solve the "keep my process running" problem, but
they do not solve the "reconnect to my running program's interface" problem.
For that, you need a **terminal multiplexer** — a program that creates
persistent terminal sessions you can detach from and reattach to.

``tmux`` (Recommended)
------------------------

``tmux`` is the modern standard. It is actively maintained, highly
configurable, and available on every Linux distribution.

.. code-block:: bash

    $ tmux                        # start a new session
    $ tmux new -s mysession       # named session
    $ tmux ls                     # list sessions
    $ tmux attach                 # attach to the most recent session
    $ tmux attach -t mysession    # attach to a named session
    $ tmux kill-session -t mysession  # kill a session

Inside ``tmux``, the **prefix key** (default ``Ctrl+B``) precedes all commands:

.. list-table:: Essential tmux Commands (after ``Ctrl+B``)
   :header-rows: 1
   :widths: 20 80

   * - Keystroke
     - Action
   * - ``Ctrl+B d``
     - Detach from session (leave it running).
   * - ``Ctrl+B c``
     - Create a new window (like a new tab).
   * - ``Ctrl+B n`` / ``p``
     - Next / previous window.
   * - ``Ctrl+B ,``
     - Rename current window.
   * - ``Ctrl+B %``
     - Split pane vertically (left/right).
   * - ``Ctrl+B "``
     - Split pane horizontally (top/bottom).
   * - ``Ctrl+B arrow``
     - Switch between panes.
   * - ``Ctrl+B x``
     - Close current pane (with confirmation).
   * - ``Ctrl+B [``
     - Enter scroll/copy mode (use arrow keys, ``PgUp``/``PgDn``, ``q`` to
       quit).

.. code-block:: bash

    # ~/.tmux.conf — sensible defaults
    set -g mouse on                    # enable mouse support
    set -g history-limit 50000        # large scrollback
    set -g default-terminal "screen-256color"
    set -g base-index 1               # windows start at 1, not 0
    set -g pane-base-index 1          # panes start at 1
    set -g renumber-windows on        # renumber when windows close

``screen`` (Legacy)
---------------------

GNU ``screen`` is the older multiplexer. It is still widely installed,
especially on legacy servers. Basic commands:

.. code-block:: bash

    $ screen                       # start
    $ screen -S name               # named session
    $ screen -ls                   # list sessions
    $ screen -r                    # reattach
    $ screen -r name               # reattach to named session

Inside ``screen``, the prefix is ``Ctrl+A``:

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Keystroke
     - Action
   * - ``Ctrl+A d``
     - Detach.
   * - ``Ctrl+A c``
     - Create window.
   * - ``Ctrl+A n`` / ``p``
     - Next/previous window.
   * - ``Ctrl+A S``
     - Split horizontally.
   * - ``Ctrl+A |``
     - Split vertically (recent versions).
   * - ``Ctrl+A Tab``
     - Switch between regions.

.. note::

   If you use ``tmux``, ``screen``, or even ``ssh``, be aware that the prefix
   key collision (``Ctrl+A`` is ``screen``'s prefix AND the Readline
   "beginning of line" shortcut) is a classic pain point. ``tmux`` defaults to
   ``Ctrl+B`` for this reason, though many users remap it to ``Ctrl+A`` for
   ergonomics.

.. _job-control-signal-summary:

Signal Reference for Job Control
=================================

.. list-table::
   :header-rows: 1
   :widths: 15 10 55 20

   * - Signal
     - Number
     - Effect (Default)
     - Trigger
   * - ``SIGINT``
     - 2
     - Terminate. Programs may catch or ignore.
     - :kbd:`Ctrl+C`
   * - ``SIGQUIT``
     - 3
     - Terminate + core dump.
     - :kbd:`Ctrl+\\`
   * - ``SIGTSTP``
     - 20
     - Suspend (stop). Not catchable.
     - :kbd:`Ctrl+Z`
   * - ``SIGSTOP``
     - 19
     - Suspend. Cannot be caught, blocked, or ignored.
     - ``kill -STOP PID``
   * - ``SIGCONT``
     - 18
     - Continue a stopped process.
     - ``kill -CONT PID`` / ``bg`` / ``fg``
   * - ``SIGHUP``
     - 1
     - Hangup. Sent when controlling terminal closes.
     - Close terminal / ``kill -HUP PID``
   * - ``SIGTERM``
     - 15
     - Polite termination request. Programs can catch for cleanup.
     - ``kill PID`` (default)
   * - ``SIGKILL``
     - 9
     - Immediate termination. Cannot be caught. Last resort.
     - ``kill -9 PID``

.. warning::

   ``SIGKILL`` (``kill -9``) should be a weapon of last resort. It gives the
   process no opportunity to flush buffers, close files, remove locks, or
   clean up child processes. Always try ``SIGTERM`` (``kill PID``) first,
   then ``SIGINT``, then ``SIGQUIT``, before escalating to ``SIGKILL``.

.. _job-control-workflow:

Practical Workflows
=====================

The Edit-Compile-Test Loop
----------------------------

.. code-block:: bash

    $ vim main.c              # edit
    # Ctrl+Z to suspend vim
    $ make                    # compile
    $ ./a.out                 # test
    $ fg                      # back to vim

Long-Running Remote Task
---------------------------

.. code-block:: bash

    $ ssh server
    $ tmux new -s data_import
    $ ./import_data.sh        # starts running
    # Ctrl+B d to detach
    $ logout                  # go home

    # Next morning:
    $ ssh server
    $ tmux attach -t data_import
    # See the completed import or any errors

Emergency Backgrounding
-------------------------

.. code-block:: bash

    $ vim file.txt
    # Realise you need to check something:
    # Ctrl+Z
    $ grep pattern /var/log/*.log
    $ fg                     # back to vim
    # OR: if vim was job 1 and you want to run it in background:
    $ bg %1                  # vim runs in background (but will be stopped if it
                             # tries to read from terminal — vim detects this)

.. admonition:: Key Takeaway

   Job control transforms the terminal from a single-task interface into a
   multitasking environment. ``Ctrl+Z`` + ``bg`` is as natural as
   "minimise this window." ``tmux`` is as essential as a window manager.
   Mastering these tools means you never lose work because of a dropped SSH
   connection, and you never open a second terminal just to run ``ls`` while
   ``vim`` is open. The shell is your workspace; job control is how you
   organise it.
