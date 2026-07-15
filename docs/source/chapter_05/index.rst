.. _chapter-05:

===================================================
Chapter 5: Package Management & Software Lifecycles
===================================================

.. rst-class:: lead

   *"Package management is the operating system's most intimate relationship
   with software. It is the bridge between source code in a repository and
   a running binary on disk — and getting that bridge wrong can take down
   an entire fleet."* — Adapted from *The Practice of System Administration*

In Chapters 1 through 4, you learned to navigate the shell, manage users and
processes, and configure system services. But none of those skills matter
without **software** — and software must be obtained, installed, updated,
and eventually removed. This is the domain of **package management**.

Package management is deceptively complex. Behind every ``apt install`` or
``dnf update`` lies:

* A **dependency resolver** — a graph-theoretic algorithm that determines
  exactly which packages (and which *versions* of those packages) must be
  present to satisfy a requested installation.
* A **trust model** — cryptographic signature verification to ensure the
  software you download is exactly what the developer published.
* A **database of state** — tracking every file on the system that belongs
  to which package, so that removal does not break other software.
* A **lifecycle model** — deciding when and how software moves from source
  code, through compilation, into a repository, and onto your disk.

This chapter explores every facet of that lifecycle. We begin with the
fundamentals of shared libraries and binary compatibility (Section 5.1),
then tour the major package management paradigms in use today:

* **Traditional binary managers** (Section 5.2): ``dpkg``/``apt`` (Debian)
  and ``rpm``/``dnf`` (Red Hat) — the engines behind the two largest
  GNU/Linux distributions.
* **Rolling-release and minimalist managers** (Section 5.3): Arch's
  ``pacman`` with the AUR, and Alpine's ``apk`` with ``abuild``.
* **Source-based ecosystems** (Section 5.4): Gentoo's Portage and the BSD
  Ports collections — where every package is compiled from source, on your
  machine, for your machine.
* **Functional and declarative management** (Section 5.5): Nix and GNU Guix
  — the radical rethinking of package management as a purely functional,
  side-effect-free operation.
* **Building from source manually** (Section 5.6): The classic
  ``./configure && make && make install`` workflow, plus GNU Stow and
  ``checkinstall`` for cleaning up the mess.
* **Universal formats and immutable systems** (Section 5.7): Snap, Flatpak,
  and AppImage for cross-distribution delivery, and OSTree-based atomic
  operating systems like Fedora Silverblue and CoreOS.

By the end of this chapter, you will not only be able to use any of these
systems proficiently — you will understand the **design trade-offs** that
led to their creation. You will see package management not as a mundane
chore, but as one of the most intellectually rich problems in systems
engineering.

.. toctree::
   :titlesonly:
   :numbered:

   01_software_lifecycle
   02_traditional_binary_managers
   03_rolling_and_minimalist
   04_source_based_and_bsd
   05_functional_declarative
   06_building_from_source
   07_universal_and_immutable
