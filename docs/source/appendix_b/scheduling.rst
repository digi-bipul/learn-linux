.. _app-b-cron:

------------------------------------------------------------------------------
Scheduling (cron, systemd timers, at/batch)
------------------------------------------------------------------------------

------------------------------------------------------------------------------
Cron
------------------------------------------------------------------------------

.. rubric:: Crontab format

.. code-block:: text

   # ┌────────── minute (0-59)
   # │ ┌────────── hour (0-23)
   # │ │ ┌────────── day of month (1-31)
   # │ │ │ ┌────────── month (1-12 or JAN-DEC)
   # │ │ │ │ ┌────────── day of week (0-7, 0=Sun, 7=Sun; or SUN-SAT)
   # * * * * *  command

.. list-table:: Crontab Special Strings
   :header-rows: 1
   :widths: 20 30 50

   * - String
     - Meaning
     - Equivalent
   * - ``@reboot``
     - Run once at boot
     - N/A (not a time field)
   * - ``@yearly`` / ``@annually``
     - Run once per year
     - ``0 0 1 1 *``
   * - ``@monthly``
     - Run once per month
     - ``0 0 1 * *``
   * - ``@weekly``
     - Run once per week
     - ``0 0 * * 0``
   * - ``@daily``
     - Run once per day
     - ``0 0 * * *``
   * - ``@hourly``
     - Run once per hour
     - ``0 * * * *``

.. rubric:: Crontab commands

.. code-block:: bash

   crontab -e              # Edit current user's crontab
   crontab -l              # List current user's crontab
   crontab -r              # Remove current user's crontab
   crontab -u alice -l     # List another user's crontab (root only)

   # System-wide cron files:
   ls /etc/cron.d/         # System crontab fragments
   ls /etc/cron.hourly/    # Scripts run hourly
   ls /etc/cron.daily/     # Scripts run daily
   ls /etc/cron.weekly/    # Scripts run weekly
   ls /etc/cron.monthly/   # Scripts run monthly

.. rubric:: Environment in cron

.. code-block:: bash

   # Set variables at the top of crontab
   SHELL=/bin/bash
   PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
   MAILTO=admin@example.com
   HOME=/root

   # Cron runs with minimal PATH — always use full paths or set PATH explicitly.

.. rubric:: Common cron patterns

.. code-block:: text

   # Every 15 minutes
   */15 * * * * /usr/local/bin/check_health.sh

   # Every day at 2:30 AM
   30 2 * * * /usr/local/bin/daily_backup.sh

   # Every weekday (Mon-Fri) at 9 AM
   0 9 * * 1-5 /usr/local/bin/weekday_report.sh

   # First day of every month at midnight
   0 0 1 * * /usr/local/bin/monthly_cleanup.sh

   # Every 2 hours during business hours (8 AM - 6 PM)
   0 8-18/2 * * * /usr/local/bin/business_hours_check.sh

   # Every Sunday at 3 AM
   0 3 * * 0 /usr/local/bin/weekly_maintenance.sh

------------------------------------------------------------------------------
systemd Timers
------------------------------------------------------------------------------

systemd timers are the modern replacement for cron. They offer calendar events
and monotonic timers (relative to boot/activation).

.. rubric:: Timer file location

.. code-block:: text

   /etc/systemd/system/*.timer
   /usr/lib/systemd/system/*.timer

.. rubric:: Monotonic timer example

.. code-block:: text

   # /etc/systemd/system/backup.service
   [Unit]
   Description=Daily backup service

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/daily_backup.sh

   # /etc/systemd/system/backup.timer
   [Unit]
   Description=Run backup daily

   [Timer]
   OnCalendar=daily
   Persistent=true                        # Catch up if missed (e.g., after boot)
   RandomizedDelaySec=1800                # 30-minute random delay to spread load

   [Install]
   WantedBy=timers.target

.. rubric:: OnCalendar syntax

.. list-table:: OnCalendar patterns
   :header-rows: 1
   :widths: 30 70

   * - Expression
     - Meaning
   * - ``daily``
     - Every day at midnight
   * - ``hourly``
     - Every hour at :00
   * - ``weekly``
     - Every Monday at midnight
   * - ``monthly``
     - First day of each month at midnight
   * - ``*-*-* 03:00:00``
     - Every day at 3:00 AM
   * - ``Mon..Fri 09:00:00``
     - Weekdays at 9 AM
   * - ``*:0/15``
     - Every 15 minutes
   * - ``2026-07-20 10:00:00``
     - Specific date/time
   * - ``Sun 02:00:00``
     - Every Sunday at 2 AM
   * - ``*-*-01 00:00:00``
     - First day of every month at midnight

.. rubric:: Monotonic timer directives

.. list-table::
   :header-rows: 1
   :widths: 25 40 35

   * - Directive
     - Example
     - Meaning
   * - ``OnBootSec``
     - ``OnBootSec=5min``
     - Run 5 minutes after boot
   * - ``OnUnitActiveSec``
     - ``OnUnitActiveSec=1h``
     - Run 1 hour after last activation
   * - ``OnUnitInactiveSec``
     - ``OnUnitInactiveSec=30m``
     - Run 30 minutes after last *de*activation
   * - ``OnStartupSec``
     - ``OnStartupSec=10min``
     - Run 10 minutes after systemd started

.. rubric:: Timer management

.. code-block:: bash

   sudo systemctl daemon-reload
   sudo systemctl enable --now backup.timer

   # List timers
   systemctl list-timers --all
   systemctl list-timers

   # Check timer status
   systemctl status backup.timer

   # View next trigger time
   systemctl show -p NextElapseUSecRealtime backup.timer

   # Debug timer (dry-run)
   systemd-analyze verify /etc/systemd/system/backup.timer

   # Force-run the associated service
   sudo systemctl start backup.service

------------------------------------------------------------------------------
at and batch
------------------------------------------------------------------------------

``at`` schedules a one-time job for a specific time. ``batch`` runs a job when
system load permits.

.. code-block:: bash

   # Schedule a job
   echo "sh /path/to/script.sh" | at now + 5 minutes
   at 14:30 <<< "/usr/bin/upgrade.sh"
   at 10:00 PM July 25 <<< "systemctl restart nginx"

   # List pending jobs
   atq

   # Remove job #5
   atrm 5

   # batch — runs when load average < 0.8
   echo "make -j8" | batch

.. list-table:: at time specification examples
   :header-rows: 1
   :widths: 40 60

   * - Expression
     - Meaning
   * - ``now + 5 minutes``
     - 5 minutes from now
   * - ``now + 2 hours``
     - 2 hours from now
   * - ``now + 1 day``
     - Tomorrow at this time
   * - ``14:30``
     - Today or tomorrow at 2:30 PM
   * - ``10:00 PM July 25``
     - Specific date and time
   * - ``4:00 AM Jul 20 2026``
     - Fully specified date
   * - ``teatime``
     - 4 PM (16:00)
   * - ``noon``
     - 12:00 PM
   * - ``midnight``
     - 12:00 AM
   * - ``next monday``
     - Next Monday at midnight (uses time if provided)
   * - ``now + 1 week``
     - 7 days from now
