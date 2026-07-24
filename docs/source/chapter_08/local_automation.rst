.. _local-automation:

.. highlight:: bash

========================================
— Local Automation & Event Hooks
========================================

A script sitting in a file is potential.  A script that runs automatically is
power.  This section covers schedulers, parallel executors, and event-driven
triggers.

--------------------------------
Cron — The Traditional Scheduler
--------------------------------

**Crontab syntax:**

.. code-block:: text

   ┌───────── minute (0-59)
   │ ┌───────── hour (0-23)
   │ │ ┌───────── day of month (1-31)
   │ │ │ ┌───────── month (1-12)
   │ │ │ │ ┌───────── day of week (0-7, 0/7=Sun)
   │ │ │ │ │
   * * * * * command-to-execute

**Common patterns:**

.. code-block:: text

   30 2 * * * /home/alice/bin/backup.sh        # Every day at 2:30 AM
   */15 * * * * /usr/local/bin/check.sh        # Every 15 minutes
   0 9 * * 1-5 /home/alice/bin/start_work.sh   # Weekdays at 9 AM
   0 0 1 * * /home/alice/bin/monthly.sh        # 1st of month at midnight

**Practical tips:**

* Use **absolute paths** — cron's ``$PATH`` is minimal.
* **Redirect output** — ``>> /var/log/backup.log 2>&1``.
* **Use locking** — ``flock -n /tmp/backup.lock /path/to/script``.

.. _cron_antipattern:

**Antipattern:** Assuming cron knows your ``$PATH`` — always use full paths.

--------------------------------
Systemd Timers — The Modern Standard
--------------------------------

**Service unit** (``/etc/systemd/system/mybackup.service``):

.. code-block:: ini

   [Unit]
   Description=Daily backup service
   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/backup.sh
   User=alice

**Timer unit** (``/etc/systemd/system/mybackup.timer``):

.. code-block:: ini

   [Unit]
   Description=Daily backup timer
   [Timer]
   OnCalendar=*-*-* 02:00:00
   Persistent=true
   RandomizedDelaySec=30min
   [Install]
   WantedBy=timers.target

**Commands:**

.. code-block:: bash

   sudo systemctl daemon-reload
   sudo systemctl enable mybackup.timer
   sudo systemctl start mybackup.timer
   systemctl list-timers
   journalctl -u mybackup.service

**Comparison:**

+----------------------------+-------------------------------+------------------------------------+
| Feature                    | Cron                          | Systemd Timer                      |
+============================+===============================+====================================+
| Persistent (catch up)      | No (unless anacron)           | Yes (``Persistent=true``)          |
+----------------------------+-------------------------------+------------------------------------+
| Random delay               | No (manual sleep hack)        | ``RandomizedDelaySec=``            |
+----------------------------+-------------------------------+------------------------------------+
| Logging                    | Mail or redirect              | ``journalctl``                     |
+----------------------------+-------------------------------+------------------------------------+
| Dependencies               | No                            | Yes (unit dependency graph)        |
+----------------------------+-------------------------------+------------------------------------+
| Portability                | Every Unix-like system        | Linux with systemd only            |
+----------------------------+-------------------------------+------------------------------------+

--------------------------------
Concurrent Execution: ``xargs -P`` and GNU ``parallel``
--------------------------------

**``xargs -P``:**

.. code-block:: bash

   find /var/log -name "*.log" -print0 | xargs -0 -P4 -I{} gzip {}
   # -P4 = 4 parallel processes, -0 = NUL-delimited input

**GNU ``parallel``:**

.. code-block:: bash

   parallel gzip ::: *.log
   parallel -j4 "echo Processing job {}; sleep 1" ::: {1..10}
   parallel --dry-run echo "Would process {}" ::: file1 file2

**Key features:** ``--keep-order`` (preserve input order), ``--progress``
(show progress bar), ``--eta`` (estimate time), ``-S`` (remote execution).

--------------------------------
Event-Driven Automation: ``inotifywait``
--------------------------------

.. code-block:: bash

   #!/usr/bin/env bash
   WATCH_DIR="/var/www/uploads"

   inotifywait -m -e close_write --format '%f' "$WATCH_DIR" |
   while IFS= read -r filename; do
       echo "New file: $filename"
       /usr/local/bin/process_file.sh "$WATCH_DIR/$filename"
   done

**Key events:** ``create``, ``close_write``, ``modify``, ``delete``,
``moved_to``.  Always use ``close_write`` rather than ``modify`` to avoid
processing a file before it is fully written.

--------------------------------
What NOT to Do — Automation Pitfalls
--------------------------------

**Antipattern 1:** Concurrent cron jobs stamping on each other — use ``flock``.

**Antipattern 2:** Not handling cron's minimal environment — always use full
paths or set ``PATH`` in crontab.

**Antipattern 3:** Using ``modify`` instead of ``close_write`` in inotify.

**Antipattern 4:** Running too many parallel jobs — use ``-P "$(nproc)"``.

--------------------------------
Summary
--------------------------------

+------------------+-------------------------------------------------------+
| Tool             | Best Use Case                                         |
+==================+=======================================================+
| ``cron``         | Simple time-based scheduling, portable across Unix    |
+------------------+-------------------------------------------------------+
| systemd timer    | Modern scheduling with persistence, logging, deps     |
+------------------+-------------------------------------------------------+
| ``xargs -P``     | Simple parallel execution from a pipeline             |
+------------------+-------------------------------------------------------+
| GNU ``parallel`` | Complex parallel jobs, multi-host, progress tracking  |
+------------------+-------------------------------------------------------+
| ``inotifywait``  | Event-driven automation from filesystem changes       |
+------------------+-------------------------------------------------------+
