.. _ch10-tracing-ebpf:

###########################################################
Tracing & eBPF (The 2026 Standard)
###########################################################

.. epigraph::

   "eBPF is to Linux what JavaScript is to the web."
   — Brendan Gregg

In the history of systems performance, there is a clear dividing line: before
eBPF and after eBPF. Before eBPF (pre-2014), tracing meant rebuilding a custom
kernel with ``FTRACE``, running ``strace`` with all its overhead, or inserting
``printk``. After eBPF, we can instrument any kernel or application function
in production with overhead measured in single-digit percentage points.

----------------------------------------------------------------------
The Overhead Problem: Why ``strace`` is a Production Anti-Pattern
----------------------------------------------------------------------

``strace`` uses ``ptrace()`` — every system call traps into the kernel twice.
Result: **10x to 100x slowdown** for syscall-heavy workloads.

.. code-block:: console

   # Never run this on production
   $ strace -p $(pidof nginx)

**eBPF runs in kernel context.** No context-switch. Overhead: 1–5% depending
on event rate, not 50–90%.

----------------------------------------------------------------------
eBPF Architecture — A Conceptual Overview
----------------------------------------------------------------------

eBPF is an in-kernel virtual machine. An eBPF program:

1. Is written in restricted C (or bpftrace) and compiled to bytecode.
2. Is loaded via the ``bpf()`` syscall.
3. Is verified (no loops, bounded execution, memory safety).
4. Is JIT-compiled to native code.
5. Attaches to a hook: kprobe, tracepoint, uprobe, XDP, or TC.
6. Writes data to a ring buffer or map.

.. code-block:: text

   +------------------+       +------------------+
   |  bpftrace script |       |  bcc Python tool |
   +--------+---------+       +--------+---------+
            |                          |
      [BCC/bpftrace]            [libbpf Python]
            |                          |
   +--------v--------------------------v---------+
   |          eBPF Verifier & JIT Compiler        |
   +----------------------------------------------+
   |          Kernel Hooks                       |
   |   kprobe | kretprobe | tracepoint | uprobe  |
   +----------------------------------------------+

----------------------------------------------------------------------
``bpftrace`` — One-Liners for the Production SRE
----------------------------------------------------------------------

**Installation:**

.. code-block:: console

   $ apt install bpftrace      # Debian/Ubuntu
   $ dnf install bpftrace      # Fedora/RHEL

**Essential one-liners:**

.. code-block:: console

   # New processes with arguments
   $ bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf("%s %s\n", comm, str(args->filename)); }'

   # Count all system calls system-wide
   $ bpftrace -e 'tracepoint:syscalls:sys_enter_* { @[probe] = count(); }'
   After Ctrl-C:
   @[tracepoint:syscalls:sys_enter_write]: 1234567
   @[tracepoint:syscalls:sys_enter_read]:  987654

   # Read latency distribution (histogram)
   $ bpftrace -e 'tracepoint:syscalls:sys_enter_read { @start[tid] = nsecs; }
                  tracepoint:syscalls:sys_exit_read /@start[tid]/ {
                    @read_latency_us = hist((nsecs - @start[tid]) / 1000);
                    delete(@start[tid]);
                  }'

   # Files opened by PID 1234
   $ bpftrace -e 'tracepoint:syscalls:sys_enter_openat /pid == 1234/ { printf("%s\n", str(args->filename)); }'

   # Block I/O latency distribution
   $ bpftrace -e 'kprobe:blk_account_io_start { @start[arg0] = nsecs; }
                  kretprobe:blk_account_io_done /@start[arg0]/ {
                    @io_latency_us = hist((nsecs - @start[arg0]) / 1000);
                    delete(@start[arg0]);
                  }'

**Anatomy of a bpftrace program:**

::

   kprobe:do_sys_open    # Hook: kernel function entry
   {
     @[comm] = count();  # Action: map indexed by process name
   }

.. admonition:: Tracepoints vs. kprobes
   :class: tip

   **Tracepoints** are stable, documented, preferred. **kprobes** are
   unstable — function names change between kernel versions. Use kprobes only
   when no tracepoint exists.

----------------------------------------------------------------------
The ``bcc`` Toolkit (Brendan Gregg's Legacy)
----------------------------------------------------------------------

**Installation:**

.. code-block:: console

   $ apt install bpfcc-tools    # Debian/Ubuntu
   $ dnf install bcc-tools      # Fedora/RHEL

**Key tools by subsystem:**

+------------------+---------------------------------------------------------+
| Tool             | Purpose                                                 |
+==================+=========================================================+
| **execsnoop**    | New process executions (low overhead).                  |
+------------------+---------------------------------------------------------+
| **biolatency**   | Block I/O latency distribution (histogram).             |
+------------------+---------------------------------------------------------+
| **biotop**       | Top processes by block I/O.                             |
+------------------+---------------------------------------------------------+
| **runqlat**      | CPU run queue latency. Definitive CPU saturation metric.|
+------------------+---------------------------------------------------------+
| **cpuunclaimed** | Time CPU idle but with runnable tasks (steal).          |
+------------------+---------------------------------------------------------+
| **opensnoop**    | File opens per process.                                 |
+------------------+---------------------------------------------------------+
| **tcpretrans**   | TCP retransmissions with stack trace.                   |
+------------------+---------------------------------------------------------+
| **tcpconnect**   | Outgoing TCP connections per process.                   |
+------------------+---------------------------------------------------------+
| **oomkill**      | Track OOM killer events.                                |
+------------------+---------------------------------------------------------+

**Example: runqlat — CPU scheduler latency:**

.. code-block:: console

   $ runqlat
   Tracing run queue latency... Hit Ctrl-C to end.
   ^C
   usecs               : count     distribution
       0 -> 1          : 12345    |****************************************|
       2 -> 3          : 5678     |*****************                       |
       4 -> 7          : 1234     |****                                    |
       8 -> 15         : 456      |*                                       |
      16 -> 31         : 89       |                                        |
      32 -> 63         : 12       |                                        |

Histogram shows the *distribution* of CPU wait times — strictly superior to
load average's single-number average.

**Example: tcpretrans — TCP retransmission biopsy:**

.. code-block:: console

   $ tcpretrans
   TIME     PID    COMM          IP  SRC              DST             STATE
   09:15:23 1234   nginx         4   10.0.0.1:443     10.0.0.2:34567  ESTAB

----------------------------------------------------------------------
Continuous Profiling in Production
----------------------------------------------------------------------

Always-on low-overhead sampling of production code paths. Tools like **Parca**
and **Polar Signals** integrate with eBPF via ``perf``.

**The workflow:**

1. Deploy a profiling agent on every node.
2. Aggregate profiles to a central store.
3. Compare flame graphs across time ("Why is this function slower than last
   week?")
4. Correlate profile deltas with code changes.

**BPF-based continuous profiling overhead:**

- CPU sampling (19 Hz): < 1%
- Memory profiling: 1–3%
- I/O tracing: 1–5%

----------------------------------------------------------------------
When to Use Which Tool
----------------------------------------------------------------------

+----------------------+-----------------------------------+--------------------------+
| Situation            | Tool                              | Why                      |
+======================+===================================+==========================+
| "Why is this process | ``perf top`` or ``bpftrace``      | Sampler or dynamic       |
| using 100% CPU?"     | one-liner counting functions      | tracer                   |
+----------------------+-----------------------------------+--------------------------+
| "What files is this  | ``opensnoop`` (bcc)               | Trace open() with        |
| process opening?"    |                                   | zero overhead            |
+----------------------+-----------------------------------+--------------------------+
| "Why is MySQL slow?" | ``offcputime`` (bcc) — where      | Shows blocked time       |
|                      | time is spent off-CPU             | (I/O, locks, mutex)      |
+----------------------+-----------------------------------+--------------------------+
| "What is the latency | ``biolatency`` (bcc)              | I/O latency distribution |
| of this NVMe drive?" |                                   |                          |
+----------------------+-----------------------------------+--------------------------+
| "Continuous          | Parca / Polar Signals + ``perf``  | Always-on profiling      |
| regression hunting"  | eBPF-based agent                  |                          |
+----------------------+-----------------------------------+--------------------------+

----------------------------------------------------------------------
eBPF USE Checklist
----------------------------------------------------------------------

.. code-block:: console

   # 1. CPU scheduler latency (saturation)
   $ runqlat

   # 2. I/O latency distribution (errors & duration)
   $ biolatency

   # 3. TCP retransmissions (errors)
   $ tcpretrans

   # 4. New process executions (forensics)
   $ execsnoop

   # 5. Top file reads/writes by process
   $ filetop

   # 6. Dynamic tracing: count all syscalls
   $ bpftrace -e 'tracepoint:syscalls:sys_enter_*{ @[probe] = count(); }'

**Further Reading:**

- Brendan Gregg, *BPF Performance Tools* (Addison-Wesley, 2019).
- https://ebpf.io
- https://github.com/iovisor/bcc
- https://github.com/bpftrace/bpftrace
