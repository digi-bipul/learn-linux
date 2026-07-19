.. _ch10-storage-io:

###########################################################
10.4  Storage I/O Profiling
###########################################################

.. epigraph::

   "The cheapest, fastest, and most reliable components of a computer system
   are those that aren't there."
   — Gordon Bell

Storage I/O is the most common bottleneck in real-world production systems.
The transition from HDDs to NVMe has changed the rules: queue depths that were
once deep are now shallow; latencies dropped from ms to µs. Many classic tools
(``iostat`` ``%util``) were designed for the HDD era and can mislead when
applied to NVMe.

----------------------------------------------------------------------
10.4.1  ``iostat`` — The Gateway Tool
----------------------------------------------------------------------

.. code-block:: console

   $ iostat -xz 1
   Linux 6.7.0 (hostname)    07/19/2026    _x86_64_    (32 CPU)

   avg-cpu:  %user   %nice %system %iowait  %steal   %idle
              5.20    0.00    2.10    0.30    0.00   92.40

   Device     r/s     w/s     rkB/s    wkB/s  rrqm/s  wrqm/s  %rrqm  %wrqm \
   await r_await w_await  aqu-sz  rareq-sz  wareq-sz  svctm  %util
   nvme0n1 4500.0 1200.0 512000.0 240000.0 0.0 0.0 0.0 0.0 \
   0.12 0.08 0.25 0.56 113.8 200.0 0.02 11.40

**Critical interpretation:**

- **r/s, w/s:** I/O completions per second (the service rate).
- **await:** Average I/O completion latency in ms. **This is user-perceived
  latency.** Includes queue + service time.
- **r_await, w_await:** Read/write await separately.
- **aqu-sz:** Average queue depth — **USE saturation** metric.
- **svctm:** **Deprecated and meaningless for NVMe.** Do not use.
- **%util:** Percentage of time the device was busy. **For NVMe, %util off 100
  does NOT mean saturation.** An NVMe drive with 64 parallel queues can be
  100% busy with headroom. Watch ``aqu-sz`` and ``await`` instead.

.. admonition:: The NVMe %util paradox
   :class: warning

   On an HDD, ``%util`` saturates at 100% and correlates with latency spikes.
   On an NVMe drive, ``%util`` can hit 100% while the drive processes millions
   of IOPS with sub-millisecond latency. **Do not alert on ``%util`` for NVMe
   drives.** Alert on ``await`` (latency) and ``aqu-sz`` (saturation).

----------------------------------------------------------------------
10.4.2  ``iotop-c`` — Per-Process I/O
----------------------------------------------------------------------

.. code-block:: console

   $ sudo iotop-c -oPa

   Total DISK READ: 12.34 M/s | Total DISK WRITE: 45.67 M/s
      TID  PRIO  USER     DISK READ  DISK WRITE  SWAPIN     IO>    COMMAND
     4567 be/4  postgres  8.00 M/s   2.00 M/s    0.00 %     65.23 % postgres: writer

- **IO>:** Percentage of time the thread spent waiting on I/O.
- **SWAPIN:** Time spent waiting for swap-in (page faults).

----------------------------------------------------------------------
10.4.3  Understanding I/O Wait (``%iowait``)
----------------------------------------------------------------------

``%iowait`` is **not** "the percentage of time the CPU was waiting for I/O."
It is the percentage of time the CPU was *idle* while *at least one* thread
had an outstanding I/O.

**When ``%iowait`` is meaningful:** High ``%iowait`` + high ``await`` + high
``aqu-sz`` = genuine I/O saturation.

**When ``%iowait`` is a distraction:** High ``%iowait`` but low ``await`` and
low ``aqu-sz`` = the application does occasional small reads.

----------------------------------------------------------------------
10.4.4  Modern Multi-Queue I/O Schedulers
----------------------------------------------------------------------

The multi-queue block layer (``blk-mq``) gives each CPU core its own
submission queue, eliminating lock contention and enabling millions of IOPS.

``mq-deadline`` — the safe default
====================================

Bounded latency via per-request deadlines. Default on many distributions.
Use for most workloads, especially traditional databases.

``kyber`` — latency-optimised for fast devices
================================================

Ticket-based scheduler for NVMe. Keeps device queues shallow, reducing
latency for read-heavy workloads. Use for NVMe in latency-sensitive
environments. Not ideal for HDDs.

``bfq`` — fairness-oriented
============================

Budget Fair Queueing. Assigns I/O proportionally per process. Use for
desktops or shared hosting. Higher CPU overhead.

**Checking and changing the scheduler:**

.. code-block:: console

   # Check current scheduler (square brackets = active)
   $ cat /sys/block/nvme0n1/queue/scheduler
   [mq-deadline] kyber bfq none

   # Change scheduler (runtime)
   $ echo kyber > /sys/block/nvme0n1/queue/scheduler

   # Permanent via udev
   $ echo 'ACTION=="add|change", KERNEL=="nvme*", ATTR{queue/scheduler}="kyber"' \
       > /etc/udev/rules.d/60-iosched.rules

----------------------------------------------------------------------
10.4.5  Benchmarking with ``fio`` (Flexible I/O Tester)
---------------------------------------------------------

.. code-block:: console

   $ fio --name=randread --ioengine=io_uring --iodepth=1 \
         --rw=randread --bs=4k --direct=1 --fsync=0 \
         --size=1G --numjobs=1 --runtime=30 --time_based \
         --output-format=json --filename=/dev/nvme0n1

Output (simplified JSON)::

   {
     "jobs": [{
       "read": {
         "io_bytes": 1073741824,
         "bw": "350.2MiB/s",
         "iops": 89651,
         "lat_ns": {
           "min": 8200,
           "max": 245000,
           "mean": 11153.45,
           "percentile": {
             "p50": 10500,
             "p90": 13000,
             "p99": 18000,
             "p99.9": 45000,
             "p99.99": 120000
           }
         }
       }
     }]
   }

**Why ``io_uring``?** Since Linux 5.1, ``io_uring`` uses shared ring buffers
to submit and complete I/O without per-operation system calls. Strictly
superior to ``libaio``.

**Key parameters mathematically:**

- **iodepth:** Concurrency (in-flight I/O). Maps to Little's Law.
- **numjobs:** Thread count.
- **direct=1:** Bypasses the page cache.

----------------------------------------------------------------------
10.4.6  Storage I/O USE Checklist
----------------------------------------------------------------------

.. code-block:: console

   # 1. Device-level utilisation, saturation, errors
   $ iostat -xz 1
   $ grep . /sys/block/nvme0n1/device/nvme*/smart/error_count

   # 2. Per-process I/O
   $ sudo iotop-c -oPa

   # 3. I/O scheduler
   $ cat /sys/block/*/queue/scheduler

   # 4. Latency benchmark
   $ fio --name=latency --ioengine=io_uring --iodepth=1 \
         --rw=randread --bs=4k --direct=1 --size=1G --runtime=10 \
         --output-format=json --filename=/dev/nvme0n1

   # 5. Queue depth scaling
   $ fio --name=scale --ioengine=io_uring --iodepth=1,2,4,8,16,32,64,128,256 \
         --rw=randread --bs=4k --direct=1 --size=1G --runtime=10 \
         --output-format=json --filename=/dev/nvme0n1
