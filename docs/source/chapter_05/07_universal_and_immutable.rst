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
