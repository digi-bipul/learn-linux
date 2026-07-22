.. _app-c-logs:

------------------------------------------------------------------------------
C.5  Log Analysis & Incident Response
------------------------------------------------------------------------------

------------------------------------------------------------------------------
C.5.1  Log File Locations

.. list-table:: Standard Linux log locations
   :header-rows: 1
   :widths: 25 25 50

   * - Log file
     - Service/Component
     - What to look for
   * - ``/var/log/syslog``
     - General system log
     - Kernel messages, service logs, cron output (Debian/Ubuntu)
   * - ``/var/log/messages``
     - General system log
     - Same as syslog (RHEL/CentOS legacy)
   * - ``/var/log/kern.log``
     - Kernel messages
     - Hardware errors, OOM, filesystem corruption, module load failures
   * - ``/var/log/auth.log``
     - Authentication
     - SSH logins, sudo commands, PAM errors, failed auth attempts (Debian)
   * - ``/var/log/secure``
     - Authentication
     - Same as auth.log (RHEL/CentOS)
   * - ``/var/log/dmesg``
     - Kernel ring buffer
     - Boot-time hardware detection, driver problems
   * - ``/var/log/debug``
     - Debug messages
     - All priorities ``debug`` and above (usually empty on production)
   * - ``/var/log/faillog``
     - Failed login records
     - ``faillog -a`` to display
   * - ``/var/log/lastlog``
     - Last login per user
     - ``lastlog`` to display
   * - ``/var/log/wtmp``
     - Login history
     - ``last`` to display (who logged in and when)
   * - ``/var/log/btmp``
     - Bad login attempts
     - ``lastb`` to display
   * - ``/var/log/apache2/``
     - Apache access/error
     - ``access.log``, ``error.log`` (or ``httpd/`` on RHEL)
   * - ``/var/log/nginx/``
     - Nginx access/error
     - ``access.log``, ``error.log``
   * - ``/var/log/mysql/``
     - MySQL/MariaDB
     - ``error.log``, ``slow-query.log``
   * - ``/var/log/postgresql/``
     - PostgreSQL
     - ``postgresql-*.log``
   * - ``/var/log/mail.log``
     - Mail server
     - Postfix, Dovecot, spamassassin messages
   * - ``/var/log/cron``
     - Cron jobs
     - Cron execution logs
   * - ``/var/log/journal/``
     - systemd journal
     - Binary format; query with ``journalctl``
   * - ``/var/log/samba/``
     - Samba
     - Netlogon, authentication, file access
   * - ``/var/log/audit/audit.log``
     - Linux Audit daemon
     - Security events: file access, syscalls, user/group changes

------------------------------------------------------------------------------
C.5.2  Log Analysis Patterns

.. code-block:: bash
   :caption: Security-focused log analysis

   # Failed SSH login attempts
   sudo journalctl -u sshd.service --since "7 days ago" | grep "Failed password"
   sudo grep "Failed password" /var/log/auth.log | awk '{print $1, $2, $9, $11}' | sort | uniq -c | sort -rn | head -20

   # Invalid users attempting SSH
   sudo grep "Invalid user" /var/log/auth.log | awk '{print $8}' | sort | uniq -c | sort -rn

   # Successful sudo commands
   sudo journalctl _COMM=sudo | grep -E "COMMAND="
   sudo grep "COMMAND=" /var/log/auth.log

   # Root logins
   sudo grep "Accepted" /var/log/auth.log | grep "root"

   # Failed sudo attempts
   sudo grep "authentication failure" /var/log/auth.log | grep "sudo"

   # Port scans (from firewall logs)
   sudo grep "DPT=" /var/log/syslog | awk '{print $NF}' | cut -d= -f2 | sort | uniq -c | sort -rn

.. code-block:: bash
   :caption: Performance-focused log analysis

   # OOM killer events
   sudo journalctl -k | grep -i "oom\|out of memory"

   # Disk errors
   sudo journalctl -k | grep -i "ata\|scsi\|i/o error\|buffer I/O"

   # Filesystem errors
   sudo journalctl -k | grep -i "ext4\|xfs\|btrfs\|corruption\|error"

   # Network interface errors
   sudo journalctl -k | grep -i "eth\|link\|carrier\|duplex\|speed"

   # Service restarts/crashes
   sudo journalctl -u nginx.service | grep -i "failed\|error\|warn\|timeout"

   # Outbound connection log (if using auditd)
   sudo ausearch -k network_connect -i

.. code-block:: bash
   :caption: Time-based log analysis

   # Logs from a specific time window
   sudo journalctl --since "2026-07-19 14:00:00" --until "2026-07-19 16:00:00"

   # Logs from today
   sudo journalctl --since today

   # Logs from previous boot
   sudo journalctl -b -1

   # Correlation: check what happened just before a crash
   sudo journalctl -b -1 --priority=err | tail -100

   # Check for time synchronization issues (ntp/chrony)
   sudo journalctl -u chronyd | grep -i "step\|skew\|offset\|sync"

------------------------------------------------------------------------------
C.5.3  Incident Response Runbook

.. rubric:: Phase 1: Detection

.. code-block:: text

   Indicators of compromise (IoC) to look for:
   - Unusual outbound network connections (beaconing)
   - New user accounts, especially in sudo/wheel group
   - Modified system binaries (check with rpm -V or debsums)
   - Unexpected cron jobs or systemd timers
   - Sudden disk activity or network traffic
   - Authentication log showing brute-force patterns
   - Processes running from /tmp or /dev/shm
   - Kernel modules loaded without corresponding hardware

.. rubric:: Phase 2: Containment

.. code-block:: bash

   # Isolate the affected system
   # 1. Disconnect network (physically or via firewall)
   sudo iptables -A INPUT -j DROP
   sudo iptables -A OUTPUT -j DROP

   # 2. Capture volatile state (before shutdown)
   # Save running processes
   ps auxf > /tmp/forensics/ps_auxf.txt
   # Save network connections
   ss -tlnp > /tmp/forensics/ss_tlnp.txt
   ss -tunap > /tmp/forensics/ss_tunap.txt
   # Save listening ports
   lsof -i -P -n > /tmp/forensics/lsof_i.txt
   # Save open files
   lsof > /tmp/forensics/lsof_all.txt
   # Save kernel modules
   lsmod > /tmp/forensics/lsmod.txt
   # Save routing table
   ip route > /tmp/forensics/ip_route.txt
   # Save ARP table
   ip neigh > /tmp/forensics/ip_neigh.txt
   # Save loaded kernel parameters
   sysctl -a > /tmp/forensics/sysctl.txt
   # Save process memory (of suspicious processes)
   sudo gcore <suspicious_pid>
   # Save system memory (requires LiME or fmem)
   # WARNING: This writes a full RAM dump

.. rubric:: Phase 3: Analysis

.. code-block:: bash

   # Check for rootkits
   sudo rkhunter --check --skip-keypress
   sudo chkrootkit

   # Verify package integrity
   # Debian/Ubuntu:
   sudo debsums -a | grep -v "OK$"
   # RHEL/Fedora:
   sudo rpm -Va | grep -v "^..\....\.\.\.\.\.\."

   # Check for modified files in critical paths
   sudo find /bin /sbin /usr/bin /usr/sbin /etc -type f -newer /etc/passwd -ls

   # Check hidden files and directories
   sudo find /home -name ".*" -type f -not -path "*/\.*/*"
   sudo ls -la /tmp /var/tmp /dev/shm

   # Check cron entries for all users
   for user in $(cut -f1 -d: /etc/passwd); do
       crontab -u $user -l 2>/dev/null
   done

   # Check systemd timers added by users
   systemctl list-timers --all

   # Check SSH authorized_keys for unexpected entries
   for f in /home/*/.ssh/authorized_keys /root/.ssh/authorized_keys; do
       echo "=== $f ==="
       cat "$f" 2>/dev/null
   done

.. rubric:: Phase 4: Eradication & Recovery

.. code-block:: bash

   # Remove unauthorized user
   sudo userdel -r <malicious_user>
   sudo passwd -l <user>          # Lock account if deletion not wanted

   # Remove unauthorized cron jobs
   sudo crontab -u <user> -r

   # Kill malicious processes
   sudo kill -9 <pid>

   # Remove unauthorized SSH keys
   # Manually edit /home/<user>/.ssh/authorized_keys

   # Reinstall compromised packages
   sudo apt-get install --reinstall <package>   # Debian
   sudo dnf reinstall <package>                  # RHEL

   # Change all passwords
   sudo passwd <user>          # Interactive
   echo "newpass" | sudo passwd --stdin <user>   # RHEL only

   # Revoke all sessions
   # For SSH: restart sshd
   sudo systemctl restart sshd

.. rubric:: Phase 5: Post-mortem

.. code-block:: text

   Questions to answer:
   1. Initial access vector — how did the attacker get in?
   2. Privilege escalation — how did they gain root/user access?
   3. Persistence — what mechanisms were left behind?
   4. Lateral movement — which other systems were accessed?
   5. Data exfiltration — what data was accessed or stolen?

   Deliverables:
   - Timeline of events (from log correlation)
   - Indicators of compromise (IPs, domains, file hashes, registry keys)
   - Recommendations to prevent recurrence
