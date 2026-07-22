.. _section-5-3:

5.3 Rolling Release & Minimalist Managers
==================================================

.. rst-class:: lead

   *"There are two philosophies of software distribution: freeze the world
   and ship it, or ride the tide of upstream development forever. The
   rolling release model chooses the latter, and its package managers are
   built to surf that wave."*

Traditional distributions like Debian and RHEL follow a **point-release**
model: a stable version is frozen, tested, and supported for years.
Rolling-release distributions take the opposite approach — packages flow
into the repository as soon as they are ready, and the system is upgraded
continuously.

This section examines two iconic rolling-release package
managers: Arch Linux's ``pacman`` and Alpine Linux's ``apk``.

------------------------------------------------
5.3.1 Arch Linux: ``pacman`` and the AUR
------------------------------------------------

Arch Linux is the quintessential rolling-release distribution. Its
package manager, ``pacman`` (short for "package manager"), is known for
its simplicity, speed, and elegant design. Unlike ``apt`` or ``dnf``,
which separate low-level and high-level tools, ``pacman`` is a single
binary that handles everything — from repository synchronization to
dependency resolution to filesystem operations.

5.3.1.1 ``pacman``: Command Structure
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Every ``pacman`` operation is invoked with a top-level flag that selects
the operation mode:

.. code-block:: bash

   # Synchronize (repository operations)
   $ sudo pacman -Sy        # Refresh package database only
   $ sudo pacman -Su        # Upgrade all packages
   $ sudo pacman -Syu       # Refresh AND upgrade (always use this, not -Sy alone)
   $ sudo pacman -S nginx   # Install a package

   # Remove
   $ sudo pacman -R nginx        # Remove package only
   $ sudo pacman -Rs nginx       # Remove package + its dependencies
   $ sudo pacman -Rns nginx      # Remove package + deps + config files

   # Query
   $ pacman -Q                     # List all installed packages
   $ pacman -Q nginx              # Check if installed, show version
   $ pacman -Qo /usr/bin/nginx     # Find which package owns a file
   $ pacman -Ql nginx              # List files owned by a package
   $ pacman -Qi nginx              # Show detailed package info

   # Search
   $ pacman -Ss "web server"       # Search repositories
   $ pacman -Qs nginx              # Search installed packages

   # Files database (optional, download with pacman -Fy)
   $ pacman -F /usr/bin/nginx      # Find which package provides a file
   $ pacman -Fx nginx              # Search file names in packages

Flags are mnemonic:

* ``-S`` = Synchronize (install/update from repositories)
* ``-R`` = Remove
* ``-Q`` = Query (the local database)
* ``-F`` = Files (query the file database)
* ``-U`` = Upgrade from a local package file (``.pkg.tar.zst``)
* ``-y`` = Refresh package databases
* ``-u`` = Upgrade all system packages
* ``-s`` = Search (with ``-S``, ``-Q``) or remove dependencies (with ``-R``)
* ``-i`` = Info (detailed view)
* ``-l`` = List files
* ``-o`` = Owner of a file
* ``-c`` = Clean package cache (``pacman -Sc``, ``pacman -Scc``)

.. important::

   Never run ``pacman -Sy`` followed by ``pacman -S <package>`` without
   also running ``-Su``. Doing so can lead to **partial upgrades** —
   a state where the package database is newer than the installed packages,
   which can break library dependencies and render the system unstable.
   Always use ``pacman -Syu`` to synchronize, update, and then install.

5.3.1.2 Packages and the Arch Build System
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Arch packages are ``.pkg.tar.zst`` files — essentially a tarball
compressed with ``zstd``. The package contains the compiled binaries plus
``.PKGINFO`` (metadata) and ``.INSTALL`` (optional install scripts).

The Arch Build System (ABS) is the framework for building these packages.
Every official package is built from a ``PKGBUILD`` file — a shell script
that describes how to download, compile, and package the software.

5.3.1.3 The Arch User Repository (AUR)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The **Arch User Repository (AUR)** is the defining feature of the Arch
ecosystem. It is a community-driven repository of ``PKGBUILD`` files —
not pre-built packages, but **recipes** that tell your machine how to
build a package from source. Anyone can submit a ``PKGBUILD``; the
community votes on quality, and the most popular packages may eventually
be promoted to the official ``[community]`` repository.

Anatomy of a PKGBUILD
^^^^^^^^^^^^^^^^^^^^^

Here is a simplified ``PKGBUILD`` for ``ripgrep`` (``rg``), a recursive
text search tool:

.. code-block:: bash
   :linenos:

   # Maintainer: Andrew Gallant <jamslam@gmail.com>
   pkgname=ripgrep
   pkgver=14.1.0
   pkgrel=1
   pkgdesc="A search tool that combines the usability of ag with raw speed"
   arch=('x86_64')
   url="https://github.com/BurntSushi/ripgrep"
   license=('MIT' 'Unlicense')
   depends=('gcc-libs' 'glibc')
   makedepends=('cargo')
   source=("https://github.com/BurntSushi/ripgrep/archive/$pkgver.tar.gz")
   sha256sums=('...')

   build() {
       cd "$srcdir/$pkgname-$pkgver"
       cargo build --release --features 'pcre2'
   }

   package() {
       cd "$srcdir/$pkgname-$pkgver"
       install -Dm755 target/release/rg "$pkgdir/usr/bin/rg"
       install -Dm644 doc/rg.1 "$pkgdir/usr/share/man/man1/rg.1"
   }

Key variables:

* ``pkgname``, ``pkgver``, ``pkgrel`` — Package identity.
* ``pkgdesc`` — Human-readable description.
* ``arch`` — Target architectures (``x86_64``, ``aarch64``, ``any``).
* ``depends`` — Runtime dependencies (package names).
* ``makedepends`` — Build-time dependencies (e.g., ``cargo`` for Rust
  projects, ``cmake``, ``python``).
* ``source`` — URLs to download (tarballs, git repos).
* ``sha256sums`` — Integrity verification hashes.
* ``build()`` — The compilation phase (runs in ``$srcdir``).
* ``package()`` — The installation phase (copies files to ``$pkgdir``,
  which becomes the root of the package archive).

The workflow::

   $ makepkg -si
   # -s : install dependencies automatically
   # -i : install the resulting package after building

   $ makepkg -c   # clean build directory after completion
   $ makepkg -o   # download and extract sources only (no compilation)

AUR helpers
^^^^^^^^^^^

Manually cloning AUR repositories and running ``makepkg`` is educational
but tedious. AUR **helpers** automate the process. The most popular are:

* ``yay`` (Yet Another Yogurt) — "yay -S package" works just like
  ``pacman`` but searches the AUR as well.
* ``paru`` — Written in Rust, modern replacement for ``yay``.
* ``trizen`` — Perl-based.

.. code-block:: bash

   # Using yay
   $ yay -S google-chrome        # Build and install from AUR
   $ yay -Syu                    # Update official and AUR packages
   $ yay -Ss package             # Search both AUR and official repos

.. caution::

   AUR packages are **user-submitted and not vetted** by Arch maintainers.
   Always inspect the ``PKGBUILD`` before building:

   .. code-block:: bash

      $ git clone https://aur.archlinux.org/google-chrome.git
      $ cd google-chrome
      $ less PKGBUILD
      $ makepkg -si

   The Arch wiki's "AUR Trusted User (TU)" system provides some quality
   control, but ultimately the responsibility is yours.

5.3.1.4 ``pacman`` Cache and Database
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

   # Package cache location
   $ ls /var/cache/pacman/pkg/
   nginx-1.24.0-1-x86_64.pkg.tar.zst
   openssl-3.0.8-2-x86_64.pkg.tar.zst
   ...

   # Clean old packages (keeps the latest 3 versions by default)
   $ sudo pacman -Sc

   # Clean ALL cached packages
   $ sudo pacman -Scc

   # Restore a downgraded package from cache
   $ sudo pacman -U /var/cache/pacman/pkg/nginx-1.22.0-1-x86_64.pkg.tar.zst

   # Database location
   $ ls /var/lib/pacman/local/   # Information about installed packages
   $ ls /var/lib/pacman/sync/    # Repository database snapshots

------------------------------------------------
5.3.2 Alpine Linux: ``apk``
------------------------------------------------

Alpine Linux is a security-oriented, lightweight Linux distribution based
on **musl libc** and **BusyBox**. Its package manager is ``apk`` (the
Alpine Package Keeper). Alpine is famous for being the default base image
in Docker — a typical Alpine Docker image is under 10 MB.

5.3.2.1 ``apk``: Design Philosophy
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``apk`` is a single binary (like ``pacman``) that handles all package
operations. Its output is deliberately terse — no progress bars, minimal
verbosity. This makes it ideal for scripts, containers, and automated
environments.

.. code-block:: bash

   # Repository configuration
   $ cat /etc/apk/repositories
   https://dl-cdn.alpinelinux.org/alpine/v3.19/main
   https://dl-cdn.alpinelinux.org/alpine/v3.19/community

   # Update package index
   $ apk update

   # Install a package
   $ apk add nginx

   # Upgrade all packages
   $ apk upgrade

   # Remove a package
   $ apk del nginx

   # List installed packages
   $ apk list --installed

   # Search for a package
   $ apk search "nginx"

   # Show package info
   $ apk info nginx

   # Show what package owns a file
   $ apk info --who-owns /usr/bin/nginx

5.3.2.2 Dependencies and Virtual Packages
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``apk`` uses a **smarter dependency solver** than traditional tools. It
has built-in support for:

* **Virtual packages** — A named group of packages that can be installed
  or removed as a unit. For example, ``gnome`` is a virtual package that
  depends on all core GNOME components.
* **Package providers** — If multiple packages provide the same
  functionality (e.g., ``openssh`` and ``dropbear`` both provide
  ``ssh-server``), ``apk`` can handle the choice declaratively.
* **World file** — ``/etc/apk/world`` lists the packages the user
  explicitly requested (as opposed to dependencies pulled in
  automatically). This is how ``apk`` tracks what to keep when
  dependencies change.

.. code-block:: bash

   # View the world file
   $ cat /etc/apk/world
   nginx
   openssl
   alpine-base

   # Adding a package adds it to the world
   $ apk add vim
   $ cat /etc/apk/world
   nginx
   openssl
   alpine-base
   vim

   # Removing a package removes it from the world
   # Orphaned dependencies are automatically cleaned up
   $ apk del vim

This "world" approach is reminiscent of Gentoo's ``world`` file (Section
5.4) and is a precursor to the **declarative** model that Nix takes to
its logical extreme (Section 5.5).

5.3.2.3 ``abuild``: Building Alpine Packages
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Alpine's package build system is called ``abuild``. Like ``makepkg`` on
Arch, it compiles source code into packages. The Alpine build process is
particularly important because Alpine uses **musl libc** instead of
glibc — a source-level compatibility concern that means many packages
must be patched to compile correctly on Alpine.

.. code-block:: bash

   # Install build tools
   $ apk add alpine-sdk

   # Create a build user (abuild refuses to run as root)
   $ adduser -D builder
   $ echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

   # Checkout a package recipe from the aports tree
   $ git clone https://gitlab.alpinelinux.org/alpine/aports.git
   $ cd aports/main/nginx

   # Build the package
   $ su builder
   $ abuild -r

The ``APKBUILD`` file is Alpine's equivalent of Arch's ``PKGBUILD``:

.. code-block:: bash

   # APKBUILD for nginx
   pkgname=nginx
   pkgver=1.24.0
   pkgrel=0
   pkgdesc="High performance web server"
   url="https://nginx.org"
   arch="all"
   license="BSD-2-Clause"
   depends="pcre libssl1.1 zlib"
   makedepends="linux-headers"
   source="https://nginx.org/download/nginx-$pkgver.tar.gz"
   builddir="$srcdir/$pkgname-$pkgver"

   build() {
       ./configure --prefix=/var/lib/nginx ...
       make
   }

   package() {
       make DESTDIR="$pkgdir" install
   }

   sha512sums="..."

------------------------------------------------
5.3.3 Comparison: ``pacman`` vs. ``apk``
------------------------------------------------

.. list-table:: pacman vs apk
   :header-rows: 1

   * - Property
     - ``pacman`` (Arch)
     - ``apk`` (Alpine)
   * - Complexity
     - Moderate
     - Minimal
   * - Default libc
     - glibc
     - musl
   * - Init system
     - systemd
     - OpenRC
   * - Binary size (container)
     - ~350 MB minimal
     - ~8 MB (busybox+apk)
   * - Package format
     - ``.pkg.tar.zst``
     - ``.apk`` (tarball)
   * - User repository
     - AUR (PKGBUILDs)
     - ``aports`` (APKBUILDs)
   * - Self-contained builds
     - ``makepkg -s``
     - ``abuild -r``
   * - Rolling release
     - Yes (bleeding edge)
     - Semi-rolling (stable release branches)
   * - Dependency tracking
     - Standard (dependency tree)
     - World file (user-intent tracking)
   * - Typical use case
     - Desktop, development
     - Containers, embedded, security-sensitive

Both ``pacman`` and ``apk`` demonstrate that a package manager does not
need the complexity of ``apt`` or ``dnf`` to be effective. By keeping the
design minimal and the toolchain unified, they achieve excellent
performance and reliability. The rolling-release model they serve demands
discipline — but for users who want the latest software without
sacrificing system integrity, these tools are unmatched.
