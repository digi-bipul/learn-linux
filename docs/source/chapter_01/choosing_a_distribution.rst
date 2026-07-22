.. _choosing-a-distribution:

Choosing a Distribution
=======================

Walk into a "distro" conversation unprepared, and you will encounter a
dizzying alphabet soup: Debian, Ubuntu, Fedora, RHEL, CentOS Stream,
Rocky, Alma, Arch, Manjaro, EndeavourOS, openSUSE, Alpine, Gentoo,
Slackware, NixOS, Void, and dozens more.  Newcomers often freeze at this
point, convinced they must pick the "right" one or risk disaster.

Relax.  The differences between distributions are real and important, but
they are also *superficial* in one crucial sense: Linux is Linux.  The
skills you learn on one distribution transfer almost entirely to every
other.  This section gives you a framework for choosing wisely.

.. contents::
   :local:
   :depth: 1


What Makes Distributions Different?
------------------------------------

Four axes define most of the variation:

.. glossary::

   Package Manager
      The tool that installs, updates, removes, and queries software.
      Different package managers use different package formats, different
      dependency-resolution algorithms, and different repositories.

      .. list-table::
         :header-rows: 1

         * - Distribution Family
           - Package Manager
           - Package Format
         * - Debian / Ubuntu / Mint
           - ``apt``, ``apt-get``
           - ``.deb``
         * - RHEL / Fedora / Rocky / Alma
           - ``dnf`` (``yum`` on older)
           - ``.rpm``
         * - Arch / Manjaro / EndeavourOS
           - ``pacman``
           - ``.pkg.tar.zst``
         * - openSUSE
           - ``zypper``
           - ``.rpm``
         * - Alpine
           - ``apk``
           - ``.apk``
         * - Gentoo
           - ``emerge`` (Portage)
           - source (ebuild)
         * - Void
           - ``xbps``
           - ``.xbps``
         * - NixOS
           - ``nix``
           - ``.nix`` (derivation)
         * - Slackware
           - ``slackpkg``
           - ``.txz``

   Init System
      The first process launched by the kernel (PID 1).  It is
      responsible for starting, stopping, and supervising all other
      services.

      .. list-table::
         :header-rows: 1

         * - Init System
           - Used By
         * - ``systemd``
           - Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, most others
         * - ``OpenRC``
           - Alpine, Gentoo (default)
         * - ``runit``
           - Void (default option)
         * - ``SysV init`` + scripts
           - Slackware, older Debian (legacy)

      ``systemd`` is the de-facto standard, used by well over 90% of
      Linux deployments today.  It does far more than launch services:
      it manages logging (journald), network naming, timers, mount
      points, and container isolation.  Alternatives like OpenRC and
      runit are simpler, smaller, and favoured in minimalist or
      embedded contexts.

   C Library (libc)
      The fundamental library that sits between every userspace program
      and the kernel.  It provides ``printf``, ``malloc``, ``fopen``,
      and hundreds of other standard C functions.

      .. list-table::
         :header-rows: 1

         * - libc
           - Used By
         * - ``glibc`` (GNU C Library)
           - Debian, Ubuntu, Fedora, RHEL, Arch, openSUSE, Gentoo, Void
             (glibc edition)
         * - ``musl``
           - Alpine, Void (musl edition), minimal/embedded systems

      ``musl`` is smaller, simpler, and sometimes faster than ``glibc``,
      but some proprietary software (and a handful of open-source
      programs) assume ``glibc``-specific behaviour and may not work
      correctly on ``musl``-based systems without patches.

   Release Model
      .. describe:: Fixed / Point Release

         The distribution ships a major version (e.g., Ubuntu 24.04,
         Debian 12 "Bookworm") and provides security updates for several
         years.  Software versions stay largely frozen; you get stability
         and predictability.  Upgrading to the next major version is a
         discrete, sometimes disruptive event.

      .. describe:: Rolling Release

         There is no "version number" of the distribution.  Software
         updates arrive continuously as upstream projects release them.
         You always run the latest kernel, the latest desktop, the latest
         libraries.  The trade-off is that things occasionally break, and
         you must stay vigilant.


The Major Families: A Field Guide
-----------------------------------

.. rubric:: Debian and Its Children (Ubuntu, Mint, Pop!_OS, Kali, Raspberry Pi OS)

**Debian** is one of the oldest, most conservative, and most respected
distributions.  It prioritises stability and free-software purity above
all else.  Debian's "Stable" branch is the gold standard for servers that
must never, ever break.

**Ubuntu**, launched in 2004 by Canonical Ltd., took Debian's foundation
and added polish, a predictable release cadence (every six months, with
Long-Term Support releases every two years), and a more pragmatic stance
on proprietary drivers and codecs.  Ubuntu is the most widely used
desktop Linux distribution and a common choice for cloud instances.

**Linux Mint** layers additional user-friendliness on top of Ubuntu,
offering the Cinnamon desktop and a curated software manager.  It is an
excellent first distribution for Windows migrants.

.. tip::

   If you are brand new, **Ubuntu** or **Linux Mint** are the safest
   starting points.  They have the largest communities, the most Google
   results for error messages, and the widest third-party software
   support.

.. rubric:: The Red Hat Family (Fedora, RHEL, CentOS Stream, Rocky, Alma)

**Fedora** is the upstream, community-driven distribution sponsored by
Red Hat.  It is a showcase for the newest open-source technologies;
Fedora often ships kernel versions, compiler versions, and desktop
environments months before anyone else.  It uses ``dnf`` and is a
**fixed release** with a new version roughly every six months.

**Red Hat Enterprise Linux (RHEL)** is Fedora's commercial downstream.
Red Hat takes Fedora releases, stabilises them, backports security fixes
for 10+ years, and sells support subscriptions to enterprises.  RHEL is
the standard operating system of corporate data centres.

After Red Hat discontinued CentOS Linux (the free RHEL clone), two
community-driven successors emerged: **Rocky Linux** and **AlmaLinux**.
Both aim to be bug-for-bug compatible with RHEL, free of charge.

.. rubric:: Arch Linux (and Manjaro, EndeavourOS)

**Arch** is a minimalist, rolling-release distribution aimed at
competent users who want full control.  It follows the **KISS principle**
(Keep It Simple, Stupid): the base system is tiny, and you build upward
by explicitly installing only what you need.  Arch's **ArchWiki** is
widely regarded as the finest Linux documentation in existence.

**Manjaro** and **EndeavourOS** wrap Arch in a more accessible
installer and pre-configured desktop, making the rolling-release model
approachable for less experienced users.

.. rubric:: openSUSE (Leap and Tumbleweed)

**openSUSE** offers two editions: **Leap** (fixed release, sharing a
common base with SUSE Linux Enterprise) and **Tumbleweed** (rolling
release, continuously updated).  openSUSE's unique contribution is
**YaST** (Yet another Setup Tool), a comprehensive system configuration
utility, and the **Open Build Service (OBS)**, which allows anyone to
build packages for multiple distributions.

.. rubric:: Alpine Linux

**Alpine** is a security-oriented, resource-minimal distribution
designed for containers, embedded devices, and routers.  It replaces
``glibc`` with ``musl`` and GNU coreutils with ``BusyBox``, resulting in
a base installation of roughly **5 MB**.  Alpine is the most common
base image for Docker containers precisely because of this tiny
footprint.

Alpine uses ``apk`` as its package manager and **OpenRC** as its init
system.  If you are following along on a resource-constrained machine or
inside a container, Alpine is an excellent teacher of "minimal" Linux.

.. warning::

   Because Alpine uses ``musl`` instead of ``glibc``, some pre-compiled
   binaries (e.g., certain proprietary software, or Python wheels with C
   extensions) may fail to run.  Always check compatibility before
   deploying Alpine in a production role that depends on third-party
   binaries.


How to Choose: A Decision Framework
------------------------------------

Answer these four questions in order:

1. **What is your goal?**
   * *Learning Linux deeply* → Arch, Gentoo, or Linux From Scratch.
   * *Daily desktop use* → Ubuntu, Linux Mint, or Fedora.
   * *Server administration career* → RHEL (or Rocky/Alma) or Debian.
   * *Containers / embedded* → Alpine.

2. **How much hand-holding do you want?**
   * *Lots* → Ubuntu, Linux Mint, Pop!_OS.
   * *Moderate* → Fedora, openSUSE, Manjaro.
   * *Minimal* → Debian, Arch, Alpine.

3. **Stability or freshness?**
   * *Stability* → Debian Stable, Ubuntu LTS, RHEL/Rocky/Alma.
   * *Freshness* → Fedora, Arch, openSUSE Tumbleweed.

4. **Community size matters.**
   Larger communities mean more tutorials, more forum posts, and faster
   answers when you get stuck.  Ubuntu and Debian have the largest
   communities by a wide margin.

.. rubric:: My Recommendation for This Book

This book is designed to work with **any** distribution.  Where commands
differ between families, we will explicitly call out the Debian/Ubuntu
way (``apt``), the RHEL/Fedora way (``dnf``), the Arch way (``pacman``),
and the Alpine way (``apk``).  If you are following along interactively,
pick one of the following three paths:

.. list-table:: Recommended Starting Distributions
   :header-rows: 1
   :widths: 20 30 50

   * - Path
     - Distribution
     - Best For
   * - **Beginner Desktop**
     - Ubuntu 24.04 LTS or Linux Mint 22
     - Users who want a graphical desktop, large community, and minimal
       friction.  Install via a GUI installer; everything "just works."
   * - **Beginner Server / Textbook**
     - Debian 12 "Bookworm" (stable)
     - Users who want a clean, minimal server environment.  Excellent
       for following along with this book on a virtual machine or VPS.
   * - **Minimalist / Container**
     - Alpine Linux (latest stable)
     - Users comfortable with a command-line-only environment who want
       to understand a non-GNU, non-systemd Linux system from the
       inside.

If you do not yet have a Linux machine, you can use:

* A **virtual machine** (VirtualBox, QEMU/KVM, VMware, UTM on macOS).
* **Windows Subsystem for Linux (WSL2)** on Windows.
* A cheap **VPS** (DigitalOcean, Linode, Hetzner, Vultr) — often $5/month.
* A **Raspberry Pi** running Raspberry Pi OS (Debian-based).


Chapter Summary
---------------

.. admonition:: The One Rule of Choosing a Distro

   **The best distribution is the one you actually install and use.**

   Analysis paralysis is the only wrong choice.  Install Ubuntu or
   Debian today, and you can always switch — or, better yet,
   multi-boot — later.  The command line, the filesystem, and the
   kernel are fundamentally the same everywhere.

With a distribution selected (or at least understood), we are ready to
take the first practical step: opening a terminal.
