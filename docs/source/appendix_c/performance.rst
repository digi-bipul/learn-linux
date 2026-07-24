.. _app-c-process:

------------------------------------------------------------------------------
Process & Performance Troubleshooting
------------------------------------------------------------------------------

------------------------------------------------------------------------------
The Linux Performance Toolkit (USE Method)

The **USE Method** (Utilization, Saturation, Errors) applies to every resource:

1. **Utilization** — How busy is the resource? (e.g., 90% CPU busy)
2. **Saturation** — How much extra work is queued? (e.g., load average > CPU count)
3. **Errors** — How many errors? (e.g., interface RX errors)

.. list-table:: USE Method Quick Reference
   :header-rows: 1
   :widths: 15 25 30 30

   * - Resource
     - Utilization check
     - Saturation check
     - Errors check
   * - CPU
     - ``top``, ``mpstat -P ALL``
     - ``loadavg``, ``perf sched``
     - ``dmesg`` (machine check exceptions)
   * - Memory
     - ``free -m``, ``/proc/meminfo``
     - ``vmstat 1`` (si/so), ``sar -B``
     - ``dmesg`` (OOM killer)
   * - Disk I/O
     - ``iostat -xz 1``
     - ``sar -d``, ``iotop``
     - ``smartctl -a``, ``dmesg`` (disk errors)
   * - Network
     - ``sar -n DEV 1``, ``ethtool``
     - ``sar -n TCP,ETCP 1``, ``ss``
     - ``ip -s link``, ``netstat -i``
   * - Filesystem
     - ``df -h``
     - ``df -i``
     - ``dmesg`` (filesystem errors)

------------------------------------------------------------------------------
CPU Troubleshooting

.. code-block:: bash
   :caption: Identifying CPU bottlenecks

   # Real-time CPU usage per core
   mpstat -P ALL 1

   # Top processes by CPU
   top -b -n 1 | head -30          # Batch mode, one iteration
   ps aux --sort=-%cpu | head -10

   # Load average interpretation
   cat /proc/loadavg
   # load average: 4.23, 5.10, 4.80
   # If load > number of CPU cores for sustained periods → overloaded
   nproc                       # Number of CPU cores

   # Context switch rate (high = possible issue)
   vmstat 1 5                  # Column: cs (context switches)

   # Run queue length (procs in 'r' column)
   vmstat 1 5
   # If 'r' consistently > number of cores → CPU saturation

   # High CPU but low load: spinning on a lock (check with perf)
   sudo perf top                     # Live profiling
   sudo perf record -a -g sleep 10   # Record system-wide stack traces
   sudo perf report                  # Analyse recorded data

   # Zombie processes (defunct, waiting for parent to reap)
   ps aux | grep -w Z
   # Fix: kill the parent process (if safe): kill -HUP <parent_pid>
   # Or reboot if children can't be reaped

.. rubric:: CPU frequency scaling & throttling

.. code-block:: bash

   # Current CPU frequency
   cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq

   # Governor (performance, powersave, ondemand, conservative, schedutil)
   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

   # Set governor
   echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

   # Check for thermal throttling
   sudo dmesg | grep -i "thermal\|throttle\|temperature"
   sensors                            # lm-sensors output

------------------------------------------------------------------------------
Memory Troubleshooting

.. code-block:: bash
   :caption: Memory usage analysis

   # Quick overview
   free -h
   # Look for: available (not just free) — this is what applications can use

   # Detailed breakdown
   cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty|Slab"

   # Process memory usage
   ps aux --sort=-%mem | head -15

   # Top memory consumers
   top -o %MEM -b -n 1 | head -20

   # Swap usage per process
   for file in /proc/*/status; do
       awk '/VmSwap|Name/{printf "%s ", $2} END{print ""}' $file 2>/dev/null
   done | sort -k2 -rn | head -15

   # Check for memory leaks (RSS growth over time)
   pidstat -r 5               # Memory stats every 5 seconds
   watch -n 5 "ps -o pid,rss,command -p <pid>"

   # OOM killer investigation
   sudo journalctl -k | grep -i "oom-killer\|out of memory"
   # Look for: "invoked oom-killer", "Killed process <pid>"
   # The OOM killer dumps memory stats when triggered

.. rubric:: Swap & OOM tuning

.. code-block:: bash

   # Swap usage by priority
   swapon --show

   # Add swap file
   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile
   # Add to /etc/fstab: /swapfile none swap sw 0 0

   # Reduce OOM killer aggressiveness for a process
   # oom_score_adj range: -1000 (never kill) to +1000 (always kill)
   sudo echo -500 > /proc/<pid>/oom_score_adj

   # Check OOM score of processes
   for pid in $(ls /proc/ | grep -E '^[0-9]+$'); do
       echo "$pid $(cat /proc/$pid/comm 2>/dev/null) $(cat /proc/$pid/oom_score 2>/dev/null)"
   done 2>/dev/null | sort -k3 -rn | head -20

------------------------------------------------------------------------------
Disk I/O Troubleshooting

.. code-block:: bash
   :caption: Finding I/O bottlenecks

   # Per-device I/O stats
   iostat -xz 1 5
   # Columns:
   # - %util: time device was busy (100% = saturated; careful: RAID changes meaning)
   # - r/s, w/s: read/write requests per second
   # - rkB/s, wkB/s: throughput
   # - await: average response time (ms) — >10ms may indicate problem
   # - svctm: average service time (older metric, less useful)
   # - aqu-sz: average queue size (should be close to 0)

   # Per-process I/O
   iotop -oP                     # Show only processes doing I/O
   iotop -k                      # Display in KB/s

   # I/O latency histogram (requires kernel 4.3+)
   sudo echo 'hist:keys=pid:vals=delta' > /sys/fs/bpf/<some_path>

   # Check for I/O errors
   sudo dmesg | grep -i "ata\|scsi\|i/o error\|buffer I/O\|sd."
   cat /sys/block/sda/device/timeout

   # Identify which file a process is writing to
   sudo lsof -p <pid> | grep REG | sort -k7 -rn | head -10

   # Directory-level I/O usage
   sudo iotop -oPu <user>

.. rubric:: I/O scheduling

.. code-block:: bash

   # Check I/O scheduler
   cat /sys/block/sda/queue/scheduler
   # Typical: [mq-deadline] none (NVMe), bfq, kyber

   # Set scheduler (for rotational HDDs, mq-deadline or bfq work well)
   echo bfq | sudo tee /sys/block/sda/queue/scheduler

   # Persistent via udev rule (/etc/udev/rules.d/60-iosched.rules):
   # ACTION=="add|change", KERNEL=="sd*", ATTR{queue/scheduler}="bfq"

------------------------------------------------------------------------------
Process Tracing & Debugging

.. list-table:: Process debugging tools
   :header-rows: 1
   :widths: 15 30 55

   * - Tool
     - Example
     - Purpose
   * - ``strace``
     - ``strace -p 12345 -e trace=network``
     - Trace system calls (files, network, processes)
   * - ``ltrace``
     - ``ltrace -p 12345``
     - Trace library calls
   * - ``gdb``
     - ``gdb -p 12345``
     - Attach to running process, inspect memory, backtrace
   * - ``perf``
     - ``perf top -p 12345``
     - CPU profiling, hardware counters, tracepoints
   * - ``lsof``
     - ``lsof -i :80``
     - List open files (sockets, pipes, regular files)
   * - ``stap`` (systemtap)
     - ``stap -e 'probe syscall.open { printf("%s\n", filename) }'``
     - Dynamic kernel tracing (advanced)
   * - ``bpftrace``
     - ``bpftrace -e 'tracepoint:syscalls:sys_enter_open { printf("%s\n", str(args->filename)); }'``
     - eBPF-based tracing (modern, safe for production)

.. code-block:: bash
   :caption: strace common use cases

   # Trace all system calls for a command
   strace -f -o trace.log ./myapp

   # Trace only file operations
   strace -e trace=file -p 12345

   # Trace only network operations
   strace -e trace=network -p 12345

   # Show only errors
   strace -e trace=file -e fault=all -p 12345

   # Show timing per syscall
   strace -T -p 12345

   # Summary of syscall counts and times
   strace -c -p 12345           # Run for a while, then Ctrl+C

   # Follow forks and show PIDs
   strace -f -p 12345

.. code-block:: bash
   :caption: lsof — what is this process doing?

   # All files opened by a process
   lsof -p 12345

   # Who is listening on port 80?
   lsof -i :80 -s TCP:LISTEN

   # All network connections
   lsof -i TCP -s TCP:ESTABLISHED

   # Which process has a file open
   lsof /var/log/syslog

   # Which process is using a deleted file (disk space not freed)
   lsof +L1

   # User-specific
   lsof -u alice

.. rubric:: Performance analysis checklist

.. code-block:: text

   HIGH CPU:
   1. mpstat -P ALL 1         → which core is busy?
   2. top / htop              → which process?
   3. perf top / perf record  → which function?
   4. strace -c -p <pid>      → what syscalls?
   5. Check for infinite loops, polling, or spinlocks

   HIGH MEMORY:
   1. free -h                 → RAM vs swap usage
   2. ps aux --sort=-%mem     → which process?
   3. cat /proc/meminfo       → detailed breakdown (Slab, PageTables)
   4. Find memory leak: watch RSS over time with pidstat -r
   5. Check vm.overcommit settings

   HIGH DISK I/O:
   1. iostat -xz 1            → which device? %util, await
   2. iotop -oP               → which process?
   3. Check for swap thrashing (vmstat si/so)
   4. Check log rotation (logrotate -d)
   5. Check for fsync-heavy workloads (strace -e fsync)

   HIGH NETWORK I/O:
   1. sar -n DEV 1            → throughput per interface
   2. sar -n TCP,ETCP 1       → TCP stats (retransmits, segments)
   3. nethogs / iftop         → per-process bandwidth
   4. tcpdump -i eth0 -w cap.pcap → detailed analysis
   5. ss -s                   → socket statistics
