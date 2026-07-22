.. _app-b-journal:

------------------------------------------------------------------------------
B.8  Journald & Log Management
------------------------------------------------------------------------------

``systemd-journald`` is the logging daemon that collects and stores log data
from the kernel, systemd services, and syslog. It replaces (or complements)
traditional syslog daemons.

------------------------------------------------------------------------------
B.8.1  Journald Configuration (``/etc/systemd/journald.conf``)
------------------------------------------------------------------------------

.. list-table:: Key journald.conf directives
   :header-rows: 1
   :widths: 30 35 35

   * - Directive
     - Example
     - Effect
   * - ``Storage=``
     - ``Storage=persistent``
     - ``volatile`` (only in memory), ``persistent`` (to disk), ``auto``, ``none``
   * - ``Compress=``
     - ``Compress=yes``
     - Compress journal files (default: yes)
   * - ``Seal=``
     - ``Seal=yes``
     - Forward secure sealing (FSS) — cryptographic integrity verification
   * - ``SplitMode=``
     - ``SplitMode=journal``
     - Split logs by user: ``uid`` (per-user journals) or ``journal`` (shared)
   * - ``SystemMaxUse=``
     - ``SystemMaxUse=500M``
     - Max total disk usage for system journals
   * - ``SystemKeepFree=``
     - ``SystemKeepFree=1G``
     - Keep at least this much free space
   * - ``SystemMaxFileSize=``
     - ``SystemMaxFileSize=50M``
     - Max size per individual journal file
   * - ``RuntimeMaxUse=``
     - ``RuntimeMaxUse=50M``
     - Max usage in ``/run/log/journal`` (volatile)
   * - ``ForwardToSyslog=``
     - ``ForwardToSyslog=no``
     - Forward messages to traditional syslog daemon
   * - ``MaxRetentionSec=``
     - ``MaxRetentionSec=1week``
     - Max journal entry age; older entries are deleted
   * - ``SyncIntervalSec=``
     - ``SyncIntervalSec=5m``
     - Time interval between journal file syncs

.. code-block:: bash

   sudo systemctl restart systemd-journald   # After config changes

------------------------------------------------------------------------------
B.8.2  journalctl — Querying the Journal
------------------------------------------------------------------------------

.. list-table:: journalctl option reference
   :header-rows: 1
   :widths: 25 35 40

   * - Option
     - Example
     - Description
   * - ``-u``
     - ``journalctl -u nginx.service``
     - Show logs for a specific unit
   * - ``-b``
     - ``journalctl -b``
     - Logs from current boot (``-b -1`` = previous boot, ``-b -2`` = 2 boots ago)
   * - ``--since``
     - ``journalctl --since "1 hour ago"``
     - Show entries since time (flexible format)
   * - ``--until``
     - ``journalctl --until "2026-07-20 10:00:00"``
     - Show entries up to time
   * - ``-p``
     - ``journalctl -p err``
     - Filter by priority: ``emerg``, ``alert``, ``crit``, ``err``, ``warning``, ``notice``, ``info``, ``debug``
   * - ``-k``
     - ``journalctl -k``
     - Kernel messages only (same as ``-b -o short-monotonic -q``)
   * - ``-f``
     - ``journalctl -f``
     - Follow (tail) new messages
   * - ``-n``
     - ``journalctl -n 50``
     - Show last N lines
   * - ``-o``
     - ``journalctl -o json``
     - Output format: ``short``, ``short-iso``, ``verbose``, ``json``, ``json-pretty``, ``cat``
   * - ``--no-pager``
     - ``journalctl --no-pager``
     - Disable pager (pipe-friendly)
   * - ``--dmesg``
     - ``journalctl --dmesg``
     - Show kernel ring buffer (like ``dmesg``)
   * - ``_PID=``
     - ``journalctl _PID=1234``
     - Filter by PID
   * - ``_UID=``
     - ``journalctl _UID=1000``
     - Filter by user ID
   * - ``_COMM=``
     - ``journalctl _COMM=sshd``
     - Filter by command name
   * - ``--list-boots``
     - ``journalctl --list-boots``
     - Show boot IDs with offsets (``-b`` uses these offsets)
   * - ``--disk-usage``
     - ``journalctl --disk-usage``
     - Show total disk usage of journal files
   * - ``--verify``
     - ``journalctl --verify``
     - Verify journal integrity (FSS)

.. rubric:: Common journalctl queries

.. code-block:: bash

   # SSH login failures in the last 24 hours
   journalctl -u sshd.service --since "yesterday" -p err

   # Kernel errors in current boot
   journalctl -k -p err -b

   # All service failures today
   journalctl -p err --since "today" --no-pager

   # Nginx log for a specific timeframe
   journalctl -u nginx.service --since "10:00:00" --until "10:30:00"

   # Who rebooted the system
   journalctl --list-boots
   journalctl -b -1 | grep -i "reboot\|shutdown\|startup"

   # Filter by user's cron jobs
   journalctl _UID=1000 _COMM=cron

------------------------------------------------------------------------------
B.8.3  Journal Persistence & Size Management
------------------------------------------------------------------------------

.. code-block:: bash

   # Make journal persistent (if Storage=auto and /var/log/journal exists)
   sudo mkdir -p /var/log/journal
   sudo systemctl restart systemd-journald

   # Manual cleanup (vacuum)
   sudo journalctl --vacuum-size=200M       # Keep only 200 MB of logs
   sudo journalctl --vacuum-time=1week      # Keep only last week
   sudo journalctl --vacuum-files=5         # Keep only 5 journal files

   # Rotate journal files manually
   sudo journalctl --rotate

   # Check current usage
   journalctl --disk-usage

.. rubric:: Forward journald logs to rsyslog

.. code-block:: bash

   # In /etc/systemd/journald.conf:
   ForwardToSyslog=yes

   # In /etc/rsyslog.conf:
   module(load="imjournal" StateFile="imjournal.state")

------------------------------------------------------------------------------
B.8.4  Log Management Best Practices
------------------------------------------------------------------------------

.. list-table:: Log management tips
   :header-rows: 1
   :widths: 35 65

   * - Practice
     - Rationale
   * - Centralized logging
     - Forward logs to a central log server (rsyslog, syslog-ng, Graylog, ELK) for analysis and long-term storage
   * - Set disk limits
     - Use ``SystemMaxUse=`` and ``MaxRetentionSec=`` to prevent log rotation issues filling the disk
   * - Monitor log volume
     - Abrupt changes in log volume often indicate misconfiguration or attack
   * - Enable FSS
     - ``Seal=yes`` provides cryptographic integrity; an attacker cannot alter logs undetected
   * - Separate log partition
     - Mount ``/var/log`` as a separate filesystem to prevent log flooding from crashing the root filesystem
   * - Regular backup
     - Back up ``/var/log`` for compliance and forensic requirements
   * - Use structured logging
     - JSON output enables easier automated analysis; enable in applications where possible
