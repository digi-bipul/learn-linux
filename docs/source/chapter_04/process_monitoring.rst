.. _section-4-2:

Process Monitoring
==================================================

.. rst-class:: lead

   A system administrator's primary diagnostic reflex is: "What processes are
   running?" The answer reveals CPU hogs, memory leaks, runaway daemons,
   zombie children, and unexpected guests. Linux provides a rich toolkit for
   process inspection, ranging from the venerable ``ps`` to the interactive
   live monitors ``top``, ``htop``, and ``atop``.

``ps`` — The Universal Process Snapshot
================================================

The ``ps(1)`` command (Process Status) is the oldest and most fundamental
process inspection tool. It provides a **snapshot** of the current processes
at the instant it runs. Understanding ``ps`` is a rite of passage for every
Linux user — and, unfortunately, a source of confusion due to the historical
conflation of **three different option syntaxes**.

The Three ``ps`` Syntaxes

.. table:: The Three ``ps`` Syntax Styles
   :widths: 10 20 30 40

   +-------+----------+------------------------+----------------------------------+
   | Style | Origin   | Convention             | Examples                         |
   +=======+==========+========================+==================================+
   | BSD   | BSD Unix | Options without a dash | ``ps aux``, ``ps ax``,           |
   |       |          |                        | ``ps auxww``                     |
   +-------+----------+------------------------+----------------------------------+
   | UNIX  | AT&T Unix| Options with a single  | ``ps -ef``, ``ps -eF``,          |
   |       |          | dash                   | ``ps -eo pid,ppid,cmd``          |
   +-------+----------+------------------------+----------------------------------+
   | GNU   | GNU/Linux| Options with double    | ``ps --pid 1234``,               |
   |       |          | dashes (long options)  | ``ps --sort=-%mem``              |
   +-------+----------+------------------------+----------------------------------+

.. warning::

   **Do not mix BSD and UNIX styles in the same invocation.** While
   ``ps aux`` works correctly, ``ps -aux`` may behave unexpectedly (on
   some systems, the dash changes how ``a`` is interpreted). The GNU
   ``ps`` implementation (procps-ng) tries to be smart about detecting
   the style, but it is best to stick to one.

The Most Common Invocations

.. code-block:: console
   :caption: Essential ``ps`` commands

   # BSD style: all processes, user-oriented format, including
   # processes without a controlling terminal
   $ ps aux

   # UNIX style: full-format listing of every process
   $ ps -ef

   # List all processes with a "forest" view (shows parent-child tree)
   $ ps af
   $ ps -ef --forest

   # Custom output: show specific columns
   $ ps -eo pid,ppid,user,%cpu,%mem,rss,vsz,stat,start,time,cmd

   # Sort by memory usage (descending)
   $ ps aux --sort=-%mem

   # Sort by CPU usage (descending)
   $ ps aux --sort=-%cpu

   # Show threads of a process
   $ ps -Lp 1234

   # Show all threads system-wide
   $ ps -eLf

   # Show processes for a specific user
   $ ps -u jdoe
   $ ps -u jdoe,alice

   # Show processes by PID
   $ ps -p 1,200,300

   # Show processes by command name
   $ ps -C nginx,sshd

   # Watch repeatedly (like top, but with ps output)
   $ watch -n 1 'ps aux --sort=-%cpu | head -20'

Decoding ``ps aux`` — Parameter by Parameter

The most famous invocation is ``ps aux``. Let us decode it:

.. code-block:: text

   ps aux
   │ ││
   │ │└── x : Include processes that do NOT have a controlling terminal
   │ │       (daemons, background processes, kernel threads).
   │ └─── u : Display user-oriented format (USER, PID, %CPU, %MEM, RSS,
   │         VSZ, STAT, START, TIME, COMMAND).
   └───── a : List all processes with a terminal (tty), plus all processes
              of other users.

**Sample output:**

.. code-block:: text

   USER       PID  %CPU %MEM    VSZ   RSS   TTY   STAT  START   TIME  COMMAND
   root         1   0.0  0.1  16772  5120   ?     Ss    12:00   0:02  /sbin/init
   root       200   0.0  0.2  18724  8192   ?     Ss    12:00   0:00  sshd: /usr/sbin/sshd
   jdoe       301   0.0  0.3  28164 13248   pts/0 Ss+   12:01   0:00  -bash
   jdoe      1234   0.5  2.1 1523844 86016  pts/0 Sl+  12:05   0:15  /usr/bin/firefox
   root      2500   0.0  0.0      0     0   ?     Z     12:10   0:00  [defunct]

**Column-by-column breakdown:**

.. table:: ``ps aux`` Column Meanings
   :widths: 15 85

   +----------+----------------------------------------------------------+
   | Column   | Meaning                                                  |
   +==========+==========================================================+
   | ``USER`` | Owner of the process (effective UID name).               |
   +----------+----------------------------------------------------------+
   | ``PID``  | Process ID.                                              |
   +----------+----------------------------------------------------------+
   | ``%CPU`` | Estimated percentage of CPU time used since the process  |
   |          | started. This is averaged over the process's lifetime,   |
   |          | *not* instantaneous. For instantaneous CPU, use ``top``. |
   +----------+----------------------------------------------------------+
   | ``%MEM`` | Resident memory as a percentage of total physical RAM.   |
   +----------+----------------------------------------------------------+
   | ``VSZ``  | Virtual memory size (in KB). Includes all memory that    |
   |          | the process *could* access: code, data, heap, stack,     |
   |          | mapped files, shared libraries. Much of this may not be  |
   |          | in physical RAM.                                         |
   +----------+----------------------------------------------------------+
   | ``RSS``  | Resident Set Size (in KB). Physical memory actually      |
   |          | in RAM. This **overcounts** shared libraries (each       |
   |          | process's RSS includes the full library, even if it is   |
   |          | shared).                                                 |
   +----------+----------------------------------------------------------+
   | ``TTY``  | Controlling terminal. ``?`` means no terminal (daemon). |
   +----------+----------------------------------------------------------+
   | ``STAT`` | Process state code(s): ``R``, ``S``, ``D``, ``Z``,      |
   |          | ``T`` (see section 4.1.3) with modifiers:               |
   |          | ``+`` = foreground group, ``s`` = session leader,       |
   |          | ``l`` = multi-threaded, ``<`` = high priority,          |
   |          | ``N`` = low priority.                                    |
   +----------+----------------------------------------------------------+
   | ``START``| Time or date the process started.                        |
   +----------+----------------------------------------------------------+
   | ``TIME``| Cumulative CPU time consumed (not wall-clock time).     |
   +----------+----------------------------------------------------------+
   | ``COMMAND``| The command name (with arguments, truncated by default). |
   +----------+----------------------------------------------------------+

.. note::

   On Linux, ``ps`` displays **estimated** CPU usage by default. The kernel
   tracks process start time and CPU time consumed, but the percentage shown
   is calculated at snapshot time. For real-time CPU monitoring, always use
   ``top`` or ``htop``.

Useful ``ps`` Output Formats

.. code-block:: console

   # Show every thread with its TID (lightweight process ID)
   $ ps -eLo pid,tid,pcpu,pmem,comm

   # Show processes with their nice value and priority
   $ ps -eo pid,ni,pri,cmd

   # Show processes with their security context (SELinux)
   $ ps -eo pid,user,label,cmd

   # Show processes with their OOM score (Out-Of-Memory killer adjustment)
   $ ps -eo pid,comm,oom_adj,oom_score,oom_score_adj

``top`` — The Classic Live Monitor
===========================================

While ``ps`` gives a snapshot, ``top(1)`` provides a **continuously
updating** real-time view of system processes. It is the default interactive
process monitor on virtually every Linux distribution.

.. code-block:: console

   $ top

**Understanding the ``top`` header:**

.. code-block:: text

   top - 12:30:45 up 5 days, 2:15,  3 users,  load average: 0.08, 0.12, 0.10
   Tasks: 245 total,   1 running, 244 sleeping,   0 stopped,   0 zombie
   %Cpu(s):  2.5 us,  0.8 sy,  0.0 ni, 96.5 id,  0.0 wa,  0.0 hi,  0.2 si,  0.0 st
   MiB Mem :  16000.0 total,   4234.5 free,   5678.2 used,   6087.3 buff/cache
   MiB Swap:   2048.0 total,   2048.0 free,      0.0 used.   9887.3 avail Mem

**Header breakdown:**

.. list-table:: ``top`` Header Lines
   :widths: 15 85

   * - **Line 1**
     - System uptime, number of logged-in users, and load averages (1, 5,
       15 minutes). Same data as ``uptime(1)`` and ``/proc/loadavg``.
   * - **Line 2**
     - Task summary: total processes, running, sleeping, stopped, zombie.
   * - **Line 3**
     - CPU state percentages:
       * ``us`` — user space (normal processes)
       * ``sy`` — system (kernel)
       * ``ni`` — nice (user processes with altered priority)
       * ``id`` — idle
       * ``wa`` — I/O wait (time waiting for disk/network I/O)
       * ``hi`` — hardware interrupts
       * ``si`` — software interrupts
       * ``st`` — steal time (virtualised: time the hypervisor took)
   * - **Line 4**
     - Physical memory: total, free, used, buff/cache.
   * - **Line 5**
     - Swap: total, free, used. ``avail Mem`` is an estimate of memory
       available for starting new applications (includes reclaimable cache).

.. note::

   On modern systems with plenty of RAM, ``avail Mem`` is a more useful
   indicator of "how much memory is actually free" than the raw ``free``
   column, because the kernel can reclaim cache pages when needed.

**Interactive ``top`` commands:**

Once ``top`` is running, press these keys to control the display:

.. code-block:: text

   h          Help
   q          Quit
   k          Kill a process (prompts for PID and signal)
   r          Renice a process (change priority)
   u          Filter by user
   M          Sort by memory usage (descending)
   P          Sort by CPU usage (descending)
   T          Sort by time (cumulative CPU time)
   N          Sort by PID
   1          Toggle per-CPU view
   c          Toggle full command line vs. command name
   V          Forest view (show parent-child tree)
   W          Write configuration to ~/.toprc
   f          Enter field management screen
   R          Reverse sort
   i          Hide idle processes
   t          Toggle display of CPU/cpu line

``htop`` — Modern Interactive Monitor
==============================================

``htop`` is a third-party interactive process viewer (install with
``apt install htop`` / ``dnf install htop`` / ``apk add htop``) that
improves on ``top`` in several ways:

* **Color-coded** — CPU, memory, and swap usage displayed as intuitive bars.
* **Mouse support** — Click to select, sort, or kill processes.
* **Tree view** — Built-in tree display (F5) showing parent-child hierarchy.
* **Scrollable** — See all processes, not just those fitting on screen.
* **Vertical and horizontal scrolling** — See full command lines.
* **LMMS** — "Last column modes" to add/remove fields interactively.

.. code-block:: console

   $ htop               # Standard view
   $ htop -t            # Start in tree view
   $ htop -u jdoe       # Show only jdoe's processes
   $ htop -p 1,200,300  # Show only specific PIDs

**Interactive htop keys:**

.. code-block:: text

   F1 / h     Help
   F2 / S     Setup (configure display, colors, columns)
   F3 / /     Search
   F4 / \     Filter (by process name)
   F5 / t     Tree view
   F6 / >     Sort by column
   F7 / ]     Decrease priority (nice +1)
   F8 / [     Increase priority (nice -1)
   F9 / k     Kill process (select signal from menu)
   F10 / q    Quit
   Space      Tag a process (for batch operations)
   u          Show processes of one user
   p          Toggle program path display
   H / I      Hide/show user threads
   K          Hide/show kernel threads

.. admonition:: Modern Alternative: ``btop``

   For the truly modern enthusiast, ``btop++`` (often just ``btop``) is a
   resource monitor that uses C++17 and provides GPU monitoring, detailed
   disk I/O per device, network speed per interface, and customisable
   colour themes. It requires a terminal with Unicode and true colour
   support (kitty, alacritty, GNOME Terminal, Konsole, etc.).

   .. code-block:: console

      $ btop

   While ``htop`` remains the community standard, ``btop`` represents the
   cutting edge of terminal-based monitoring.

``atop`` — Advanced System & Process Monitor
=====================================================

``atop`` is unique in that it **records** system activity to a log file,
enabling **historical analysis**. This makes it invaluable for diagnosing
intermittent issues that happened hours ago.

.. code-block:: console

   # Start atop in interactive mode
   $ atop

   # Read historical data
   $ atop -r /var/log/atop/atop_20260715

   # Log data automatically (via systemd service or cron)
   $ systemctl enable --now atop     # Most distros
   $ rc-update add atop default      # Alpine/OpenRC

**Unique atop features:**

* **Per-process disk I/O** — Shows read/write throughput per process.
* **Network usage per process** — (with ``atop -n`` or atopnet).
* **Process exit codes** — Records why processes died (useful for detecting
  crashes behind the scenes).
* **Accumulated resource accounting** — Shows the total resource consumption
  since boot.
* **Colour alerts** — Red highlights for critical resource saturation.

**Key atop interactive keys:**

.. code-block:: text

   g          Show general overview
   c          Sort by CPU consumption
   m          Sort by memory consumption
   d          Show disk I/O details
   n          Show network details
   v          Show various process details
   t         Jump to older (previous) log interval
   T         Jump to newer (next) log interval
   b          Jump back to specified timestamp

``pstree`` — Process Trees
====================================

The ``pstree(1)`` command displays processes as a tree, visually showing the
parent-child hierarchy. This is invaluable for understanding the
relationships between daemons, shells, and their children.

.. code-block:: console

   $ pstree
   systemd─┬─cron─┬─cron
           │      └─cron───sh───php
           ├─dbus-daemon
           ├─networkd
           ├─nginx───2*[nginx]
           ├─sshd───sshd───sshd───bash───pstree
           └─systemd-journal

   # Show PIDs
   $ pstree -p
   systemd(1)─┬─cron(250)─┬─cron(1234)
              │           └─cron(1235)───sh(1236)───php(1237)
              ├─sshd(200)───sshd(300)───sshd(301)───bash(302)───pstree(400)
              └─nginx(280)───nginx(281)───nginx(282)

   # Show only a specific user's processes
   $ pstree jdoe

   # Highlight the current process and its ancestors
   $ pstree -s $$

   # Show command-line arguments
   $ pstree -a

   # Compact view (hide threads)
   $ pstree -T

   # Show only processes matching a name
   $ pstree sshd

Choosing the Right Tool
================================

.. table:: Monitoring Tool Selection Guide
   :widths: 20 25 25 30

   +---------+-------------------+-----------------------+------------------------+
   | Tool    | Best For          | Not For               | Availability            |
   +=========+===================+=======================+========================+
   | ``ps``  | Scripting,        | Real-time monitoring  | Every Linux, ever.      |
   |         | one-shot queries, | (it's a snapshot).    |                         |
   |         | piping to grep.   |                       |                         |
   +---------+-------------------+-----------------------+------------------------+
   | ``top`` | Quick live view,  | Visual customisation, | Every Linux, in the     |
   |         | sorting, killing. | tree view, scrolling. | ``procps-ng`` package.  |
   +---------+-------------------+-----------------------+------------------------+
   | ``htop``| Interactive       | Historical analysis,  | Third-party (``htop``   |
   |         | browsing, tree    | per-process I/O.      | package).               |
   |         | view, mouse.      |                       |                         |
   +---------+-------------------+-----------------------+------------------------+
   | ``atop``| Historical        | Quick glance          | Third-party (``atop``   |
   |         | analysis, per-    | (overwhelming initial | package).               |
   |         | process I/O/net,  | display).             |                         |
   |         | crash forensics.  |                       |                         |
   +---------+-------------------+-----------------------+------------------------+
   | ``btop``| Modern visual     | Older terminals,     | Third-party (``btop``   |
   |         | polish, GPU       | remote TTY sessions   | package, newer distros).|
   |         | monitoring,       | (no true colour).     |                         |
   |         | custom themes.    |                       |                         |
   +---------+-------------------+-----------------------+------------------------+
   |``pstree``| Visualising       | Numerical data,      | Usually in ``psmisc``   |
   |         | parent-child      | resource usage.       | (always installed).     |
   |         | relationships.    |                       |                         |
   +---------+-------------------+-----------------------+------------------------+

Summary
==============

*   ``ps`` provides a snapshot of processes. Understand its three syntax
    styles (BSD, UNIX, GNU) and never mix them.
*   ``ps aux`` is the single most common invocation: all processes, user
    format, including those without a TTY.
*   ``top`` is the default live monitor; learn its interactive hotkeys.
*   ``htop`` improves on ``top`` with colour, mouse support, tree view,
    and scrolling. ``btop`` is the newest alternative with GPU support.
*   ``atop`` records historical data for retrospective diagnosis.
*   ``pstree`` visualises the process hierarchy as a tree.
*   For scripting, always use ``ps`` with custom ``-eo`` format for
    machine-parseable output.

