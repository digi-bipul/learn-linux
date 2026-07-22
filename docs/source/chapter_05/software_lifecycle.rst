.. _section-5-1:

5.1 Software Lifecycle & Shared Libraries
==================================================

.. rst-class:: lead

   *"A program's journey from a text file to a running process is a
   pipeline of transformations: compilation, assembly, linking, loading.
   Understanding each stage is the key to understanding why packages
   exist at all."*

Before we can discuss package managers, we must understand **what they
manage**. The raw material of package management is **source code**;
the finished product is an **installed, runnable program** composed of
one or more **binaries** and their supporting **shared libraries**.

This section traces that journey from beginning to end, then focuses on
the critical infrastructure of **shared libraries** — the mechanism that
allows millions of lines of code to be reused across thousands of
programs without duplicating a single byte on disk.

------------------------------------------------
5.1.1 The Software Lifecycle: Source to Execution
------------------------------------------------

Every piece of software on a Linux system begins its life as **source
code** — human-readable text written in a language such as C, C++, Rust,
Go, or Python. To become a running process, it must pass through a series
of stages.

Stage 1: Compilation
^^^^^^^^^^^^^^^^^^^^

A **compiler** (e.g., ``gcc``, ``clang``, ``rustc``) translates source
code into **object code** — machine-readable instructions in a file
typically suffixed ``.o``. At this stage, unresolved references to
external functions (e.g., ``printf`` from the C standard library) are left
as **symbols** with placeholder addresses.

Consider a minimal C program:

.. code-block:: c
   :linenos:

   #include <stdio.h>

   int main(void) {
       printf("Hello, world!\n");
       return 0;
   }

Compiling to an object file::

   $ gcc -c hello.c -o hello.o

The resulting ``hello.o`` contains the machine code for ``main``, but the
call to ``printf`` is an **undefined symbol** — its address is not yet
known.

Stage 2: Linking
^^^^^^^^^^^^^^^^

A **linker** (typically ``ld``, invoked automatically by ``gcc``) resolves
symbols and produces a final executable. The linker can work in two ways:

* **Static linking:** The linker copies the machine code of every needed
  library function directly into the final executable.
* **Dynamic linking:** The linker records the names of the needed shared
  libraries and the symbols to resolve; resolution happens at **load
  time** (when the program starts) or at **runtime** (when the symbol is
  first used).

Dynamic linking is the dominant model on modern Linux systems because it
saves disk space and memory — every program on the system can share a
single copy of ``libc.so`` in RAM.

.. code-block:: bash

   # Static linking (produces large executable, ~800 KB for "hello, world")
   $ gcc -static hello.c -o hello_static

   # Dynamic linking (produces small executable, ~16 KB)
   $ gcc hello.c -o hello_dynamic

   $ ls -lh hello_*
   -rwxr-xr-x 1 root root 800K Jul 15 12:00 hello_static
   -rwxr-xr-x 1 root root  16K Jul 15 12:00 hello_dynamic

Stage 3: Packaging
^^^^^^^^^^^^^^^^^^

A raw executable is not yet a **package**. A package bundles:

* One or more binaries and/or libraries.
* Supporting files: configuration defaults, man pages, documentation,
  icons, systemd service units.
* **Metadata:** Package name, version, architecture, dependencies,
  conflicts, digital signature.

This metadata is the package manager's nutritional label — it tells the
system what else must be present for the software to work.

Stage 4: Distribution
^^^^^^^^^^^^^^^^^^^^^

Packages are uploaded to **repositories** — structured archives of
packages, typically signed with the maintainer's GPG key. The client
package manager downloads packages over HTTPS (or HTTP with signature
verification), verifies their integrity, and installs them into the
filesystem.

Stage 5: Installation and Configuration
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The package manager unpacks files to their correct locations, runs
pre- and post-installation scripts (e.g., creating a system user for a
daemon, reloading the init system), and updates its local database of
installed packages.

Stage 6: Execution
^^^^^^^^^^^^^^^^^^

When you run a dynamically linked program, the **dynamic linker/loader**
(``/lib64/ld-linux-x86-64.so.2`` on x86_64) locates and loads all required
shared libraries, resolves the remaining symbols, and transfers control to
the program's entry point.

----------------------------------------------
5.1.2 Shared Libraries: The Backbone of Reuse
----------------------------------------------

A **shared library** is a compiled collection of functions and data that
can be loaded into a process's address space at runtime. On Linux, shared
libraries follow the ``lib<name>.so.<major>.<minor>`` naming convention.

Library naming convention
^^^^^^^^^^^^^^^^^^^^^^^^^

Consider the C standard library on a typical system::

   $ ls -l /lib/x86_64-linux-gnu/libc.so.6
   lrwxrwxrwx 1 root root 12 Jun 15 12:00 /lib/x86_64-linux-gnu/libc.so.6 -> libc-2.31.so

* **Real name:** ``libc-2.31.so`` — the actual file containing the code.
* **SONAME (short for "shared object name"):** ``libc.so.6`` — a symlink
  that encodes only the **major version number** (6). This is the name
  that the linker embeds in the executable at build time.
* **Linker name:** ``libc.so`` — a symlink used only at compile time,
  typically found in ``/usr/lib`` or ``/usr/lib64``.

The SONAME convention is how library compatibility is managed. If
``libfoo.so.1`` and ``libfoo.so.2`` both exist, programs linked against
SONAME ``libfoo.so.1`` will continue to work even when ``libfoo.so.2`` is
installed — because they never reference ``libfoo.so.2``.

The ``ldd`` command
^^^^^^^^^^^^^^^^^^^

The ``ldd`` command prints the shared library dependencies of an
executable. It is the first tool you reach for when a program refuses to
run with a cryptic error like "cannot open shared object file."

.. code-block:: bash

   $ ldd /bin/bash
       linux-vdso.so.1 (0x00007ffe3b7e0000)
       libtinfo.so.6 => /lib/x86_64-linux-gnu/libtinfo.so.6 (0x00007f8a1a800000)
       libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007f8a1a400000)
       /lib64/ld-linux-x86-64.so.2 (0x00007f8a1ae00000)

Breaking down the output:

* ``linux-vdso.so.1`` — A virtual dynamic shared object (VDSO) that the
  kernel maps into every process's address space to accelerate certain
  system calls (e.g., ``gettimeofday``). It has no path because it does
  not exist on disk.
* ``libtinfo.so.6 => /lib/.../libtinfo.so.6`` — The terminal information
  library. The ``=>`` shows the **actual path** resolved by the dynamic
  linker.
* ``libc.so.6 => /lib/.../libc.so.6`` — The C standard library.
* ``/lib64/ld-linux-x86-64.so.2`` — The dynamic linker itself (it is a
  dependency of every dynamically linked executable).

.. caution::

   ``ldd`` works by setting an environment variable (``LD_TRACE_LOADED_OBJECTS=1``)
   that causes the dynamic linker to print dependencies rather than run the
   program. For untrusted binaries, use ``objdump -p <binary> | grep NEEDED``
   instead, which reads the ELF headers without executing anything.

----------------------------------------
5.1.3 The Dynamic Linker and ``ldconfig``
----------------------------------------

When a program starts, the kernel loads the executable into memory, then
transfers control to **the dynamic linker** (the ``.interp`` section of
the ELF binary points to its path).

The dynamic linker's job:

1. Read the list of needed shared libraries from the ``DT_NEEDED`` entries
   in the ELF dynamic section.
2. For each library, search the **library search path** and load the first
   match.
3. Resolve all symbols (relocate the code).
4. Call each library's initialization code (if any).
5. Transfer control to the program's ``_start`` entry point.

The search order is:

1. ``DT_RPATH`` — embedded in the executable (deprecated).
2. ``LD_LIBRARY_PATH`` — the runtime environment variable (see below).
3. ``DT_RUNPATH`` — embedded in the executable (modern replacement for
   ``DT_RPATH``, searched *after* ``LD_LIBRARY_PATH``).
4. ``/etc/ld.so.cache`` — the compiled binary cache of the library search
   paths.
5. ``/lib``, ``/usr/lib`` (fallback).

The ``ldconfig`` command
^^^^^^^^^^^^^^^^^^^^^^^^

``ldconfig`` is the system utility that maintains ``/etc/ld.so.cache``.
It scans the trusted library directories (configured in ``/etc/ld.so.conf``
and its included files) and creates symlinks for SONAMEs.

.. code-block:: bash

   # See which directories are scanned
   $ cat /etc/ld.so.conf
   include /etc/ld.so.conf.d/*.conf

   $ ls /etc/ld.so.conf.d/
   libc.conf
   x86_64-linux-gnu.conf

   $ cat /etc/ld.so.conf.d/x86_64-linux-gnu.conf
   /usr/lib/x86_64-linux-gnu

   # After installing a new shared library, refresh the cache
   $ sudo ldconfig

   # See all cached libraries and their SONAMEs
   $ ldconfig -p | head -20

.. warning::

   Failing to run ``ldconfig`` after manually installing a shared library
   is the most common cause of the dreaded ``error while loading shared
   libraries: libfoo.so.1: cannot open shared object file``. The library
   exists on disk, but ``ld.so.cache`` does not know about it.

--------------------------------------------
5.1.4 The ``LD_LIBRARY_PATH`` Environment Variable
--------------------------------------------

``LD_LIBRARY_PATH`` is a colon-separated list of directories that the
dynamic linker searches *before* the system library cache. It is a
powerful and dangerous tool.

.. code-block:: bash

   # Temporarily add a custom library path
   $ export LD_LIBRARY_PATH=/opt/myapp/lib:$LD_LIBRARY_PATH
   $ ./myapp

Use cases:

* **Development:** Testing a new version of a library without installing
  it system-wide.
* **Application bundling:** Running an application that ships with its own
  versions of libraries (common in commercial Linux software).
* **Debugging:** Replacing a system library with a debug build.

Security implications
^^^^^^^^^^^^^^^^^^^^^

``LD_LIBRARY_PATH`` is a classic **preload attack vector**. An attacker who
can write a malicious library to a directory and set ``LD_LIBRARY_PATH``
can hijack any function call in any program.

For this reason:

* ``LD_LIBRARY_PATH`` is **ignored for setuid binaries** — the dynamic
  linker silently drops it when running a program with elevated
  privileges.
* Container runtimes (Docker, Podman) often sanitize or clear
  ``LD_LIBRARY_PATH``.
* Most modern packaging systems (including Flatpak, Snap, and Nix)
  completely bypass ``LD_LIBRARY_PATH`` by using their own library
  resolution mechanisms.

.. note::

   There is also ``LD_PRELOAD``, which lets you force-load specific
   libraries *before* any others. This is used legitimately by tools like
   ``libeatmydata`` (to skip fsync calls for faster builds) and
   maliciously by rootkits. The same setuid restriction applies.

----------------------------------------------
5.1.5 Symbol Versioning and ABI Compatibility
----------------------------------------------

Shared libraries live with a tension: they must evolve (fixing bugs,
adding features), but they must not break the programs that depend on
them. Two mechanisms manage this:

**SONAME versioning (major.minor.micro):**

* **Major version** (``libfoo.so.1`` → ``libfoo.so.2``): Breaking ABI
  change. Old programs must be re-linked or recompiled.
* **Minor version** (``libfoo.so.1.1`` → ``libfoo.so.1.2``): Backward
  compatible addition. Old binaries still work.
* **Micro/patch version** (``libfoo.so.1.1.3`` → ``libfoo.so.1.1.4``):
  Bug fix, no API/ABI change.

**Symbol versioning (GNU symbol versioning):**

ELF shared libraries can attach version information to individual symbols.
This allows a single library to export different versions of the same
function, maintaining backward compatibility indefinitely.

.. code-block:: bash

   # See versioned symbols in libc
   $ objdump -T /lib/x86_64-linux-gnu/libc.so.6 | grep -E "GLIBC_2\.[0-9]+"

   # Check which version of glibc is needed by a binary
   $ objdump -p /bin/bash | grep -i "glibc\|needed"

Output::

   version  ...
   NEEDED               libc.so.6
   NEEDED               libtinfo.so.6

Each ``NEEDED`` entry may include a minimum version requirement, ensuring
the binary only runs with a compatible library.

----------------------------------------------
5.1.6 Practical Tooling: Inspecting Libraries
----------------------------------------------

The following commands form your library diagnostic toolkit:

.. list-table:: Shared library inspection tools
   :header-rows: 1

   * - Command
     - Purpose
     - Example
   * - ``ldd <binary>``
     - Show dynamic dependencies
     - ``ldd /usr/bin/ssh``
   * - ``ldconfig -p``
     - List cached libraries
     - ``ldconfig -p | grep libssl``
   * - ``objdump -p <binary>``
     - Read ELF dynamic section (safe for untrusted files)
     - ``objdump -p /bin/ls | grep NEEDED``
   * - ``readelf -d <binary>``
     - Read ELF dynamic section
     - ``readelf -d /bin/ls``
   * - ``nm -D <library>``
     - List dynamic symbols exported by a library
     - ``nm -D /lib/x86_64-linux-gnu/libc.so.6 | grep printf``
   * - ``patchelf``
     - Modify RPATH/RUNPATH and interpreter of ELF binaries
     - ``patchelf --set-rpath /opt/lib ./myapp``

.. code-block:: bash

   # Example: find which package provides a missing library
   # Debian/Ubuntu
   $ dpkg -S libcrypto.so.1.1
   libssl1.1: /usr/lib/x86_64-linux-gnu/libcrypto.so.1.1

   # RHEL/Fedora
   $ rpm -qf /usr/lib64/libcrypto.so.1.1
   openssl-libs-1.1.1k-2.fc34.x86_64

   # Arch Linux
   $ pacman -Qo /usr/lib/libcrypto.so.1.1
   /usr/lib/libcrypto.so.1.1 is owned by openssl 1.1.1k-1

------------------------------------------------
5.1.7 Summary and Key Principles
------------------------------------------------

The software lifecycle — source → compilation → linkage → packaging →
distribution → installation → execution — is the framework that every
package manager operates within. The shared library infrastructure is the
critical substructure that makes package management both necessary and
challenging.

**Key takeaways for the system administrator:**

1. **Dynamic linking saves resources** but introduces **dependency hell**
   — the problem of satisfying a consistent set of library versions across
   an entire system. This is the problem package managers exist to solve.
2. **SONAMEs are the ABI contract.** A program linked against
   ``libfoo.so.1`` will work with any ``libfoo.so.1.x.y``, but not with
   ``libfoo.so.2``.
3. **``ldconfig`` is your friend.** Always run it after manually
   installing libraries.
4. **``LD_LIBRARY_PATH`` is a temporary debug tool.** Never rely on it
   for production deployment; use RPATH, RUNPATH, or a proper package
   manager instead.
5. **The ``ldd`` output tells the whole story** — a missing library shows
   as "not found." When diagnosing "command not found" vs. "library not
   found," always check ``ldd``.

In the next section, we explore the most widely deployed solution to the
dependency problem: **traditional binary package managers** like
``dpkg``/``apt`` and ``rpm``/``dnf``.
