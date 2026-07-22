.. _ch10-memory-dynamics:

###########################################################
10.3  Memory Dynamics
###########################################################

.. epigraph::

   "All problems in computer science can be solved by another level of
   indirection, except for the problem of too many levels of indirection."
   — David Wheeler

Memory is the performance engineer's most treacherous subsystem. The
difference between a cache hit and a cache miss is three orders of magnitude
in latency (nanoseconds vs. microseconds). The difference between local and
remote NUMA access can be 50%. In this section, we develop a mental model of
the Linux virtual memory subsystem, then apply modern tools to measure and
control memory behaviour.

----------------------------------------------------------------------
10.3.1  Virtual Memory and the Page Cache
----------------------------------------------------------------------

**Virtual memory** gives every process its own linear address space,
abstracted from physical RAM through a **page table** managed by the MMU.
Each page (typically 4 KiB on x86-64; huge pages are 2 MiB or 1 GiB) maps to
a physical frame or is marked as swapped, mapped, or anonymous.

**The Page Cache** is the kernel's mechanism for caching file-backed data.

.. code-block:: console

   $ free -h
                 total        used        free      shared  buff/cache   available
   Mem:            31Gi        18Gi       2.1Gi       456Mi        11Gi        12Gi
   Swap:          2.0Gi       256Mi       1.7Gi

**Reading ``free -h`` correctly:**

- **buff/cache:** Reclaimable memory. Not free, but available under pressure.
- **available:** The estimate of memory available for new applications without
  swapping. This is the column to watch.
- **shared:** ``tmpfs`` and shared memory segments.

For precise inspection, read ``/proc/meminfo`` directly:

.. code-block:: console

   $ cat /proc/meminfo
   MemTotal:       32612312 kB
   MemFree:         2097152 kB
   MemAvailable:   12345678 kB
   Buffers:          456789 kB
   Cached:         10240000 kB
   Active(anon):    8000000 kB
   Inactive(anon):   500000 kB
   Active(file):   12000000 kB
   Inactive(file):  2000000 kB

The distinction between **Active** and **Inactive** is critical. Inactive
pages are the first candidates for reclamation under memory pressure.

----------------------------------------------------------------------
10.3.2  Translation Lookaside Buffers (TLB) and Huge Pages
----------------------------------------------------------------------

**TLB** (Translation Lookaside Buffer) is a hardware cache of recent
page-table translations. A TLB miss forces a page-table walk, costing
tens of nanoseconds. With 4 KiB pages, a 2 GiB workload requires 524,288
page-table entries — the L1 TLB (64–128 entries) will miss catastrophically.

**Huge pages** reduce the number of entries by using larger page sizes.

**Transparent Huge Pages (THP)** — the kernel's automatic promotion of 4 KiB
to 2 MiB pages — is a double-edged sword. The promotion triggers compaction,
which can cause latency spikes. For database workloads, disable THP and use
**explicit huge pages**:

.. code-block:: console

   # Check current THP status
   $ cat /sys/kernel/mm/transparent_hugepage/enabled
   always [madvise] never

   # Reserve explicit huge pages (2 MiB each)
   $ echo 1024 > /proc/sys/vm/nr_hugepages
   $ grep HugePages /proc/meminfo
   HugePages_Total:    1024
   HugePages_Free:     1024

**TLB pressure measurement:**

.. code-block:: console

   $ perf stat -e dTLB-loads,dTLB-load-misses,iTLB-loads,iTLB-load-misses \
       my-application

A TLB miss rate > 1% usually means huge pages would improve performance.

----------------------------------------------------------------------
10.3.3  NUMA Architectures and ``numactl``
----------------------------------------------------------------------

**NUMA** (Non-Uniform Memory Access) is the standard topology for multi-socket
servers. Each CPU socket has its own local memory controller.

**Discover the NUMA topology:**

.. code-block:: console

   $ numactl --hardware
   available: 4 nodes (0-3)
   node 0 cpus: 0 1 2 3 4 5 6 7
   node 0 size: 65536 MB
   node 0 free: 32768 MB
   node 1 cpus: 8 9 10 11 12 13 14 15
   node 1 size: 65536 MB
   node 1 free: 40960 MB

``lstopo`` (from the ``hwloc`` package) provides a graphical topology view:

.. code-block:: console

   $ lstopo --of png > topology.png

**``numastat`` — per-process NUMA access:**

.. code-block:: console

   $ numastat -p $$
   Per-node process memory usage (in MBs)
   PID: 12345 (my-process)
   Node 0 Node 1 Node 2 Node 3 Total
             1024    512     64     32  1632

If memory is on a different node than the executing CPU, every access is a
**NUMA fault**. The ``numa_balancing`` kernel feature migrates pages but adds
overhead.

**Binding with ``numactl``:**

.. code-block:: console

   # Bind to Node 0 CPUs and memory
   $ numactl --cpunodebind=0 --membind=0 my-application

   # Interleave across all nodes
   $ numactl --physcpubind=0-7 --interleave=all my-application

----------------------------------------------------------------------
10.3.4  Modern Memory Management: ``zram`` vs. Traditional Swapping
----------------------------------------------------------------------

**Traditional swapping** writes pages to a block device. Even NVMe (50 µs) is
1000× slower than RAM (80 ns).

**``zram``** creates a compressed block device **in RAM**. Instead of paging
to disk, the kernel compresses infrequently used pages.

.. code-block:: console

   # Enable zram
   $ modprobe zram
   $ echo lz4 > /sys/block/zram0/comp_algorithm
   $ echo 4G > /sys/block/zram0/disksize
   $ mkswap /dev/zram0
   $ swapon -p 100 /dev/zram0   # Higher priority than disk swap

+----------------------------+---------------------------+---------------------------+
| Consideration              | zram                      | Disk swap                 |
+============================+===========================+===========================+
| Speed                      | ~100–500 MB/s compress    | ~2–6 GB/s (NVMe) read     |
+----------------------------+---------------------------+---------------------------+
| Memory saved               | Compression ratio ~2–3×   | Frees RAM entirely        |
+----------------------------+---------------------------+---------------------------+
| CPU cost                   | Moderate (LZ4)            | None                      |
+----------------------------+---------------------------+---------------------------+

----------------------------------------------------------------------
10.3.5  From Kernel OOM Killer to ``systemd-oomd``
----------------------------------------------------------------------

The **kernel OOM killer** fires when the system is critically low on memory.
It is a reactive sledgehammer — the selection algorithm is opaque and not
policy-aware.

**``systemd-oomd``** is a userspace daemon that implements **proactive**
memory pressure management via PSI (Pressure Stall Information).

.. code-block:: console

   # Check PSI memory pressure
   $ cat /proc/pressure/memory
   some avg10=2.35 avg60=1.87 avg300=1.02 total=123456789
   full avg10=0.45 avg60=0.33 avg300=0.15 total=23456789

- **some:** At least one task is stalled waiting on memory.
- **full:** All tasks are stalled (complete system stall).

.. code-block:: console

   # Enable the daemon
   $ systemctl enable --now systemd-oomd

   # View oomd logs
   $ journalctl -u systemd-oomd --since "1 hour ago"

.. admonition:: Why systemd-oomd is preferred over kernel OOM in 2026
   :class: important

   The kernel OOM killer is a *reactive* sledgehammer. ``systemd-oomd`` is a
   *proactive* scalpel. It uses PSI — the same mechanism modern orchestration
   platforms use. If you are running production Linux ≥ 6.0, you should have
   ``systemd-oomd`` enabled.

----------------------------------------------------------------------
10.3.6  Memory USE Checklist
----------------------------------------------------------------------

.. code-block:: console

   # 1. Capacity
   $ free -h
   $ cat /proc/meminfo | grep -E "^(MemTotal|MemAvailable|SwapTotal|SwapFree)"

   # 2. Saturation: swap activity and page fault rate
   $ vmstat 1 5   # si (swap in), so (swap out)
   $ sar -S 1

   # 3. Errors: OOM kills
   $ journalctl -k | grep -i "out of memory\|oom_kill\|oom-killer"

   # 4. TLB efficiency
   $ perf stat -e dTLB-loads,dTLB-load-misses -p PID

   # 5. NUMA balance
   $ numastat -p PID

   # 6. Memory pressure
   $ cat /proc/pressure/memory
