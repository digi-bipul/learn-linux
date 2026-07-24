.. _chapter-11-2:

============================================================
Container Fundamentals (The Deep Core)
============================================================

If you take only one lesson from this chapter, let it be this: **a container is not a
virtual machine**. A container is simply a group of Linux processes that share a kernel
with the host but are presented with an isolated view of the system via **namespaces**
and bounded in resource consumption via **control groups (cgroups)** . There is no
second kernel, no emulated hardware, no hypervisor. A "container engine" (Docker,
Podman, runc, containerd) is nothing more than a sophisticated orchestrator of kernel
primitives that you, the Linux professional, can invoke directly from the command line.

In this section, we strip away the tooling and examine the raw kernel machinery. By the
end, you will be able to construct a fully isolated container environment using nothing
but ``unshare``, ``pivot_root``, and ``echo`` into cgroup files.

Linux Namespaces: The Illusion of Isolation
===================================================

A **namespace** wraps a global system resource so that processes inside the namespace
see it as a private, independent instance. There are currently **eight namespaces**
in the Linux kernel:

.. list-table:: Linux Namespaces (as of kernel 6.x)
   :header-rows: 1
   :widths: 10 20 30 40

   * - #.
     - Namespace
     - Isolates
     - ``clone()`` flag
   * - 1
     - Mount (``mnt``)
     - Filesystem mount points
     - ``CLONE_NEWNS``
   * - 2
     - Process ID (``pid``)
     - Process number space
     - ``CLONE_NEWPID``
   * - 3
     - Network (``net``)
     - Network devices, stacks, ports
     - ``CLONE_NEWNET``
   * - 4
     - Interprocess Comm. (``ipc``)
     - System V IPC, POSIX message queues
     - ``CLONE_NEWIPC``
   * - 5
     - UTS (``uts``)
     - Hostname, domain name
     - ``CLONE_NEWUTS``
   * - 6
     - User (``user``)
     - UID/GID mappings (user ID inside vs outside)
     - ``CLONE_NEWUSER``
   * - 7
     - Cgroup (``cgroup``)
     - Cgroup root directory (virtualisation of cgroupfs)
     - ``CLONE_NEWCGROUP``
   * - 8
     - Time (``time``)
     - System time (``CLOCK_MONOTONIC``, ``CLOCK_BOOTTIME``)
     - ``CLONE_NEWTIME``

.. note::
   The **time namespace** was the most recent addition, merged in Linux 5.6 (2020). It
   allows containers to have a different view of system time — useful for checkpoint/
   restore and for adjusting monotonic clock offsets without affecting the host.

Every process has a namespace membership for each type. When a process is created with
``clone()`` and the appropriate ``CLONE_NEW*`` flags (or later joined via ``setns()``),
it enters a new or existing namespace.

**Inspecting current namespaces:**

.. code-block:: bash

   # List the namespaces of the current process
   ls -l /proc/self/ns/

   # Output (example):
   # lrwxrwxrwx 1 root root 0 Mar 10 10:00 cgroup -> 'cgroup:[4026531835]'
   # lrwxrwxrwx 1 root root 0 Mar 10 10:00 ipc -> 'ipc:[4026531839]'
   # lrwxrwxrwx 1 root root 0 Mar 10 10:00 mnt -> 'mnt:[4026531840]'
   # lrwxrwxrwx 1 root root 0 Mar 10 10:00 net -> 'net:[4026531942]'
   # lrwxrwxrwx 1 root root 0 Mar 10 10:00 pid -> 'pid:[4026531836]'
   # lrwxrwxrwx 1 root root 0 Mar 10 10:00 time -> 'time:[4026531834]'
   # lrwxrwxrwx 1 root root 0 Mar 10 10:00 user -> 'user:[4026531837]'
   # lrwxrwxrwx 1 root root 0 Mar 10 10:00 uts -> 'uts:[4026531838]'

Each namespace is identified by an **inode number** (e.g., ``4026531835``). Two
processes sharing the same inode number for a namespace type are in the same namespace.

**Mount Namespace (CLONE_NEWNS) — The oldest namespace:**

The mount namespace isolates the set of filesystem mount points visible to a process.
When a process creates a new mount namespace, it gets a copy of the parent's mount
table, but subsequent mounts and unmounts inside the namespace are invisible outside.

.. note::
   Historically, the mount namespace was the *only* namespace (hence the flag
   ``CLONE_NEWNS`` — "new namespace"). All other namespaces were added later.

**PID Namespace (CLONE_NEWPID):**

Processes inside a PID namespace see themselves as PID 1 and cannot see processes
outside. However, from the host perspective, the same processes have normal PID
numbers greater than 1. This is critical for init systems inside containers — a
process that thinks it is PID 1 will handle orphaned children and respond to
``SIGTERM`` properly.

.. warning::
   A process running as PID 1 inside a container must have an init-like behaviour:
   it must reap orphaned zombie processes and forward signals. This is why many
   containers include a minimal init (tini, dumb-init), and why a naive ``sleep``
   as PID 1 can cause zombie accumulation.

**Network Namespace (CLONE_NEWNET):**

Each network namespace has its own:

* Network interfaces (including ``lo``, ``eth0``, etc.)
* Routing tables (``ip route``)
* ARP tables
* Netfilter/iptables rules
* Socket buffers and the networking stack itself

When you create a container with Docker, it creates a new network namespace with only
a ``lo`` interface (down by default). Docker then creates a **veth pair** — a virtual
ethernet cable — with one end in the container's namespace and the other attached to a
bridge (``docker0``) in the host namespace.

**User Namespace (CLONE_NEWUSER):**

The user namespace maps UIDs and GIDs between the container and the host. A process
can be **root (UID 0) inside** the container while being **an unprivileged user** on
the host. This is the foundation of **rootless containers**.

The mapping is defined in ``/proc/<pid>/uid_map`` and ``/proc/<pid>/gid_map``:

.. code-block:: bash

   # Inside a rootless container, uid_map might look like:
   cat /proc/self/uid_map
   #        0     1000        1
   #        ^     ^          ^
   #        |     |          Number of contiguous UIDs mapped
   #        |     Host UID (1000 = the user who created the container)
   #        Container UID (0 = root inside)

This means UID 0 inside the container maps to UID 1000 on the host. The process has
zero effective privileges on the host — any resource access is governed by the
host UID's capabilities.

.. note::
   The user namespace is the **only** namespace that can be created by an unprivileged
   user (no ``CAP_SYS_ADMIN`` required) since Linux 3.8. All other namespaces require
   ``CAP_SYS_ADMIN`` *unless* they are created inside a user namespace, where the
   process already has reduced capabilities.

**Time Namespace (CLONE_NEWTIME):**

Added in Linux 5.6, the time namespace allows each container to have its own offset
for ``CLOCK_MONOTONIC`` and ``CLOCK_BOOTTIME``. This is essential for:

* **Checkpoint/restore (CRIU):** When restoring a container, monotonic time must
  continue from where it left off, not jump to the current host time.
* **Consistent logging:** Log timestamps are relative to the container's boot epoch.
* **Testing:** Simulating time passage without affecting the host clock.

Control Groups v2: The Resource Governor
================================================

Namespaces provide isolation but not enforcement. A container that sees its own PID
namespace can still consume 100% of all CPUs and exhaust all host memory. **Control
groups (cgroups)** impose limits.

**Cgroups v1 vs v2:**

Linux has transitioned to **cgroups v2** (unified hierarchy), which became the default
in systemd v247+ and was adopted by all major distributions by 2023. The key
differences:

* **Unified hierarchy:** A single tree under ``/sys/fs/cgroup``, replacing the
  multiple per-controller trees of v1.
* **No more ``tasks`` file:** Processes are managed through ``cgroup.procs`` and
  ``cgroup.threads``.
* **No more ``release_agent``:** Delegate responsibility to user-space managers.
* **``no internal processes`` constraint:** Only leaf cgroups can contain processes;
  internal nodes serve only as policy ancestors.

.. warning::
   **Cgroups v1 is deprecated.** As of 2026, all major container runtimes (runc,
   crun, containerd) use cgroups v2 by default. On systems still running v1, run
   ``systemd-cgls`` to verify, and consider migrating with the kernel parameter
   ``systemd.unified_cgroup_hierarchy=1``.

**The cgroups v2 hierarchy:**

.. code-block:: bash

   /sys/fs/cgroup/
   ├── cgroup.controllers        # Available controllers (cpu, memory, io, pids, etc.)
   ├── cgroup.subtree_control    # Controllers active for child cgroups
   ├── cgroup.procs              # Processes in this (root) cgroup
   ├── cpu/                      # Subtree for CPU control
   ├── memory/                   # Subtree for memory control
   ├── io/                       # Subtree for I/O control
   ├── system.slice/             # Systemd service cgroups
   │   ├── sshd.service/
   │   └── docker-<hash>.scope/
   └── user.slice/
       └── user-1000.slice/
           └── ...

**Limiting memory for a container manually:**

.. code-block:: bash

   # 1. Create a cgroup for our "container"
   sudo mkdir /sys/fs/cgroup/mycontainer

   # 2. Enable the memory controller for this subtree
   #    (unless already enabled in the parent)
   echo "+memory" | sudo tee /sys/fs/cgroup/cgroup.subtree_control

   # 3. Set a memory limit of 256 MB
   echo 268435456 | sudo tee /sys/fs/cgroup/mycontainer/memory.max

   # 4. Add our container process to this cgroup
   echo $CONTAINER_PID | sudo tee /sys/fs/cgroup/mycontainer/cgroup.procs

   # 5. If the process exceeds 256 MB, the kernel will invoke the OOM killer
   cat /sys/fs/cgroup/mycontainer/memory.events
   #   low 0
   #   high 0
   #   max 0
   #   oom 0
   #   oom_kill 0

**CPU limiting:**

.. code-block:: bash

   # CPU weight (relative share, default 100)
   echo 200 | sudo tee /sys/fs/cgroup/mycontainer/cpu.weight

   # CPU quota + period (max 500ms of CPU per 1000ms period = 0.5 CPU)
   echo 50000 | sudo tee /sys/fs/cgroup/mycontainer/cpu.max   # 50ms per 100ms
   cat /sys/fs/cgroup/mycontainer/cpu.max
   #  50000 100000

**IO limiting:**

.. code-block:: bash

   # Limit write bandwidth on /dev/sda to 10 MB/s (riomax/rbps)
   echo "8:0  rbps=0 wbps=10485760" | sudo tee /sys/fs/cgroup/mycontainer/io.max

**PIDs limit (prevent fork bombs):**

.. code-block:: bash

   echo 512 | sudo tee /sys/fs/cgroup/mycontainer/pids.max

Root Filesystem Isolation: chroot vs pivot_root
=======================================================

Namespaces and cgroups isolate processes and resources, but a container also needs an
**isolated root filesystem** — a different ``/`` directory containing its own
``/bin``, ``/lib``, ``/etc``, and so on. Two system calls provide this:

``chroot(2)``
    Changes the root directory of the calling process. It is simple but has a critical
    flaw: if a process holds a file descriptor to a directory outside the new root
    (e.g., ``/`` was opened before the ``chroot``), it can "escape" the jail via
    ``fchdir()``. Moreover, ``chroot`` does not affect child processes that share the
    filesystem context via ``clone()`` — they can still see the old root.

``pivot_root(2)``
    Moves the current root to a directory (``put_old``) and puts a new directory at
    the root (``new_root``). This is **atomic** — there is no way for a process to
    hold an open fd to the old root because the kernel swaps the mount points at the
    VFS layer. After ``pivot_root``, the old root is still accessible at ``put_old``
    but only to processes that know the path.

**Why container runtimes use pivot_root:**

Every OCI-compliant container runtime (runc, crun, youki) calls ``pivot_root``, not
``chroot``. The reason is security: ``pivot_root`` guarantees that the running process
cannot escape back to the host's filesystem even if it retains elevated privileges.

**Building a container by hand (the "no-Docker" container):**

Let us construct an isolated process using nothing but shell commands and kernel
primitives. This is exactly what ``runc`` does when it runs an OCI bundle.

.. code-block:: bash

   #!/bin/bash
   # ─── Container from scratch ───

   IMAGE="ubuntu:24.04"
   CIDIR="/tmp/container-test"
   ROOTFS="${CIDIR}/rootfs"

   # 1. Prepare a root filesystem
   mkdir -p "$ROOTFS"
   apt-get download $(apt-cache depends --recurse --no-recommends \
       --no-suggests --no-conflicts --no-breaks --no-replaces \
       --no-enhances --no-pre-depends bash coreutils | grep "^ " | tr -d ' ')
   for pkg in *.deb; do dpkg-deb -x "$pkg" "$ROOTFS"; done
   rm -f *.deb

   # 2. Enter a new set of namespaces
   #    -m: mount, -p: pid, -n: net, -i: ipc, -u: uts, -U: user
   unshare \
       --mount \
       --pid \
       --net \
       --ipc \
       --uts \
       --user \
       --fork \
       --mount-proc \
       --root="$ROOTFS" \
       /bin/bash -c '
           # Inside the new namespace now
           # 3. Set hostname
           hostname container-from-scratch

           # 4. Mount /proc (new PID namespace needs this)
           mount -t proc proc /proc

           # 5. Run a command
           echo "Hello from inside the container!"
           echo "PID: $$"
           echo "Hostname: $(hostname)"
           ps aux

           # 6. Stay alive
           exec /bin/bash
       '

   # Cleanup
   unshare -m pf --root="$ROOTFS" /bin/bash  # If needed

.. note::
   The ``--mount-proc`` flag to ``unshare`` automatically mounts a new ``procfs``
   inside the new PID namespace. Without this, ``ps`` inside the container would
   still show host processes.

**The OCI Runtime Specification:**

The Open Container Initiative (OCI) defines an interoperable standard for container
formats and runtimes. The **runtime-spec** specifies:

* The filesystem bundle (a directory with ``config.json`` and a root filesystem).
* The ``config.json`` describes namespaces, cgroups, mounts, capabilities, and
  environment variables.

Here is a minimal ``config.json`` for a container that runs ``/bin/sh``:

.. code-block:: json

   {
     "ociVersion": "1.1.0",
     "process": {
       "terminal": true,
       "user": {"uid": 0, "gid": 0},
       "args": ["/bin/sh"],
       "env": ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"],
       "cwd": "/",
       "capabilities": {"bounding": ["CAP_CHOWN", "CAP_DAC_OVERRIDE"]},
       "rlimits": [{"type": "RLIMIT_NOFILE", "hard": 1024, "soft": 1024}]
     },
     "root": {
       "path": "rootfs",
       "readonly": true
     },
     "hostname": "oci-container",
     "linux": {
       "namespaces": [
         {"type": "pid"},
         {"type": "network"},
         {"type": "mount"},
         {"type": "uts"},
         {"type": "ipc"},
         {"type": "user"}
       ],
       "resources": {
         "memory": {"limit": 268435456},
         "cpu": {"shares": 512}
       }
     }
   }

To run this bundle with ``runc``:

.. code-block:: bash

   mkdir -p /tmp/my-bundle/rootfs
   # Copy rootfs contents into rootfs/ ...
   cd /tmp/my-bundle
   cat > config.json
   runc run my-container

The Container Runtime Stack
===================================

Understanding the layers of a container runtime helps demystify the Docker/Podman
ecosystem:

.. code-block:: none

   ┌──────────────────────────────────────────┐
   │        High-level Runtime                │
   │  (Docker Engine, Podman, containerd)     │
   │  - Image management (pull/build/push)    │
   │  - API server (REST/gRPC)                │
   │  - Volume management, networking setup   │
   └──────────────┬───────────────────────────┘
                  │ gRPC (containerd - CRI)
   ┌──────────────┴───────────────────────────┐
   │        Low-level Runtime                 │
   │  (runc, crun, youki, gVisor, Kata)      │
   │  - Reads OCI bundle (config.json)        │
   │  - Creates namespaces & cgroups          │
   │  - Calls pivot_root + exec              │
   └──────────────────────────────────────────┘

* **High-level runtimes** manage images, networking, storage, and expose an API
  (the Docker API or the CRI — Container Runtime Interface used by Kubernetes).
* **Low-level runtimes** actually create the container. ``runc`` is the reference
  implementation (Go); ``crun`` is a faster C implementation; ``youki`` is a Rust
  implementation; ``gVisor`` and ``Kata Containers`` are sandboxed runtimes that
  add an extra isolation layer.

Antipatterns
===================

.. admonition:: Antipattern: Running a Container's Process as Root
   :class: danger

   The number-one container security mistake. By default, Docker containers run as
   root (UID 0). If the container process is compromised, and the user namespace is
   not used, the attacker has UID 0 on the host. **Always create a user inside the
   Dockerfile and switch to it:**

   .. code-block:: dockerfile

      RUN useradd -m -u 1000 appuser
      USER appuser

   Or better, use rootless Podman (see §11.4).

.. admonition:: Antipattern: Storing Secrets in Environment Variables
   :class: danger

   Environment variables are visible via ``/proc/self/environ```, ``docker inspect``,
   and ``kubectl describe pod``. They are inherited by child processes and leak into
   logs. Use ephemeral secrets mounted as files (Kubernetes Secrets, tmpfs) instead.

.. admonition:: Antipattern: Running Multiple Processes in One Container
   :class: warning

   The container philosophy is **one process per container**. Running a full init
   system (systemd) or a process supervisor (supervisord) inside a container
   indicates you are treating the container like a VM. Use Kubernetes Pods to
   co-schedule related processes if they must share a network namespace.

Practical Exercises
==========================

**1. Explore Your Namespaces**

.. code-block:: bash

   # What namespaces am I in?
   ls -l /proc/$$/ns/

   # Compare with another bash process
   ls -l /proc/$(pgrep -u $USER bash | head -1)/ns/

   # Are they the same? Probably yes — processes inherit namespaces from parents.

**2. Create a New UTS and User Namespace**

.. code-block:: bash

   unshare --uts --user --fork /bin/bash
   # Inside:
   hostname container-test
   exec bash  # Start a new shell to see the changed hostname
   whoami     # Should show "nobody" if user namespace is new

**3. Manually Create a Memory Limit**

.. code-block:: bash

   # As root, in a separate terminal
   mkdir /sys/fs/cgroup/demo
   echo "+memory" > /sys/fs/cgroup/cgroup.subtree_control
   echo 52428800 > /sys/fs/cgroup/demo/memory.max   # 50 MB
   echo $$ > /sys/fs/cgroup/demo/cgroup.procs
   # Now this shell is capped at 50 MB. Try allocating 100 MB:
   python3 -c "x = bytearray(100 * 1024 * 1024)"
   # Watch the OOM killer in dmesg
