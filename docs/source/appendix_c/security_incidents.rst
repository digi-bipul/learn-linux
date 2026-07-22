.. _app-c-security-incidents:

------------------------------------------------------------------------------
C.9  Security Incident Response
------------------------------------------------------------------------------

------------------------------------------------------------------------------
C.9.1  Common Attack Types & Defenses

.. list-table:: Attack types and Linux-specific defenses
   :header-rows: 1
   :widths: 20 30 50

   * - Attack type
     - How it works
     - Linux defense
   * - SSH brute force
     - Automated password guessing against SSH
     - ``fail2ban``, ``sshguard``; disable password auth, use keys; change port
   * - DDoS / SYN flood
     - Overwhelm server with half-open connections
     - ``iptables`` SYN cookie; ``synproxy``; rate limiting; CDN
   * - Web application attack
     - SQL injection, XSS, path traversal, RCE
     - ModSecurity (WAF); proper input validation; least privilege; SELinux
   * - Privilege escalation
     - Exploit SUID binary, kernel vuln, misconfigured sudo
     - Regular patching; ``sudo -l`` audit; remove unnecessary SUID; ``aa-status``
   * - Malware / rootkits
     - Backdoor, keylogger, crypto miner
     - rkhunter, chkrootkit; tripwire/AIDE file integrity; SELinux/AppArmor
   * - Man-in-the-middle (MITM)
     - ARP spoofing, DNS hijacking, rogue AP
     - DNSSEC; HTTPS/TLS; SSH host key verification; switch security
   * - Social engineering
     - Phishing email, phone call, tailgating
     - User training; two-factor auth; physical security
   * - Crypto mining (cryptojacking)
     - Attacker runs miner on compromised server
     - Monitor CPU usage (``top``, ``htop``); unexpected external connections

------------------------------------------------------------------------------
C.9.2  Intrusion Detection Tools

.. list-table:: Linux IDS/IPS tools
   :header-rows: 1
   :widths: 20 30 50

   * - Tool
     - Type
     - Description
   * - ``fail2ban``
     - Log-based IDS
     - Scans log files for brute-force patterns; bans IPs via iptables/nftables
   * - ``rkhunter``
     - Rootkit hunter
     - Scans for known rootkits, bad binaries, hidden files, suspicious kernel modules
   * - ``chkrootkit``
     - Rootkit hunter
     - Locally checks for signs of rootkits (runs from the system itself)
   * - ``aide``
     - File integrity
     - Creates a database of file checksums; alerts on changes
   * - ``tripwire``
     - File integrity
     - Similar to AIDE; commercial and open-source versions
   * - ``ossec``
     - HIDS
     - Host-based intrusion detection; log analysis, file integrity, rootkit detection
   * - ``wazuh``
     - HIDS (fork of OSSEC)
     - Extended OSSEC; SIEM integration; PCI DSS compliance
   * - ``snort`` / ``suricata``
     - NIDS
     - Network-based intrusion detection; deep packet inspection
   * - ``lynis``
     - Security audit
     - System hardening audit; checks configs, permissions, services

.. code-block:: bash
   :caption: fail2ban setup

   # Install
   sudo apt install fail2ban            # Debian/Ubuntu
   sudo dnf install fail2ban            # RHEL/Fedora

   # Configuration (local overrides)
   sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

   # Enable SSH protection
   # In /etc/fail2ban/jail.local:
   # [sshd]
   # enabled = true
   # maxretry = 5
   # bantime = 3600
   # findtime = 600

   # Check status
   sudo fail2ban-client status
   sudo fail2ban-client status sshd

   # Unban an IP
   sudo fail2ban-client set sshd unbanip 192.168.1.100

   # View ban logs
   sudo tail -f /var/log/fail2ban.log

.. code-block:: bash
   :caption: AIDE file integrity setup

   # Install
   sudo apt install aide               # Debian/Ubuntu
   sudo dnf install aide               # RHEL/Fedora

   # Initialize database
   sudo aideinit
   # Moves database to /var/lib/aide/aide.db.new
   sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

   # Run a check
   sudo aide --check

   # Update database (after legitimate changes)
   sudo aide --update

   # Schedule daily checks (via cron/systemd timer)
   # sudo dpkg-reconfigure aide   (Debian: enables daily cron job)

.. code-block:: bash
   :caption: lynis system audit

   # Install
   sudo apt install lynis

   # Run audit (non-privileged)
   lynis audit system

   # Run audit (as root — more thorough)
   sudo lynis audit system

   # View report
   sudo lynis show reports

   # Key warnings to act on:
   # - Unpatched packages
   # - Open ports without firewall rules
   # - Weak password policies
   # - SUID/SGID files
   # - Unnecessary services enabled

------------------------------------------------------------------------------
C.9.3  Hardening Checklist

.. rubric:: Quick hardening checklist (10-point rapid response)

.. list-table::
   :header-rows: 1
   :widths: 5 30 65

   * - #
     - Action
     - Command / Verification
   * - 1
     - Update all packages
     - ``sudo apt update && sudo apt upgrade`` (Debian); ``sudo dnf upgrade`` (RHEL)
   * - 2
     - Disable root SSH login
     - ``PermitRootLogin no`` in ``/etc/ssh/sshd_config``; ``systemctl restart sshd``
   * - 3
     - Use SSH keys only
     - ``PasswordAuthentication no`` in ``/etc/ssh/sshd_config``
   * - 4
     - Configure firewall
     - Default deny incoming; allow only needed ports (22, 80, 443)
   * - 5
     - Enable auditd
     - ``systemctl enable --now auditd``; add monitoring rules for critical files
   * - 6
     - Remove unnecessary SUID/SGID
     - ``find / -perm -4000 -type f 2>/dev/null``; review each; remove bits as needed
   * - 7
     - Set strong password policy
     - Install ``libpam-pwquality``; configure ``/etc/security/pwquality.conf``
   * - 8
     - Enable fail2ban
     - ``sudo apt install fail2ban``; configure SSH jail
   * - 9
     - Secure shared memory
     - ``tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0`` in ``/etc/fstab``
   * - 10
     - Check kernel parameters
     - Apply hardening via ``/etc/sysctl.d/99-network-security.conf`` (see :ref:`B.10 <app-b-kernel>`)

.. rubric:: Weekly maintenance checklist

.. code-block:: text

   ☐ Review auth logs for suspicious activity (journalctl -u sshd --since "7 days ago")
   ☐ Check for failed services (systemctl --failed)
   ☐ Check disk usage (df -h; df -i)
   ☐ Monitor swap usage (free -h; vmstat 1 5)
   ☐ Review last logins (last -20)
   ☐ Check for pending updates (apt list --upgradable; dnf check-update)
   ☐ Verify backups ran successfully last 7 days
   ☐ Check systemd journal for hardware errors (journalctl -k -p err)
   ☐ Review auditd reports (aureport --summary)
   ☐ Run lynis audit and address high-severity items

.. rubric:: Monthly compliance checks

.. code-block:: bash

   # Check for users with empty passwords
   sudo awk -F: '($2 == "") {print $1}' /etc/shadow

   # Check for accounts with UID 0 (should only be root)
   sudo awk -F: '($3 == 0) {print $1}' /etc/passwd

   # Check for expired passwords
   sudo chage -l <username>

   # List all users and their groups
   for user in $(cut -f1 -d: /etc/passwd); do
       groups $user 2>/dev/null
   done

   # Check for world-writable files critical directories
   find /etc -perm -o+w -type f -exec ls -la {} \; 2>/dev/null

   # Check for suspicious cron jobs
   cat /etc/crontab /etc/cron.d/* 2>/dev/null
   for u in $(cut -f1 -d: /etc/passwd); do
       crontab -u $u -l 2>/dev/null
   done

   # Verify no services listen on all interfaces that shouldn't
   ss -tlnp | grep 0.0.0.0: | grep -vE ":80|:443|:22"
