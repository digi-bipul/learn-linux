.. _what-is-linux:

What Is Linux?
==============

If you have ever used an Android phone, browsed the web, streamed a
movie on Netflix, or withdrawn money from an ATM, you have almost
certainly interacted with Linux — probably without realising it.  Linux
is the invisible engine running the majority of the world's servers,
supercomputers, embedded devices, and cloud infrastructure.  Yet,
defining what "Linux" actually *is* turns out to be trickier than most
people expect.

.. contents::
   :local:
   :depth: 1


The Kernel: A Traffic Controller for Hardware
----------------------------------------------

At its narrowest — and technically most correct — definition, **Linux**
is a *kernel*: a single, monolithic piece of software that sits directly
on top of the physical hardware and arbitrates access to it.  Think of
the kernel as a hyper-vigilant traffic controller at the busiest
intersection in the city.  Every process, every keystroke, every network
packet, and every disk write must pass through it.

The Linux kernel is responsible for five fundamental jobs:

.. describe:: Process Management

   The kernel decides *which* program gets to use the CPU, *when*, and
   for *how long*.  It can pre-empt (pause) a running process to let
   another one run, giving the illusion that hundreds of programs are
   executing simultaneously even on a single CPU core.

.. describe:: Memory Management

   Every program believes it has the entire computer's RAM to itself.
   The kernel maintains this illusion through *virtual memory*: it maps
   each process's "virtual" addresses onto real, physical RAM pages and
   swaps idle pages out to disk when memory runs low.

.. describe:: Device Drivers

   The kernel speaks the native protocol of your keyboard, mouse,
   graphics card, Wi‑Fi chip, and storage controller.  These
   translation layers are called *device drivers*, and the Linux kernel
   ships with more of them than any other operating system kernel in
   history.

.. describe:: Filesystem Abstraction

   Whether your data lives on an ext4 partition, an NVMe SSD, a USB
   stick formatted with FAT32, or a remote NFS share, the kernel
   presents it to userspace programs through a single, uniform
   interface: the *Virtual File System* (VFS) layer.  Programs simply
   ``open()``, ``read()``, and ``write()`` files; they do not need to
   know (and usually should not care) about the underlying storage
   technology.

.. describe:: Networking Stack

   The kernel implements the full TCP/IP protocol suite — from Ethernet
   frames up through IP routing, TCP congestion control, and the BSD
   sockets API that applications use to send and receive data.

.. note::

   The Linux kernel is **monolithic**, meaning all of these subsystems
   run in a single address space (kernel space).  This contrasts with
   *microkernels* (such as the GNU Hurd or Minix), where drivers and
   filesystems run as separate user-space servers.  The monolithic
   design gives Linux a raw performance advantage at the cost of a
   larger trusted computing base.


GNU/Linux: The Full Operating System
--------------------------------------

A kernel alone is useless to a human.  You cannot type commands into a
kernel; you cannot edit a file with a kernel; you cannot compile a
program with a kernel.  The kernel needs a surrounding ecosystem of
*userspace* tools: a shell, a C library, core utilities (``ls``, ``cp``,
``mkdir``), a compiler, a text editor, and so on.

Here enters the **GNU Project**, launched by Richard Stallman in 1983.
GNU's goal was to create a completely free, Unix-compatible operating
system.  By the early 1990s, GNU had produced a high-quality C compiler
(GCC), a C library (glibc), a shell (Bash), and a comprehensive set of
command-line utilities (coreutils, grep, sed, awk, etc.).  The one piece
GNU lacked was a working kernel.

When Linus Torvalds released the first version of the Linux kernel in
1991, the two halves snapped together like puzzle pieces.  The result is
properly called **GNU/Linux** — the GNU userspace running on top of the
Linux kernel.  Most people simply say "Linux" out of convenience, and
this book will largely follow that convention, but the historical and
philosophical distinction matters.

.. sidebar:: Not All Linux Systems Are GNU

   Some Linux-based systems deliberately avoid GNU components.  **Alpine
   Linux**, for example, replaces glibc with the smaller **musl libc**
   and replaces the GNU coreutils with **BusyBox**, a single binary that
   provides stripped-down versions of hundreds of Unix commands.  Android
   uses the Linux kernel but its userspace is the Android Runtime (ART)
   and Bionic libc — no GNU at all.


What, Then, Is a "Distribution"?
----------------------------------

A **Linux distribution** (or "distro") is a curated bundle that
includes:

1. The Linux kernel (often with distro-specific patches).
2. A set of userspace tools (GNU or alternatives).
3. A **package manager** — the software that installs, updates, and
   removes applications (e.g., ``apt``, ``dnf``, ``pacman``, ``apk``).
4. An **init system** — the first process the kernel launches, which
   then brings up all other services (e.g., ``systemd``, ``OpenRC``,
   ``runit``).
5. Default configuration files, artwork, documentation, and an
   installer.

Think of a distribution as a *complete product*, analogous to buying a
car.  The kernel is the engine.  Toyota, Ford, and Honda all build cars
around engines, but each offers a different interior, different controls,
and a different driving philosophy.  Debian, Fedora, and Arch all ship
the Linux kernel, but each provides a different *experience*.

We will explore the major distribution families in depth in
:ref:`choosing-a-distribution`.


Why Does Linux Dominate the World?
------------------------------------

It is worth pausing to appreciate the sheer scale of Linux's reach:

* **100%** of the TOP500 supercomputers run Linux.
* **~96%** of the top one million web servers run Linux.
* **~70%** of all smartphones run Android, which uses the Linux kernel.
* The **cloud** — AWS, Google Cloud, Microsoft Azure — is overwhelmingly
  Linux.
* Embedded devices: routers, smart TVs, cars, IoT sensors, and the
  International Space Station all run Linux.

The reasons are not accidental.  Linux is:

.. glossary::

   Free (as in freedom)
      The source code is published under the GNU General Public License
      (GPL).  Anyone can inspect it, modify it, and redistribute it.
      This creates a global, decentralised community of contributors.

   Free (as in cost)
      You can download, install, and deploy Linux on any number of
      machines without paying a licence fee.

   Portable
      Linux runs on more CPU architectures than any other kernel: x86_64,
      ARM (32- and 64-bit), RISC-V, PowerPC, s390x (IBM mainframes),
      MIPS, and more.

   Modular
      You can strip Linux down to a few megabytes for an embedded sensor,
      or scale it up to manage petabytes of storage across thousands of
      nodes.  The same kernel serves both extremes.

   Stable and Secure
      The kernel's development process is famously rigorous.  Thousands of
      developers contribute; patches are reviewed in public; releases
      follow a strict, time-based cadence.  Security vulnerabilities are
      tracked, disclosed, and patched with remarkable speed.


Chapter Summary
---------------

* **Linux** is, strictly, a *kernel* — the low-level software that
  manages hardware resources.
* A usable operating system requires userspace tools; most systems pair
  the Linux kernel with the **GNU** userspace, hence **GNU/Linux**.
* A **distribution** is a complete, ready-to-install product bundling a
  kernel, userspace, package manager, init system, and configuration.
* Linux is not a niche hobbyist project; it is the industrial backbone
  of modern computing.

In the next section, we travel back in time to understand *how* we got
here — from Bell Labs in 1969 to the vibrant, diverse ecosystem of 2026.
