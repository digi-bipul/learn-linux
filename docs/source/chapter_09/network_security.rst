.. _sec9_5:

###########################################################
Network Security & Next-Generation Firewalls
###########################################################

Network security is the outermost defensive layer in the Linux stack. In
2026, the classic ``iptables`` firewall has been fully superseded by
``nftables`` (available since Linux 3.13, mature and default in Debian 12+,
RHEL 9+, Ubuntu 24.04+). But the real revolution is the adoption of
**eBPF (extended Berkeley Packet Filter)** and the **eXpress Data Path (XDP)**
for packet processing at wire speed, running directly in the kernel without
the overhead of context switches to userspace.

This section covers the practical administration of ``nftables``,
intrusion prevention with ``fail2ban``, the stealth technique of
port knocking, and the 2026 industry-standard approach of eBPF/XDP-based
networking with Cilium.

nftables: The Modern Linux Firewall
==========================================

The ``nftables`` framework replaces the legacy ``iptables`` (and its
variants ``ip6tables``, ``arptables``, ``ebtables``) with a single,
unified, and more performant packet classification engine.

**Why nftables over iptables:**

- **Single kernel framework** replaces multiple legacy modules.
- **No per-packet rule counting overhead** unless explicitly enabled.
- **Native maps, sets, and verdict maps** for efficient lookups.
- **Atomic rule replacement** — entire chains are swapped atomically.
- **Simpler syntax** with proper separators and no counter-intuitive
  table/chain inheritance rules.

**Basic nftables workflow:**

1. Create a table (address-family + table-name).
2. Create chains within the table (type, hook, priority).
3. Add rules to chains.

**Example: Stateless IPv4 firewall**

::

    #!/usr/sbin/nft -f

    flush ruleset

    table inet filter {
        chain input {
            type filter hook input priority 0; policy drop;

            # Allow established/related connections
            ct state established,related accept

            # Allow loopback
            iif "lo" accept

            # ICMP (limited)
            ip protocol icmp icmp type { echo-request, echo-reply } accept

            # SSH (rate-limited)
            tcp dport 22 ct state new limit rate 5/minute accept

            # HTTP/HTTPS
            tcp dport { 80, 443 } accept

            # Log and drop everything else
            log prefix "nftables-drop: " flags all
        }

        chain forward {
            type filter hook forward priority 0; policy drop;
        }

        chain output {
            type filter hook output priority 0; policy accept;
        }
    }

**Sets in nftables:**

Sets are the most powerful feature. They replace the long chains of
``-s`` rules in iptables.

::

    nft add set inet filter allowed_hosts { type ipv4_addr\; }
    nft add element inet filter allowed_hosts { 10.0.0.1, 10.0.0.2, 192.168.1.0/24 }

    # Use in a rule:
    nft add rule inet filter input ip saddr @allowed_hosts tcp dport 22 accept

Sets are automatically optimized by the kernel into hash tables, bitmap
tables, or interval trees depending on the element types.

**Verdict maps for polices:**

Verdict maps (``vmap``) map packet characteristics to actions, enabling
efficient multi-way branching in a single rule:

::

    nft add chain inet filter input
    nft add rule inet filter input ip saddr vmap {
: accept,
: drop,
/16 : accept,
        * : drop
    }

**Migrating from iptables to nftables:**

The ``iptables-translate`` and ``ip6tables-translate`` tools (from the
``iptables-nftables-compat`` package) will convert legacy rules:
::

    iptables-translate -A INPUT -p tcp --dport 22 -j ACCEPT
    # Output: nft add rule ip filter INPUT tcp dport 22 accept

For a full migration, use ``iptables-save`` piped through ``iptables-restore-translate``:
::

    iptables-save > /tmp/rules.v4
    iptables-restore-translate -f /tmp/rules.v4 > /tmp/rules.nft
    nft -f /tmp/rules.nft

fail2ban: Automated Intrusion Prevention
===============================================

``fail2ban`` monitors log files for repeated authentication failures and
dynamically adds firewall rules to block the offending IP address. In 2026,
it remains the standard tool for protecting SSH, SMTP, HTTP basic auth, and
other login-vector services.

**How it works:**

1. A **jail** watches a specific log file for failure patterns (regex-based).
2. After N failures within a time window, the IP is banned for a configured
   duration.
3. Optionally, ``fail2ban`` sends email alerts and/or runs custom scripts.

**Essential configuration (``/etc/fail2ban/jail.local``):**

::

    [DEFAULT]
    # Ban IP after 5 failures in 10 minutes for 1 hour
    bantime  = 1h
    findtime = 10m
    maxretry = 5

    # Use nftables (not legacy iptables)
    banaction = nftables-multiport
    chain     = input

    # Ignore internal networks (never ban them)
    ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16

    # Email notification (requires MTA)
    destemail = security@example.com
    sender    = fail2ban@example.com
    action    = %(action_mwl)s       # ban + whois report + log lines

    [sshd]
    enabled = true
    port    = ssh
    logpath = %(sshd_log)s
    backend = systemd                # Reads from journald

    [apache-auth]
    enabled  = true
    port     = http,https
    logpath  = /var/log/apache2/*error.log
    failregex = ^%(_apache_error_client)s (?:AH\d+: )?.*(?:authentication failure|...

**Advanced fail2ban features in 2026:**

- **Recidive jail:** IPs that get banned multiple times get a *longer* ban
  (e.g., 1 week). This is composed by chaining jails.
- **Geo-IP filtering:** Use ``maxminddb`` to only allow logins from
  specific countries, then ban everything else at the firewall level.
  ``fail2ban`` can integrate with ``xt_geoip`` / nftables sets.

**Performance note:** With modern systems handling millions of log lines
per day, ensure ``fail2ban`` uses the ``systemd`` backend (``backend =
systemd``) rather than ``pyinotify`` or ``gamin``, as journald is orders
of magnitude more efficient for log access.

Port Knocking
====================

Port knocking is a security technique that keeps a port (typically SSH)
hidden from port scans. A firewall rule only opens the port after the
client sends a specific sequence of connection attempts to closed ports.
An attacker who simply scans ``tcp/22`` sees it as **filtered** or
**closed** until the correct knock sequence is delivered.

**knockd (the standard implementation):**

Configuration in ``/etc/knockd.conf``:
::

    [options]
        logfile = /var/log/knockd.log

    [openSSH]
        sequence    = 7000,8000,9000
        seq_timeout = 5
        command     = /usr/sbin/nft add rule inet filter input tcp dport 22 accept
        tcpflags    = syn

    [closeSSH]
        sequence    = 9000,8000,7000
        seq_timeout = 5
        command     = /usr/sbin/nft delete rule inet filter input handle <HANDLE>
        tcpflags    = syn

Client connects:
::

    knock -d 500 server.example.com 7000 8000 9000
    ssh alice@server.example.com

**Critique and 2026 status:**

Port knocking is controversial. It is **security-by-obscurity** and provides
no protection against a determined adversary who has captured network traffic
and can replay the sequence. Its primary value is reducing log noise from
automated scanners. In 2026, most organizations prefer **authenticated port
access via VPN** (WireGuard) or **Zero Trust Network Access (ZTNA)** instead.

Nevertheless, for low-profile personal servers and IoT devices, port knocking
combined with ``fail2ban`` remains a practical way to reduce attack surface.

eBPF and XDP: The 2026 Network Security Revolution
==========================================================

**eBPF (extended Berkeley Packet Filter)** allows sandboxed programs to run
inside the Linux kernel without changing kernel source code or loading
kernel modules. **XDP (eXpress Data Path)** is an eBPF-based hook that runs
the earliest possible point in the network stack—before the ``sk_buff`` is
allocated—enabling packet processing at **line rate** (tens of millions of
packets per second per core).

**Why eBPF/XDP for network security:**

+-------------------------------------+--------------------------------------+
| Traditional (nftables/iptables)     | eBPF/XDP                             |
+=====================================+======================================+
| Processed in kernel's netfilter     | Processed in driver/NIC context      |
| stack after ``sk_buff`` allocation. | before memory allocation.            |
+-------------------------------------+--------------------------------------+
| Millions of packets/sec per core.   | Tens of millions of packets/sec per  |
|                                     | core (10-40x improvement).           |
+-------------------------------------+--------------------------------------+
| Static rule sets; adding new logic  | Dynamic: programs loaded at runtime, |
| requires kernel patches.            | verified by eBPF verifier.           |
+-------------------------------------+--------------------------------------+
| Visibility only at L3/L4.           | Full visibility: L2–L7, application  |
|                                     | protocol parsing via kernel helpers. |
+-------------------------------------+--------------------------------------+

**Cilium: eBPF-powered networking and security**

**Cilium** is the leading eBPF-based CNI (Container Network Interface) for
Kubernetes, but in 2026 it is increasingly deployed on **bare-metal Linux**
for eBPF firewall and observability.

**CiliumNetworkPolicy** replaces traditional firewall rules with
identity-aware, L3–L7 policies:

::

    apiVersion: cilium.io/v2
    kind: CiliumNetworkPolicy
    metadata:
      name: secure-ssh
    spec:
      endpointSelector:
        matchLabels:
          app: ssh-server
      ingress:
      - fromEndpoints:
        - matchLabels:
            role: admin
        toPorts:
        - ports:
          - port: "22"
            protocol: TCP

On bare metal, ``cilium-agent`` manages eBPF programs that enforce these
policies, providing:

- **Identity-based security** (not IP-based).
- **L7 protocol inspection** (HTTP, gRPC, Kafka, DNS).
- **Transparent encryption** (WireGuard via eBPF).
- **Hubble observability** — real-time service map and flow inspection.

**Falco: eBPF-based runtime security**

While Cilium focuses on *network* security, **Falco** (now a CNCF graduated
project) uses eBPF to monitor *system calls* for suspicious behaviour:

::

    # Rule: Detect shell spawned in container
    - rule: Terminal shell in container
      desc: A shell was spawned in a container
      condition: >
        spawned_process and container
        and shell_procs
        and not proc.name in (bash, zsh, sh)
      output: >
        Shell spawned in container (user=%user.name container=%container.id
        cmdline=%proc.cmdline)
      priority: WARNING
      tags: [container, shell]

Falco's eBPF probe (``falco-modern-bpf``, released 2024) requires no kernel
module and no manual driver installation—it loads a pre-compiled BPF program
at startup.

**Tetragon: The next evolution**

Tetragon (also from the Cilium team, donated to CNCF) is a **runtime
security enforcement** tool that uses eBPF to *block* malicious syscalls,
not just detect them. In 2026, Tetragon provides:

- Process lifecycle monitoring (exec, exit, clone).
- File access enforcement (read/write/execute on specific paths).
- Network socket access control.

A Tetragon policy to prevent SSH key exfiltration:

::

    apiVersion: cilium.io/v1alpha1
    kind: TracingPolicy
    metadata:
      name: "block-ssh-key-read"
    spec:
      kprobes:
      - call: "security_file_permission"
        syscall: false
        args:
        - index: 0
          type: file
        selectors:
        - matchArgs:
          - index: 0
            operator: "Equal"
            values:
            - "/home/*/.ssh/id_*"
          matchActions:
          - action: Sigkill

Putting It All Together: The 2026 Network Security Stack
===============================================================

A modern Linux server's network security stack in 2026:

+-------------+---------------------------------------------------+
| Layer       | Technology                                        |
+=============+===================================================+
| Line rate   | XDP program (DDoS mitigation, basic allow/deny    |
| filtering   | by IP/port) — e.g., ``xdp-tools`` from libbpf.    |
+-------------+---------------------------------------------------+
| Stateful    | nftables (stateful connection tracking for        |
| firewall    | established traffic, NAT, logging).               |
+-------------+---------------------------------------------------+
| L7 / edge   | Cilium or Envoy proxy (TLS termination, HTTP      |
|             | routing, mTLS, rate limiting).                    |
+-------------+---------------------------------------------------+
| Intrusion   | Falco / Tetragon (eBPF-based syscall monitoring   |
| prevention  | and blocking).                                    |
+-------------+---------------------------------------------------+
| Access      | WireGuard tunnel or ZTNA (Teleport, Tailscale)    |
| control     | for authenticated network access.                 |
+-------------+---------------------------------------------------+
| Automated   | fail2ban (log-based IP banning for SSH, web apps).|
| banning     |                                                   |
+-------------+---------------------------------------------------+

**Real-world example — Global CDN provider:**

A major content delivery network (serving 20% of global web traffic)
uses XDP on every edge server to drop DDoS traffic at the NIC level.
Their XDP program (written in C, compiled with ``clang -target bpf``)
classifies packets in under 50 nanoseconds. Traffic that passes the XDP
filter then enters nftables for connection tracking. The entire control
plane is managed by Cilium, with Hubble providing real-time flow
visualization across 200,000+ servers.
