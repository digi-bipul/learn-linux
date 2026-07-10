.. _filesystem-hierarchy:

The Linux Filesystem Hierarchy
==============================

If the terminal is your cockpit, the filesystem is the landscape you
fly over.  Understanding its layout — *why* each directory exists,
*what* belongs where — is foundational knowledge that separates a
mechanically competent user from someone who truly understands the
system.

This section is guided by the **Filesystem Hierarchy Standard (FHS)**,
currently at version 3.0, maintained by the Linux Foundation.  Most
distributions adhere to it; where they diverge, we flag the differences
explicitly.

.. contents::
   :local:
   :depth: 1


The Single Tree: Everything Starts at ``/``
---------------------------------------------

Linux organises **all** files — every disk partition, every USB stick,
every network share — under a single, unified hierarchy whose root is
the forward slash: ``/`` (pronounced "root").

.. code-block:: text

   /
   ├── bin -> usr/bin
   ├── boot
   ├── dev
   ├── etc
   ├── home
   │   ├── alice
   │   │   ├── Documents
   │   │   ├── Downloads
   │   │   └── .bashrc
   │   └── bob
   ├── lib -> usr/lib
   ├── media
   ├── mnt
   ├── opt
   ├── proc
   ├── root
   ├── run
   ├── sbin -> usr/sbin
   ├── srv
   ├── sys
   ├── tmp
   ├── usr
   │   ├── bin
   │   ├── lib
   │   ├── local
   │   ├── sbin
   │   └── share
   └── var
       ├── log
       ├── spool
       └── tmp

This is not an arbitrary mess.  Every directory has a specific role,
rooted in decades of Unix evolution.

.. warning::

   On most modern distributions (Debian ≥10, Ubuntu ≥20.04, Fedora ≥33,
   Arch, openSUSE), ``/bin``, ``/sbin``, and ``/lib`` are **symbolic
   links** to their counterparts under ``/usr``.  This is called the
   **``/usr`` merge** (``usrmerge``).  Alpine Linux and some minimal
   systems may still have separate ``/bin`` and ``/usr/bin``.  The
   distinction is largely transparent, but it explains why you see
   ``bin -> usr/bin`` in the tree above.


The Root-Level Directories, Explained
---------------------------------------

.. rubric:: ``/bin`` — Essential User Binaries (→ ``/usr/bin``)

Historically, ``/bin`` held commands needed to boot the system and
repair it in single-user mode (e.g., ``ls``, ``cp``, ``cat``, ``sh``).
After the ``/usr`` merge, ``/bin`` is typically a symlink to
``/usr/bin``.  All general-purpose executables now live together.

.. code-block:: console

   $ ls /bin
   bash  cat  cp  dash  dd  df  echo  grep  gzip  less  ln  ls  mkdir ...

.. rubric:: ``/sbin`` — System Binaries (→ ``/usr/sbin``)

Commands intended for system administration: ``fdisk``, ``fsck``,
``mkfs``, ``iptables``, ``ss``, ``sysctl``.  These often require root
privileges.  After ``usrmerge``, ``/sbin`` → ``/usr/sbin``.

.. code-block:: console

   $ ls /sbin
   fdisk  fsck  ifconfig  iptables  mkfs  reboot  shutdown  sysctl ...

.. rubric:: ``/boot`` — The Boot Loader's Files

Everything needed to start the system *before* the kernel takes full
control: the kernel image itself (``vmlinuz-*``), the initial RAM disk
(``initrd.img-*`` or ``initramfs-*``), and the bootloader configuration
(``grub/`` or ``efi/``).

.. code-block:: console

   $ ls /boot
   config-6.1.0-25-amd64
   initrd.img-6.1.0-25-amd64
   System.map-6.1.0-25-amd64
   vmlinuz-6.1.0-25-amd64
   grub/

.. warning::

   Never casually delete files from ``/boot``.  A missing kernel image
   means an unbootable system.

.. rubric:: ``/dev`` — Device Files

A virtual filesystem populated by the kernel.  Every hardware device
(and many pseudo-devices) appears as a file:

.. list-table::
   :header-rows: 1

   * - Path
     - What It Represents
   * - ``/dev/sda``
     - First SCSI/SATA disk
   * - ``/dev/sda1``
     - First partition on the first disk
   * - ``/dev/nvme0n1``
     - First NVMe SSD
   * - ``/dev/tty``
     - The current terminal
   * - ``/dev/null``
     - The "bit bucket" — data written here is discarded
   * - ``/dev/zero``
     - An endless stream of zero bytes
   * - ``/dev/random``, ``/dev/urandom``
     - Kernel random number generators

.. code-block:: console

   $ echo "This disappears" > /dev/null
   $ cat /dev/null
   (no output — the data is gone)

.. rubric:: ``/etc`` — Host-Specific Configuration

The nerve centre of system configuration.  Pronounced "et-see" (not
"ee-tee-see").  ``/etc`` contains plain-text configuration files —
never binaries.  The name comes from "et cetera," a historical dumping
ground that evolved into the standard location for config files.

.. code-block:: console

   $ ls /etc
   passwd      # user account info
   shadow      # hashed passwords (root-only readable)
   group       # group definitions
   hosts       # static hostname-to-IP mappings
   hostname    # the machine's hostname
   resolv.conf # DNS resolver configuration
   fstab       # filesystem mount table
   ssh/        # SSH server and client configuration
   systemd/    # systemd service definitions
   apt/        # Debian/Ubuntu package manager config
   apk/        # Alpine package manager config

.. tip::

   The ``/etc`` directory is version-control-friendly.  Professionals
   often keep ``/etc`` in a Git repository (using tools like ``etckeeper``)
   so every configuration change is tracked and reversible.

.. rubric:: ``/home`` — User Home Directories

Each regular user gets a personal directory under ``/home``:

.. code-block:: text

   /home/alice/     — Alice's files, configs, documents
   /home/bob/       — Bob's files, configs, documents

A user's home directory contains their personal files (``Documents/``,
``Downloads/``, ``Pictures/``) and their per-user configuration files,
which are hidden (names starting with a dot):

.. code-block:: console

   $ ls -a ~
   .bashrc        # Bash configuration
   .bash_history  # Command history
   .config/       # XDG config directory (many apps store settings here)
   .local/        # XDG local data directory
   .ssh/          # SSH keys and known hosts
   .gitconfig     # Git configuration

The tilde (``~``) always expands to the current user's home directory.
``~bob`` expands to Bob's home directory.

.. rubric:: ``/lib`` — Essential Shared Libraries (→ ``/usr/lib``)

Shared libraries (``.so`` files) and kernel modules.  After ``usrmerge``,
``/lib`` → ``/usr/lib``.

.. code-block:: console

   $ ls /lib/x86_64-linux-gnu/ | head -5
   ld-linux-x86-64.so.2    # the dynamic linker/loader
   libc.so.6               # the C library (glibc)
   libpthread.so.0         # POSIX threads
   libdl.so.2              # dynamic linking
   libm.so.6               # math library

.. rubric:: ``/media`` and ``/mnt`` — Mount Points

Both are directories where *other* filesystems are attached (mounted)
into the main tree:

.. describe:: ``/media``

   Automatic mount points for removable media — USB drives, CD-ROMs,
   SD cards.  The desktop environment typically creates subdirectories
   here automatically when you plug in a device:

   .. code-block:: console

      $ ls /media/alice/
      KINGSTON_USB/    # a USB stick was auto-mounted here

.. describe:: ``/mnt``

   A generic, temporary mount point for manual use by the system
   administrator.  If you need to mount a disk temporarily to recover
   files, ``/mnt`` is the conventional place:

   .. code-block:: console

      $ sudo mount /dev/sdb1 /mnt
      $ ls /mnt
      (contents of the external disk)
      $ sudo umount /mnt

.. rubric:: ``/opt`` — Optional / Third-Party Software

Self-contained, third-party application bundles that are not managed by
the distribution's package manager.  Examples: Google Chrome, MATLAB,
VMware Tools, some proprietary VPN clients.  Each application typically
gets its own subdirectory:

.. code-block:: console

   $ ls /opt
   google/    chrome/    matlab/    zoom/

Installing software into ``/opt`` keeps it isolated from the
distribution-managed files under ``/usr``.

.. rubric:: ``/proc`` — Process and Kernel Information (Virtual)

``/proc`` is a **pseudo-filesystem**: nothing inside it exists on disk.
The kernel generates its contents on the fly when you read them.  It
exposes runtime information about processes, hardware, and kernel
parameters.

.. code-block:: console

   $ cat /proc/cpuinfo       # CPU details
   $ cat /proc/meminfo       # Memory usage statistics
   $ cat /proc/version       # Kernel version string
   $ cat /proc/uptime        # Seconds since boot (two numbers)
   $ ls /proc/$$/            # Info about the current shell process
   $ cat /proc/$$/status     # Human-readable process status

Each running process has a directory named after its PID:

.. code-block:: console

   $ echo $$
   1847                      # the PID of the current shell
   $ ls /proc/1847/
   cmdline  cwd  environ  exe  fd  maps  mounts  root  status  ...

.. rubric:: ``/root`` — The Root User's Home Directory

The superuser's home.  This is *not* under ``/home`` because ``/home``
might be on a separate partition that could fail to mount, and the root
user must always be able to log in.  ``/root`` lives on the root
filesystem.

.. rubric:: ``/run`` — Runtime Variable Data (tmpfs)

A temporary filesystem (``tmpfs``) stored in RAM.  It holds data that is
only valid until the next reboot: PID files, socket files, lock files,
and system state.  ``/run`` replaced the older ``/var/run`` (which is now
a symlink to ``/run`` on most systems).

.. code-block:: console

   $ ls /run
   user/       # per-user runtime directories
   systemd/    # systemd runtime data
   sshd.pid    # PID file for the SSH daemon
   utmp        # record of currently logged-in users

.. rubric:: ``/srv`` — Service Data

Data served by the system: web server document roots, FTP files, version
control repositories.  Many administrators ignore ``/srv`` and place
service data under ``/var`` instead; both conventions are valid.

.. code-block:: console

   $ ls /srv
   www/        # web server content
   ftp/        # anonymous FTP files
   git/        # Git repositories

.. rubric:: ``/sys`` — Kernel and Device Information (Virtual)

Like ``/proc``, ``/sys`` (sysfs) is a pseudo-filesystem exposing kernel
objects — devices, buses, drivers, power management — in a structured
hierarchy.  It is primarily used by hardware management tools and device
drivers.

.. code-block:: console

   $ ls /sys/class/          # device classes: block, net, tty, ...
   $ ls /sys/block/sda/      # info about the first disk
   $ cat /sys/class/net/eth0/address   # MAC address of eth0

.. rubric:: ``/tmp`` — Temporary Files

A world-writable scratch space.  Any user can create files here.  Files
in ``/tmp`` may be deleted on reboot (depending on distribution
configuration).  Never store anything important in ``/tmp``.

.. code-block:: console

   $ echo "temporary data" > /tmp/my_temp_file
   $ cat /tmp/my_temp_file
   temporary data
   # After reboot, the file is likely gone.

.. rubric:: ``/usr`` — User System Resources (Shareable, Read-Only)

Despite the name, ``/usr`` has nothing to do with "user" in the sense of
home directories.  It stands for **Unix System Resources**.  ``/usr``
is the largest directory on most systems and contains all read-only,
shareable data:

.. list-table::
   :header-rows: 1

   * - Subdirectory
     - Contents
   * - ``/usr/bin``
     - The vast majority of user commands (``python3``, ``git``,
       ``vim``, ``gcc``, ``ssh``, ``man``, etc.)
   * - ``/usr/sbin``
     - System administration commands not needed for boot
   * - ``/usr/lib``
     - Libraries, and often package-specific data
   * - ``/usr/share``
     - Architecture-independent data: documentation, fonts, icons,
       locale data, man pages
   * - ``/usr/local``
     - Locally compiled/installed software, separate from the package
       manager.  Mirrors the ``/usr`` structure internally
       (``/usr/local/bin``, ``/usr/local/lib``, etc.)
   * - ``/usr/include``
     - C/C++ header files for development
   * - ``/usr/src``
     - Source code, notably kernel source if installed

The ``/usr/local`` hierarchy deserves special mention.  When you compile
software from source and run ``make install``, the default prefix is
``/usr/local``.  This cleanly separates distribution-managed software
(``/usr/bin``) from software you built yourself (``/usr/local/bin``).

.. rubric:: ``/var`` — Variable Data

Files that are expected to grow, change, or accumulate over time: logs,
caches, spool directories, databases, and websites.

.. list-table::
   :header-rows: 1

   * - Subdirectory
     - Contents
   * - ``/var/log``
     - System and application log files
   * - ``/var/spool``
     - Queued jobs: print spools, mail queues, cron jobs
   * - ``/var/cache``
     - Application cache data (e.g., ``/var/cache/apt/`` for Debian)
   * - ``/var/lib``
     - Persistent application state (e.g., ``/var/lib/docker/``,
       ``/var/lib/mysql/``)
   * - ``/var/tmp``
     - Like ``/tmp``, but preserved across reboots


Distro-Specific Differences
-----------------------------

.. rubric:: Debian / Ubuntu

Strict FHS compliance.  ``/bin`` → ``/usr/bin`` symlink (since Debian
10).  Package manager cache lives at ``/var/cache/apt/``.

.. rubric:: Fedora / RHEL / Rocky / Alma

FHS-compliant with ``usrmerge``.  Package manager cache lives at
``/var/cache/dnf/``.  RHEL-family systems use ``/etc/sysconfig/`` for
many network and service configuration files — a convention unique to
this family.

.. rubric:: Arch Linux

Arch completed ``usrmerge`` very early (2012).  Arch does *not* use
``/etc/default/`` for service defaults; it favours editing the service
files directly or using drop-in overrides.

.. rubric:: Alpine Linux

The most divergent layout among mainstream distributions:

* ``/bin`` and ``/usr/bin`` may be **separate** (no ``usrmerge``).
* ``/bin`` typically contains **BusyBox** applet symlinks.
* GNU coreutils are *not* installed by default; commands like ``ls``
  and ``cp`` are the BusyBox versions.
* ``/etc/apk/`` holds the package manager configuration.
* ``/etc/init.d/`` holds OpenRC service scripts (instead of systemd unit
  files).

Despite these differences, the FHS principles still apply: ``/etc`` for
config, ``/var/log`` for logs, ``/home`` for user data, etc.


Navigating the Tree Mentally
------------------------------

When you encounter an unfamiliar file, ask:

1. **Is it configuration?** → ``/etc/``
2. **Is it a log?** → ``/var/log/``
3. **Is it an executable?** → ``/usr/bin/`` or ``/usr/sbin/``
4. **Is it a user's personal file?** → ``/home/<user>/``
5. **Is it temporary?** → ``/tmp/`` or ``/var/tmp/``
6. **Is it kernel/runtime information?** → ``/proc/`` or ``/sys/``

This mental model, combined with a few navigation commands we cover
next, will let you orient yourself on any Linux system in seconds.
