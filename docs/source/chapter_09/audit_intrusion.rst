.. _sec9_7:

###########################################################
Audit, EDR, & Intrusion Detection
###########################################################

Detection is the complement to prevention. Even the most hardened system will
eventually face a compromise. The question is: *will you know about it?*
This section covers the Linux audit subsystem, file integrity monitoring,
rootkit detection, and the modern Endpoint Detection and Response (EDR)
tools that define security operations in 2026.

auditd: The Linux Audit Framework
========================================

The Linux Audit Daemon (``auditd``) is the kernel's event-logging subsystem
for security-relevant activity. It captures system calls, file accesses,
process executions, and configuration changes—all at the kernel level,
making it extremely difficult for an attacker to evade.

**Architecture:**

1. The **kernel audit subsystem** (``CONFIG_AUDIT=y``) generates events.
2. **``auditd``** (userspace daemon) reads events from ``netlink`` socket
   and writes them to ``/var/log/audit/audit.log``.
3. **``audispd``** (audit dispatcher) can forward events to remote syslog,
   SIEM (Splunk, Elastic, Wazuh), or custom plugins.

**Essential rules (``/etc/audit/rules.d/audit.rules``):**

::

    # Remove any existing rules
    -D

    # Buffer size (increase for busy systems)
    -b 8192

    # Failure mode: 0=silent, 1=printk, 2=panic (high-security)
    -f 1

    # Log all system calls by privileged users (uid < 1000)
    -a always,exit -F arch=b64 -S execve -F uid=0 -k privileged-exec

    # Monitor password files
    -w /etc/passwd -p wa -k passwd-changes
    -w /etc/shadow -p wa -k shadow-changes
    -w /etc/sudoers -p wa -k sudoers-changes

    # Monitor SSH configuration and keys
    -w /etc/ssh/sshd_config -p wa -k sshd-config
    -w /etc/ssh/ -p wa -k sshd-config
    -w ~/.ssh/ -p wa -k user-ssh

    # Monitor sensitive binaries
    -w /usr/bin/su -p x -k su-exec
    -w /usr/bin/sudo -p x -k sudo-exec

    # Monitor kernel module loading
    -w /sbin/insmod -p x -k kernel-modules
    -w /sbin/modprobe -p x -k kernel-modules

    # Monitor time changes
    -a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change

    # Monitor user/group management
    -w /usr/sbin/useradd -p x -k user-mgmt
    -w /usr/sbin/userdel -p x -k user-mgmt
    -w /usr/sbin/usermod -p x -k user-mgmt
    -w /usr/sbin/groupadd -p x -k group-mgmt

    # Monitor mount operations
    -a always,exit -F arch=b64 -S mount -S umount2 -k mount

    # Make the configuration immutable (prevents tampering with audit rules)
    -e 2

.. warning::
   The ``-e 2`` flag makes the audit rules immutable until the next reboot.
   Test new rules thoroughly before enabling this.

**Querying the audit log:**

::

    # All events in the last hour
    ausearch -ts today -i

    # Events for a specific key
    ausearch -k passwd-changes -i

    # Login events
    ausearch -m USER_LOGIN -i

    # Failed file access attempts
    ausearch -m PATH -i --success no

    # Real-time monitoring
    tail -f /var/log/audit/audit.log | audit2why

**Remote log forwarding (SIEM integration):**

::

    # /etc/audit/audispd-plugins/au-remote.conf
    active = yes
    direction = out
    path = /sbin/audisp-remote
    args = tcp://10.0.0.100:60
    format = rich

For high-security environments, configure TLS-encrypted audit transport
using ``audisp-remote`` with TLS or forward via syslog-ng/rsyslog with
TLS to an Elastic SIEM or Splunk Heavy Forwarder.

File Integrity Monitoring: AIDE
======================================

**AIDE (Advanced Intrusion Detection Environment)** creates a cryptographic
database of file metadata and content hashes, then periodically compares the
live filesystem against that database to detect unauthorized changes.

**Initialization:**

::

    # Install
    sudo apt install aide

    # Configure /etc/aide/aide.conf (or /etc/aide.conf)
    # Define rules for what to monitor
    #
    # Example rules:
    #   p: permissions, i: inode, n: number of links
    #   u: user, g: group, s: size, b: block count
    #   m: mtime, a: atime, c: ctime, S: SHA-256 hash

    # Monitor critical system binaries with SHA-256
    /bin    NORMAL
    /sbin   NORMAL
    /usr/bin NORMAL
    /usr/sbin NORMAL

    # Monitor configuration files
    /etc    NORMAL

    # Exclude volatile directories
    !/var/log
    !/var/spool
    !/tmp
    !/proc
    !/sys

    # Initialize the database
    sudo aide --init

    # Rename the database
    sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

**Periodic checks:**

::

    # Run a check
    sudo aide --check

    # Report differences
    # Output includes: "added", "removed", "changed" files with before/after hashes

**Automation with systemd:**

::

    # /etc/systemd/system/aide-check.service
    [Unit]
    Description=AIDE integrity check

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/aide --check
    ExecStartPost=/usr/bin/systemd-cat -t aide /usr/bin/logger -p authpriv.notice "AIDE check complete"

    [Install]
    WantedBy=multi-user.target

    # Timer: run daily
    # /etc/systemd/system/aide-check.timer
    [Unit]
    Description=Daily AIDE integrity check

    [Timer]
    OnCalendar=daily
    Persistent=true

    [Install]
    WantedBy=timers.target

**Tripwire (alternative to AIDE):**

Tripwire is the predecessor to AIDE and follows the same concept. AIDE is
more widely used today due to its simpler configuration and better
performance. However, Tripwire's commercial version (Tripwire Enterprise)
is still deployed in large financial institutions where centralized policy
management and compliance reporting are required.

**dm-verity / Integrity Measurement Architecture (IMA):**

For the highest-security deployments (e.g., Android Verified Boot,
ChromeOS, and certain DoD systems), **dm-verity** provides block-level
integrity verification using a Merkle hash tree stored in a separate
partition. **IMA** (Integrity Measurement Architecture) extends this to
measure and attest the integrity of every executed file. These are
beyond the scope of typical Linux administration but are essential in
**Trusted Computing** environments with TPM-based remote attestation.

Rootkit Detection: rkhunter and chkrootkit
=================================================

**Rootkits** are stealth malware that modify the kernel or system binaries
to hide the attacker's presence. Detection requires specialised tools.

**rkhunter (Rootkit Hunter):**

::

    sudo apt install rkhunter

    # Update signatures
    sudo rkhunter --update

    # Run a check
    sudo rkhunter --check --skip-keypress

    # Check specific categories
    sudo rkhunter --check --scan-knownbad-files --skip-keypress

rkhunter checks for:

- Known rootkit signatures (by name and hash).
- Suspicious kernel module loading.
- Hidden processes and open ports.
- Binary signature mismatches (compares against distribution database).
- Root-owned SUID/SGID files.
- SSH and LD_PRELOAD vulnerabilities.

**chkrootkit:**

::

    sudo apt install chkrootkit
    sudo chkrootkit

chkrootkit is more primitive and signature-based than rkhunter. It checks
for specific strings in memory, hidden file descriptors, and known rootkit
commands.

**2026 status of rootkit detection:**

Traditional signature-based rootkit detection (rkhunter, chkrootkit) is
increasingly obsolete. Modern kernel rootkits (e.g., Syslogk, Reptile,
Diamorphine) are easily modified to evade signatures. The 2026 standard for
rootkit detection is **eBPF-based runtime monitoring** (Falco, Tetragon)
which detects the *behaviour* of a rootkit (e.g., hiding processes via
hook modification) rather than its static signature.

Nevertheless, rkhunter and chkrootkit remain useful as a *complementary*
layer—particularly in legacy environments where eBPF is not available.

lynis: Security Auditing
===============================

**Lynis** is an open-source security auditing tool that scans a Linux system
for compliance with security best practices. It is the most comprehensive
automated auditing tool available for Linux.

::

    sudo apt install lynis
    sudo lynis audit system

Lynis checks:

- System boot and kernel configuration.
- User accounts, groups, and sudo settings.
- File system and disk encryption.
- Firewall and network configuration.
- Services and daemons.
- Authentication (PAM, SSH, NSS).
- Software updates and package management.
- Logging and auditing.
- Custom compliance profiles (CIS, PCI DSS, HIPAA).

**Example output:**

::

    [+] Firewall
      ----------------------------------------
      - iptables is active
      - nftables is active (not used, iptables is used)
      - Found 2 rules
      - Firewall rules loaded
      - Complete profile (not configured)

    [+] Hardening
      ----------------------------------------
      - 15 of 70 tests passed
      - 3 of 70 tests failed (see below)
      - 52 of 70 tests are suggestions

    Suggestions (3):
      * Install a PAM module for password strength testing
        https://cisofy.com/lynis/controls/ACCT-0037/
      * Install a file integrity tool like AIDE or Tripwire
        https://cisofy.com/lynis/controls/FINT-4350/

Lynis **hardening index** ranges from 0 (worst) to 100 (best). A freshly
installed Ubuntu 24.04 LTS typically scores around 65. After applying the
guidance in this chapter, a properly hardened system should score 85+.

**Automation in CI/CD:**

::

    # Run lynis in non-interactive mode and output JSON for dashboards
    sudo lynis audit system --quiet --report-file /tmp/lynis-report.json
    sudo lynis show details --json > /tmp/lynis-full.json

**Warning:** Lynis is an *advisory* tool. It generates suggestions, not
absolute requirements. Evaluate each suggestion against your specific threat
model and operational requirements.

Modern EDR: osquery and Falco
====================================

**osquery: SQL-based OS instrumentation**

Osquery exposes the operating system as a relational database that can be
queried with SQL. It is developed by Facebook/Meta and used by thousands of
organizations for security monitoring and incident response.

::

    sudo apt install osquery

    # Interactive query mode
    osqueryi

    # Query running processes
    osquery> SELECT pid, name, path, cmdline FROM processes WHERE name = 'sshd';

    # Query listening ports
    osquery> SELECT pid, port, protocol, address FROM listening_ports;

    # Query recently modified files (last 24 hours)
    osquery> SELECT path, mtime, size FROM file WHERE path LIKE '/etc/%'
             AND mtime > (SELECT unix_time - 86400 FROM time);

    # Query ARP cache (lateral movement detection)
    osquery> SELECT address, mac, interface FROM arp_cache;

**Osquery fleet management (2026):**

For enterprise deployment, **Fleet** (formerly Kolide) or
**osctrl** manages osquery agents across thousands of endpoints. Queries are
scheduled centrally, and results are streamed to a SIEM. Osquery is the
standard EDR data source for **CISA's Continuous Diagnostics and Mitigation
(CDM)** program in the US federal government.

**Falco: eBPF-based runtime security**

Falco (introduced in :ref:`Section 9.5 <sec9_5>`) monitors system calls via
eBPF and alerts on suspicious behaviour. It is the de-facto standard for
container runtime security in 2026.

**Key Falco rules for Linux hosts (not just containers):**

::

    # /etc/falco/falco_rules.local.yaml
    - rule: Unauthorized process execution in /tmp
      desc: A binary was executed from /tmp (potential malware staging)
      condition: >
        spawned_process and
        proc.exe startswith "/tmp"
      priority: CRITICAL
      output: >
        Executable in /tmp (user=%user.name command=%proc.cmdline
        pid=%proc.pid parent=%proc.pname)

    - rule: Sensitive file read by non-authorized process
      desc: Non-SSH process reading SSH private keys
      condition: >
        open_read and
        fd.name startswith "/root/.ssh/" and
        not proc.name in (sshd, ssh, tmux)
      priority: WARNING
      output: >
        SSH key read alert (user=%user.name command=%proc.cmdline
        file=%fd.name)

    - rule: Kernel module insertion
      desc: A kernel module was loaded (potential rootkit)
      condition: >
        evt.type=init_module
      priority: CRITICAL
      output: >
        Kernel module loaded (module=%evt.arg.name
        user=%user.name command=%proc.cmdline)

- **Alert outputs:** Falco can send alerts to syslog, stdout, Slack, PagerDuty,
  AWS SNS, GCP Pub/Sub, or any HTTP endpoint via webhook.
- **Falco Talons:** The open-source Falco Talon engine enables *automated
  response* — when a critical alert fires, Talon can kill the process,
  pause the container, or trigger a network block via CiliumNetworkPolicy.

Real-World EDR Stack (2026)
==================================

A production EDR stack deployed by a Fortune 500 company in 2026:

+------------------+---------------------------------------------------+
| Component        | Role                                              |
+==================+===================================================+
| Osquery (Fleet)  | Baseline visibility: processes, network           |
|                  | connections, file changes, logged in users.       |
+------------------+---------------------------------------------------+
| Falco (eBPF)     | Real-time syscall-level threat detection and      |
|                  | blocking (kernel mode rootkits, container         |
|                  | breakouts, crypto miners).                        |
+------------------+---------------------------------------------------+
| auditd           | User activity logging (who ran what command,      |
|                  | when, with what UID). Logs forwarded to SIEM.     |
+------------------+---------------------------------------------------+
| AIDE             | Hourly filesystem integrity check. Alerts on      |
|                  | changed binaries or unexpected new SUID files.    |
+------------------+---------------------------------------------------+
| Wazuh (SIEM/XDR) | Open-source SIEM that ingests osquery, Falco,     |
|                  | auditd, and AIDE data; correlates alerts and      |
|                  | generates incidents with MITRE ATT&CK mapping.    |
+------------------+---------------------------------------------------+
| SOAR (Shuffle    | Automated incident response: isolate compromised  |
| or Tines)        | host via nftables block, trigger PagerDuty, open  |
|                  | Jira ticket.                                      |
+------------------+---------------------------------------------------+

This stack detects:

- **Supply chain attack (e.g., tampered package):** AIDE detects the
  changed binary hash; Falco detects the anomalous behaviour; Wazuh
  correlates and alerts.
- **Lateral movement (SSH key theft):** Falco detection of SSH key read
  by non-SSH process; osquery cross-references failed SSH logins across
  the fleet.
- **Rootkit installation:** auditd captures ``insmod`` syscall; Falco
  detects hidden process via eBPF; the host is isolated by SOAR
  within 30 seconds.
