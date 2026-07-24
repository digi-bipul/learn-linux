.. _section-4-1:

Process Lifecycle
==================================================

.. rst-class:: lead

   Programs are inert. They sit on disk as sequences of bytes. It is only
   when the kernel loads a program into memory and begins executing it that
   we have a **process** — a living, breathing entity with state, identity,
   and resources. Understanding how processes come into existence, how they
   change state, and how they die is fundamental to understanding Linux as a
   whole.

The ``fork`` / ``exec`` Paradigm
========================================

On Unix-like systems (including Linux), every new process is created by a
**two-step mechanism**: ``fork`` then ``exec``. This is one of the oldest
and most elegant designs in operating systems, originating in the earliest
versions of Unix at Bell Labs.

.. _figure-fork-exec:

.. code-block:: text
   :caption: The fork/exec sequence (conceptual)

   ┌─────────────┐
   │  Shell (bash)│
   │  PID=1234    │
   │  Executing   │
   └──────┬───────┘
          │ User types "ls -l"
          ▼
   ┌─────────────┐     fork(2)     ┌──────────────┐
   │  Shell (bash)│ ──────────────▶│  Shell (bash) │
   │  PID=1234    │                │  PID=1235     │
   │  (parent)    │                │  (child)      │
   └─────────────┘                └──────┬─────────┘
                                         │ execve(2) replaces
                                         │ the child's memory
                                         │ with /bin/ls
                                         ▼
                                   ┌──────────────┐
                                   │  /bin/ls     │
                                   │  PID=1235    │
                                   │  (running ls)│
                                   └──────────────┘

**Step 1: ``fork(2)`` — The Clone**

The ``fork(2)`` system call creates a new process that is an **almost exact
copy** of the calling process:

* The child gets a **new PID** (Process ID).
* The child gets a **copy** of the parent's memory (in practice, the kernel
  uses **copy-on-write** — COW — to avoid copying memory pages until one of
  the processes writes to them; until then they share the same physical
  pages).
* The child inherits file descriptors, signal handlers, environment
  variables, and the current working directory.
* The parent's PID is recorded as the child's **PPID** (Parent Process ID).

After ``fork``, both parent and child continue executing from the **same
point** in the code, with one critical difference: ``fork`` returns the
child's PID to the parent, and ``0`` to the child (or ``-1`` on error). This
return value is how programs distinguish parent from child:

.. code-block:: c
   :caption: Conceptual C code for fork (simplified)

   pid_t pid = fork();

   if (pid > 0) {
       /* This is the parent. pid == child's PID */
       wait(NULL);  /* Wait for child to finish */
   } else if (pid == 0) {
       /* This is the child. pid == 0 */
       execve("/bin/ls", argv, envp);  /* See Step 2 */
   } else {
       /* fork() returned -1 — something went wrong */
       perror("fork");
   }

**Step 2: ``execve(2)`` — The Transformation**

The ``execve(2)`` system call (and its family: ``execvp``, ``execl``,
``execle``, etc.) replaces the **entire address space** of the calling
process with a new program loaded from disk:

* The process's PID **does not change**.
* All memory (code, data, heap, stack) is replaced.
* File descriptors with the ``FD_CLOEXEC`` flag are closed.
* Signal handlers are reset to default.
* The new program begins execution at its ``main()`` entry point.

The child created by ``fork`` almost immediately calls ``exec``, which
transforms it from a clone of the parent into the desired program. This is
why the two calls are always discussed together: ``fork`` creates the
process; ``exec`` gives it a new identity.

.. note::

   The ``fork``/``exec`` separation is a Unix design breakthrough. It means
   that **creating a process is cheap** (just copy a few kernel data
   structures, thanks to COW), and **loading a new program is a separate
   operation**. This separation allows the shell to do things like:

   .. code-block:: console

      $ ls -l | wc -l

   The shell forks three times (for ``ls``, ``wc``, and the pipeline shell),
   then executes each program. The pipe is set up **between** the fork and
   exec calls, so the child inherits the pipe file descriptors.

PID, PPID, and the Process Hierarchy
============================================

Every process on a Linux system has a unique numeric identifier called a
**PID (Process ID)**. PIDs are allocated by the kernel sequentially, up to
a maximum defined in ``/proc/sys/kernel/pid_max`` (default ``32768`` on
64-bit systems, though values up to 4,194,304 are possible). When the kernel
wraps around, it skips PIDs that are still in use.

**The process tree:**

Every process (except PID 1) has a **parent process**. This creates a strict
hierarchy, rooted at ``init`` (PID 1):

.. code-block:: text

   PID 1 (init/systemd)
     ├─ PID 200 (sshd)
     │   └─ PID 300 (sshd: jdoe@pts/0)
     │       └─ PID 301 (bash)
     │           ├─ PID 400 (ls)
     │           └─ PID 401 (wc)
     ├─ PID 250 (cron)
     ├─ PID 260 (rsyslogd)
     └─ PID 280 (nginx)
         ├─ PID 281 (nginx: worker)
         └─ PID 282 (nginx: worker)

**Viewing parent-child relationships:**

.. code-block:: console

   $ ps -eo pid,ppid,cmd | head -10
     PID  PPID  CMD
       1     0  /sbin/init
     200     1  sshd: /usr/sbin/sshd -D
     300   200  sshd: jdoe [priv]
     301   300  bash
     400   301  ps -eo pid,ppid,cmd

   $ pstree -p
   systemd(1)─┬─sshd(200)───sshd(300)───bash(301)───pstree(400)
              ├─cron(250)
              ├─rsyslogd(260)
              └─nginx(280)─┬─nginx(281)
                            └─nginx(282)

Process States
======================

A process is not always "running." The kernel's scheduler moves processes
through a series of states depending on what they are doing. The traditional
five-state model (running, ready, blocked, new, terminated) is refined by
Linux into several distinct states visible in the ``ps`` output:

.. table:: Linux Process States (as shown by ``ps``)
   :widths: 10 30 60

   +--------+------------------------+-----------------------------------------+
   | Code   | Name                   | Description                             |
   +========+========================+=========================================+
   | ``R``  | Running / Runnable     | The process is either currently running |
   |        |                        | on a CPU or is ready to run (waiting in |
   |        |                        | the run queue).                         |
   +--------+------------------------+-----------------------------------------+
   | ``S``  | Interruptible Sleep    | The process is waiting for an event or  |
   |        |                        | resource (e.g., I/O completion, a timer,|
   |        |                        | a signal). Can be woken by signals.     |
   +--------+------------------------+-----------------------------------------+
   | ``D``  | Uninterruptible Sleep  | The process is waiting for I/O (usually |
   |        | (Disk Sleep)           | disk) and **cannot** be interrupted by  |
   |        |                        | signals. This state exists to protect   |
   |        |                        | critical I/O operations from being      |
   |        |                        | aborted mid-transfer.                   |
   +--------+------------------------+-----------------------------------------+
   | ``Z``  | Zombie                 | The process has terminated but its exit |
   |        |                        | code has not been collected by its      |
   |        |                        | parent (via ``wait(2)``). A zombie only |
   |        |                        | consumes a PID table entry — no memory. |
   +--------+------------------------+-----------------------------------------+
   | ``T``  | Stopped                | Execution has been suspended, typically |
   |        |                        | by a signal (``SIGSTOP`` or ``SIGTSTP``)|
   |        |                        | or via a debugger (ptrace).             |
   +--------+------------------------+-----------------------------------------+
   | ``X``  | Dead (rarely seen)     | The process is being torn down. This    |
   |        |                        | state is so brief that ``ps`` almost    |
   |        |                        | never catches it.                       |
   +--------+------------------------+-----------------------------------------+

**Additional modifiers** (shown as sub-status in parentheses):

.. code-block:: text

   R+      Running in the foreground process group
   Ss      Interruptible sleep, session leader
   S<      Interruptible sleep, high priority (nice < 0)
   SN      Interruptible sleep, low priority (nice > 0)
   Sl      Interruptible sleep, multi-threaded (uses NPTL threads)
   Ds      Uninterruptible sleep, session leader

**The Zombie state — a deeper look:**

Zombie processes are perhaps the most misunderstood. A zombie is **not** a
runaway process; it is a **finished** process whose exit code has not yet
been collected:

.. code-block:: console

   $ ps -eo pid,stat,cmd | grep Z
   12345 Z  [defunct]

**Why zombies exist:**

When a process terminates (via ``exit(2)`` or signal), the kernel sends
``SIGCHLD`` to the parent and keeps the terminated process's entry in the
process table (containing the exit code, resource usage statistics, etc.)
until the parent calls ``wait(2)`` or ``waitpid(2)``. If the parent never
does, the zombie persists.

**Why zombies are bad:**

Each zombie consumes a slot in the kernel's PID table. If a parent process
fails to ``wait`` for its children (e.g., due to a bug), and creates
thousands of children, the system can run out of PID entries, preventing new
processes from starting.

**How zombies get cleaned up:**

1. The parent calls ``wait(2)`` — the zombie is reaped.
2. The parent terminates — the zombie child is **inherited by PID 1**
   (init), which periodically calls ``wait(2)`` to reap orphaned children.

.. note::

   You **cannot** kill a zombie with ``SIGKILL``. It is already dead. You
   must kill its parent (which may be PID 1). If the parent is PID 1 and
   refuses to reap, the zombie is essentially permanent until reboot.

**The Orphan process:**

An **orphan** is a process whose parent has terminated before it did. The
kernel immediately **reparents** all orphans to PID 1 (init/systemd):

.. code-block:: console

   $ sleep 100 &
   [1] 1234
   $ kill $PPID        # Simulate parent shell dying
   $ ps -o pid,ppid,cmd -p 1234
     PID  PPID  CMD
     1234     1  sleep 100

   # PID 1 (systemd) is now the parent. It will reap this process
   # when sleep finishes.

The ``/proc`` Filesystem — A Window into the Kernel
============================================================

The ``/proc`` pseudo-filesystem (also called the **procfs**) is one of the
most remarkable design features of Linux. It presents kernel data structures
as a **virtual file system** — directories and files that don't exist on
disk but are manufactured on-the-fly by the kernel when you read them.

**Mount point:**

.. code-block:: console

   $ mount | grep proc
   proc on /proc type proc (rw,nosuid,nodev,noexec,relatime)

Note the ``noexec`` flag — you cannot execute files in ``/proc``, which
makes sense since they are not real files.

Per-Process Directories: ``/proc/[PID]``

Every running process has a directory named after its PID:

.. code-block:: console

   $ ls /proc/1/
   attr/        fd/          net/          sessionid
   autogroup    fdinfo/      ns/           setgroups
   auxv         gid_map      numa_maps     smaps
   cgroup       io           oom_adj       stack
   clear_refs   limits       oom_score     stat
   cmdline      loginuid     oom_score_adj status
   comm         map_files/   pagemap       syscall
   coredump_filter  mem      personality  task/
   cpuset       mountinfo    projid_map    timers
   cwd/         mounts       root/         uid_map
   environ      mountstats   sched         wchan
   exe          net/         schedstat

**Key files and directories within ``/proc/[PID]/``:**

.. table:: Important entries in ``/proc/[PID]/``
   :widths: 20 80

   +-------------------+----------------------------------------------------+
   | Entry             | Description                                        |
   +===================+====================================================+
   | ``cmdline``       | The full command line that started the process,    |
   |                   | null-separated. Use ``tr '\0' ' ' < cmdline`` to   |
   |                   | display.                                           |
   +-------------------+----------------------------------------------------+
   | ``cwd``           | A symlink to the process's current working         |
   |                   | directory.                                         |
   +-------------------+----------------------------------------------------+
   | ``environ``       | The process's environment variables, as             |
   |                   | ``KEY=VALUE\0`` pairs. Contains secrets!            |
   +-------------------+----------------------------------------------------+
   | ``exe``           | A symlink to the executable file. You can copy     |
   |                   | this to recover a deleted binary that is still     |
   |                   | running: ``cp /proc/1234/exe /tmp/recovered``.     |
   +-------------------+----------------------------------------------------+
   | ``fd/``           | A directory containing one symlink per open file   |
   |                   | descriptor. ``ls -l /proc/1234/fd/`` shows what    |
   |                   | files the process has open: pipes, sockets,        |
   |                   | regular files.                                     |
   +-------------------+----------------------------------------------------+
   | ``fdinfo/``       | Per-fd flags and positions (for ``lsof``-like      |
   |                   | inspection without elevated privileges).           |
   +-------------------+----------------------------------------------------+
   | ``limits``        | The resource limits (``RLIMIT_*``) for this        |
   |                   | process. Shows soft and hard limits for CPU,       |
   |                   | file size, open files, etc.                        |
   +-------------------+----------------------------------------------------+
   | ``maps``          | Memory-mapped regions (shared libraries, heap,     |
   |                   | stack, anonymous mappings).                        |
   +-------------------+----------------------------------------------------+
   | ``mem``           | Direct access to the process's memory (requires    |
   |                   | ``PTRACE_MODE_ATTACH_FSCREDS`` — essentially root  |
   |                   | or the same user).                                 |
   +-------------------+----------------------------------------------------+
   | ``root/``         | A symlink to the process's root directory (as set  |
   |                   | by ``chroot(2)``). For non-chrooted processes,     |
   |                   | this points to ``/``.                              |
   +-------------------+----------------------------------------------------+
   | ``stat``          | Process state information in machine-parseable     |
   |                   | format. Used by ``ps`` and ``top``.                |
   +-------------------+----------------------------------------------------+
   | ``status``        | Human-readable version of ``stat``. Contains       |
   |                   | Name, State, Pid, PPid, Uid, Gid, FDSize, etc.    |
   +-------------------+----------------------------------------------------+
   | ``task/``         | Directory containing one subdirectory per thread   |
   |                   | (thread ID = TID). This is how the kernel presents |
   |                   | multi-threaded processes.                          |
   +-------------------+----------------------------------------------------+

**Practical exploration:**

.. code-block:: console
   :caption: Exploring your own process via /proc

   # View your shell's command line
   $ cat /proc/$$/cmdline | tr '\0' ' '
   bash

   # View your shell's environment (pipe to less for scrolling)
   $ cat /proc/$$/environ | tr '\0' '\n' | head -5
   SHELL=/bin/bash
   PATH=/usr/local/bin:/usr/bin:/bin
   USER=jdoe
   HOME=/home/jdoe

   # See what files your shell has open
   $ ls -l /proc/$$/fd/
   total 0
   lrwx------ 1 jdoe jdoe 64 Jul 15 12:00 0 -> /dev/pts/0
   lrwx------ 1 jdoe jdoe 64 Jul 15 12:00 1 -> /dev/pts/0
   lrwx------ 1 jdoe jdoe 64 Jul 15 12:00 2 -> /dev/pts/0
   lrwx------ 1 jdoe jdoe 64 Jul 15 12:00 255 -> /dev/pts/0

   # Check resource limits
   $ cat /proc/$$/limits | head -5
   Limit                     Soft Limit           Hard Limit           Units
   Max cpu time              unlimited            unlimited            seconds
   Max file size             unlimited            unlimited            bytes
   Max data size             unlimited            unlimited            bytes
   Max stack size            8388608              unlimited            bytes

System-Wide Information in ``/proc``

Beyond per-process directories, ``/proc`` contains system-level information:

.. table:: Key System-Wide ``/proc`` Entries
   :widths: 25 75

   +----------------------------+--------------------------------------------+
   | Entry                      | Information                                |
   +============================+============================================+
   | ``/proc/cpuinfo``          | Detailed per-CPU information (model,       |
   |                            | cache, flags, MHz, bogomips).              |
   +----------------------------+--------------------------------------------+
   | ``/proc/meminfo``          | Memory statistics (total, free, buffers,   |
   |                            | cached, swap, hugepages).                  |
   +----------------------------+--------------------------------------------+
   | ``/proc/loadavg``          | System load averages (1, 5, 15 min) plus   |
   |                            | running/total processes and last PID.      |
   +----------------------------+--------------------------------------------+
   | ``/proc/uptime``           | Seconds since boot and seconds idle.       |
   +----------------------------+--------------------------------------------+
   | ``/proc/version``          | Linux kernel version, gcc version, and     |
   |                            | build host info.                           |
   +----------------------------+--------------------------------------------+
   | ``/proc/sys/``             | Kernel tunable parameters via sysctl.      |
   |                            | Writing to these files changes runtime     |
   |                            | kernel behaviour (e.g.,                    |
   |                            | ``echo 1 > /proc/sys/net/ipv4/ip_forward``)|
   +----------------------------+--------------------------------------------+
   | ``/proc/net/``             | Network stack status (ARP table, TCP       |
   |                            | connections, routing table, socket stats). |
   +----------------------------+--------------------------------------------+
   | ``/proc/diskstats``        | Disk I/O statistics per device.            |
   +----------------------------+--------------------------------------------+
   | ``/proc/partitions``       | Partition table as seen by the kernel.     |
   +----------------------------+--------------------------------------------+
   | ``/proc/modules``          | Loaded kernel modules.                     |
   +----------------------------+--------------------------------------------+

.. code-block:: console
   :caption: Quick system checks from /proc

   $ head -1 /proc/loadavg
0.32 0.28 1/245 12345

   # Interpretation:
   # 0.45  = 1-minute load average
   # 0.32  = 5-minute load average
   # 0.28  = 15-minute load average
   # 1/245 = 1 running process / 245 total processes/threads
   # 12345 = last PID assigned

   $ head -3 /proc/meminfo
   MemTotal:       16383284 kB
   MemFree:         4234568 kB
   MemAvailable:   10293848 kB

   $ cat /proc/uptime
389102.12
   # 482193 seconds since boot = 5.58 days
   # 389102 seconds idle

.. note::

   Many tools you use daily (``ps``, ``top``, ``free``, ``uptime``,
   ``sysctl``) are essentially **formatted readers of files in /proc**.
   Learning to read ``/proc`` directly helps when these tools are
   unavailable (e.g., in a minimal container or a recovery environment).

The Copy-on-Write (COW) Optimisation
============================================

When we said earlier that ``fork`` creates "a copy" of the parent's memory,
that was a simplification. In reality, modern Linux uses **copy-on-write**
to make ``fork`` extremely efficient:

* After ``fork``, parent and child **share** all physical memory pages,
  marked read-only in the page table.
* When either process tries to **write** to a shared page, the kernel
  catches the page fault, **copies** the page, and gives each process its
  own private copy (with read-write permissions).
* If the child calls ``exec`` immediately — which it almost always does —
  no writes occur, and the kernel saves the enormous cost of duplicating the
  entire address space.

This optimisation is why ``fork`` is so fast on Linux: it only copies
kernel data structures (a few hundred bytes) and creates new page table
entries pointing to the same physical pages. The heavy lifting of memory
duplication is **deferred until actually needed** — and often never happens.

``exec`` Family Variants
================================

The ``exec`` system call has several variants in the C library:

.. table:: The exec Family
   :widths: 15 25 60

   +------------+------------------------+-----------------------------------+
   | Function   | Search PATH?           | Argument passing                  |
   +============+========================+===================================+
   | ``execve`` | No (must supply full   | Array of strings (``argv``) +     |
   |            | path)                  | array of environment.             |
   +------------+------------------------+-----------------------------------+
   | ``execvp`` | Yes                    | Array of strings.                 |
   +------------+------------------------+-----------------------------------+
   | ``execlp`` | Yes                    | Variadic arguments (list)         |
   +------------+------------------------+-----------------------------------+
   | ``execle`` | No                     | Variadic arguments + environment  |
   |            |                        | array.                            |
   +------------+------------------------+-----------------------------------+
   | ``execl``  | No                     | Variadic arguments.               |
   +------------+------------------------+-----------------------------------+

All ``exec`` functions ultimately call ``execve(2)`` — the kernel system
call. The others are library wrappers that handle PATH searching and
argument marshalling.

**The most common scenario: fork + execvp**

.. code-block:: c

   pid_t pid = fork();
   if (pid == 0) {
       execvp("ls", (char *[]){"ls", "-l", NULL});
       // If execvp returns, it failed
       perror("execvp");
       _exit(1);
   } else if (pid > 0) {
       wait(NULL);
   }

Summary
==============

* Processes are created via the **fork/exec** two-step: ``fork`` clones the
  process, ``exec`` transforms it.
* Every process has a **PID** (unique numeric identifier) and a **PPID**
  (parent's PID), forming a strict tree rooted at PID 1.
* Linux processes exist in multiple states: **R** (running/runnable),
  **S** (sleeping), **D** (disk sleep / uninterruptible), **Z** (zombie),
  and **T** (stopped).
* **Zombies** are terminated processes whose exit codes have not been
  collected. They cannot be killed — the parent must ``wait(2)`` for them.
* **Orphans** are reparented to PID 1, which reaps them.
* The ``/proc`` filesystem exposes kernel data as virtual files — every
  running process has a subdirectory ``/proc/[PID]/`` rich with diagnostic
  information.
* **Copy-on-write** (COW) makes ``fork`` efficient by sharing physical
  memory pages until a write occurs.

