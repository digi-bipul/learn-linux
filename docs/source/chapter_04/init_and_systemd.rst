.. _section-4-4:

Initialization Archetypes & systemd Architecture
====================================================

.. rst-class:: lead

   When the Linux kernel finishes booting, it executes the **init** process
   (PID 1) — the ancestor of every other process on the system. The design
   of PID 1 determines how services start, stop, and interact; how
   dependencies are resolved; and how the system shuts down. Over Linux's
   three-decade history, three distinct init philosophies have emerged:
   **SysV init** (sequential shell scripts), **systemd** (event-driven,
   parallelised), and **minimalist alternatives** (OpenRC, Runit).

   This section focuses on systemd — its architecture, design philosophy,
   and unit types — while contrasting it with the older SysV model it
   replaced.

The Historical Evolution of PID 1
=========================================

.. table:: Major Init Systems in Linux History
   :widths: 15 30 55

   +------------+---------------------+--------------------------------------+
   | Years      | Init System         | Characteristics                      |
   +============+=====================+======================================+
   | 1991–2000  | SysV init (System V | Sequential startup of shell scripts  |
   |            | Unix style)         | in numbered order (``/etc/rc.d/``).  |
   |            |                     | Simple but slow — each service waits |
   |            |                     | for the previous to finish.          |
   +------------+---------------------+--------------------------------------+
   | 2000–2010  | SysV variants       | Improvisations on the same theme:    |
   |            | (Debian's file-rc,  | parallel boot, LSB headers,          |
   |            | Gentoo's baselayout,| dependency information in comments.  |
   |            | LSB init scripts)   | Still fundamentally script-driven.   |
   +------------+---------------------+--------------------------------------+
   | 2010–2012  | Upstart (Ubuntu)    | Event-driven init by Canonical.      |
   |            |                     | "Jobs" triggered by events. Smarter  |
   |            |                     | than SysV but ultimately abandoned   |
   |            |                     | in favour of systemd.                |
   +------------+---------------------+--------------------------------------+
   | 2012–present| systemd            | Event-driven, parallel, socket-aware, |
   |            | (Lennart Poettering | cgroup-integrated, binary unit files. |
   |            | & Red Hat)          | Adopted by Fedora first, then most   |
   |            |                     | major distributions.                  |
   +------------+---------------------+--------------------------------------+
   | 2004–present| OpenRC (Gentoo,    | Dependency-based, script-driven init, |
   |            | Alpine, Funtoo,     | **not PID 1**. Uses a supervisor     |
   |            | Sabayon)            | (supervise-daemon or other) for      |
   |            |                     | process monitoring. Shell-script     |
   |            |                     | based, explicit dependency trees.    |
   +------------+---------------------+--------------------------------------+
   | 2001–present| Runit (Void,       | Extreme minimalism. PID 1 runs       |
   |            | antiX, -based)      | ``runit-init``; services are         |
   |            |                     | supervised by ``runsvdir``. Every     |
   |            |                     | service is a directory with an       |
   |            |                     | executable ``run`` script.           |
   +------------+---------------------+--------------------------------------+

systemd's Design Philosophy
====================================

systemd is not *just* an init system — it is a **comprehensive system and
service manager** that replaces the traditional SysV init model with a
coherent, integrated set of tools. Its design principles are:

1. **Parallelisation**: systemd analyses unit dependencies and starts
   independent services **simultaneously**, dramatically reducing boot time.
   SysV init started services one-by-one in a fixed sequence.

2. **Socket Activation**: systemd can listen on sockets (network ports,
   Unix sockets) on behalf of a service. When a connection arrives, systemd
   starts the service and hands it the socket. This means services can be
   started **on demand** — they don't need to be running all the time.

3. **On-Demand Activation**: Beyond sockets, systemd can start services
   based on D-Bus messages (bus activation), device insertion, file path
   access, or timer events.

4. **Unified Logging**: The **journal** (``systemd-journald``) collects
   log output from all services, structured metadata, and kernel messages
   into a single, indexed, binary log.

5. **Cgroup Integration**: systemd tracks processes in **control groups**
   (cgroups), providing reliable process lifecycle tracking — when a
   service stops, systemd can guarantee that all its child processes are
   cleaned up (eliminating "zombie daemon" problems).

6. **Declarative Configuration**: Instead of shell scripts, systemd uses
   **unit files** — declarative INI-style configuration files that specify
   what a service does, how it starts, what its dependencies are, and how it
   should be restarted.

The SysV Model (Brief Contrast)
========================================

To understand why systemd was created, one must appreciate the limitations
of SysV init:

**SysV init directory structure:**

.. code-block:: text

   /etc/init.d/           # Contains the actual init scripts (e.g., /etc/init.d/nginx)
   /etc/rc0.d/            # Runlevel 0 (shutdown)
   /etc/rc1.d/            # Runlevel 1 (single-user mode)
   /etc/rc2.d/            # Runlevel 2 (multi-user, no GUI — Debian)
   /etc/rc3.d/            # Runlevel 3 (multi-user, no GUI — RHEL)
   /etc/rc4.d/            # Runlevel 4 (custom)
   /etc/rc5.d/            # Runlevel 5 (multi-user with GUI)
   /etc/rc6.d/            # Runlevel 6 (reboot)

Each ``rcX.d`` directory contains symlinks to scripts in ``/etc/init.d/``:

.. code-block:: text

   S01rsyslog -> ../init.d/rsyslog    # S = start, 01 = order
   S02dbus   -> ../init.d/dbus
   S10network -> ../init.d/network
   K01nginx  -> ../init.d/nginx      # K = kill (stop)

**Problems with SysV init:**

* **Sequential**: ``S01`` must finish before ``S02`` starts.
* **Shell-script fragility**: A buggy init script (syntax error, infinite
  loop, missing ``$remote_fs``) can break the entire boot sequence.
* **No dependency resolution**: The ordering was manual and fragile.
  "LSB headers" (comments like ``# Required-Start: $network $syslog``)
  were a later attempt to add dependency info, but they were comments —
  nothing enforced them.
* **No supervision**: If a daemon crashed, SysV init did not restart it.
* **Process tracking**: When a SysV script started a daemon, the shell
  script often forked multiple processes, and tracking which processes
  belonged to which service was difficult.

systemd Units — The Core Abstraction
=============================================

In systemd, everything is a **unit**. A unit is a resource that systemd
knows how to manage. There are several types:

.. table:: systemd Unit Types
   :widths: 15 25 60

   +---------+---------------------+------------------------------------------+
   | Type    | File Extension       | Managed Resource                         |
   +=========+=====================+==========================================+
   | Service | ``.service``         | A daemon, server, or background process  |
   |         |                     | (nginx, sshd, cron, etc.).               |
   +---------+---------------------+------------------------------------------+
   | Socket  | ``.socket``          | A network socket or Unix socket that     |
   |         |                     | systemd listens on. Used for socket      |
   |         |                     | activation.                              |
   +---------+---------------------+------------------------------------------+
   | Timer   | ``.timer``           | A timed event that triggers a service    |
   |         |                     | (replaces cron). Monotonic or calendar-  |
   |         |                     | based.                                   |
   +---------+---------------------+------------------------------------------+
   | Mount   | ``.mount``           | A filesystem mount point (replaces       |
   |         |                     | ``/etc/fstab`` entries for systemd-      |
   |         |                     | managed mounts).                         |
   +---------+---------------------+------------------------------------------+
   | Automount| ``.automount``      | An on-demand mount point. The filesystem |
   |         |                     | is mounted only when first accessed.     |
   +---------+---------------------+------------------------------------------+
   | Target  | ``.target``          | A synchronisation point that groups      |
   |         |                     | other units. Replaces runlevels.         |
   |         |                     | Examples: ``multi-user.target``,         |
   |         |                     | ``graphical.target``, ``reboot.target``. |
   +---------+---------------------+------------------------------------------+
   | Path    | ``.path``            | Monitors a file or directory for changes |
   |         |                     | (inotify) and starts a service when      |
   |         |                     | the path is modified.                    |
   +---------+---------------------+------------------------------------------+
   | Device  | ``.device``          | A hardware device (kernel device object, |
   |         |                     | managed by udev/systemd).                |
   +---------+---------------------+------------------------------------------+
   | Scope   | ``.scope``           | Externally created groups of processes   |
   |         |                     | (used by user sessions, containers).     |
   +---------+---------------------+------------------------------------------+
   | Slice   | ``.slice``           | A hierarchical group of units for        |
   |         |                     | resource management (cgroups).           |
   |         |                     | ``system.slice``, ``user.slice``,        |
   |         |                     | ``machine.slice``.                       |
   +---------+---------------------+------------------------------------------+
   | Swap    | ``.swap``            | A swap device or file.                   |
   +---------+---------------------+------------------------------------------+

**Unit file locations (in precedence order):**

.. code-block:: text

   /etc/systemd/system/            # Local administrator overrides (highest priority)
   /run/systemd/system/            # Runtime units (generated by tools, lost on reboot)
   /usr/lib/systemd/system/        # Distribution-provided units (package manager)

**The rule of thumb:** Never edit files in ``/usr/lib/systemd/system/``
directly. Package updates will overwrite them. Instead, use:

1. ``systemctl edit UNIT`` — creates an override drop-in in
   ``/etc/systemd/system/UNIT.d/override.conf``.
2. ``systemctl mask UNIT`` — creates a symlink to ``/dev/null`` that
   completely disables a unit.
3. Copy the unit file to ``/etc/systemd/system/`` and modify there.

Targets — Replacements for Runlevels
============================================

SysV runlevels (0–6) are replaced by **targets** in systemd:

.. table:: SysV Runlevels vs. systemd Targets
   :widths: 15 25 60

   +---------------+----------------------------+------------------------------+
   | SysV Runlevel | systemd Target             | Purpose                      |
   +===============+============================+==============================+
   | 0             | ``poweroff.target``        | Shutdown                     |
   +---------------+----------------------------+------------------------------+
   | 1 (S)         | ``rescue.target``          | Single-user (emergency       |
   |               |                            | shell, no networking).       |
   +---------------+----------------------------+------------------------------+
   | 2, 3, 4       | ``multi-user.target``      | Multi-user, text mode,       |
   |               |                            | all services running.        |
   +---------------+----------------------------+------------------------------+
   | 5             | ``graphical.target``       | Multi-user with GUI.         |
   |               |                            | Pulls in ``multi-user.target``|
   |               |                            | plus display manager.        |
   +---------------+----------------------------+------------------------------+
   | 6             | ``reboot.target``          | Reboot                       |
   +---------------+----------------------------+------------------------------+
   | N/A           | ``emergency.target``       | Minimal emergency shell      |
   |               |                            | (root fs read-only, no       |
   |               |                            | networking, not even syslog).|
   +---------------+----------------------------+------------------------------+

**Viewing and switching targets:**

.. code-block:: console

   # View the current default target
   $ systemctl get-default
   multi-user.target

   # Set the default target (e.g., boot to text mode)
   # systemctl set-default multi-user.target

   # View all loaded targets and their units
   $ systemctl list-units --type=target

   # Switch to a different target right now (isolate)
   # systemctl isolate rescue.target

   # View dependencies of a target
   $ systemctl list-dependencies multi-user.target

.. note::

   ``systemctl isolate`` replaces all currently running units with the
   requested target's units. It is analogous to ``init 3`` in SysV.
   Use it carefully — ``systemctl isolate graphical.target`` will start
   your display manager.

systemd's Service Architecture
=======================================

When a service starts under systemd:

.. code-block:: text

   1. systemd reads the .service unit file.
   2. systemd resolves dependencies (Wants, Requires, After, Before).
   3. systemd creates a cgroup for the service process(es).
   4. systemd forks and execs the service (using the specified
      ExecStart, working directory, user, environment, etc.).
   5. systemd monitors the service's main PID.
   6. If the service exits, systemd applies the Restart= policy.
   7. On stop, systemd sends SIGTERM, then (after timeout) SIGKILL,
      and kills the entire cgroup (all descendant processes).

**Key service states:**

.. code-block:: text

   systemctl status nginx
   ● nginx.service - A high performance web server and a reverse proxy server
        Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
        Active: active (running) since Wed 2026-07-15 12:00:00 UTC; 2h 30min ago
          Docs: man:nginx(8)
       Process: 1234 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
       Process: 1235 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
      Main PID: 1236 (nginx)
         Tasks: 3 (limit: 1131)
        Memory: 8.2M
           CPU: 150ms
        CGroup: /system.slice/nginx.service
                ├─1236 nginx: master process /usr/sbin/nginx -g daemon on; master_process on
                ├─1237 nginx: worker process
                └─1238 nginx: worker process

**Active state meanings:**

.. table:: systemd Unit Active States
   :widths: 20 80

   +---------------------+---------------------------------------------------+
   | State               | Meaning                                           |
   +=====================+===================================================+
   | ``active (running)``| The service is currently running.                 |
   +---------------------+---------------------------------------------------+
   | ``active (exited)`` | The service completed successfully and exited.    |
   |                     | Used for one-shot tasks (e.g., filesystem check). |
   +---------------------+---------------------------------------------------+
   | ``active (waiting)``| The service is running but waiting for an event   |
   |                     | (e.g., a socket unit waiting for a connection).   |
   +---------------------+---------------------------------------------------+
   | ``inactive``        | The service is not running.                       |
   +---------------------+---------------------------------------------------+
   | ``failed``          | The service has failed (exit code != 0, or        |
   |                     | terminated by signal).                             |
   +---------------------+---------------------------------------------------+

Socket Activation
==========================

One of systemd's most powerful features: systemd can listen on a socket
*before* the service is running, and start the service on demand when a
connection arrives.

**How it works:**

.. code-block:: text

   1. systemd creates and binds the socket (defined in a .socket unit).
   2. systemd monitors the socket for incoming connections.
   3. When a connection arrives, systemd starts the corresponding
      .service unit.
   4. systemd passes the socket file descriptor to the service via
      the filesystem (the ``sd_listen_fds`` mechanism).
   5. The service accepts the connection and serves it.

**Benefits:**

* Services that are rarely used (e.g., ``sshd`` on a personal machine) are
  not running until someone actually tries to connect.
* Parallel boot: systemd can start listening on sockets while the service
  is still loading, meaning incoming connections are **never lost** during
  boot — they queue up until the service is ready.
* Dependencies can be resolved via sockets: if service A requires service B,
  but B's socket can be opened before B starts, A can be activated in
  parallel.

**Example — SSH socket activation:**

.. code-block:: console

   # Check if SSH uses socket activation
   $ systemctl list-units --type=socket
   sshd.socket              loaded active   listening  OpenSSH Server Socket

   # If socket-activated, the service stops when idle
   $ systemctl status sshd.service
   ● sshd.service - OpenSSH server (multi-session)
        Active: inactive (dead)
          Triggers: ● sshd.socket

   # A connection triggers the service
   $ ssh localhost
   # Now sshd.service becomes active, handles the connection

   # After the last connection closes, systemd stops sshd again
   # (if configured to do so)

Timers — Replacing Cron (Covered in Detail in Section 4.8)
====================================================================

systemd timers (``.timer`` units) provide cron-like functionality with
several advantages:

* **Failure handling**: systemd records whether the triggered service
  succeeded or failed.
* **Dependencies**: Timers can depend on network availability, other
  timers, or system state.
* **Monotonic timers**: "Run 30 minutes after boot" or "Run 15 minutes
  after the previous run finished" (not possible with cron).
* **Calendar-based timers**: Same as cron, but more readable (``Mon..Fri``
  instead of ``1-5``).
* **Persistent timers**: "Catch up" on missed runs if the system was off.

The ``systemctl`` Command — Central Control
====================================================

``systemctl`` is the primary control interface for systemd:

.. code-block:: console
   :caption: Essential ``systemctl`` commands

   # Service management
   systemctl start nginx
   systemctl stop nginx
   systemctl restart nginx
   systemctl reload nginx          # Sends SIGHUP (if supported)
   systemctl status nginx          # Show detailed status
   systemctl is-active nginx       # Returns "active" or "inactive"
   systemctl is-enabled nginx      # Returns "enabled" or "disabled"
   systemctl is-failed nginx       # Returns "failed" or "active"

   # Enable/disable (start automatically at boot)
   systemctl enable nginx          # Creates symlinks in .wants/
   systemctl disable nginx         # Removes symlinks
   systemctl enable --now nginx    # Enable AND start (common pattern)
   systemctl disable --now nginx   # Disable AND stop

   # Override and masking
   systemctl edit nginx            # Create drop-in override
   systemctl edit --full nginx     # Edit the full unit file
   systemctl mask nginx            # Completely disable (symlink to /dev/null)
   systemctl unmask nginx          # Re-enable

   # System state
   systemctl list-units            # Show loaded units
   systemctl list-units --type=service --state=running
   systemctl list-unit-files       # Show all installed unit files
   systemctl list-dependencies multi-user.target

   # Power management
   systemctl reboot
   systemctl poweroff
   systemctl suspend
   systemctl hibernate
   systemctl hybrid-sleep

Summary
===============

* PID 1 is the ancestor of all processes. Modern Linux distributions
  overwhelmingly use **systemd** as PID 1.
* systemd replaces SysV init's sequential shell scripts with
  **declarative unit files**, **parallel startup**, **socket activation**,
  **cgroup-based tracking**, and **unified logging**.
* systemd units are configuration files ending in ``.service``,
  ``.socket``, ``.timer``, ``.mount``, ``.target``, ``.path``, etc.
* **Targets** replace runlevels (``multi-user.target``, ``graphical.target``).
* **Socket activation** allows services to be started on demand without
  losing incoming connections.
* The ``systemctl`` command manages all aspects of systemd — starting,
  stopping, enabling, masking, and inspecting units.
* Custom unit files go in ``/etc/systemd/system/``; distribution units live
  in ``/usr/lib/systemd/system/``.

