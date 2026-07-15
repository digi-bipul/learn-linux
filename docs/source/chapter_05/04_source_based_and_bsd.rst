.. _section-5-4:

================================================
5.4 Source-Based Ecosystems & BSD Ports
================================================

.. rst-class:: lead

   *"If binary packages are restaurants serving pre-cooked meals, source-based
   distributions are the kitchen where you choose every ingredient. The
   result is a system that is uniquely optimized for your hardware, your
   preferences, and your needs — at the cost of the time it takes to cook."*

Binary package managers solve the distribution problem by shipping
pre-compiled code. But pre-compilation imposes a cost: the binaries must
run on the widest possible range of hardware, so they target a generic
baseline (e.g., ``x86-64`` with no specific CPU features). **Source-based
distributions** take the opposite approach: compile everything from source
on the target machine, using compile-time flags that are tuned to the
exact CPU and user preferences.

The most prominent Linux example is **Gentoo** with its **Portage**
system. Outside the Linux world, the **BSD Ports collections** (FreeBSD,
OpenBSD, NetBSD) follow a similar philosophy but with their own unique
design trade-offs.

------------------------------------------------
5.4.1 Gentoo Linux and Portage
------------------------------------------------

Gentoo Linux is a **met distribution** — you configure it from the ground
up. Its package management system, **Portage**, is written in Python and
centered around a tool called ``emerge``. Unlike ``apt`` or ``dnf``, which
install pre-compiled binaries, ``emerge`` downloads source code, applies
patches, compiles it with your chosen options, and installs the result.

5.4.1.1 The Portage Tree and Ebuilds
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The **ebuild** is Portage's fundamental unit. An ebuild is a shell script
(``.ebuild``) that describes how to fetch, configure, compile, and install
a piece of software. The collection of all ebuilds is the **Portage tree**,
typically located at ``/var/db/repos/gentoo`` (formerly ``/usr/portage``).

.. code-block:: bash

   # Example: the structure of an ebuild for nginx
   $ ls /var/db/repos/gentoo/www-servers/nginx/
   nginx-1.24.0.ebuild
   nginx-1.24.0-r1.ebuild
   nginx-1.25.0.ebuild
   metadata.xml
   files/

A typical ebuild (simplified):

.. code-block:: bash
   :linenos:

   # Copyright 2024 Gentoo Authors
   EAPI=8

   DESCRIPTION="Robust, small and high performance http and reverse proxy server"
   HOMEPAGE="https://nginx.org"
   SRC_URI="https://nginx.org/download/${P}.tar.gz"

   LICENSE="BSD-2"
   SLOT="0"
   KEYWORDS="~amd64 ~arm64 ~x86"

   IUSE="ssl http2 http3 pcre libatomic mail"

   DEPEND="
       ssl? ( dev-libs/openssl )
       http2? ( net-libs/nghttp2 )
       pcre? ( dev-libs/libpcre )
   "

   src_configure() {
       local myconf=(
           --prefix=/usr
           --sbin-path=/usr/sbin/nginx
           --conf-path=/etc/nginx/nginx.conf
       )
       use ssl && myconf+=( --with-http_ssl_module )
       use http2 && myconf+=( --with-http_v2_module )
       ./configure "${myconf[@]}" || die "configure failed"
   }

   src_compile() {
       make || die "make failed"
   }

   src_install() {
       make DESTDIR="${D}" install || die "install failed"
   }

Key metadata:

* **EAPI** — The ebuild API version. Determines which features and
  functions are available.
* **IUSE** — **USE flags** (see below) — configurable options that toggle
  features on and off.
* **KEYWORDS** — Architecture support. ``~amd64`` means "testing for
  amd64" (unmasked only with ``ACCEPT_KEYWORDS="~amd64"``). ``amd64``
  (without tilde) means "stable."
* **SLOT** — Allows multiple versions of the same package to coexist
  (e.g., Python 3.10 and 3.11 can be slotted separately).
* **DEPEND** — Build-time and runtime dependencies, with USE-flag
  conditionals.

5.4.1.2 USE Flags: The Heart of Gentoo
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

USE flags are the defining innovation of Gentoo. They are Boolean
variables (on/off) that control optional features at compile time. Instead
of shipping a separate package for ``nginx-with-ssl`` and
``nginx-without-ssl``, a single ebuild handles both via the ``ssl`` USE
flag.

.. code-block:: bash

   # Global USE flags (apply to all packages)
   $ cat /etc/portage/make.conf
   USE="-kde -gnome minimal ssl X wayland pulseaudio -systemd"

   # Per-package USE flags
   $ cat /etc/portage/package.use/nginx
   www-servers/nginx ssl http2 pcre

   # List available USE flags for a package
   $ emerge -pv nginx
   $ equery uses nginx

The effect: a ``USE="-X -gtk -qt5"`` system will compile every package
*without* graphical toolkit support, producing smaller, faster binaries
that consume less memory. A ``USE="systemd"`` system will build with
systemd integration; ``USE="-systemd"`` will use OpenRC or another init.

.. note::

   USE flags propagate through the dependency tree. If you set
   ``USE="ssl"`` globally, every dependency that supports SSL will be
   compiled with SSL support. This is one of Portage's most powerful
   features — and the source of its most complex dependency graphs.

5.4.1.3 ``emerge``: The Portage Frontend
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

   # Synchronize the Portage tree
   $ sudo emerge --sync

   # Install a package (with dependency resolution)
   $ sudo emerge nginx

   # Same, but show what would be compiled (pretend)
   $ sudo emerge -pv nginx

   # Update all packages
   $ sudo emerge --update --deep --newuse @world

   # Remove orphaned dependencies
   $ sudo emerge --depclean

   # See dependency information
   $ emerge -ep nginx           # Dependency tree
   $ emerge -g nginx           # Graphviz output (renders a graph)

   # Search for packages
   $ emerge --search "nginx"

The ``@world`` set is crucial. It comprises:

* All packages listed in ``/var/lib/portage/world`` (user-requested).
* All their recursive dependencies.
* The system set (essential packages).

Running ``emerge --update --deep --newuse @world`` ensures every package
on the system is rebuilt with the latest stable versions and your current
USE flags.

5.4.1.4 ``emerge`` vs. Binary Package Managers
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: emerge vs apt/dnf
   :header-rows: 1

   * - Aspect
     - ``emerge`` (Gentoo)
     - ``apt`` / ``dnf``
   * - Installation model
     - Compile from source
     - Download binary
   * - Configuration
     - USE flags, CFLAGS, per-package overrides
     - None (pre-compiled)
   * - Update time
     - Hours (full recompilation)
     - Minutes (download only)
   * - Binary size
     - Optimized for CPU (e.g., -march=native)
     - Generic (x86-64 baseline)
   * - Dependency tracking
     - Full SAT resolver, USE-flag-aware
     - SAT resolver (dnf) or greedy (apt)
   * - Rollback
     - Manual (no official rollback)
     - Manual

5.4.1.5 Masking and Slots
^^^^^^^^^^^^^^^^^^^^^^^^^^^

Portage has a concept of **masking** — preventing certain packages or
versions from being installed:

* **Hard mask:** ``/etc/portage/profile/package.mask`` — the package is
  invisible to emerge.
* **Accept keywords:** ``/etc/portage/package.accept_keywords`` —
  unmask testing (~amd64) or specific architectures.

.. code-block:: bash

   # Accept a testing version of a specific package
   $ echo "www-servers/nginx ~amd64" >> /etc/portage/package.accept_keywords

**Slotting** allows multiple major versions to coexist:

.. code-block:: bash

   # Python 3.10 and 3.11 are slotted
   $ equery list python
   * Searching for python ...
   [IP-] [  ] dev-lang/python-3.10.13:3.10
   [IP-] [  ] dev-lang/python-3.11.6:3.11

This allows different packages to depend on different Python versions
without conflict — something that is notoriously painful in binary
distributions.

----------------------------------------------
5.4.2 The BSD Ports Collection
----------------------------------------------

The BSD operating systems — FreeBSD, OpenBSD, NetBSD — have their own
package management traditions. Each has a **binary package** system for
quick installation and a **Ports collection** for building from source.

The ports collection is a directory tree of **Makefiles** (not shell
scripts like ebuilds). Each port knows where to download source code,
which patches to apply, and how to compile and install.

5.4.2.1 FreeBSD: ``pkg`` and Ports
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

FreeBSD has two complementary systems:

* ``pkg`` — The modern binary package manager (similar to ``apt`` or
  ``dnf``).
* Ports — The source-based build system (similar to Gentoo's Portage).

.. code-block:: bash

   # Binary package management (pkg)
   $ pkg update
   $ pkg install nginx
   $ pkg upgrade
   $ pkg delete nginx
   $ pkg search nginx
   $ pkg info nginx
   $ pkg which /usr/local/bin/nginx   # Find package owning a file

   # Ports collection (source-based)
   $ cd /usr/ports/www/nginx
   $ make install clean
   $ make deinstall        # Remove
   $ make reinstall        # Remove and reinstall
   $ make config           # Configure compile options (port-specific menu)

FreeBSD ports use **OPTIONS** (a menu-driven configuration system) rather
than Gentoo's USE flags. When you run ``make config`` for the first time
on a port, a ``ncurses`` menu appears where you toggle features on/off.
Your selections are saved to ``/var/db/ports/<portname>/options``.

``make config`` offers the same granularity as USE flags but with a
per-port configuration menu instead of global flags. This is both simpler
(for new users) and more tedious (for system-wide consistency).

5.4.2.2 OpenBSD: ``pkg_add`` and ``pkg_delete``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

OpenBSD's package tools are minimal and opinionated — reflecting the
project's security-first philosophy:

.. code-block:: bash

   # Binary packages
   $ pkg_add nginx
   $ pkg_delete nginx
   $ pkg_info nginx

   # Ports (source-based)
   $ cd /usr/ports/www/nginx
   $ make install

OpenBSD's ports system is notably simpler than FreeBSD's. It does **not**
use a SAT solver — if dependencies cannot be satisfied, the build simply
fails. This is by design: OpenBSD avoids complexity in its base system
to minimize attack surface.

OpenBSD also pioneered **privilege separation** in package building. The
``DPB`` (Distributed Ports Builder) can build packages in a sandboxed
environment, and the ``signify`` cryptographic signing system is used
instead of GPG for package verification.

5.4.2.3 NetBSD: ``pkgsrc``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

NetBSD's ``pkgsrc`` (package source) is unique in that it is
**cross-platform** — it runs on NetBSD, Linux, macOS, Solaris, and many
other Unix-like systems. It is the only BSD ports system designed to be
portable beyond its native OS.

.. code-block:: bash

   # Binary packages
   $ pkg_add nginx

   # Building from pkgsrc
   $ cd /usr/pkgsrc/www/nginx
   $ make install
   $ make clean

   # pkgsrc-specific configuration
   $ echo "PKG_OPTIONS.nginx+= ssl" >> /usr/pkg/etc/mk.conf

Like Gentoo, pkgsrc uses a configuration file (``mk.conf``) for global
and per-package options. It also has a concept called **"bulk builds"**
— the automated recreation of the entire binary package set.

----------------------------------------------
5.4.3 Source-Based vs. Binary: The Trade-Offs
----------------------------------------------

.. list-table:: Source-based vs. binary package management
   :header-rows: 1

   * - Criterion
     - Source-based (Gentoo, BSD Ports)
     - Binary (Debian, Red Hat, Arch)
   * - Installation time
     - Hours to days (initial setup)
     - Minutes
   * - CPU optimization
     - Full (``-march=native``)
     - Generic baseline
   * - Feature selection
     - Per-system (USE flags, OPTIONS)
     - One-size-fits-all binary
   * - Software availability
     - Very broad (compile anything)
     - Broad (must be packaged for your distro)
   * - System consistency
     - Excellent (everything built with same flags)
     - Good (carefully managed dependencies)
   * - Upgrade risk
     - ABI changes require rebuilds
     - Pre-built binaries may break rare edge cases
   * - Learning curve
     - Steep
     - Shallow
   * - Resource usage (compilation)
     - High (CPU, RAM, disk)
     - Low (download only)

**When to use source-based:**

* You need CPU-specific optimizations (HPC, scientific computing, embedded).
* You want fine-grained control over every feature in every package.
* You are building a minimal system and want to exclude all unnecessary
  dependencies.
* You are learning systems programming and want to understand how software
  fits together.

**When to use binary:**

* You need a working system quickly.
* You manage a fleet of machines and want consistent, auditable builds.
* You lack the CPU/RAM budget for compilation.
* You prefer
.. list-table:: Source-based vs. binary package management
   :header-rows: 1

   * - Criterion
     - Source-based (Gentoo, BSD Ports)
     - Binary (Debian, Red Hat, Arch)
   * - Installation time
     - Hours to days (initial setup)
     - Minutes
   * - CPU optimization
     - Full (``-march=native``)
     - Generic baseline
   * - Feature selection
     - Per-system (USE flags, OPTIONS)
     - One-size-fits-all binary
   * - Software availability
     - Very broad (compile anything)
     - Broad (must be packaged for your distro)
   * - System consistency
     - Excellent (everything built with same flags)
     - Good (carefully managed dependencies)
   * - Upgrade risk
     - ABI changes require rebuilds
     - Pre-built binaries may break rare edge cases
   * - Learning curve
     - Steep
     - Shallow
   * - Resource usage (compilation)
     - High (CPU, RAM, disk)
     - Low (download only)

**When to use source-based:**

* You need CPU-specific optimizations (HPC, scientific computing, embedded).
* You want fine-grained control over every feature in every package.
* You are building a minimal system and want to exclude all unnecessary
  dependencies.
* You are learning systems programming and want to understand how software
  fits together.

**When to use binary:**

* You need a working system quickly.
* You manage a fleet of machines and want consistent, auditable builds.
* You lack the CPU/RAM budget for compilation.
* You prefer stability and predictability over micro-optimization.

------------------------------------------------
5.4.4 Summary
------------------------------------------------

Source-based package management represents the ultimate in user control.
Gentoo's Portage, with its USE flags, slots, and powerful dependency
resolver, is the most sophisticated implementation in the Linux world.
The BSD Ports collections offer similar capabilities with different design
choices (Makefiles vs. ebuilds, OPTIONS menus vs. USE flags).

Both approaches share a core philosophy: **the machine that runs the
software should be the machine that compiles it.** This ensures perfect
binary compatibility and optimal performance — but it comes at the cost
of time, resources, and complexity.

In the next section, we explore a radically different approach that
solves many of the problems inherent in both binary and source-based
systems: **functional and declarative package management** with Nix
and GNU Guix.
