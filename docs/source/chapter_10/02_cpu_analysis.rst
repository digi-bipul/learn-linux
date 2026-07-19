.. _ch10-cpu-analysis:

###########################################################
10.2  CPU Analysis
###########################################################

.. epigraph::

   "You can't optimise what you can't measure."
   — Peter Drucker

The CPU is the most familiar resource in any system, yet it is the most
misunderstood. A "high CPU" alert rarely tells you *why* the CPU is busy — is
it executing user code? Kernel interrupts? Waiting on memory (stalled)? In
this section, we dismantle the CPU abstraction layer by layer, using the USE
method as our guide.

----------------------------------------------------------------------
10.2.1  Demystifying Load Averages
----------------------------------------------------------------------

The **load average** — displayed by ``uptime``, ``top``, and countless
dashboards — is simultaneously the most ubiquitous and most misinterpreted
metric in Linux.

The load average is a tuple of three numbers (1-minute, 5-minute, 15-minute
exponential moving averages) representing the number of **tasks in the
TASK_RUNNING** or **TASK_UNINTERRUPTIBLE** state. That is:

- **TASK_RUNNING:** Threads currently executing on a CPU, or queued waiting
  for a core (the run queue).
- **TASK_UNINTERRUPTIBLE:** Threads waiting on I/O (typically disk I/O or
  NFS), famously called "D-state" tasks. These tasks cannot be killed (not
  even with ``SIGKILL``) and they *inflate* the load average.

This second component is the source of endless confusion. A high load average
does **not** necessarily mean the CPU is saturated. It may mean a disk is
overwhelmed and dozens of processes are stuck in D-state.

.. code-block:: console

   $ uptime
   14:23:17 up 14 days,  3:01,  2 users,  load average: 32.45, 28.12, 22.60

A load of 32 on a 16-core machine means an *average* of 32 tasks are either
running or waiting. 16 of them can run simultaneously; the other 16 are
contending for CPU. This is **saturation** per the USE method. The "proper"
metric is normalised load:

.. math::

   \text{Normalised Load} = \frac{\text{Load Average}}{\text{Number of Cores}}

If normalised load > 1.0, the CPU is saturated on average. If normalised load
is > 1.0 but CPU utilisation (``%user + %system + %iowait``) is low, the
excess tasks are in D-state (I/O bound), and the bottleneck is elsewhere.

**Reading load averages correctly:**

+--------------------------+-----------------------------------------------+
| Scenario                 | Interpretation                                |
+==========================+===============================================+
| Load high, CPU utilisation high          | CPU saturation (compute-bound)    |
+--------------------------+-----------------------------------------------+
| Load high, CPU utilisation low           | I/O saturation (D-state tasks)    |
+--------------------------+-----------------------------------------------+
| Load == number of cores / 2             | Comfortable headroom              |
+--------------------------+-----------------------------------------------+
| Load >> number of cores + high iowait   | Storage subsystem is the bottleneck           |
+--------------------------+-----------------------------------------------+

----------------------------------------------------------------------
10.2.2  Modern Process Viewers: btop, htop, atop
----------------------------------------------------------------------

``htop`` — the incremental upgrade
====================================

``htop`` provides colour-coded output, tree-view (``F5``), per-process
environment variables, and mouse interaction.

.. code-block:: console

   $ htop

``btop`` — the modern upgrade
==============================

``btop++`` (simply ``btop``) is the state of the art in 2026. Written in C++,
it renders GPU stats, per-core utilisation graphs, disk load, network
throughput, and process lists *in a single terminal window*.

.. code-block:: console

   $ btop

``btop`` excels at *visual pattern recognition*. A CPU graph showing one core
pegged at 100% while others idle suggests a single-threaded bottleneck. A
"wall" of cores all at 60% suggests a well-parallelised workload hitting a
shared resource (e.g., memory bandwidth).

``atop`` — the forensic historian
===================================

``atop`` is not just a live viewer; it is a **recording daemon**. The
``atop`` service logs system resource snapshots every 60 seconds to
``/var/log/atop/``.

.. code-block:: console

   $ atop -r /var/log/atop/atop_20260719  # Replay a specific date

----------------------------------------------------------------------
10.2.3  Deep Profiling with the ``perf`` Subsystem
----------------------------------------------------------------------

``perf`` (formally ``perf_events``) is the Linux kernel's built-in profiling
infrastructure. It uses hardware performance counters (PMCs) and kernel
tracepoints.

``perf stat`` — counting events
================================

.. code-block:: console

   $ perf stat -e cycles,instructions,cache-misses,cache-references \
       my-binary

Output::

   Performance counter stats for 'my-binary':

       1,034,567,891      cycles                    # 2.91 GHz
       2,200,123,456      instructions              # 2.13  insn per cycle
            12,345,678      cache-misses              # 3.4% of all cache refs
           345,678,901      cache-references

The **CPI** (cycles per instruction) or its inverse **IPC** (instructions per
cycle) is the single most important CPU efficiency metric.

``perf top`` — live sampling
==============================

.. code-block:: console

   $ perf top

Output (simplified)::

   Samples: 1M  of event 'cycles:P', 4000 Hz
   Event count (approx.): 8501234567
   Overhead  Shared Object        Symbol
     15.2%   kernel.kallsyms      [k] _raw_spin_unlock_irqrestore
     12.8%   libc-2.35.so         [.] __memmove_avx512
      7.1%   nginx                [.] ngx_http_process_request

``perf record`` and ``perf report`` — saved profiles
=====================================================

.. code-block:: console

   # Record for 10 seconds, CPU-wide
   $ perf record -a -g -- sleep 10
   $ perf report -g --stdio

The ``-g`` flag enables **call-graph sampling** — you see not just the hot
function, but the entire call chain.

.. code-block:: console

   # Trace all context switches
   $ perf record -e sched:sched_switch -a
   # Trace system calls by a specific process
   $ perf record -e syscalls:sys_enter_write -p PID

----------------------------------------------------------------------
10.2.4  Multi-Core Analysis with ``mpstat``
----------------------------------------------------------------------

.. code-block:: console

   $ mpstat -P ALL 1

Output::

   22:30:01  CPU   %usr   %nice   %sys   %iowait   %irq   %soft   %steal  %guest  %gnice  %idle
   22:30:02  all   12.5    0.0     3.2      0.5     0.0     0.2      0.0     0.0     0.0   83.6
   22:30:02    0   45.2    0.0     8.1      0.0     0.0     0.0      0.0     0.0     0.0   46.7
   22:30:02    1    2.1    0.0     1.0      0.0     0.0     0.0      0.0     0.0     0.0   96.9
   22:30:02    2   55.3    0.0     7.2      0.0     0.0     0.0      0.0     0.0     0.0   37.5
   22:30:02    3    0.5    0.0     0.2      0.0     0.0     0.0      0.0     0.0     0.0   99.3

**Critical fields:**

- **%usr:** Time running user-space code.
- **%sys:** Time running kernel code.
- **%iowait:** Time the CPU was idle while at least one process had an
  outstanding I/O request. A *hint*, not a precise metric.
- **%steal:** In virtualised environments, time the hypervisor ran another
  vCPU. Persistent steal > 10% means overcommitment.
- **%idle:** CPU has no runnable tasks.

----------------------------------------------------------------------
10.2.5  Putting It Together: CPU USE Checklist
----------------------------------------------------------------------

.. code-block:: console

   # 1. Load average (saturation)
   $ uptime

   # 2. Per-core utilisation breakdown
   $ mpstat -P ALL 1 3

   # 3. Top processes by CPU
   $ btop    # or htop

   # 4. Hot code paths (1 minute sample)
   $ perf top

   # 5. Context switch rate
   $ cat /proc/PID/status | grep voluntary

   # 6. NUMA balance
   $ numastat -p PID
