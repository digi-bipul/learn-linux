.. _section-4-6:

4.6 Alternative Init Systems: OpenRC & Runit
==================================================

.. rst-class:: lead

   While systemd dominates the Linux landscape, its near-universal adoption
   is not absolute. Two alternative init systems maintain vibrant,
   production-quality communities: **OpenRC** (the default on Alpine Linux,
   Gentoo, and Funtoo) and **Runit** (the default on Void Linux). These
   systems embody fundamentally different design philosophies from systemd
   and from each other. Understanding them is not merely an academic
   exercise — it is essential for anyone who works with containers,
   embedded systems, or Alpine-based infrastructure.

4.6.1 Why Alternatives Exist
===============================

The Linux ecosystem has never accepted a monoculture without debate. The
alternatives to systemd stem from several philosophical positions:

* **The Unix philosophy**: "Do one thing and do it well." systemd is a
  monolithic suite replacing init, logging, cron, nsswitch, hostnamed,
  resolved, timesyncd, and more. Critics argue it violates the Unix
  principle of small, composable tools.
* **Simplicity and auditability**: Shell scripts (OpenRC) or tiny
  compiled binaries (Runit) are easier to review, understand, and patch
  than a million-line C codebase.
* **Resource constraints**: systemd's dependencies (D-Bus, cgroups v2,
  a modern kernel) are burdensome on extremely minimal systems (embedded
  devices, old hardware, busybox-based containers).
* **PID 1 design**: OpenRC explicitly avoids being PID 1 (it runs as a
  normal process), while Runit's PID 1 is a tiny binary that does almost
  nothing — supervision is delegated elsewhere.

.. table:: Init System Comparison
   :widths: 20 25 25 30

   +----------------+---------------------+---------------------+---------------------+
   | Property       | systemd             | OpenRC              | Runit               |
   +================+=====================+=====================+=====================+
   | Language       | C                   | Shell (POSIX sh)    | C                   |
   +----------------+---------------------+---------------------+---------------------+
   | Lines of code  | ~1.5 million        | ~15,000 (scripts)   | ~3,000              |
   +----------------+---------------------+---------------------+---------------------+
   | PID 1          | systemd itself      | ``/sbin/init``      | ``runit-init``      |
   |                |                     | (a tiny C binary    | (tiny, minimal      |
   |                |                     | that hands off to   | PID 1)              |
   |                |                     | OpenRC via ``openrc-|                     |
   |                |                     | init``)             |                     |
   +----------------+---------------------+---------------------+---------------------+
   | Service format | Declarative INI     | Shell scripts       | Executable shell    |
   |                | files (.service)    | (``/etc/init.d/``)  | scripts (``run``)   |
   +----------------+---------------------+---------------------+---------------------+
   | Supervision    | Built-in (cgroups)  | Optional (via       | Built-in (runsv,    |
   |                |                     | ``supervise-daemon``| a dedicated daemon  |
   |                |                     | or separate tools)  | per service)        |
   +----------------+---------------------+---------------------+---------------------+
   | Dependency     | Declarative in      | Declarative via     | Not built-in (rely  |
   | resolution     | ``[Unit]`` section  | shell variables     | on directory        |
   |                |                     | (``need``,          | structure and       |
   |                |                     | ``use``, ``after``) | scripts)            |
   +----------------+---------------------+---------------------+---------------------+
   | Logging        | journald (binary)   | Syslog (text)       | Syslog (text)       |
   +----------------+---------------------+---------------------+---------------------+
   | Primary distros| Debian, Ubuntu,     | **Alpine**, Gentoo, | **Void**, antiX,    |
   |                | RHEL, Fedora, Arch, | Funtoo             | some BSDs           |
   |                | SUSE, Pop!_OS       |                     |                     |
   +----------------+---------------------+---------------------+---------------------+

4.6.2 OpenRC — Dependency-Based, Script-Driven Init
======================================================

OpenRC is the init system used by **Alpine Linux** (the most popular
container base image on Docker Hub), Gentoo, and Funtoo. Its core design
decisions are:

1. **It is not PID 1**. On Alpine, ``/sbin/init`` is OpenRC's ``openrc-init``
   — a tiny C binary that performs minimal PID 1 duties (reaping orphans,
   handling signals like Ctrl+Alt+Del) and then immediately hands control to
   the OpenRC runlevel system via a shell process.
2. **It is script-driven**. Init scripts are POSIX shell scripts in
   ``/etc/init.d/``. They are easy to read, write, and debug.
3. **Dependencies are explicit**. Scripts declare what they ``need``,
   ``use``, or run ``before``/``after``.
4. **Runlevels are directories**. Instead of numbered symlinks, OpenRC uses
   named runlevels (``boot``, ``default``, ``shutdown``, ``sysinit``).
5. **Service state is tracked via files** in ``/var/run/openrc/`` or
   ``/run/openrc/`` (no database, no binary journal).

4.6.2.1 OpenRC Directory Structure

.. code-block:: text

   /etc/init.d/                  # Init scripts for services
   /etc/init.d/sshd              # Example: SSH daemon script

   /etc/runlevels/               # Runlevel directories (contain symlinks)
   /etc/runlevels/boot/          # Services started at boot (hwclock, sysfs, etc.)
   /etc/runlevels/default/       # Normal multi-user services (sshd, cron, etc.)
   /etc/runlevels/sysinit/       # Single-user / system initialization
   /etc/runlevels/shutdown/      # Services stopped on shutdown
   /etc/runlevels/nonetwork/     # Rescue-like runlevel without networking

   /etc/conf.d/                  # Configuration files for init scripts
   /etc/conf.d/sshd              # SSH daemon config (e.g., SSH_OPTIONS)

4.6.2.2 Managing Services with ``rc-update`` and ``rc-service``

**``rc-update`` — adding/removing services from runlevels:**

.. code-block:: console
   :caption: ``rc-update`` — managing runlevel membership

   # Add sshd to the default runlevel (starts at boot)
   # rc-update add sshd default

   # Behind the scenes:
   # This creates a symlink:
   #   /etc/runlevels/default/sshd -> /etc/init.d/sshd

   # Remove sshd from the default runlevel
   # rc-update del sshd default

   # List all services in all runlevels
   # rc-update show
   #         boot |        default |      sysinit |     shutdown
   #    ----------+----------------+--------------+--------------
   #       acpid |         chronyd |         hwdr |
   #       bootmisc|        crond   |            |
   #       hwclock |        sshd    |            |
   #       ...

   # Add a service to multiple runlevels
   # rc-update add nginx default

**``rc-service`` — starting/stopping individual services:**

.. code-block:: console
   :caption: ``rc-service`` — managing service state

   # Start a service (runs /etc/init.d/sshd start)
   # rc-service sshd start

   # Stop a service
   # rc-service sshd stop

   # Restart
   # rc-service sshd restart

   # Status
   # rc-service sshd status

   # Reload configuration
   # rc-service sshd reload

**The direct equivalent — calling init scripts directly:**

.. code-block:: console

   # This is exactly equivalent to rc-service sshd start:
   # /etc/init.d/sshd start

Because init scripts are shell scripts, you can also do:

.. code-block:: console

   # /etc/init.d/sshd --help
   # /etc/init.d/sshd zap          # Reset service state (force stop tracking)
   # /etc/init.d/sshd clean        # Clean any stale PID files

4.6.2.3 Anatomy of an OpenRC Init Script

OpenRC init scripts are shell scripts that define a small set of variables
and functions. Here is a representative example:

.. code-block:: shell
   :caption: ``/etc/init.d/sshd`` (simplified) — OpenRC init script

   #!/sbin/openrc-run

   name="OpenBSD Secure Shell server"
   description="SSH daemon for remote login"

   command="/usr/sbin/sshd"
   command_args="-D"
   pidfile="/run/sshd.pid"
   command_user="sshd:sshd"

   depend() {
       need net
       use dns logger
   }

   # Optional: custom start/stop functions (if more than just running
   # the command is needed)
   start_pre() {
       checkpath --directory --owner sshd:sshd --mode 0750 /run/sshd
   }

**Key components explained:**

.. list-table:: OpenRC Init Script Elements
   :widths: 25 75

   * - ``#!/sbin/openrc-run``
     - The script interpreter. ``openrc-run`` is a shell function library
       that provides ``start``, ``stop``, ``status``, etc.
   * - ``command=``
     - The daemon binary to run (absolute path).
   * - ``command_args=``
     - Arguments passed to the binary. ``-D`` means "stay in foreground."
   * - ``pidfile=``
     - PID file path. OpenRC uses this to track the process.
   * - ``command_user=``
     - Drop privileges to this user:group before running the command.
   * - ``depend()``
     - Declares dependencies:
       * ``need net`` — the ``net`` service is required.
       * ``use dns logger`` — if DNS or logging is available, start them
         before this service, but they are not required.
   * - ``start_pre()``
     - A function that runs before the service starts. Here it ensures the
       runtime directory exists with correct permissions.

**Configuration variables from ``/etc/conf.d/``:**

Services can source configuration from ``/etc/conf.d/``:

.. code-block:: shell
   :caption: ``/etc/conf.d/sshd`` — configuration for the sshd service

   # Command line arguments for sshd
   SSH_OPTIONS="-D -p 2222"

   # Additional environment variables
   SSH_EXTRA_ENV="LOG_LEVEL=VERBOSE"

The init script picks these up automatically because ``openrc-run`` sources
``/etc/conf.d/$RC_SVCNAME`` before running the service.

4.6.2.4 Dependency Pragmas in OpenRC

The ``depend()`` function supports these keywords:

.. table:: OpenRC Dependency Keywords
   :widths: 20 80

   +-----------------+-----------------------------------------------------+
   | Keyword         | Meaning                                             |
   +=================+=====================================================+
   | ``need``        | Hard dependency. The listed service(s) **must**     |
   |                 | start before this one. If they fail, this fails.    |
   +-----------------+-----------------------------------------------------+
   | ``use``         | Soft dependency. If the listed service is configured |
   |                 | for this runlevel, start it first. No failure if    |
   |                 | absent.                                             |
   +-----------------+-----------------------------------------------------+
   | ``after``       | Ordering only. This service starts after the listed |
   |                 | one, but no dependency relationship.                |
   +-----------------+-----------------------------------------------------+
   | ``before``      | This service starts before the listed one.          |
   +-----------------+-----------------------------------------------------+
   | ``provide``     | This service provides a virtual service name        |
   |                 | (e.g., ``provide mysql`` — multiple implementations |
   |                 | of "mysql" can satisfy a ``need``).                 |
   +-----------------+-----------------------------------------------------+

4.6.2.5 OpenRC on Alpine Linux — Practical Notes

Alpine Linux is the most widely encountered OpenRC system (it is the default
base image for Docker containers). The key commands differ slightly:

.. code-block:: console

   # Alpine uses these commands (note: no leading 'rc-' prefix)
   # rc-update add sshd default
   # rc-service sshd start
   # rc-status          # Show current runlevel and service states

   # Check the default runlevel
   $ rc-status default

   # Debug a service that won't start
   $ rc-service sshd status
   $ rc-service sshd -v start   # Verbose mode

   # View OpenRC's boot log
   $ cat /var/log/messages | grep rc

**OpenRC's service supervision (optional):**

OpenRC does **not** supervise services by default. If a daemon crashes,
it stays dead. To add supervision, use the ``supervise-daemon`` wrapper:

.. code-block:: shell
   :caption: Using ``supervise-daemon`` for auto-restart

   # In /etc/init.d/myapp:
   command="/usr/bin/myapp"
   supervise_daemon="myapp"
   command_args="--foreground"

   # This wraps the daemon in a supervisor that restarts it
   # if it crashes (similar to Runit's supervision model).

4.6.3 Runit — Extreme Minimalism
====================================

Runit is a **cross-platform init and service supervision system** designed
by Gerrit Pape for Unix-like systems. It is the default init system on
**Void Linux** and is also used on some BSD systems and as a replacement
for systemd on minimal installations.

The guiding philosophy of Runit:

* **One program, one responsibility**: Runit consists of several small,
  independent binaries (``runit-init``, ``runsvdir``, ``runsv``,
  ``sv``, ``chpst``, ``utmpset``).
* **Supervision is fundamental**: Every service runs under a ``runsv``
  supervisor that automatically restarts it if it dies — *without* any
  configuration. This is a design feature, not an optional add-on.
* **Extreme speed**: Runit starts services in parallel and with minimal
  overhead. Boot times are measured in milliseconds.
* **PID 1 is tiny**: ``runit-init`` (PID 1) only handles signal
  propagation, orphan reaping, and executing ``runit`` (the stage
  manager). It does not manage services.

4.6.3.1 Runit Architecture

.. code-block:: text

   PID 1: runit-init
   ├─ Runs /etc/runit/1       (Stage 1: system initialization)
   ├─ Runs /etc/runit/2       (Stage 2: runsvdir — the supervisor)
   └─ Waits for /etc/runit/3  (Stage 3: shutdown)

   Stage 2 (runsvdir) monitors /etc/sv/ and /var/service/:
   /etc/sv/sshd/               # Service directory for SSH
       ├── run                 # Executable shell script (the daemon)
       ├── finish              # (optional) Runs after daemon exits
       ├── supervise/          # Runtime state (created automatically)
       └── log/                # (optional) Log service sub-directory
           └── run             # Runs multilog/tai64n for log capture

**The service directory:**

Every service in Runit is a **directory** containing at minimum an
executable ``run`` script. That's it. No configuration file, no variable
declarations, no dependencies — just a script.

4.6.3.2 Writing a Runit Service

.. code-block:: bash
   :caption: ``/etc/sv/sshd/run`` — a Runit service script

   #!/bin/sh
   exec /usr/sbin/sshd -D 2>&1

**Critical details:**

* ``exec`` is used to replace the shell process with the daemon — this
  ensures the supervisor tracks the correct PID.
* The daemon must run in the **foreground** (``-D`` flag for sshd).
  Backgrounding (forking) defeats supervision.
* The script is executed fresh each time the service starts (or restarts).

**An optional ``finish`` script:**

.. code-block:: bash
   :caption: ``/etc/sv/sshd/finish`` — runs after the service exits

   #!/bin/sh
   # Exit code of the daemon is in $1
   # If finish returns non-zero, the service is NOT restarted
   echo "sshd exited with code $1 at $(date)" >> /var/log/sshd-finish.log
   exit 0

If the ``finish`` script exits with code 0, ``runsv`` restarts the service.
If it exits with a non-zero code, the service stays stopped (prevents
restart loops).

**The ``log/`` subdirectory (optional, for logging):**

.. code-block:: bash
   :caption: ``/etc/sv/sshd/log/run`` — separate log service

   #!/bin/sh
   exec svlogd -tt /var/log/sshd

``svlogd`` is Runit's log daemon — it reads from stdin and writes to a
rotating set of files in the specified directory. The ``-tt`` option
prepends timestamps.

4.6.3.3 Managing Services with ``sv``

The ``sv(1)`` command controls all Runit services:

.. code-block:: console
   :caption: ``sv`` — service control

   # Start a service
   # sv up sshd

   # Stop a service
   # sv down sshd

   # Restart
   # sv restart sshd

   # Status
   $ sv status sshd
   run: sshd: (pid 1234) 3600s

   # Other status outputs:
   # run:   service is running
   # down:  service is stopped
   # want up:   will be started (pending)
   # want down: will be stopped (pending)

   # Reload (send SIGHUP)
   # sv reload sshd

   # Check if a service is running (exit code 0 = running)
   $ sv check sshd
   ok: run

   # Force stop (send SIGKILL immediately)
   # sv force-stop sshd

   # Send a custom signal
   # sv -USR1 sshd     # Send SIGUSR1

**Enabling a service at boot:**

Runit runs ``runsvdir`` on ``/etc/service/`` (or ``/var/service/`` on some
systems). To enable a service, create a symlink from the service directory
into this directory:

.. code-block:: console

   # ln -s /etc/sv/sshd /etc/service/sshd
   # runsvdir will immediately start sshd

   # To disable (remove from /etc/service without deleting /etc/sv/sshd):
   # rm /etc/service/sshd
   # sv down sshd

4.6.3.4 Runit on Void Linux

Void Linux uses Runit by default. Key paths:

.. code-block:: text

   /etc/sv/                 # All available service directories
   /var/service/            # Enabled services (symlinks to /etc/sv/)
   /etc/runit/              # Stage scripts (1, 2, 3)

**Void-specific commands:**

.. code-block:: console

   # Enable a service
   # ln -s /etc/sv/sshd /var/service/
   # (immediately starts)

   # Disable
   # rm /var/service/sshd
   # sv down sshd

   # List all services
   $ ls /var/service/

   # Reboot
   # shutdown -r now
   # or:          # sv force-quit runsvdir && init 6

4.6.4 When to Choose OpenRC or Runit over systemd
====================================================

.. table:: Decision Guide
   :widths: 30 35 35

   +---------------------------+-------------------------------+------------------------------+
   | Use Case                 | Recommended Init              | Rationale                    |
   +===========================+===============================+==============================+
   | Container base image      | **OpenRC** (Alpine) or none   | Alpine's 5 MB base image     |
   | (Docker, podman, LXC)     |                               | with OpenRC is the standard. |
   |                           |                               | Runit also works well.       |
   +---------------------------+-------------------------------+------------------------------+
   | Embedded system with      | **OpenRC** or **Runit**       | systemd has heavy deps       |
   | minimal resources         |                               | (D-Bus, udev, etc.).         |
   | (64 MB RAM, older CPU)    |                               | OpenRC scripts are minimal.  |
   +---------------------------+-------------------------------+------------------------------+
   | Personal Gentoo/Funtoo    | **OpenRC**                    | Gentoo's native init.        |
   | installation              |                               | Script-driven, transparent.  |
   +---------------------------+-------------------------------+------------------------------+
   | Hardened minimal desktop  | **Runit** (Void)              | Runit's supervision model is |
   | or server                 |                               | robust yet minimal.          |
   +---------------------------+-------------------------------+------------------------------+
   | Enterprise datacenter,    | **systemd**                   | Standardisation, logging,    |
   | multi-admin team,         |                               | auditing, cgroups,           |
   | compliance requirements   |                               | widespread documentation.    |
   +---------------------------+-------------------------------+------------------------------+
   | Learning init internals   | **OpenRC**                    | Shell scripts are            |
   | for study                 |                               | transparent and easy to      |
   |                           |                               | trace.                       |
   +---------------------------+-------------------------------+------------------------------+

4.6.5 Summary
==============

* **OpenRC** is a dependency-based, script-driven init system used by Alpine
  Linux and Gentoo. It is **not PID 1** — PID 1 is a small C binary that
  delegates to OpenRC.
* OpenRC services are shell scripts in ``/etc/init.d/`` with
  ``depend()`` functions for dependency resolution.
* Runlevels are directories (``/etc/runlevels/default/``) containing
  symlinks to init scripts.
* ``rc-update add/del`` manages runlevel membership;
  ``rc-service start/stop/restart`` manages service state.
* **Runit** is an extreme-minimalist supervision-based init system default
  on Void Linux.
* Every Runit service is a directory (``/etc/sv/sshd/``) containing an
  executable ``run`` script. That is all that is required.
* ``runsv`` automatically restarts any service that exits (supervision
  is built-in, not optional).
* The ``sv`` command controls services (``sv up/down/status/restart``).
* Both OpenRC and Runit use traditional syslog for logging (not a binary
  journal), and both are significantly smaller and more auditable than
  systemd.

