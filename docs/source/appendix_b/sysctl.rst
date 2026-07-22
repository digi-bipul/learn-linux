.. _app-b-kernel:

------------------------------------------------------------------------------
B.10  Kernel Parameters & Sysctl
------------------------------------------------------------------------------

The Linux kernel exposes hundreds of runtime parameters via the ``sysctl``
interface (``/proc/sys/``). These control networking, memory management,
security, and more — all adjustable without reboot.

------------------------------------------------------------------------------
B.10.1  sysctl Command Reference
------------------------------------------------------------------------------

.. list-table:: sysctl commands
   :header-rows: 1
   :widths: 25 35 40

   * - Command
     - Example
     - Description
   * - ``sysctl -a``
     - ``sysctl -a | grep tcp``
     - List ALL parameters (use ``grep`` to filter)
   * - ``sysctl <param>``
     - ``sysctl net.ipv4.ip_forward``
     - Read a specific parameter
   * - ``sysctl -w``
     - ``sysctl -w net.ipv4.ip_forward=1``
     - Set a parameter (runtime only — lost on reboot)
   * - ``sysctl -p``
     - ``sysctl -p /etc/sysctl.d/99-custom.conf``
     - Load parameters from a file (default: ``/etc/sysctl.conf``)
   * - ``sysctl -n``
     - ``sysctl -n net.ipv4.ip_forward``
     - Print only the value (no key name)

------------------------------------------------------------------------------
B.10.2  Network Security Hardening
------------------------------------------------------------------------------

.. code-block:: bash

   # /etc/sysctl.d/99-network-security.conf

   # --- IP forwarding (enable only if router/gateway) ---
   # net.ipv4.ip_forward = 1

   # --- Reverse-path filtering (strict mode) ---
   # Protects against IP spoofing by verifying packets arrive on the expected interface
   net.ipv4.conf.all.rp_filter = 1
   net.ipv4.conf.default.rp_filter = 1

   # --- Ignore ICMP redirects (prevents MITM via bogus redirects) ---
   net.ipv4.conf.all.accept_redirects = 0
   net.ipv4.conf.default.accept_redirects = 0
   net.ipv6.conf.all.accept_redirects = 0
   net.ipv6.conf.default.accept_redirects = 0

   # --- Ignore source-routed packets ---
   net.ipv4.conf.all.accept_source_route = 0
   net.ipv4.conf.default.accept_source_route = 0
   net.ipv6.conf.all.accept_source_route = 0

   # --- Ignore ICMP echo broadcasts (prevents smurf attacks) ---
   net.ipv4.icmp_echo_ignore_broadcasts = 1

   # --- Ignore bogus ICMP errors ---
   net.ipv4.icmp_ignore_bogus_error_responses = 1

   # --- Enable TCP SYN cookies (protect against SYN floods) ---
   net.ipv4.tcp_syncookies = 1

   # --- Disable ICMP timestamp responses ---
   net.ipv4.tcp_timestamps = 0   # Note: breaks some TCP optimizations; set to 1 if needed

   # --- Reduce connection timeout for half-open connections ---
   net.ipv4.tcp_fin_timeout = 15
   net.ipv4.tcp_tw_reuse = 1

   # --- Limit TCP SYN backlog ---
   net.ipv4.tcp_max_syn_backlog = 2048
   net.ipv4.tcp_syn_retries = 3
   net.ipv4.tcp_synack_retries = 2

   # --- IPv6 privacy extensions (SLAAC privacy) ---
   net.ipv6.conf.all.use_tempaddr = 2
   net.ipv6.conf.default.use_tempaddr = 2

   # --- Disable IPv6 if not needed ---
   # net.ipv6.conf.all.disable_ipv6 = 1
   # net.ipv6.conf.default.disable_ipv6 = 1

   # --- Log martian packets (packets with impossible source addresses) ---
   net.ipv4.conf.all.log_martians = 1
   net.ipv4.conf.default.log_martians = 1

------------------------------------------------------------------------------
B.10.3  Memory & VM Tuning
------------------------------------------------------------------------------

.. code-block:: bash

   # /etc/sysctl.d/99-memory.conf

   # --- OOM behaviour ---
   # 0 = heuristic, 1 = always kill, 2 = trigger panic
   vm.panic_on_oom = 0

   # --- Swappiness (0-100) ---
   # Lower = less swapping (prefer RAM); higher = aggressive swap
   # Default 60; set 10-30 for servers, 1 for low-latency, 100 for desktops
   # vm.swappiness = 10

   # --- VM dirty ratio ---
   # Max % of memory that can be dirty before writing to disk
   vm.dirty_ratio = 30
   vm.dirty_background_ratio = 5

   # --- Out-of-memory killer tuning ---
   # Lower oom_score_adj for important processes (-1000 = never kill)
   # echo -1000 > /proc/pid/oom_score_adj

   # --- Memory overcommit ---
   # 0 = heuristic (default), 1 = always allow, 2 = deny if > commit limit
   vm.overcommit_memory = 0

   # --- Huge pages (for databases, Java, VMs) ---
   # vm.nr_hugepages = 1024

------------------------------------------------------------------------------
B.10.4  File System & Kernel Limits
------------------------------------------------------------------------------

.. code-block:: bash

   # /etc/sysctl.d/99-fs.conf

   # --- Max open files (system-wide) ---
   # Individual process limit set in /etc/security/limits.conf
   fs.file-max = 2097152

   # --- Max number of inotify watches ---
   # Low values break tools like tail, rsync (common on Docker hosts)
   fs.inotify.max_user_watches = 524288

   # --- Max number of inotify instances ---
   fs.inotify.max_user_instances = 512

   # --- Core dumps ---
   # fs.suid_dumpable = 0   # Disable SUID core dumps (security)

   # --- Pid limit ---
   kernel.pid_max = 65536

------------------------------------------------------------------------------
B.10.5  Network Performance Tuning
------------------------------------------------------------------------------

.. code-block:: bash

   # /etc/sysctl.d/99-network-performance.conf

   # --- TCP buffer sizes (auto-tuning limits) ---
   # min, default, max (bytes)
   net.ipv4.tcp_rmem = 4096 131072 16777216
   net.ipv4.tcp_wmem = 4096 65536 16777216

   # --- Enable TCP window scaling ---
   net.ipv4.tcp_window_scaling = 1

   # --- Enable TCP Fast Open (client + server) ---
   # 0 = off, 1 = client only, 2 = server only, 3 = both
   net.ipv4.tcp_fastopen = 3

   # --- Increase backlog queue ---
   net.core.somaxconn = 4096
   net.core.netdev_max_backlog = 10000

   # --- Ephemeral port range ---
   net.ipv4.ip_local_port_range = 1024 65535

   # --- TCP keepalive settings ---
   net.ipv4.tcp_keepalive_time = 300
   net.ipv4.tcp_keepalive_intvl = 30
   net.ipv4.tcp_keepalive_probes = 5

   # --- Increase socket buffer sizes ---
   net.core.rmem_max = 16777216
   net.core.wmem_max = 16777216

   # --- BBR congestion control (requires kernel 4.9+) ---
   # net.core.default_qdisc = fq
   # net.ipv4.tcp_congestion_control = bbr

   # --- Enable MTU probing ---
   net.ipv4.tcp_mtu_probing = 1

------------------------------------------------------------------------------
B.10.6  Applying and Testing Changes
------------------------------------------------------------------------------

.. code-block:: bash

   # Apply all files in /etc/sysctl.d/ and /etc/sysctl.conf
   sudo sysctl --system

   # Apply a single file
   sudo sysctl -p /etc/sysctl.d/99-network-security.conf

   # Check if a parameter was applied
   sysctl net.ipv4.tcp_syncookies
   # Should return: net.ipv4.tcp_syncookies = 1

   # Persistence: files in /etc/sysctl.d/*.conf are loaded in alphabetical order
   # Later files override earlier ones. Use numeric prefixes for ordering.

.. danger::
   Some sysctl changes can lock you out of a remote system (e.g., ``net.ipv6.conf.all.disable_ipv6=1``
   on a system relying on IPv6, or ``net.ipv4.ip_forward=0`` on a router).
   Always test changes on a non-production host first, or apply via a
   script with a rollback mechanism.

.. rubric:: Checking current kernel parameters

.. code-block:: bash

   # All parameters
   sysctl -a | less

   # Filter by category
   sysctl -a | grep -E '^net\.ipv4\.tcp'
   sysctl -a | grep -E '^vm\.'

   # Specific parameter
   cat /proc/sys/net/ipv4/tcp_syncookies
   sysctl net.ipv4.tcp_syncookies

.. rubric:: Common sysctl files on disk

.. code-block:: text

   /etc/sysctl.conf              # Traditional single file
   /etc/sysctl.d/*.conf          # Drop-in directory (recommended)
   /usr/lib/sysctl.d/*.conf      # Distribution defaults
   /run/sysctl.d/*.conf          # Runtime overrides (use with care)
