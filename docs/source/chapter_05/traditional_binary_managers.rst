.. _section-5-2:

Traditional Binary Package Managers
==================================================

.. rst-class:: lead

   *"The `.deb` and `.rpm` formats are the Latin alphabet of Linux package
   management. They are not the newest or the most elegant, but nearly
   everything descends from them, and they run the vast majority of the
   world's Linux servers."*

Traditional binary package managers are the backbone of enterprise and
desktop Linux. They operate on **pre-compiled binary packages** —
software that has been built once (by a distribution maintainer) and
distributed to millions of machines. The user never compiles anything;
they simply download, verify, and install.

The two dominant families — Debian (``.deb``) and Red Hat (``.rpm``) —
share the same basic architecture but differ in their tooling, their
dependency resolution strategies, and their philosophical approach to
stability versus freshness.

------------------------------------------------
The Debian Family: ``dpkg`` and ``apt``
------------------------------------------------

The Debian package management stack has two layers:

* **Low-level:** ``dpkg`` — the tool that installs, removes, and queries
  ``.deb`` packages. It handles the filesystem operations but does **not**
  resolve dependencies.
* **High-level:** ``apt`` (the Advanced Package Tool) — a front-end that
  resolves dependencies, downloads from repositories, and invokes
  ``dpkg`` to perform the actual installation.

There is also ``apt-get``, the original CLI tool, and ``apt``, the newer
unified frontend introduced in Debian 8 / Ubuntu 16.04. The two share the
same underlying libraries; ``apt`` is designed to be more user-friendly
and combines the functionality of ``apt-get`` and ``apt-cache``.

``dpkg``: The Foundation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Every ``.deb`` file is an ``ar`` archive containing three files:

* ``debian-binary`` — a text file with the format version.
* ``control.tar.gz`` — package metadata (name, version, dependencies,
  maintainer, description).
* ``data.tar.gz`` (or ``data.tar.xz``) — the actual files to install.

.. code-block:: bash

   # Inspect a .deb file without installing it
   $ dpkg --info some-package.deb
   $ dpkg --contents some-package.deb

   # Install a local .deb file (no dependency resolution)
   $ sudo dpkg -i some-package.deb

   # Remove a package
   $ sudo dpkg -r package-name

   # Purge (remove package AND configuration files)
   $ sudo dpkg -P package-name

   # List installed packages
   $ dpkg -l | grep -i openssh

   # Find which package owns a file
   $ dpkg -S /usr/bin/ssh

   # Verify installed package integrity (checksums)
   $ sudo dpkg --verify openssh-server

The ``-i`` flag (install) unpacks the ``.deb``, runs the pre-installation
script (``preinst``), copies files to their destinations, runs the
post-installation script (``postinst``), and updates the dpkg database at
``/var/lib/dpkg/``.

.. important::

   Using ``dpkg -i`` on a package with unmet dependencies will fail with
   an error like::

       dpkg: dependency problems prevent configuration of some-package

   This is intentional. ``dpkg`` refuses to leave the system in a broken
   state. You must resolve dependencies manually or use ``apt`` to
   pull them in automatically.

``apt`` and ``apt-get``: Dependency Resolution
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``apt`` and ``apt-get`` introduce the **repository** concept. Instead of
passing individual ``.deb`` files, you configure **sources** — URLs that
point to structured archives of packages.

.. code-block:: bash

   # The sources list
   $ cat /etc/apt/sources.list
   deb http://deb.debian.org/debian bookworm main contrib non-free
   deb-src http://deb.debian.org/debian bookworm main contrib non-free

   # Repository structure
   # deb http://deb.debian.org/debian bookworm main
   # │   │                          │        │
   # │   │                          │        └── component (main, contrib, non-free)
   # │   │                          └─────────── distribution (release codename)
   # │   └────────────────────────────────────── archive mirror URL
   # └────────────────────────────────────────── type: "deb" for binary, "deb-src" for source

Each repository contains:

* A ``Packages.gz`` (or ``Packages.xz``) file — a compressed index of all
  binary packages available, with their dependencies, versions, and
  checksums.
* A ``Release`` file — signed metadata about the repository (suite, date,
  hashes of the ``Packages`` files).
* A ``Release.gpg`` or ``InRelease`` file — the GPG signature.

The workflow::

   # 1. Update the local package index from repositories
   $ sudo apt update

   # 2. Install a package (with automatic dependency resolution)
   $ sudo apt install nginx

   # 3. Upgrade all packages to the latest versions
   $ sudo apt upgrade

   # 4. Perform a distribution upgrade (handles changed dependencies)
   $ sudo apt full-upgrade

   # 5. Remove a package
   $ sudo apt remove nginx
   $ sudo apt purge nginx  # removes config files too

   # 6. Autoremove orphaned dependencies
   $ sudo apt autoremove

   # 7. Search for packages
   $ apt search "web server"

   # 8. Show detailed information
   $ apt show nginx

Dependency resolution algorithm
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When you run ``apt install foo``, ``apt`` performs a **satisfiability
check**:

1. Build a graph where nodes are packages (with version constraints) and
   edges are dependencies.
2. Mark the requested package(s) for installation.
3. Recursively identify all unmarked packages that satisfy the
   dependencies.
4. Check for conflicts — packages that cannot coexist.
5. Present the solution to the user for confirmation.
6. Download and install all packages in dependency order.

If multiple versions of a dependency exist, ``apt`` selects the **highest
version that satisfies all constraints** — unless other rules (pinning,
APT pinning priorities) override this selection.

APT pinning
^^^^^^^^^^^

APT's **pinning** mechanism (controlled by ``/etc/apt/preferences``)
allows you to assign **priority numbers** to packages from different
repositories. A package from a repository with higher priority will be
preferred over one with lower priority.

.. code-block:: bash

   # /etc/apt/preferences.d/stable-pinning
   Package: *
   Pin: release a=stable
   Pin-Priority: 900

   Package: *
   Pin: release a=testing
   Pin-Priority: 100

   # Now testing packages are only installed if explicitly requested
   $ sudo apt install -t testing some-new-package

Priority values:

* **1000 or higher:** Force installation even if it would break dependencies.
* **990 to 999:** High priority — packages from this source are preferred.
* **500 to 899:** Default range for distribution repositories.
* **100 to 499:** Lower priority — only installed if no higher-priority
  version satisfies the dependency.
* **0 to 99:** Packages are effectively invisible unless explicitly
  requested.
* **Negative:** Prevent installation altogether.

Backports
^^^^^^^^^

**Backports** are packages from a newer Debian/Ubuntu release recompiled
for an older (stable) release. They allow you to run newer software on a
stable base without destabilizing the core system.

.. code-block:: bash

   # Enable backports for Debian Bookworm
   $ echo "deb http://deb.debian.org/debian bookworm-backports main" \
       | sudo tee /etc/apt/sources.list.d/backports.list

   $ sudo apt update
   $ sudo apt install -t bookworm-backports wireguard

The ``-t`` flag selects the target release, overriding the default
priority.

``dpkg`` vs. ``apt``: When to Use Which
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: dpkg vs apt
   :header-rows: 1

   * - Task
     - Use ``dpkg``
     - Use ``apt``
   * - Install a local ``.deb`` file
     - ✅ ``dpkg -i file.deb``
     - ✅ ``apt install ./file.deb`` (also resolves deps)
   * - Resolve dependencies automatically
     - ❌
     - ✅
   * - Remove a package
     - ✅ ``dpkg -r``
     - ✅ ``apt remove``
   * - Query what package owns a file
     - ✅ ``dpkg -S``
     - ✅ ``apt-file search`` (extra tool)
   * - List installed packages
     - ✅ ``dpkg -l``
     - ✅ ``apt list --installed``
   * - Update package index
     - ❌
     - ✅ ``apt update``
   * - Verify package integrity
     - ✅ ``dpkg --verify``
     - ❌ (calls dpkg)

The rule of thumb: use ``apt`` for everything involving repositories and
dependency resolution; use ``dpkg`` only when you need to work directly
with ``.deb`` files or query the low-level database.

------------------------------------------------
The Red Hat Family: ``rpm`` and ``dnf``
------------------------------------------------

The Red Hat ecosystem has evolved dramatically. The toolchain went from
``rpm`` (low-level) → ``yum`` (Yellowdog Updater Modified, high-level) →
``dnf`` (Dandified YUM, the modern replacement). On Fedora, ``dnf`` is the
default; on RHEL 8+ and CentOS Stream, ``dnf`` replaces ``yum``. The
``yum`` command still exists on many systems as a compat symlink to
``dnf``.

``rpm``: The Foundation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

RPM packages are binary archives with the ``.rpm`` extension. They use the
``cpio`` archive format wrapped in header metadata.

.. code-block:: bash

   # Query a package file
   $ rpm -qip some-package.rpm       # package info
   $ rpm -qlp some-package.rpm       # list files in the package

   # Install a local .rpm file
   $ sudo rpm -ivh some-package.rpm

   # Upgrade a package
   $ sudo rpm -Uvh some-package.rpm

   # Remove a package
   $ sudo rpm -e package-name

   # List installed packages
   $ rpm -qa | grep -i openssh

   # Find which package owns a file
   $ rpm -qf /usr/bin/ssh

   # Verify installed package (checksums, permissions, etc.)
   $ sudo rpm -Va

Flags explained:

* ``-q`` = query mode
* ``-i`` (with ``-q``): package info
* ``-l`` (with ``-q``): list files
* ``-p`` (with ``-q``): query an uninstalled package file
* ``-i`` (alone): install
* ``-v``: verbose
* ``-h``: print hash marks (progress bar)
* ``-U``: upgrade (install or upgrade)
* ``-e``: erase (remove)
* ``-a``: all packages
* ``-V``: verify
* ``-f``: file → package

``dnf``: The Modern High-Level Tool
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

   # Repository configuration
   $ cat /etc/yum.repos.d/fedora.repo
   [fedora]
   name=Fedora $releasever - $basearch
   metalink=https://mirrors.fedoraproject.org/metalink?repo=fedora-$releasever&arch=$basearch
   enabled=1
   gpgcheck=1
   gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch

   # Basic operations
   $ sudo dnf update              # Update package index and upgrade all
   $ sudo dnf install nginx       # Install with dependency resolution
   $ sudo dnf remove nginx        # Remove package
   $ sudo dnf autoremove         # Remove orphaned dependencies
   $ sudo dnf search nginx        # Search packages
   $ sudo dnf info nginx          # Show package info
   $ sudo dnf reinstall nginx     # Reinstall (fix broken state)
   $ sudo dnf history             # View transaction history
   $ sudo dnf history undo 7      # Undo transaction #7

Key features of ``dnf``:

* **libsolv dependency resolver** — A SAT-solver-based engine (the same
  library used by ``zypper`` on openSUSE). It can handle complex
  dependency graphs with boolean satisfiability, allowing it to find
  solutions that simpler greedy algorithms might miss.
* **Automatic dependency cleanup** — ``dnf`` tracks *why* each package was
  installed (requested by user, or pulled in as a dependency). Unused
  dependencies are candidates for ``autoremove``.
* **Transaction history** — Every ``dnf`` operation is logged. You can
  roll back to previous states.

``dnf`` vs. ``yum``: What Changed
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: yum vs dnf
   :header-rows: 1

   * - Feature
     - yum
     - dnf
   * - Dependency resolver
     - Custom (Python-based)
     - libsolv (SAT solver)
   * - Performance
     - Slower (Python overhead)
     - Faster (C library, less memory)
   * - API for plugins
     - Yum API (Python)
     - DNF API (Python, but cleaner)
   * - Automatic cleanup
     - Manual ``yum autoremove``
     - Automatic with transaction tracking
   * - History
     - ``yum history``
     - ``dnf history`` (more reliable)

For end-users, the commands are nearly identical. The transition was
primarily about replacing a monolithic Python codebase with a modular
stack using a compiled dependency resolver.

RPM Fusion, EPEL, and COPR
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

RHEL and Fedora maintain strict policies about what can be included in
their official repositories. Third-party repositories fill the gaps.

**EPEL (Extra Packages for Enterprise Linux):**

A Fedora Special Interest Group (SIG) that maintains a large collection
of high-quality add-on packages for RHEL (and compatible derivatives like
CentOS Stream and AlmaLinux). EPEL does not include software that
conflicts with Red Hat's licensing (e.g., multimedia codecs).

.. code-block:: bash

   # Enable EPEL on RHEL 9 / CentOS Stream 9
   $ sudo dnf install epel-release
   $ sudo dnf update

**RPM Fusion:**

A community-maintained repository for software that Fedora cannot ship
due to US patent or copyright law — multimedia codecs (MP3, H.264, H.265,
AAC), NVIDIA drivers, Steam, and more.

.. code-block:: bash

   # Enable RPM Fusion for Fedora
   $ sudo dnf install \
       https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
       https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

**COPR (Cool Other Packages Repo):**

A personal/experimental build service — anyone can create a COPR
repository. COPR is Fedora's equivalent of the Arch User Repository (AUR)
or Ubuntu PPAs, but with automated builds and distribution through DNF.

.. code-block:: bash

   # Enable a COPR repository
   $ sudo dnf copr enable @go-sig/ripgrep
   $ sudo dnf install ripgrep

   # Remove a COPR repository
   $ sudo dnf copr remove @go-sig/ripgrep

.. caution::

   COPR packages are **not reviewed** by Fedora maintainers. Use the same
   caution you would with any third-party software source.

------------------------------------------------
Comparative Philosophy: Debian vs. Red Hat
------------------------------------------------

.. list-table:: Debian vs. Red Hat family comparison
   :header-rows: 1

   * - Dimension
     - Debian/Ubuntu
     - Red Hat/Fedora
   * - Package format
     - ``.deb`` (ar archive)
     - ``.rpm`` (cpio + header)
   * - Low-level tool
     - ``dpkg``
     - ``rpm``
   * - High-level tool (legacy)
     - ``apt-get`` / ``aptitude``
     - ``yum``
   * - High-level tool (modern)
     - ``apt``
     - ``dnf``
   * - Dependency resolver
     - Greedy / SAT-based (apt 1.0+)
     - libsolv (SAT solver)
   * - Release model
     - Stable (frozen) + Testing + Sid
     - Fedora (rolling-ish) → RHEL (stable)
   * - Configuration
     - ``/etc/apt/``
     - ``/etc/yum.repos.d/``
   * - Third-party repos
     - PPAs (Ubuntu), ``/etc/apt/sources.list.d/``
     - COPR, RPM Fusion, EPEL
   * - Package signing
     - GPG with ``apt-key`` (deprecated) or signed ``.sources``
     - GPG keys in ``/etc/pki/rpm-gpg/``

Despite the surface differences, both systems tackle the same fundamental
problem: **given a set of packages with dependency constraints, find a
consistent, installable set of versions, and keep it up to date.** The
crowning achievement of both ecosystems is that on a well-maintained
system, a single command (``apt upgrade`` or ``dnf update``) can safely
upgrade thousands of interdependent packages — a feat of dependency
engineering that should never be taken for granted.

------------------------------------------------
When Traditional Binary Managers Struggle
------------------------------------------------

It is important to acknowledge the limitations that motivated the
alternative systems covered later in this chapter:

1. **Global state mutation:** ``apt install`` and ``dnf install`` modify
   shared system directories (``/usr/bin``, ``/usr/lib``, ``/etc``).
   There is no transaction rollback — if an upgrade breaks something,
   you must manually downgrade.
2. **Dependency conflicts on shared libraries:** Two applications may
   require different versions of the same library. With traditional
   managers, this is impossible to resolve without containers or
   workarounds.
3. **Non-reproducible builds:** Different machines, built at different
   times, with different repository mirrors, will get different sets of
   packages.
4. **No per-user installation:** Package managers are system-global.
   Installing a package requires root privileges and affects all users.

These limitations are not failures of design — they are consequences of
the **stateful, imperative** model. Later sections (5.5, 5.7) explore
systems that take a fundamentally different approach.
