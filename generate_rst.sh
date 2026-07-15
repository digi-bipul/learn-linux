#!/usr/bin/env bash

# Set the target directory
TARGET_DIR=~/learn-linux/docs/source/chapter_05

# Ensure the directory exists just in case
mkdir -p "$TARGET_DIR"

echo "Appending the rest of 04_source_based_and_bsd.rst..."
cat << 'EOF' >> "$TARGET_DIR/04_source_based_and_bsd.rst"
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
EOF

echo "Writing 05_functional_declarative.rst..."
cat << 'EOF' > "$TARGET_DIR/05_functional_declarative.rst"
.. _section-5-5:

================================================
5.5 Functional & Declarative Package Management
================================================

.. rst-class:: lead

   *"What if installing a package did not mutate any global state? What if
   every installation produced a unique, immutable, content-addressed
   directory that could never conflict with any other installation — and
   could be rolled back instantly? This is the promise of functional
   package management."*

Every package manager we have discussed so far — ``apt``, ``dnf``,
``pacman``, ``emerge`` — operates on a **shared state** model.
They install files into global directories (``/usr/bin``, ``/usr/lib``,
``/etc``) and maintain a database of what is installed.
This model has deep limitations:

* **No rollback:** ``apt upgrade`` that breaks the system cannot be
  atomically undone.
* **Global conflicts:** Two applications requiring different versions of
  the same library cannot coexist.
* **Non-reproducibility:** A system's state depends on the order and
  timing of installations.
* **Side effects:** Installing a package modifies shared state that other
  packages may implicitly depend on.

**Functional package management** reimagines the entire concept. Instead
of mutating global paths, it treats software installation as a **pure
function**: given the same inputs (source code, dependencies, build
instructions), it always produces the same output — a content-addressed,
immutable directory in a **store** — without side effects.

------------------------------------------------
5.5.1 Nix: The Pioneering Functional Package Manager
------------------------------------------------

Nix (named after "Nix" as in the model-theoretic "nix" of state) is both
a package manager and the foundation of the NixOS Linux distribution.
Its core ideas are:

1. **The Nix store** (``/nix/store``) — all packages are installed in
   unique, hash-addressed directories.
2. **Purely functional builds** — build processes cannot access the
   network or write to arbitrary paths;
   they can only reference inputs explicitly declared in the derivation.
3. **Declarative configuration** — the entire system (packages, services,
   users, kernel parameters) is specified in a single configuration file,
   and changes are atomic.

5.5.1.1 The Nix Store: Content-Addressed, Immutable, and Garbage-Collected
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The Nix store is at ``/nix/store``.
Every package is installed in a directory named with a **cryptographic hash**
of all its build inputs:

.. code-block:: bash

   $ ls /nix/store/
   a9xn0gx...-glibc-2.37-8/
   d3l4m9k...-openssl-3.0.8/
   f7p2q5r...-zlib-1.2.13/
   ...

Each directory is **immutable** — once written, it is never modified.
If a package needs to be changed (e.g., a security update), a *new*
directory is created with a different hash.
The old directory remains until it is garbage-collected (all users/derivations
that referenced it have been removed).
This has profound consequences:

* **No dependency hell:** ``/nix/store/a9xn0gx...-glibc-2.37-8/`` and
  ``/nix/store/b2ym1p...-glibc-2.35-3/`` can coexist peacefully.
* **Atomic upgrades and rollbacks:** Switching a profile from one
  generation to the next is a symlink swap — instantaneous and atomic.
* **Garbage collection:** ``nix-collect-garbage`` removes unreachable
  store paths, exactly like a tracing garbage collector in a programming
  language.

5.5.1.2 Derivations: The Build Recipe
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A **derivation** (``.drv`` file) is Nix's equivalent of a ``PKGBUILD`` or
ebuild.
It is a low-level, machine-readable description of:

* The builder (typically ``bash``).
* The build inputs (references to other store paths).
* The build script.
* The environment variables to set.
* The expected output paths.

Derivations are generated from **Nix expressions** (``.nix`` files) —
the Nix language, a purely functional, lazily-evaluated domain-specific
language.

.. code-block:: nix
   :linenos:

   # A simple Nix expression to build "hello" from source
   { pkgs ?
   import <nixpkgs> {} }:

   pkgs.stdenv.mkDerivation {
     name = "hello-2.12.1";
     src = pkgs.fetchurl {
       url = "https://ftp.gnu.org/gnu/hello/hello-2.12.1.tar.gz";
       sha256 = "...";
     };
   }

Building this expression::

   $ nix-build hello.nix
   /nix/store/6gkz8f...-hello-2.12.1

   $ /nix/store/6gkz8f...-hello-2.12.1/bin/hello
   Hello, world!

5.5.1.3 ``nix-shell``: Ephemeral Development Environments
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

One of Nix's killer features is ``nix-shell`` — a command that creates a
temporary shell with specific packages available, without installing them
system-wide:

.. code-block:: bash

   # Enter a shell with Python 3.11 and Node.js 20
   $ nix-shell -p python311 nodejs_20

   $ python --version
   Python 3.11.5
   $ node --version
   v20.5.0

   $ exit  # Back to your normal environment;
   # python and node are gone

This can be formalized in a ``shell.nix`` file for reproducible
development environments:

.. code-block:: nix
   :linenos:

   { pkgs ?
   import <nixpkgs> {} }:

   pkgs.mkShell {
     buildInputs = with pkgs;
     [
       python311
       nodejs_20
       postgresql_15
       cmake
       gcc13
     ];
   }

Now ``nix-shell`` in that directory always provides the exact same
tool versions, regardless of what is installed on the host system.

5.5.1.4 NixOS: The Declarative Operating System
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

NixOS takes Nix to the OS level.
The entire system — all packages, services, users, firewall rules, kernel
parameters — is declared in a single file, ``/etc/nixos/configuration.nix``:

.. code-block:: nix
   :linenos:

   { config, pkgs, ... }:

   {
     # Boot loader
     boot.loader.grub.enable = true;
     boot.loader.grub.device = "/dev/sda";

     # Kernel
     boot.kernelPackages = pkgs.linuxPackages_6_1;

     # Networking
     networking.hostName = "my-server";
     networking.networkmanager.enable = true;

     # Packages installed globally
     environment.systemPackages = with pkgs;
     [
       vim
       htop
       git
       curl
     ];

     # Services
     services.nginx.enable = true;
     services.nginx.virtualHosts."example.com" = {
       root = "/var/www/example";
     };

     # SSH server
     services.openssh.enable = true;

     # Users
     users.users.alice = {
       isNormalUser = true;
       extraGroups = [ "wheel" ];
     };
   }

After editing ``configuration.nix``::

   $ sudo nixos-rebuild switch  # Apply changes atomically
   $ sudo nixos-rebuild boot    # Apply on next boot
   $ sudo nixos-rebuild test    # Apply temporarily (until reboot)

Each invocation creates a new **generation**.
You can list and roll back:

.. code-block:: bash

   $ sudo nix-env --list-generations
     139  2024-06-01 12:34:56
     140  2024-06-15 10:22:31

   $ sudo nix-env --rollback   # Switch to previous generation
   $ sudo nix-env --switch-generation 139  # Switch to specific generation

This is the ultimate expression of **declarative infrastructure** — your
system configuration is a file under version control, and changes are
atomic, testable, and reversible.

5.5.1.5 Nix Flakes (Modern Nix)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Flakes** (introduced experimentally in Nix 2.4, stable in Nix 2.17+)
are a new system for making Nix expressions **hermetic** and
**reproducible**.
A flake is a directory with a ``flake.nix`` that explicitly declares all
its inputs (dependencies from other flake repositories) and outputs
(packages, NixOS configurations, dev shells).

.. code-block:: nix
   :linenos:

   {
     description = "My project";

     inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
     outputs = { self, nixpkgs }: {
       packages.x86_64-linux.default =
         nixpkgs.legacyPackages.x86_64-linux.hello;
     };
   }

Flakes eliminate the "magic" of ``<nixpkgs>`` by pinning every input to
an exact Git revision.
A locked ``flake.lock`` file ensures every build uses the identical source
code — even years later.

------------------------------------------------
5.5.2 GNU Guix: Functional Management with Scheme
------------------------------------------------

**GNU Guix** (pronounced "geeks") is the GNU Project's functional package
manager, heavily inspired by Nix but with key differences:

* **Scheme API:** Guix uses **GNU Guile** (a Scheme dialect) as its
  extension language.
  Packages are defined as Scheme functions.
* **GNU philosophy:** Guix is part of the GNU Project and prioritizes
  free software (the ``guix`` command refuses to install non-free
  packages unless explicitly configured otherwise).
* **Daemon-based:** Like Nix, Guix uses a build daemon that runs builds
  in isolated environments (containers, user namespaces, or chroots).

5.5.2.1 Package Definitions in Guile Scheme
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: scheme
   :linenos:

   ;; A package definition for GNU Hello
   (define-public hello
     (package
       (name "hello")
       (version "2.12.1")
       (source (origin
                 (method url-fetch)
                 (uri (string-append "mirror://gnu/hello/hello-"
                                     version ".tar.gz"))
                 (sha256
                  (base32 "0ssi1wpaf7plaswqqjwigppsg5fyh99vdlb9kzl7c9lng89ndq1i"))))
       (build-system gnu-build-system)
       (synopsis "Hello, GNU world: An example GNU package")
       (description "GNU Hello prints a friendly greeting.")
       (home-page "https://www.gnu.org/software/hello/")
       (license gpl3+)))

Build and install::

   $ guix build hello         # Build without installing
   $ guix install hello       # Install into user's profile
   $ guix remove hello        # Remove from profile
   $ guix upgrade             # Upgrade all user-installed packages
   $ guix gc                  # Garbage-collect unreachable store paths

5.5.2.2 Guix System (GuixSD)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Like NixOS, Guix can manage the entire operating system declaratively:

.. code-block:: scheme
   :linenos:

   ;; /etc/config.scm (excerpt)
   (use-modules (gnu))
   (use-service-modules networking ssh)
   (use-package-modules admin ssh)

   (operating-system
     (host-name "my-guix-system")
     (timezone "UTC")
     (locale "en_US.utf8")
     (bootloader (bootloader-configuration
                   (bootloader grub-bootloader)
                   (targets '("/dev/sda"))))
     (file-systems (cons (file-system
                           (device "/dev/sda1")
                           (mount-point "/")
                           (type "ext4"))
                         %base-file-systems))
     (packages (cons* openssh htop %base-packages))
     (services (cons* (service ssh-daemon-type)
                      %base-services)))

Apply::

   $ sudo guix system reconfigure /etc/config.scm

Guix also supports **generations** and **rollback**, just like Nix:

.. code-block:: bash

   $ sudo guix system list-generations
   $ sudo guix system roll-back

5.5.2.3 The Guix Substitute System
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

While Nix and Guix are source-based by default, both support **binary
substitutes** — pre-built binaries served from a cache.
Nix uses ``cache.nixos.org``; Guix uses ``ci.guix.gnu.org``.

.. code-block:: bash

   # Guix will automatically download substitutes
   $ guix install hello
   The following package will be installed:
      hello  2.12.1  (downloading from ci.guix.gnu.org...)

   # Authorize the substitute server
   $ sudo guix archive --authorize < /etc/guix/ci.guix.gnu.org.pub

This gives users the best of both worlds: **reproducible, functional
builds** with the option of **binary speed** when desired.

------------------------------------------------
5.5.3 Nix vs. Guix: A Comparison
------------------------------------------------

.. list-table:: Nix vs. GNU Guix
   :header-rows: 1

   * - Property
     - Nix / NixOS
     - GNU Guix / Guix System
   * - Expression language
     - Nix language (custom, lazy, purely functional)
     - Guile Scheme (Scheme Lisp dialect)
   * - Build daemon isolation
     - chroot / build users / Linux containers
     - chroot / user namespaces / Linux containers
   * - Binary substitutes
     - cache.nixos.org (official)
     - ci.guix.gnu.org (official)
   * - Free software policy
     - Neutral (nixpkgs includes unfree)
     - Strict (free by default; unfree opt-in)
   * - Init system
     - systemd
     - GNU Shepherd (Scheme-configured)
   * - Community
     - Large, diverse
     - Smaller, GNU-focused
   * - Bootstrapping
     - Traditional binary bootstrap
     - "Reduced Binary Seed" bootstrap (trust-minimizing)
   * - Cross-compilation
     - Excellent (native cross-build support)
     - Excellent (native cross-build support)

The choice between Nix and Guix is often ideological (GNU vs. not, Scheme
vs. Nix language) or community-driven.
Both are technically extraordinary — they represent a paradigm shift from
*stateful management* to *functional composition*.

------------------------------------------------
5.5.4 The Implications for System Administration
------------------------------------------------

Functional package management is not merely an academic curiosity.
It solves real problems that traditional managers cannot:

**Reproducible deployments:**
If your ``flake.lock`` pins ``nixpkgs`` to commit ``abc123``, every build
anywhere — today, next year, on any machine — will produce byte-for-byte
identical store paths (assuming the same architecture).
This is transformative for CI/CD, infrastructure-as-code, and auditable
deployments.

**No "works on my machine" syndrome:**
With ``nix-shell`` or ``guix shell``, every developer gets exactly the
same toolchain, eliminating an entire class of environmental bugs.

**Atomic upgrades with zero-downtime rollback:**
In production, ``nixos-rebuild switch --rollback`` in case of failure
is instantaneous. There is no "partial upgrade" state.

**Stateless infrastructure:**
NixOS servers can be entirely ephemeral — the system configuration is
rebuilt from scratch on every boot, with no state accumulated over time.
This aligns perfectly with container and cloud-native paradigms.

Functional package management is still a minority practice, but its
influence is growing rapidly.
Many of its ideas — content-addressed stores, deterministic builds,
declarative configuration — are being adopted by traditional distributions
and will shape the future of how we manage software on Linux.
EOF

echo "Writing 06_building_from_source.rst..."
cat << 'EOF' > "$TARGET_DIR/06_building_from_source.rst"
.. _section-5-6:

================================================
5.6 Building from Source Manually
================================================

.. rst-class:: lead

   *"Before there were package managers, there was `tar`, `./configure`,
   `make`, and `make install`. This ancient workflow is still essential —
   not because it is better, but because it is the last resort when no
   package exists for the software you need."*

No matter how comprehensive a distribution's repositories are, you will
eventually encounter software that is not packaged — a proprietary tool,
an obscure academic library, a custom in-house application.
In these situations, you must build from source manually.

This section covers the classic build workflow, the tools that automate
it, and — most importantly — how to install software in a way that does
not break your system or conflict with your package manager.

------------------------------------------------
5.6.1 The Classic Triad: ``./configure && make && make install``
------------------------------------------------

Most C/C++ open-source software that follows the GNU Autotools or
autoconf/automake standard is built with three commands:

.. code-block:: bash

   $ tar -xzf nginx-1.24.0.tar.gz
   $ cd nginx-1.24.0

   $ ./configure --prefix=/usr/local
   $ make
   $ sudo make install

Let us examine each step.

5.6.1.1 ``./configure``: The Pre-Build Sanity Check
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``configure`` script — generated by GNU Autotools (specifically
``autoconf``) — is a shell script that:

1. **Checks the build environment:** Is the compiler installed?
   Are the necessary libraries present? What is the CPU architecture?
2. **Sets compilation flags:** It generates ``Makefile`` (and often
   ``config.h``) with platform-specific values.
3. **Handles optional features:** Flags like ``--enable-ssl`` or
   ``--with-pcre`` turn features on and off.

Common ``./configure`` flags:

.. code-block:: bash

   # Installation prefix (where binaries and libraries go)
   $ ./configure --prefix=/usr/local

   # System-wide installation vs. per-user
   $ ./configure --prefix=/opt/myapp

   # Optional features
   $ ./configure --enable-ssl --with-pcre-jit

   # Specify library paths for non-standard locations
   $ ./configure --with-cc=/usr/bin/clang
   $ CPPFLAGS="-I/opt/include" LDFLAGS="-L/opt/lib" ./configure

The single most important flag is ``--prefix``.
It controls where the software is installed:

* ``--prefix=/usr/local`` — The traditional location for manually built
  software.
  Binaries go to ``/usr/local/bin``, libraries to ``/usr/local/lib``,
  configuration to ``/usr/local/etc``.
* ``--prefix=/opt/<package>`` — Self-contained directory for a specific
  package.
* ``--prefix=/usr`` — Installs into the system directories.
  **Avoid this** — it will conflict with your package manager.

5.6.1.2 ``make``: Compilation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``make`` reads the ``Makefile`` (generated by ``./configure``) and
executes the compilation rules.
Key invocations:

.. code-block:: bash

   $ make                   # Build everything
   $ make -j$(nproc)        # Build with parallel jobs (faster on multi-core)
   $ make -j4 V=1           # Verbose output (show actual compiler commands)

When you run ``make`` for the first time, it may take a while.
On subsequent runs, ``make`` only rebuilds files that have changed — it
checks file timestamps against the last build.

.. note::

   If ``make`` fails, look at the **first error**, not the last.
   Make often continues after an error and produces pages of cascading
   failures.
   The pattern is: scroll up, find the first ``make: *** [...]
   Error 1``, and fix the problem above it.

5.6.1.3 ``make install``: Installation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

   $ sudo make install          # Copy files to --prefix target
   $ sudo make install DESTDIR=/tmp/staging  # Install to a temporary root

``make install`` copies the compiled binaries, libraries, headers, man
pages, and configuration files to the directories under ``--prefix``.
It typically runs post-install commands (e.g., creating symlinks, running
``ldconfig``).

.. caution::

   **``make install`` is the most dangerous command in this triad.** It
   writes files into your system.
   If you used ``--prefix=/usr``, it can overwrite files managed by your
   package manager, causing conflicts that are extremely difficult to
   untangle.
   **Never use ``--prefix=/usr`` for manually compiled software.**

------------------------------------------------
5.6.2 Alternatives to GNU Autotools: CMake and Meson
------------------------------------------------

Not all projects use ``./configure``.
Two other build systems are widely used:

**CMake:**

.. code-block:: bash

   $ mkdir build && cd build
   $ cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
   $ make -j$(nproc)
   $ sudo make install

CMake is cross-platform (Windows, macOS, Linux) and generates native build
files (Makefiles, Ninja files, Visual Studio solutions).
Key flags:

* ``-DCMAKE_INSTALL_PREFIX=/usr/local`` — Installation prefix.
* ``-DCMAKE_BUILD_TYPE=Release`` — ``Release``, ``Debug``, ``RelWithDebInfo``.
* ``-DBUILD_SHARED_LIBS=ON`` — Build shared libraries instead of static.
* ``-G Ninja`` — Use the Ninja build system instead of Make.

**Meson:**

.. code-block:: bash

   $ meson setup builddir --prefix=/usr/local
   $ ninja -C builddir
   $ sudo ninja -C builddir install

Meson is a modern build system designed for speed and correctness.
It uses the Ninja backend by default and has a Python-like syntax.

------------------------------------------------
5.6.3 ``checkinstall``: Making Package Managers Aware of Manual Builds
------------------------------------------------

The fundamental problem with ``make install`` is that your package manager
does not know about it.
You cannot use ``apt remove`` or ``dnf erase`` to uninstall — you must
manually track what was installed (or hope the project provides a
``make uninstall`` target, which is rare).

``checkinstall`` solves this by intercepting ``make install`` and
generating a package (``.deb``, ``.rpm``, or ``.pkg.tar.zst``) that can
be installed with the native package manager.

.. code-block:: bash

   # Install checkinstall
   $ sudo apt install checkinstall   # Debian/Ubuntu
   $ sudo dnf install checkinstall   # Fedora

   # Use it instead of 'make install'
   $ ./configure --prefix=/usr/local
   $ make
   $ sudo checkinstall

What happens:

1. ``checkinstall`` runs ``make install`` and watches every file written.
2. It creates a package with all those files, plus metadata (package
   name, version, description).
3. It prompts you to edit the metadata.
4. It installs the package with the system's native package manager.

Now you can manage the software like any other package::

   $ dpkg -l | grep nginx         # See it in the dpkg database
   $ sudo apt remove my-nginx     # Remove it cleanly

.. caution::

   ``checkinstall`` packages are not signed, verified, or reviewed.
   They are a convenient hack, not a distribution-quality packaging
   solution.
   The generated packages may also miss dependencies or conflict with
   official packages of the same name.

------------------------------------------------
5.6.4 Managing ``/usr/local`` with GNU Stow
------------------------------------------------

If you build multiple packages from source with ``--prefix=/usr/local``,
the directory can become a mess: binaries, libraries, headers, and man
pages from different projects all mixed together.
Uninstalling one package becomes guesswork.

**GNU Stow** is a **symlink farm manager** that solves this.
It keeps each package in its own subdirectory under ``/usr/local/stow``
and creates symlinks into ``/usr/local``.
The idea:

.. code-block:: bash

   # Instead of installing to /usr/local directly:
   $ ./configure --prefix=/usr/local
   $ sudo make install

   # Install to a private directory for stow:
   $ ./configure --prefix=/usr/local/stow/nginx-1.24.0
   $ make
   $ sudo make install

   # Now "stow" the package — creates symlinks in /usr/local
   $ cd /usr/local/stow
   $ sudo stow nginx-1.24.0

After ``stow``::

   $ ls -l /usr/local/bin/nginx
   lrwxrwxrwx 1 root root 28 ... /usr/local/bin/nginx -> ../stow/nginx-1.24.0/bin/nginx

   $ ls /usr/local/stow/
   nginx-1.24.0/
   openssl-3.0.8/
   python-3.11.5/

To remove a package::

   $ cd /usr/local/stow
   $ sudo stow --delete nginx-1.24.0   # Remove all symlinks
   $ sudo rm -rf nginx-1.24.0          # Delete the actual files

To upgrade — unstow the old version, install the new version, stow the
new version::

   $ sudo stow --delete nginx-1.24.0
   $ # ... build and install nginx-1.26.0 into /usr/local/stow/nginx-1.26.0 ...
   $ sudo stow nginx-1.26.0

GNU Stow respects the standard Filesystem Hierarchy Standard (FHS):
``bin/``, ``lib/``, ``share/``, ``etc/`` are all linked correctly.

.. note::

   GNU Stow requires discipline. You must install each version of each
   package into its own uniquely-named directory.
   But this small discipline repays itself enormously: your ``/usr/local``
   remains clean, every package is independently removable, and you can see
   at a glance what you have installed.

------------------------------------------------
5.6.5 The DESTDIR Pattern: Staging Installations
------------------------------------------------

Before Stow, there is the ``DESTDIR`` variable.
Many Makefiles support it::

   $ ./configure --prefix=/usr/local
   $ make
   $ make install DESTDIR=/tmp/nginx-staging

This installs the package with paths *relative to* ``/tmp/nginx-staging``.
What would go to ``/usr/local/bin/nginx`` goes to
``/tmp/nginx-staging/usr/local/bin/nginx``.

You can then inspect the staged files, package them, or manually move
them::

   $ find /tmp/nginx-staging -type f
   /tmp/nginx-staging/usr/local/bin/nginx
   /tmp/nginx-staging/usr/local/conf/nginx.conf
   ...

   $ sudo cp -a /tmp/nginx-staging/usr/local/* /usr/local/

Not all Makefiles support ``DESTDIR``, but Autotools-based projects
almost always do.
When building with CMake, the equivalent is::

   $ cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_INSTALL_STAGING_PREFIX=/tmp/staging

------------------------------------------------
5.6.6 A Complete Workflow: Building ``nginx`` from Source
------------------------------------------------

Here is a complete, clean workflow combining the tools above:

.. code-block:: bash
   :linenos:

   # 1. Download and extract
   $ wget https://nginx.org/download/nginx-1.24.0.tar.gz
   $ tar -xzf nginx-1.24.0.tar.gz
   $ cd nginx-1.24.0

   # 2. Configure with stow-friendly prefix
   $ ./configure --prefix=/usr/local/stow/nginx-1.24.0 \
                 --with-http_ssl_module \
                 --with-http_v2_module \
                 --with-pcre

   # 3. Build (parallel)
   $ make -j$(nproc)

   # 4. Install to the stow directory
   $ sudo make install

   # 5. Create symlinks in /usr/local
   $ sudo stow -d /usr/local/stow nginx-1.24.0

   # 6. Verify
   $ nginx -v
   nginx version: nginx/1.24.0

   # 7. To remove later:
   # $ sudo stow -d /usr/local/stow --delete nginx-1.24.0
   # $ sudo rm -rf /usr/local/stow/nginx-1.24.0

Using ``checkinstall`` instead of Stow::

   # (After ./configure and make)
   $ sudo checkinstall --pkgname=nginx-custom \
                       --pkgversion=1.24.0 \
                       --pkgrelease=1 \
                       --default

------------------------------------------------
5.6.7 Summary of Best Practices
------------------------------------------------

.. list-table:: Manual build best practices
   :header-rows: 1

   * - Practice
     - Why
   * - Always use ``--prefix=/usr/local`` or ``/opt/<pkg>``
     - Avoids conflicts with the package manager
   * - Never use ``--prefix=/usr``
     - Overwrites system files, breaks package management
   * - Use GNU Stow for ``/usr/local`` management
     - Keeps each package independently removable
   * - Use ``checkinstall`` for production systems
     - Makes the package manager aware of manual installs
   * - Build with ``-j$(nproc)``
     - Leverages all CPU cores for faster compilation
   * - Keep the build directory for debugging
     - ``make uninstall`` may work if the directory is preserved
   * - Read ``INSTALL`` or ``README`` before building
     - Some projects have non-standard build instructions
   * - Use ``DESTDIR`` when available
     - Clean staging before final installation

Building from source manually is a rite of passage for any serious system
administrator.
It teaches you what package managers do behind the scenes
— and gives you the skills to escape their limitations when necessary.
EOF

echo "Writing 07_universal_and_immutable.rst..."
cat << 'EOF' > "$TARGET_DIR/07_universal_and_immutable.rst"
.. _section-5-7:

================================================
5.7 Universal Formats & Immutable Systems
================================================

.. rst-class:: lead

   *"The traditional Linux distribution model assumes a permanent,
   mutable installation. But containers, IoT devices, and cloud images
   have forced a rethinking: what if the operating system itself were
   immutable — a read-only root filesystem that is atomically replaced,
   never patched in place?"*

This final section of Chapter 5 explores two converging trends:

1. **Universal package formats** — Snap, Flatpak, and AppImage, which
   allow a single binary to run on any Linux distribution.
2. **Immutable (atomic) operating systems** — where the root filesystem
   is read-only and system updates are applied by swapping entire disk
   images, not by mutating package state.

Both trends represent a reaction to the limitations of traditional,
stateful package management — and both are shaping the future of Linux
deployment.

------------------------------------------------
5.7.1 Universal Package Formats
------------------------------------------------

The problem: A binary compiled for Ubuntu's glibc 2.35 will not run on
RHEL 7 with glibc 2.17.
Different distributions ship different library versions, different init
systems, and different filesystem layouts.
Three projects have emerged to solve this, each with a different approach.

5.7.1.1 Flatpak
^^^^^^^^^^^^^^^^^^

**Flatpak** (formerly xdg-app) focuses on **desktop applications** and is
developed primarily by Red Hat.
It provides a **sandboxed environment** where applications see only the
resources they explicitly request.

Architecture:

* **Host system:** A minimal Linux kernel with user namespaces, bind
  mounts, and bubblewrap (``bwrap``) for sandboxing.
* **Runtimes:** Shared platform runtimes (``org.freedesktop.Platform``,
  ``org.gnome.Platform``) that provide base libraries (glib, GTK, Mesa,
  PipeWire).
  Applications depend on a runtime rather than bundling their own libraries.
* **Applications:** Each application is a self-contained image in
  ``/var/lib/flatpak/app/`` (system-wide) or ``~/.local/share/flatpak/``
  (per-user).

.. code-block:: bash

   # Install Flatpak
   $ sudo apt install flatpak
   $ flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

   # Search and install
   $ flatpak search gimp
   $ flatpak install flathub org.gimp.GIMP

   # Run
   $ flatpak run org.gimp.GIMP

   # List installed
   $ flatpak list

   # Update everything
   $ flatpak update

**Sandboxing model:**

Applications are confined using:

* **Bubblewrap** — A lightweight user-namespace-based sandbox.
* **Portals** — APIs for accessing host resources (files, network,
  camera, notifications) through user-consent dialogs.
* **Seccomp filters** — System call whitelisting/blacklisting.

By default, a Flatpak application cannot access files outside its sandbox,
cannot see other processes, and cannot use ``/usr``.
Permissions are explicit:

.. code-block:: bash

   # Override permissions for a specific application
   $ flatpak override --user --filesystem=home org.gimp.GIMP
   $ flatpak override --user --socket=network org.gimp.GIMP

5.7.1.2 Snap
^^^^^^^^^^^^^^

**Snap** (developed by Canonical, the company behind Ubuntu) is a more
ambitious system than Flatpak.
It packages not just desktop applications but also **servers, command-line
tools, and even the kernel and boot loader** via **Ubuntu Core**, the
all-Snap version of Ubuntu.

Architecture:

* **snapd** — The background daemon that manages snaps (analogous to
  ``dockerd``).
* **SquashFS images** — Each snap is a compressed, read-only SquashFS
  filesystem mounted via a loop device at ``/snap/<name>/<revision>/``.
* **Confined execution** — Snaps use **AppArmor** (mandatory access
  control) and **seccomp** for sandboxing.
* **Automatic updates** — By default, snaps are updated four times per
  day via delta updates (binary diffs).

.. code-block:: bash

   # Install snapd
   $ sudo apt install snapd

   # Install a snap
   $ sudo snap install lxd
   $ sudo snap install core

   # List installed snaps
   $ snap list

   # View channels and versions
   $ snap info lxd

   # Run a snap command
   $ lxc list

   # Switch between channels (stable, candidate, beta, edge)
   $ sudo snap switch lxd --channel=5.0/stable
   $ sudo snap refresh lxd

**Snap confinement levels:**

* **Strict** — Full AppArmor/sandbox confinement. No access to the host
  system beyond what interfaces declare.
* **Classic** — No confinement (same as a traditional package). Requires
  manual approval because it bypasses the security model.
* **Devmode** — Runs with warnings instead of denials (for development).

**Controversy:** Snap has been criticized for:

* The proprietary server-side Snap Store (the store backend is not
  open-source).
* The aggressive ``snap refresh`` pace (four times daily).
* The ``/snap`` mount namespace and loop device overhead.
* Slower startup times compared to native packages.

Flatpak vs. Snap vs. AppImage
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. list-table:: Universal format comparison
   :header-rows: 1

   * - Property
     - Flatpak
     - Snap
     - AppImage
   * - Primary sponsor
     - Red Hat / GNOME
     - Canonical / Ubuntu
     - Community (Simon Peter)
   * - Runtime model
     - Shared runtimes (Freedesktop/GNOME/KDE)
     - Base snaps (core, core18, core20, core22)
     - Self-contained (everything in one file)
   * - Sandbox technology
     - Bubblewrap (user namespaces)
     - AppArmor + seccomp
     - None (but can spawn with firejail)
   * - Update mechanism
     - Incremental (ostree-based)
     - Delta updates (binary diffs)
     - Manual download (or AppImageUpdate)
   * - Store
     - Flathub (open-source, community)
     - Snap Store (proprietary backend)
     - None (AppImageHub is a directory, not a store)
   * - Installation scope
     - Per-user or system-wide
     - System-wide (snapd daemon)
     - Per-user (no daemon needed)
   * - Best for
     - Desktop applications
     - Servers + desktop + IoT (Ubuntu Core)
     - Portable, no-install applications
   * - Startup time
     - Moderate (runtime mount)
     - Slower (mount + AppArmor setup)
     - Instant (direct execution)

5.7.1.3 AppImage
^^^^^^^^^^^^^^^^^^

**AppImage** takes the simplest possible approach: a single executable
file that contains the application and all its dependencies.
Download, chmod +x, and run. No installation, no daemon, no sandboxing
(unless combined with external tools like ``firejail``).

.. code-block:: bash

   # Download and run (no installation)
   $ wget https://github.com/neovim/neovim/releases/download/stable/nvim.appimage
   $ chmod +x nvim.appimage
   $ ./nvim.appimage

   # Or install to PATH
   $ mkdir -p ~/Applications
   $ mv nvim.appimage ~/Applications/
   $ ln -s ~/Applications/nvim.appimage ~/.local/bin/nvim

   # Integrate with desktop (optional)
   $ ./nvim.appimage --appimage-extract   # Extract to a directory
   $ ./nvim.appimage --appimage-mount     # Mount the image

AppImage is ideal for:

* Portable tools that you carry on a USB drive.
* Testing applications without committing to an installation.
* Running software on air-gapped systems.

The trade-off is size — each AppImage bundles its own libraries, so a
simple text editor may be 50 MB+ — and the lack of automatic updates.

------------------------------------------------
5.7.2 Immutable (Atomic) Operating Systems
------------------------------------------------

An **immutable operating system** is one where the root filesystem is
read-only at runtime.
System updates are not applied by mutating ``/usr/bin`` and ``/usr/lib``
in place, but by swapping the entire root filesystem image — atomically
and with the ability to roll back.

5.7.2.1 OSTree: The Foundation
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**OSTree** (formerly "git for operating system binaries") is the
underlying technology behind most modern immutable Linux systems.
It manages bootable, versioned filesystem trees.

How it works:

1. The system is built from a **manifest** (a set of packages and
   configuration) into a **tree** — a content-addressed directory
   structure in ``/ostree/deploy/``.
2. Each tree is immutable and identified by a cryptographic checksum
   (similar to a Git commit hash).
3. The bootloader selects a **deployment** — a specific tree to boot.
4. Updates create a new tree;
   the old tree remains for rollback.

.. code-block:: bash

   # On a running OSTree-based system (e.g., Fedora Silverblue)
   $ rpm-ostree status
   State: idle
   Deployments:
   ● fedora:fedora/39/x86_64/silverblue
                Version: 39.20240615.0 (2024-06-15T12:00:00Z)
                Commit: 8a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b

   $ sudo rpm-ostree upgrade    # Download and prepare a new deployment
   $ systemctl reboot           # Boot into the new deployment

   # Rollback at boot: select the previous deployment from GRUB
   # Or from the running system:
   $ sudo rpm-ostree rollback

OSTree is not a package manager — it is a **versioned filesystem manager**
that can be used with any package manager (``rpm``, ``dnf``, ``apt``)
to compose images.

5.7.2.2 Fedora Silverblue: The Desktop Immutable OS
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Fedora Silverblue** is a desktop variant of Fedora Workstation that
uses OSTree with ``rpm-ostree`` for package management.
The root filesystem (``/usr``) is read-only. Users install applications as:

* **Flatpaks** (recommended for GUI applications).
* **Toolbox containers** (for development tools, via ``toolbox``).
* **Package layering** (when absolutely necessary, via ``rpm-ostree
  install``).

.. code-block:: bash

   # Package layering — layers an RPM on top of the base image
   $ sudo rpm-ostree install htop

   # This creates a new deployment with htop layered.
   # A reboot is required for the change to take effect.
   $ systemctl reboot

   # Remove layered packages
   $ sudo rpm-ostree uninstall htop
   $ sudo rpm-ostree cleanup -m   # Clear cached metadata
   $ sudo rpm-ostree cleanup -p   # Remove pending deployments

   # Use toolbox for development (no layering needed)
   $ toolbox enter
   ⬢ $ dnf install gcc make gdb   # Inside the toolbox container
   ⬢ $ exit

The **toolbox** model is key: instead of polluting the host OS with
development libraries, you work inside a container that shares your home
directory and can be discarded and recreated at any time.

5.7.2.3 Fedora CoreOS: Immutable for Servers
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

**Fedora CoreOS** (FCOS) is the server/cloud version of Silverblue.
It is designed for **automated, large-scale deployments** — the OS is never
manually configured or patched.
Instead:

* **Ignition** — A provisioning tool that configures the first boot
  (disk layout, users, network, systemd units) from a JSON config.
* **Automatic updates** — ``zincati``, the update agent, automatically
  stages and applies updates from an OSTree repository.
* **No SSH by default** — Management is done through the Ignition config
  or through a container orchestrator (Kubernetes, Nomad).

The FCOS update model::

   # View available updates
   $ rpm-ostree status

   # The zincati agent will automatically:
   # 1. Download the new tree in the background
   # 2. Stage it for the next boot
   # 3. Reboot at a configurable maintenance window

   # Manual update
   $ sudo rpm-ostree update

   # Rollback at next boot
   $ sudo rpm-ostree rollback

5.7.2.4 Other Immutable Distributions
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

* **Vanilla OS** — An immutable Ubuntu derivative using OSTree.
* **openSUSE MicroOS** — A transactional-update version of openSUSE,
  using ``transactional-update`` and btrfs snapshots instead of OSTree.
* **Endless OS** — A Debian-based OSTree distribution focused on offline
  use and automatic updates.
* **ChromeOS / ChromeOS Flex** — The most widely deployed immutable OS,
  using a dual-root (A/B) update scheme.
* **Alpine Linux (diskless mode)** — Can run entirely from RAM with a
  read-only rootfs, updated by replacing the APK overlay.

------------------------------------------------
5.7.3 The Immutable OS: Trade-Offs and Philosophy
------------------------------------------------

.. list-table:: Traditional vs. Immutable OS
   :header-rows: 1

   * - Property
     - Traditional (Ubuntu, Fedora, Arch)
     - Immutable (Silverblue, CoreOS)
   * - Root filesystem
     - Read-write
     - Read-only (``/usr`` immutable)
   * - Update model
     - Package-level mutation (apt upgrade)
     - Image-level swap (OSTree deployment)
   * - Rollback
     - Difficult (downgrade each package)
     - Trivial (select previous deployment at boot)
   * - Package installation
     - ``apt install`` (global)
     - Flatpak / toolbox / layering (scoped)
   * - Configuration drift
     - Common over time
     - Minimal (stateless provisioning)
   * - Security surface
     - Larger (writable /usr)
     - Smaller (attackers cannot modify binaries)
   * - Admin flexibility
     - High (modify anything)
     - Low (must follow the platform model)
   * - Suitable for
     - Workstations, development machines
     - Servers, IoT, kiosks, CI/CD

**When to choose immutable:**

* **Servers at scale:** Immutable infrastructure (CoreOS, Flatcar Linux)
  aligns perfectly with container orchestration.
  The OS is a minimal base that is never "fixed" — it is replaced.
* **Security-critical environments:** A read-only rootfs prevents many
  classes of privilege escalation and malware persistence.
* **IoT and embedded:** Atomic updates prevent bricked devices from
  partial updates.
* **Desktop stability:** Silverblue's layered approach means you cannot
  accidentally break the base OS by installing a misbehaving application.

**When to avoid immutable:**

* **When you need to modify system configuration frequently.**
* **When your workflow involves compiling native system libraries.**
* **When you must use software that does not support Flatpak or
  containers.**

------------------------------------------------
5.7.4 Summary: The Evolution of Package Management
------------------------------------------------

This chapter has traced package management from its simplest form —
shared libraries and manual compilation — through the established binary
managers (``apt``, ``dnf``), the rolling and source-based alternatives
(``pacman``, ``apk``, Portage), the functional paradigm (Nix, Guix), and
finally to universal formats and immutable systems.
Each generation addresses the limitations of the previous one:

+---------------------------+-------------------------------------+
| **Problem** | **Solution** |
+---------------------------+-------------------------------------+
| Dependency hell           | Binary package managers (``apt``,   |
|                           | ``dnf``) with SAT solving           |
+---------------------------+-------------------------------------+
| Pre-compiled binaries     | Source-based managers (Portage,     |
| cannot be tuned           | BSD Ports)                          |
+---------------------------+-------------------------------------+
| Global state mutations    | Functional managers (Nix, Guix)     |
| cannot be rolled back     | with content-addressed stores       |
+---------------------------+-------------------------------------+
| Cross-distribution        | Universal formats (Flatpak, Snap,   |
| packaging                 | AppImage)                           |
+---------------------------+-------------------------------------+
| Update-induced drift      | Immutable OS (OSTree, Silverblue)   |
| and configuration rot     | with atomic image swaps             |
+---------------------------+-------------------------------------+

There is no single "best" approach. The right choice depends on your
deployment scale, security requirements, workflow preferences, and
tolerance for complexity.
A professional system administrator should be conversant in all of them —
able to use ``apt`` on a Debian server, ``dnf`` on a Fedora workstation,
``nix-shell`` for reproducible development environments, and Flatpak for
desktop applications — and understand why each tool exists.

The package manager is the operating system's relationship with software.
Understanding that relationship at the depth presented in this chapter
separates a competent sysadmin from an exceptional one.
EOF

echo "Done! Final files successfully appended and created in $TARGET_DIR."
