.. _section-4-3:

Signals — Inter-Process Communication via Notifications
===========================================================

.. rst-class:: lead

   Signals are the oldest form of inter-process communication (IPC) on Unix.
   They are **asynchronous notifications** sent from the kernel (or another
   process) to a target process, informing it that some event has occurred.
   Signals can terminate a process, pause it, continue it, tell it to
   re-read configuration files, or trigger custom behaviour defined by the
   process itself.

What Is a Signal?
=========================

A signal is a small, fixed-format message (just an integer) delivered to a
process by the kernel. There is no payload — no data, no message body. The
signal's **number** *is* the message. The receiving process can respond in
one of three ways:

1. **Default action**: The kernel performs a predefined action (terminate,
   core dump, ignore, stop, or continue).
2. **Catch (handle)**: The process registers a **signal handler** — a
   function in its code that is executed when the signal arrives.
3. **Ignore**: The process explicitly tells the kernel to discard the
   signal (``SIGKILL`` and ``SIGSTOP`` cannot be ignored or caught).

**Signals on the command line:**

.. code-block:: console

   $ kill -l           # List all available signals
    1) SIGHUP       2) SIGINT       3) SIGQUIT      4) SIGILL
    5) SIGTRAP      6) SIGABRT      7) SIGBUS       8) SIGFPE
    9) SIGKILL     10) SIGUSR1     11) SIGSEGV     12) SIGUSR2
   13) SIGPIPE     14) SIGALRM     15) SIGTERM     16) SIGSTKFLT
   17) SIGCHLD     18) SIGCONT     19) SIGSTOP     20) SIGTSTP
   21) SIGTTIN     22) SIGTTOU     23) SIGURG      24) SIGXCPU
   25) SIGXFSZ     26) SIGVTALRM   27) SIGPROF     28) SIGWINCH
   29) SIGIO       30) SIGPWR      31) SIGSYS

Essential Signals — The Ones You Must Know
==================================================

Not all 31 standard signals (plus real-time signals 32–64) are equally
important. Here are the signals that every Linux user and administrator
must understand:

.. table:: Essential Linux Signals
   :widths: 10 20 15 55

   +-------+----------+------------+---------------------------------------+
   | Number| Name     | Default    | Typical Use                           |
   |       |          | Action     |                                       |
   +=======+==========+============+=======================================+
   | 1     | SIGHUP   | Terminate  | **Hang up.** Originally sent when a   |
   |       |          |            | terminal line was disconnected. Today |
   |       |          |            | commonly used to tell daemons to      |
   |       |          |            | **reload their configuration** (e.g., |
   |       |          |            | ``kill -HUP $(cat /var/run/nginx.pid)``|
   +-------+----------+------------+---------------------------------------+
   | 2     | SIGINT   | Terminate  | **Interrupt.** Sent when the user     |
   |       |          |            | presses ``Ctrl+C``. The process is    |
   |       |          |            | expected to terminate gracefully.     |
   +-------+----------+------------+---------------------------------------+
   | 3     | SIGQUIT  | Core dump  | **Quit.** Sent by ``Ctrl+\``.         |
   |       |          |            | Terminates with a core dump for       |
   |       |          |            | debugging.                            |
   +-------+----------+------------+---------------------------------------+
   | 9     | SIGKILL  | Terminate  | **Kill.** The process is terminated   |
   |       |          |            | **immediately** by the kernel. Cannot |
   |       |          |            | be caught, blocked, or ignored.       |
   |       |          |            | Always the last resort.               |
   +-------+----------+------------+---------------------------------------+
   | 10    | SIGUSR1  | Terminate  | **User-defined signal 1.** Available  |
   |       |          |            | for application-specific purposes.    |
   |       |          |            | (e.g., Apache: graceful restart.)     |
   +-------+----------+------------+---------------------------------------+
   | 11    | SIGSEGV  | Core dump  | **Segmentation fault.** Sent by the   |
   |       |          |            | kernel when a process accesses invalid |
   |       |          |            | memory. Program bug.                   |
   +-------+----------+------------+---------------------------------------+
   | 12    | SIGUSR2  | Terminate  | **User-defined signal 2.** Like       |
   |       |          |            | SIGUSR1.                              |
   +-------+----------+------------+---------------------------------------+
   | 13    | SIGPIPE  | Terminate  | **Broken pipe.** Sent when a process  |
   |       |          |            | writes to a pipe whose reading end has|
   |       |          |            | been closed. Classic example:         |
   |       |          |            | ``yes | head`` — ``yes`` gets SIGPIPE |
   |       |          |            | when ``head`` closes the pipe.        |
   +-------+----------+------------+---------------------------------------+
   | 15    | SIGTERM  | Terminate  | **Terminate.** The *polite* way to    |
   |       |          |            | ask a process to stop. The process    |
   |       |          |            | can catch this signal, clean up       |
   |       |          |            | resources, and exit gracefully.       |
   |       |          |            | Default for ``kill`` without a signal |
   |       |          |            | number.                               |
   +-------+----------+------------+---------------------------------------+
   | 17    | SIGCHLD  | Ignore     | **Child status changed.** Sent to the |
   |       |          |            | parent when a child process terminates,|
   |       |          |            | stops, or continues. Used by ``wait`` |
   |       |          |            | mechanics.                            |
   +-------+----------+------------+---------------------------------------+
   | 18    | SIGCONT  | Continue   | **Continue.** Resumes a stopped       |
   |       |          |            | process. ``fg`` and ``bg`` in the     |
   |       |          |            | shell send SIGCONT.                   |
   +-------+----------+------------+---------------------------------------+
   | 19    | SIGSTOP  | Stop       | **Stop.** Pauses the process          |
   |       |          |            | **immediately**. Cannot be caught,    |
   |       |          |            | blocked, or ignored. ``Ctrl+Z``       |
   |       |          |            | sends SIGTSTP (similar but catchable).|
   +-------+----------+------------+---------------------------------------+
   | 20    | SIGTSTP  | Stop       | **Terminal stop.** ``Ctrl+Z``. The    |
   |       |          |            | process can catch this and perform    |
   |       |          |            | actions before stopping (e.g., shell  |
   |       |          |            | suspends the foreground job).         |
   +-------+----------+------------+---------------------------------------+

.. admonition:: The Golden Rule of Signals

   Always try **SIGTERM (15)** first. Give the process a chance to shut down
   gracefully. If it refuses after a reasonable timeout (5–10 seconds), use
   **SIGKILL (9)** as a last resort. ``SIGKILL`` does not allow any cleanup
   — file descriptors remain unclosed, temporary files stay behind, and data
   buffers are not flushed.

Sending Signals: ``kill``, ``killall``, ``pkill``
============================================================

``kill`` — The Original Signal Sender

Despite its name, ``kill(1)`` sends **any** signal to a process, not just
SIGKILL. If no signal is specified, SIGTERM is sent.

.. code-block:: console
   :caption: ``kill`` in action

   # Send SIGTERM (default) to process 1234
   kill 1234

   # Send a specific signal by number
   kill -9 1234            # SIGKILL
   kill -15 1234           # SIGTERM (explicit)
   kill -1 1234            # SIGHUP

   # Send a specific signal by name
   kill -HUP 1234          # SIGHUP (reload config)
   kill -INT 1234          # SIGINT (Ctrl+C equivalent)
   kill -TERM 1234         # SIGTERM

   # Send a signal to multiple processes
   kill -TERM 1234 5678 9012

   # Check if a signal can be sent (no-op test)
   kill -0 1234            # Returns 0 if process exists and you can signal it

   # Send signal to all processes (only root)
   kill -TERM -1           # Sends SIGTERM to all processes except PID 1

   # Force a process to dump core for debugging
   kill -ABRT 1234         # SIGABRT — abort with core dump

.. note::

   The ``kill -0 PID`` trick is widely used in scripts to check if a
   process is running:

   .. code-block:: bash

      if kill -0 "$PID" 2>/dev/null; then
          echo "Process $PID is running"
      else
          echo "Process $PID is not running or not accessible"
      fi

``killall`` — Kill Processes by Name

The ``killall(1)`` command sends a signal to **all processes matching a
command name** (not to be confused with the ``killall`` command on some
other Unix systems which kills everything).

.. code-block:: console

   # Kill all processes named "firefox"
   killall firefox

   # Kill all nginx worker processes
   killall -9 nginx

   # Send SIGHUP to all sshd processes
   killall -HUP sshd

   # Do not complain if no processes match
   killall -q nonexistent

   # Interactive: ask before killing each process
   killall -I -TERM firefox

   # Match process names exactly (case-sensitive by default)
   killall FIREFOX           # No match on Linux (case-sensitive!)
   killall -I firefox         # Case-insensitive matching

   # Only kill processes owned by a specific user
   killall -u jdoe firefox

.. warning::

   ``killall`` matches the **process name**, which is limited to 15
   characters (the ``comm`` field in ``/proc/[PID]/stat``). This is the
   base name of the executable, without path or arguments. A long command
   like ``/usr/lib/chromium-browser/chromium-browser`` will appear as
   ``chromium-browse`` in some contexts.

``pkill`` — Flexible Pattern-Based Signalling

The ``pkill(1)`` command (part of the ``procps-ng`` package, same as ``ps``)
sends signals to processes matching **extended regular expressions** on the
process name or command line.

.. code-block:: console

   # Kill all processes with "apache" in the name
   pkill apache

   # Kill processes whose command line matches a regex
   pkill -f "python.*server.py"

   # Send specific signal
   pkill -HUP nginx

   # Kill only processes owned by a user
   pkill -u jdoe

   # Kill only processes running on a specific terminal
   pkill -t pts/1

   # Kill the newest or oldest process matching the pattern
   pkill -n firefox          # Newest
   pkill -o firefox          # Oldest

   # Show what would be killed (dry run — won't actually signal)
   pkill -f "sleep 100"

   # With pgrep — show matching PIDs before killing
   $ pgrep -f "sleep"
   12345
   12346
   $ pkill -f "sleep"

.. note::

   The difference between ``killall`` and ``pkill`` is subtle:
   * ``killall`` matches the exact process base name (the ``comm`` field).
   * ``pkill`` matches a **regular expression** against the full command
     line (with ``-f``) or the process name (without).

   For most daily use, ``pkill`` is more flexible. ``killall`` is simpler
   and less error-prone when you know the exact binary name.

Trapping Signals in Shell Scripts
=========================================

A **signal trap** allows a shell script to intercept a signal and execute
custom code instead of the default action. This is essential for writing
robust scripts that clean up temporary files, release resources, or perform
graceful shutdowns.

The ``trap`` Built-In

The syntax:

.. code-block:: bash

   trap 'commands' SIGNAL1 SIGNAL2 ...

**Practical examples:**

.. code-block:: bash
   :caption: ``trap`` — cleaning up temporary files

   #!/bin/bash
   # A script that cleans up on interruption

   TEMPDIR=$(mktemp -d)
   echo "Working in $TEMPDIR"

   # Cleanup function
   cleanup() {
       echo "Cleaning up..."
       rm -rf "$TEMPDIR"
       echo "Done."
       exit 0
   }

   # Register trap for multiple signals
   trap cleanup EXIT       # Runs on normal script exit
   trap cleanup INT        # Ctrl+C
   trap cleanup TERM       # kill -TERM

   # Simulate work
   cd "$TEMPDIR"
   for i in $(seq 1 10); do
       echo "Working... iteration $i"
       sleep 1
   done

   echo "Completed successfully."

**Multiple signal handling:**

.. code-block:: bash
   :caption: Different handlers for different signals

   #!/bin/bash

   clean_exit() {
       echo "Normal exit."
       rm -f /tmp/lockfile
   }

   abrupt_exit() {
       echo "Interrupted! Cleaning up..."
       rm -f /tmp/lockfile
       exit 1
   }

   trap clean_exit EXIT           # Normal exit (end of script)
   trap abrupt_exit INT TERM HUP  # Interrupted
   trap '' QUIT                   # Ignore SIGQUIT entirely

   # Create a lock
   echo $$ > /tmp/lockfile
   echo "PID $$ written to /tmp/lockfile"

   # Main work loop
   while true; do
       echo "Running... (PID=$$)"
       sleep 2
   done

**Resetting a trap:**

.. code-block:: bash

   # Set a trap
   trap 'echo "Caught SIGINT"' INT

   # Reset to default action
   trap - INT

   # Ignore a signal (set to empty string)
   trap '' HUP

**The ``EXIT`` pseudo-signal:**

``EXIT`` is not a real signal — it is a bash pseudo-signal that triggers
when the shell exits for **any** reason (normal end, ``exit`` command, or
receipt of uncatched SIGTERM). It is the most commonly trapped "signal"
because it guarantees cleanup runs.

Critical Patterns

**Pattern 1: Ensure only one instance of a script runs:**

.. code-block:: bash
   :caption: Singleton script with trap

   #!/bin/bash
   LOCKFILE="/var/run/myscript.lock"

   cleanup() {
       rm -f "$LOCKFILE"
       exit 0
   }

   trap cleanup EXIT

   if [ -f "$LOCKFILE" ]; then
       echo "Script already running (PID $(cat "$LOCKFILE"))"
       exit 1
   fi

   echo $$ > "$LOCKFILE"
   # ... main script logic ...

**Pattern 2: Timeout a long-running operation:**

.. code-block:: bash
   :caption: Using SIGALRM via trap

   #!/bin/bash
   TIMEOUT=10

   timeout_handler() {
       echo "Timeout reached. Exiting."
       exit 1
   }

   trap timeout_handler ALRM

   # The child process must handle SIGALRM
   (sleep $TIMEOUT && kill -ALRM $$) &
   ALARM_PID=$!

   # Main work
   echo "Starting work (timeout: ${TIMEOUT}s)..."
   # ... long-running command ...
   kill $ALARM_PID 2>/dev/null  # Cancel the alarm if work finished
   echo "Work completed before timeout."

The ``SIGPIPE`` Special Case
====================================

``SIGPIPE`` is unique because it is not sent explicitly by any user command;
it is generated by the kernel when a process writes to a pipe whose reading
end has been closed.

.. code-block:: console

   # The classic SIGPIPE example
   $ yes | head -5
   y
   y
   y
   y
   y

   What happens:
   1. ``yes`` writes "y\n" to stdout (the pipe).
   2. ``head`` reads from the pipe, prints 5 lines, and exits.
   3. When ``head`` exits, the reading end of the pipe is closed.
   4. The next ``write(2)`` by ``yes`` to the pipe causes the kernel to
      deliver SIGPIPE to ``yes``.
   5. ``yes`` terminates (default action for SIGPIPE).

You can observe this directly:

.. code-block:: console

   $ yes > /dev/null &
   [1] 1234
   $ kill %1        # Kill yes normally
   $ strace -e write yes 2>&1 | head -10
   ...
   write(1, "y\n", 2)                     = 2
   write(1, "y\n", 2)                     = 2
   write(1, "y\n", 2)                     = -1 EPIPE (Broken pipe)
   --- SIGPIPE {si_signo=SIGPIPE, ...} ---
   +++ killed by SIGPIPE +++

.. note::

   Shell scripts that use pipes should be aware that a command in the middle
   of a pipeline can receive SIGPIPE if a later command exits early. The
   shell's default behaviour (``set -o pipefail``) combined with careful
   error handling can manage this.

Sending Signals Between Users
======================================

By default, a user can send signals only to their own processes
(processes with the same real or effective UID). Root can send signals to
any process.

.. code-block:: console

   # Alice tries to kill Bob's process
   $ kill 5678
   -bash: kill: (5678) - Operation not permitted

   # Root can kill any process
   # kill 5678   # succeeds

**Exceptions:**

* ``SIGCONT`` can be sent to any process in the same session (allows ``fg``
  and ``bg`` to work across users in some configurations).
* ``kill -0 PID`` (checking existence) is permitted if the process's
  executable is readable by the probing process.

Real-Time Signals (32–64)
==================================

Linux supports 33 real-time signals (``SIGRTMIN`` to ``SIGRTMAX``, typically
signals 34–64). Unlike standard signals:

* They are **queued** — multiple pending signals are not merged.
* They can carry an **integer payload** (via ``sigqueue(3)``).
* They are used primarily by real-time applications and threading libraries
  (NPTL uses some of these internally).

You will rarely need to use real-time signals directly, but their existence
explains why ``ps`` sometimes shows processes with real-time priority.

Summary
==============

* Signals are asynchronous integer notifications sent by the kernel or
  another process.
* **SIGTERM (15)** — polite termination request. Try first.
* **SIGKILL (9)** — forcible, immediate termination. Cannot be caught.
  Last resort.
* **SIGHUP (1)** — historically "hang up," now commonly "reload config."
* **SIGSTOP (19)** / **SIGCONT (18)** — pause and resume execution.
* **SIGINT (2)** — ``Ctrl+C``. **SIGTSTP (20)** — ``Ctrl+Z``.
* ``kill`` sends signals by PID; ``killall`` by process name;
  ``pkill`` by regex on the command line.
* ``trap`` enables shell scripts to catch signals and run cleanup code.
* Always trap ``EXIT`` for resource cleanup.
* ``SIGPIPE`` is automatically sent by the kernel on broken pipe writes.

