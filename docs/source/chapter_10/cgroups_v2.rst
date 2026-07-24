.. _ch10-cgroups-v2:

###########################################################
Resource Isolation (cgroups v2)
###########################################################

.. epigraph::

   "The art of programming is the art of organising complexity."
   — Edsger W. Dijkstra

Control Groups (cgroups) are the kernel feature that enables resource
isolation for containers, system services, and user sessions. In 2026,
cgroups v2 is the **only** game in town. The v1 hierarchy — fragmented,
deadlock-prone, and inconsistent — was deprecated in systemd ≥ 242 (2019) and
is no longer supported in any modern distribution. **Teaching cgroups v1 in
2026 is academic archaeology, not engineering.**

----------------------------------------------------------------------
The Unified Hierarchy (cgroups v2)
----------------------------------------------------------------------

In cgroups v2:

1. **Single hierarchy:** All controllers under ``/sys/fs/cgroup/``.
2. **No internal process concurrency:** Cgroups with children cannot have
   processes.
3. **Delegation by design:** Unprivileged users can manage subtrees.
4. **PSI integration:** Per-cgroup pressure stall information.

**Verify your system uses cgroups v2:**

.. code-block:: console

   $ grep cgroup /proc/filesystems
   cgroup2

   $ mount | grep cgroup2
   cgroup2 on /sys/fs/cgroup type cgroup2 (rw,nosuid,nodev,noexec,relatime)

----------------------------------------------------------------------
Exploring the cgroups v2 Tree
----------------------------------------------------------------------

.. code-block:: console

   $ ls -la /sys/fs/cgroup/
   -r--r--r--  1 root root 0 Jul 19 14:00 cgroup.controllers
   -rw-r--r--  1 root root 0 Jul 19 14:00 cgroup.subtree_control
   -rw-r--r--  1 root root 0 Jul 19 14:00 cgroup.procs
   drwxr-xr-x  2 root root 0 Jul 19 14:00 init.scope
   drwxr-xr-x 59 root root 0 Jul 19 14:00 system.slice

**Key files in each cgroup directory:**

+-------------------------+---------------------------------------------------+
| File                    | Purpose                                           |
+=========================+===================================================+
| ``cgroup.procs``        | List of PIDs; write a PID to migrate it.          |
+-------------------------+---------------------------------------------------+
| ``cgroup.controllers``  | Available controllers for this cgroup.            |
+-------------------------+---------------------------------------------------+
| ``cpu.max``             | CPU quota — ``$MAX $PERIOD`` format.              |
+-------------------------+---------------------------------------------------+
| ``memory.max``          | Hard memory limit in bytes.                       |
+-------------------------+---------------------------------------------------+
| ``memory.high``         | Soft limit — reclaim above this.                  |
+-------------------------+---------------------------------------------------+
| ``io.max``              | I/O bandwidth limits (BPS and IOPS).              |
+-------------------------+---------------------------------------------------+
| ``pids.max``            | Maximum number of tasks.                          |
+-------------------------+---------------------------------------------------+

**Reading resource usage:**

.. code-block:: console

   $ cat /sys/fs/cgroup/system.slice/postgresql.service/memory.current
   2462908416
   $ cat /sys/fs/cgroup/system.slice/postgresql.service/cpu.stat
   usage_usec 12345678901234
   nr_throttled 0
   throttled_usec 0

If ``nr_throttled > 0``, the cgroup hit its ``cpu.max`` limit.

----------------------------------------------------------------------
Observing with ``systemd-cgtop``
----------------------------------------------------------------------

.. code-block:: console

   $ systemd-cgtop
   Control Group                                Tasks   %CPU    Memory  Input/s Output/s
   /system.slice/nginx.service                   12    45.2%   456.7M    0B      1.2M
   /system.slice/postgresql.service               8    12.1%     2.3G    234K    1.1M

- **%CPU:** Percentage of *one core* (100% = 1 core, 3200% = 32 cores).
- **Memory:** RSS + page cache + swap.

----------------------------------------------------------------------
Defining Resource Limits with Systemd Slices
----------------------------------------------------------------------

**Limit nginx to 2 CPU cores and 1 GiB of memory:**

.. code-block:: console

   # mkdir -p /etc/systemd/system/nginx.service.d/
   # cat > /etc/systemd/system/nginx.service.d/90-resources.conf << 'EOF'
   [Service]
   CPUQuota=200%
   MemoryMax=1G
   MemoryHigh=800M
   IOWeight=200
   EOF
   # systemctl daemon-reload
   # systemctl restart nginx

**Verifying:**

.. code-block:: console

   $ cat /sys/fs/cgroup/system.slice/nginx.service/cpu.max
   200000 100000    # 200 ms per 100 ms period = 2 cores

**Slice grouping:**

.. code-block:: console

   # /etc/systemd/system/database.slice
   [Slice]
   CPUQuota=400%
   MemoryMax=4G

   # Assign PostgreSQL to the slice
   # /etc/systemd/system/postgresql.service.d/90-slice.conf
   [Service]
   Slice=database.slice

----------------------------------------------------------------------
Container Observability: ``podman stats``
----------------------------------------------------------------------

.. code-block:: console

   $ podman stats -a --no-stream
   ID            NAME      CPU %    MEM USAGE / LIMIT   MEM %    NET I/O
   a1b2c3d4e5f6  webapp    12.5%    234.5MiB / 1GiB    22.9%    12.5MB / 3.2MB

   # Direct cgroup inspection
   $ podman inspect --format '{{.State.CgroupPath}}' webapp
   /machine.slice/libpod-a1b2c3d4e5f6.scope/container

----------------------------------------------------------------------
Why cgroups v1 is Dead
----------------------------------------------------------------------

- **Multiple mount points** with inconsistent behaviour (e.g.,
  ``memory.memsw.limit_in_bytes`` vs. ``memory.limit_in_bytes``).
- **Deadlocks under pressure** — v1's OOM notification was racy.
- **No delegation** — unprivileged containers required complex workarounds.

The Linux cgroup maintainers have been unequivocal: **v1 is unsupported in
kernels ≥ 6.0.** Every major distribution ships with v2 as default.

----------------------------------------------------------------------
cgroups v2 USE Checklist
----------------------------------------------------------------------

.. code-block:: console

   # 1. Confirm cgroups v2 is active
   $ grep cgroup2 /proc/filesystems

   # 2. Explore the tree
   $ ls /sys/fs/cgroup/system.slice/
   $ cat /sys/fs/cgroup/system.slice/*.service/cpu.stat

   # 3. Live view
   $ systemd-cgtop

   # 4. Check limits
   $ systemctl show my-service -p CPUQuota -p MemoryMax -p TasksMax

   # 5. Container cgroups
   $ podman stats --no-stream
