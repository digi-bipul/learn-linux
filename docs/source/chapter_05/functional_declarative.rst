.. _section-5-5:

5.5 Functional & Declarative Package Management
==================================================

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
