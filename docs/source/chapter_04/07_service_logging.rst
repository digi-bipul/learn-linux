.. _section-4-7:

================================================
4.7 Service Logging: journalctl & the Syslog Model
================================================

.. rst-class:: lead

   Every service produces log output — status messages, errors, warnings,
   debug information. How that output is collected, stored, and retrieved is
   a critical operational concern. This section covers the two dominant
   logging paradigms on Linux: **systemd's journal** (binary, structured,
   indexed) and the **traditional syslog** model (plain text, file-based,
   human-readable with standard Unix tools).

4.7.1 The Two Worlds of Linux Logging
========================================

On a systemd-based distribution (Debian, Ubuntu, RHEL, Fedora, Arch), you
have **both** logging systems running:

1. **``systemd-journald``** — systemd's native logging daemon. Captures
   stdout/stderr from all services, kernel messages, and syslog calls.
   Stores everything in a **binary, structured, indexed journal**.
2. **``rsyslogd`` or ``syslog-ng``** — the traditional syslog daemon.
   Reads messages (often forwarded by journald) and writes them to
   human-readable text files like ``/var/log/syslog`` or
   ``/var/log/messages``.

On OpenRC-based systems (Alpine Linux) and Runit-based systems (Void Linux),
only the traditional syslog model is used — typically ``busybox syslogd``
or ``rsyslogd`` writing directly to ``/var/log/messages``.

.. code-block:: text
   :caption: Logging architecture comparison

   systemd system:                    OpenRC/Runit system:

   Service → journald ─┬─→ /var/log/journal/      Service → syslogd ──→ /var/log/messages
                       │                              (busybox or rsyslog)
                       └─→ /run/systemd/journal/
                           (socket → rsyslogd → /var/log/syslog)

4.7.2 The Traditional Syslog Model
=====================================

The syslog system was standardised in **RFC 5424** (2009, superseding RFC
3164 from 2001). Messages have three attributes:

1. **Facility** — The type of system that generated the message
   (``auth``, ``authpriv``, ``cron``, ``daemon``, ``kern``, ``local0``–
   ``local7``, ``mail``, ``news``, ``syslog``, ``user``, ``uucp``).
2. **Severity (Priority)** — The importance level (0–7, with 0 being
   "emergency" and 7 being "debug").
3. **Message** — The free-form text.

.. table:: Syslog Severity Levels
   :widths: 10 15 25 50

   +-------+----------+-----------------+-----------------------------------+
   | Code  | Keyword  | Syslog constant  | Typical meaning                   |
   +=======+==========+=================+===================================+
   | 0     | emerg    | LOG_EMERG       | System is unusable (panic).        |
   +-------+----------+-----------------+-----------------------------------+
   | 1     | alert    | LOG_ALERT       | Immediate action required         |
   |       |          |                 | (e.g., database corruption).       |
   +-------+----------+-----------------+-----------------------------------+
   | 2     | crit     | LOG_CRIT        | Critical condition (disk failure, |
   |       |          |                 | service crash).                   |
   +-------+----------+-----------------+-----------------------------------+
   | 3     | err      | LOG_ERR         | Error condition.                  |
   +-------+----------+-----------------+-----------------------------------+
   | 4     | warning  | LOG_WARNING     | Warning condition.                |
   +-------+----------+-----------------+-----------------------------------+
   | 5     | notice   | LOG_NOTICE      | Normal but significant condition. |
   +-------+----------+-----------------+-----------------------------------+
   | 6     | info     | LOG_INFO        | Informational message.            |
   +-------+----------+-----------------+-----------------------------------+
   | 7     | debug    | LOG_DEBUG       | Debug-level messages (not usually |
   |       |          |                 | logged by default).               |
   +-------+----------+-----------------+-----------------------------------+

**Traditional log files:**

.. table:: Common Traditional Syslog Files
   :widths: 25 75

   +-----------------------------+-------------------------------------------+
   | File                        | Content                                   |
   +=============================+===========================================+
   | ``/var/log/messages``       | General system messages (RHEL/CentOS).    |
   |                             | Alpine Linux also uses this.              |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/syslog``         | General system messages (Debian/Ubuntu).  |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/auth.log``       | Authentication events (Debian/Ubuntu).    |
   |                             | ``ssh``, ``sudo``, login attempts.        |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/secure``         | Authentication events (RHEL/Fedora).      |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/kern.log``       | Kernel messages.                          |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/cron.log``       | Cron job execution logs.                  |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/maillog``        | Mail server logs (postfix, sendmail).     |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/boot.log``       | System boot messages.                     |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/faillog``        | Failed login attempts.                    |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/lastlog``        | Last login records (binary, use           |
   |                             | ``lastlog`` to read).                     |
   +-----------------------------+-------------------------------------------+
   | ``/var/log/wtmp``           | Login records (binary, use ``last``       |
   |                             | or ``who /var/log/wtmp``).                |
   +-----------------------------+-------------------------------------------+

**Viewing traditional logs:**

.. code-block:: console

   # View syslog with standard Unix tools
   $ tail -f /var/log/syslog         # Follow new messages
   $ grep -i error /var/log/syslog   # Search for errors
   $ less /var/log/messages          # Page through
   $ head -50 /var/log/auth.log      # First 50 lines

   # On Alpine Linux (OpenRC):
   $ cat /var/log/messages | tail -20

**Log rotation (logrotate):**

Log files are rotated (archived and compressed) by ``logrotate(8)``,
typically run daily via cron:

.. code-block:: text
   :caption: ``/etc/logrotate.d/rsyslog``

   /var/log/syslog
   {
       rotate 7
       daily
       compress
       delaycompress
       missingok
       notifempty
       postrotate
           /usr/lib/rsyslog/rsyslog-rotate
       endscript
   }

4.7.3 The systemd Journal — ``journalctl``
=============================================

The systemd journal is a **binary, structured, indexed** log storage system.
It offers several advantages over plain-text syslog:

* **Structured metadata**: Every log entry has 50+ fields (PID, UID, GID,
  executable path, code location, kernel facility, priority, boot ID, etc.).
* **Indexed**: Fast querying by time, priority, unit, executable, or any
  metadata field — no ``grep`` needed.
* **Reliable storage**: Entries are written atomically. Corruption is
  detected and isolated.
* **Compression**: Journal files are compressed with LZ4 or XZ.
* **Forward-secure sealing**: Cryptographic sealing (if enabled) detects
  log tampering.

4.7.3.1 ``journalctl`` — Querying the Journal

.. code-block:: console
   :caption: Essential ``journalctl`` commands

   # Show all log entries (most recent last — same as less)
   $ journalctl

   # Follow new entries (like tail -f)
   $ journalctl -f

   # Show only the last N lines
   $ journalctl -n 50

   # Show logs for a specific service
   $ journalctl -u nginx.service

   # Show logs for multiple services
   $ journalctl -u nginx.service -u sshd.service

   # Show kernel messages only (equivalent to dmesg)
   $ journalctl -k

   # Show logs from the current boot
   $ journalctl -b

   # Show logs from the previous boot
   $ journalctl -b -1

   # Show logs from a specific boot ID
   $ journalctl -b 7c8a1a2b3c4d5e6f7a8b9c0d1e2f3a4b

   # List available boots
   $ journalctl --list-boots
   -2 a1b2c3d4...  Mon 2026-07-13 08:00:00 UTC—Mon 2026-07-13 18:30:00 UTC
   -1 e5f6a7b8...  Tue 2026-07-14 09:00:00 UTC—Tue 2026-07-14 22:00:00 UTC
    0 c9d0e1f2...  Wed 2026-07-15 06:00:00 UTC—Wed 2026-07-15 12:30:00 UTC

4.7.3.2 Filtering by Time

.. code-block:: console
   :caption: Time-based filtering

   # Show logs from the last hour
   $ journalctl --since "1 hour ago"

   # Show logs since a specific time
   $ journalctl --since "2026-07-15 10:00:00"

   # Show logs until a specific time
   $ journalctl --until "2026-07-15 12:00:00"

   # Time range
   $ journalctl --since "2026-07-15 08:00" --until "2026-07-15 10:00"

   # Relative time expressions
   $ journalctl --since yesterday
   $ journalctl --since "2 days ago"
   $ journalctl --since "last week"

4.7.3.3 Filtering by Priority

.. code-block:: console

   # Show only messages with priority 'err' or higher (0-3)
   $ journalctl -p err
   $ journalctl -p 3           # Same as above (numeric)

   # Show only messages with priority 'warning' or higher (0-4)
   $ journalctl -p warning

   # Combine with service filter
   $ journalctl -u nginx.service -p err --since "1 hour ago"

4.7.3.4 Output Format Control

.. code-block:: console

   # Traditional syslog-style output
   $ journalctl -o short          # Default
   $ journalctl -o short-iso      # With ISO timestamps

   # Verbose: show all metadata fields for each entry
   $ journalctl -o verbose

   # JSON output (for programmatic consumption)
   $ journalctl -o json
   $ journalctl -o json-pretty    # Multi-line, human-readable JSON

   # cat mode: just the message (no timestamp, no hostname)
   $ journalctl -o cat

   # Export format (for transfer between systems)
   $ journalctl -o export

4.7.3.5 Metadata Field Filtering

The journal records dozens of metadata fields. You can filter on any of
them:

.. code-block:: console

   # Show all available fields for a unit
   $ journalctl -u sshd.service -o verbose | head -20

   # Filter by executable path
   $ journalctl _EXE=/usr/sbin/sshd

   # Filter by PID
   $ journalctl _PID=1234

   # Filter by UID
   $ journalctl _UID=0            # Root's messages

   # Filter by systemd unit (equivalent to -u)
   $ journalctl _SYSTEMD_UNIT=nginx.service

   # Filter by command line match
   $ journalctl _COMM=sshd        # Base process name

   # Filter by facility
   $ journalctl SYSLOG_FACILITY=10     # 10 = authpriv

   # Combine multiple fields (AND logic)
   $ journalctl _UID=0 _PID=1     # Only messages from PID 1 as root

   # Show only messages with a specific message ID
   $ journalctl MESSAGE_ID=9f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c

4.7.3.6 Journal Maintenance

.. code-block:: console

   # Check journal disk usage
   $ journalctl --disk-usage
   Archived and active journals take up 128.0M in the file system.

   # Vacuum journals older than the specified time
   # journalctl --vacuum-time=30d

   # Vacuum to a maximum size
   # journalctl --vacuum-size=500M

   # Vacuum to a maximum number of files
   # journalctl --vacuum-files=10

   # Manually rotate the journal (archives current file, starts new)
   # journalctl --rotate

**Persistent vs. volatile journal:**

By default on many distributions, the journal is stored in
``/run/systemd/journal/`` — a **volatile** tmpfs that is lost on reboot.
To make it persistent:

.. code-block:: console

   # mkdir -p /var/log/journal
   # chown root:systemd-journal /var/log/journal
   # systemctl restart systemd-journald

   # Verify:
   $ journalctl --header | grep 'Storage:'
   Storage: persistent

The configuration is in ``/etc/systemd/journald.conf``:

.. code-block:: ini
   :caption: ``/etc/systemd/journald.conf`` (key options)

   [Journal]
   Storage=auto             # auto, volatile, persistent, or none
   Compress=yes             # Compress old entries (LZ4/XZ)
   SystemMaxUse=1G          # Maximum space for persistent journals
   SystemMaxFileSize=100M   # Maximum file size for a single journal file
   MaxRetentionSec=1month   # Maximum age for entries
   ForwardToSyslog=yes      # Forward entries to the traditional syslog daemon

4.7.4 Structured Logging with ``journalctl`` — A Practical Example
=====================================================================

Let us trace a real diagnostic workflow:

.. code-block:: console
   :caption: Investigating an nginx crash

   # 1. What happened?
   $ journalctl -u nginx.service --since "5 min ago"

   # 2. Any recent errors?
   $ journalctl -u nginx.service -p err --since "1 hour ago"

   # 3. Show the last 20 messages with verbose metadata
   $ journalctl -u nginx.service -n 20 -o verbose

   # 4. Did the service restart?
   $ journalctl -u nginx.service _COMM=nginx | grep -i "start\|stop\|exit"

   # 5. Check for OOM kills around the same time
   $ journalctl -k -p emerg --since "1 hour ago"

   # 6. Follow the log in real time while reproducing the issue
   $ journalctl -u nginx.service -f

   # 7. Export the relevant time window for later analysis
   $ journalctl -u nginx.service --since "2026-07-15 12:00" \
     --until "2026-07-15 12:05" -o json > nginx-crash.json

4.7.5 ``journalctl`` vs. ``tail -f /var/log/syslog`` — When to Use Which
===========================================================================

.. table:: Comparison
   :widths: 25 35 40

   +---------------------------+--------------------------------+--------------------------------+
   | Task                      | journalctl                     | Traditional syslog             |
   +===========================+================================+================================+
   | Real-time monitoring      | ``journalctl -u UNIT -f``      | ``tail -f /var/log/syslog``    |
   +---------------------------+--------------------------------+--------------------------------+
   | Search by service         | ``-u UNIT`` (fast, indexed)    | ``grep "nginx" /var/log/syslog``|
   +---------------------------+--------------------------------+--------------------------------+
   | Search by time range      | ``--since/--until`` (easy)     | ``awk`` or manual date         |
   |                           |                                | filtering (cumbersome).        |
   +---------------------------+--------------------------------+--------------------------------+
   | Search by priority        | ``-p err`` (easy)              | ``grep -E "(error|critical)"`` |
   +---------------------------+--------------------------------+--------------------------------+
   | Structured metadata       | ``-o verbose / -o json``       | Not available (plain text).    |
   +---------------------------+--------------------------------+--------------------------------+
   | Cross-service correlation | ``journalctl -u a -u b``       | ``grep`` with timestamps       |
   |                           |                                | (manual).                      |
   +---------------------------+--------------------------------+--------------------------------+
   | Piping to other tools     | ``-o cat`` (message only) or   | Direct piping (it is text).    |
   |                           | ``-o json`` (for jq).          |                                |
   +---------------------------+--------------------------------+--------------------------------+
   | Script integration        | ``journalctl -q -u UNIT -n 1`` | ``tail -1 /var/log/syslog``    |
   +---------------------------+--------------------------------+--------------------------------+
   | Disk space efficiency     | Compressed, indexed (less I/O  | Plain text, larger, not indexed|
   |                           | for searches).                 | but trivially compressible.    |
   +---------------------------+--------------------------------+--------------------------------+
   | Works without systemd     | **No** — requires systemd-journald | **Yes** — on OpenRC, Runit, |
   |                           |                                | or any system with syslog.     |
   +---------------------------+--------------------------------+--------------------------------+

4.7.6 The ``dmesg`` Kernel Ring Buffer
=========================================

The kernel maintains a **ring buffer** of boot and runtime messages. On
systemd systems, these are available via both ``dmesg(1)`` and
``journalctl -k``.

.. code-block:: console

   # Traditional: kernel ring buffer
   $ dmesg | tail -20

   # Follow kernel messages in real time
   $ dmesg -w

   # Human-readable timestamps
   $ dmesg -T

   # Clear the ring buffer
   # dmesg -c

   # Via journalctl
   $ journalctl -k --since "10 min ago"

4.7.7 Summary
==============

* The **traditional syslog model** stores plain-text log files in
  ``/var/log/`` (``syslog``, ``messages``, ``auth.log``, ``kern.log``).
  It is simple, universally understood, and works with standard Unix tools.
* **systemd's journal** stores binary, structured, indexed logs. The
  ``journalctl`` command provides powerful querying by unit, time,
  priority, and metadata fields.
* ``journalctl -u SERVICE -p err --since "1 hour ago"`` is the go-to
  command for investigating a service problem.
* On systemd systems, both journald and rsyslog typically run — journald
  for structured storage and rapid querying, rsyslog for traditional
  plain-text log files.
* On OpenRC/Runit systems (Alpine, Void), only traditional syslog is
  used — typically ``/var/log/messages`` is the central log file.
* The journal can be persisted by creating ``/var/log/journal/``.
* Use ``journalctl --vacuum-*`` to manage journal disk usage.

