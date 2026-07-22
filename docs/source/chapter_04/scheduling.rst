.. _section-4-8:

4.8 Scheduling: Cron, Anacron, At, and systemd Timers
=====================================================

.. rst-class:: lead

   Automating recurring tasks is one of the most fundamental responsibilities
   of a system administrator. Rotating logs, updating package databases,
   running backups, generating reports — these tasks must happen reliably
   on schedule, without human intervention. Linux provides a rich ecosystem
   of scheduling tools, from the venerable ``cron`` to the modern
   ``systemd.timer``. This section covers them all, with a detailed
   comparison to help you choose the right tool for each job.

4.8.1 The History of Unix Scheduling
======================================

The original ``cron`` (from the Greek *chronos*, meaning "time") was written
by Ken Thompson in 1975 for Version 7 Unix. It was a simple daemon that
woke up every minute, checked a set of scheduled jobs, and ran any that
were due. This design has remained essentially unchanged for 50 years —
a testament to its simplicity and correctness.

.. code-block:: text

   Evolution of Linux scheduling tools:
   1975:  Ken Thompson's cron (V7 Unix)
   1987:  Vixie cron (Paul Vixie) — the standard Linux implementation
   1990s: anacron — handles jobs missed while the system was off
   2000s: at and batch — one-time future execution
   2010s: fcron — enhanced cron with finer granularity
   2015+:  systemd timers — modern, integrated replacement for cron

4.8.2 Cron — The Universal Scheduler
========================================

The ``cron(8)`` daemon reads configuration files (crontabs) and executes
commands at specified times. The two most common implementations are:

* **Vixie cron** (``cronie`` package on RHEL/Fedora/Arch, ``cron`` on
  Debian/Ubuntu).
* **Busybox cron** (on Alpine Linux — smaller, fewer features).

4.8.2.1 The Crontab Syntax

A crontab file has five time-and-date fields followed by the command:

.. code-block:: text

   ┌──────── minute (0-59)
   │ ┌─────── hour (0-23)
   │ │ ┌────── day of month (1-31)
   │ │ │ ┌───── month (1-12)
   │ │ │ │ ┌──── day of week (0-7, where 0 and 7 = Sunday)
   │ │ │ │ │
   * * * * * command_to_execute

**Field operators:**

.. table:: Crontab Field Operators
   :widths: 15 25 60

   +----------+-------------------+-----------------------------------------+
   | Operator | Example           | Meaning                                 |
   +==========+===================+=========================================+
   | ``*``    | ``* * * * *``     | Every minute (wildcard — matches all). |
   +----------+-------------------+-----------------------------------------+
   | ``*/N``  | ``*/15 * * * *``  | Every N units. ``*/15`` = every 15     |
   |          |                   | minutes.                                |
   +----------+-------------------+-----------------------------------------+
   | ``N,M``  | ``0,30 * * * *``  | Multiple discrete values: at minute 0  |
   |          |                   | and minute 30.                          |
   +----------+-------------------+-----------------------------------------+
   | ``N-M``  | ``9-17 * * * *``  | Range: every hour from 09:00 to 17:00. |
   +----------+-------------------+-----------------------------------------+
   | ``N``    | ``30 2 * * *``    | A specific value: at 02:30 daily.      |
   +----------+-------------------+-----------------------------------------+

**Common crontab examples:**

.. code-block:: text
   :caption: Useful crontab entries

   # Every minute (for testing)
   * * * * * /usr/bin/logger "cron ran"

   # Every day at 3:30 AM
   30 3 * * * /usr/local/bin/daily-backup

   # Every Monday at 5:00 AM
   0 5 * * 1 /usr/local/bin/weekly-report

   # Every 15 minutes during business hours (9 AM - 6 PM)
   */15 9-17 * * * /usr/local/bin/health-check

   # First day of every month at midnight
   0 0 1 * * /usr/local/bin/monthly-archive

   # Twice daily: 6:00 AM and 6:00 PM
   0 6,18 * * * /usr/local/bin/twice-daily

   # Every 10 minutes, Monday through Friday
   */10 * * * 1-5 /usr/local/bin/check-work-hours

   # Every restart of cron (special @reboot)
   @reboot /usr/local/bin/start-custom-daemon

   # Special shorthands (Vixie cron)
   @hourly     /usr/local/bin/hourly-task
   @daily      /usr/local/bin/daily-task
   @weekly     /usr/local/bin/weekly-task
   @monthly    /usr/local/bin/monthly-task
   @yearly     /usr/local/bin/yearly-task

.. caution::

   Cron runs commands with a **limited environment**. By default:
   * ``SHELL=/bin/sh`` (not bash).
   * ``HOME`` is the user's home directory.
   * ``PATH`` is typically ``/usr/bin:/bin`` (not
     ``/usr/local/sbin:/usr/local/bin``, etc.).
   * No interactive environment variables (``DISPLAY``, ``DBUS_SESSION_BUS_ADDRESS``)
     are set.

   Always use **absolute paths** for commands in crontab, or set ``PATH``
   at the top of the crontab:

   .. code-block:: text

      PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
      SHELL=/bin/bash
      30 3 * * * /usr/local/bin/daily-backup

4.8.2.2 Managing Crontabs with ``crontab``

.. code-block:: console
   :caption: ``crontab`` commands

   # Edit the current user's crontab
   $ crontab -e

   # List the current user's crontab
   $ crontab -l

   # Remove the current user's crontab
   $ crontab -r

   # Edit another user's crontab (root only)
   # crontab -u alice -e

   # List another user's crontab (root only)
   # crontab -u alice -l

   # Install a crontab from a file
   $ crontab my_crontab.txt

**Crontab security:**

Access to cron is controlled by two files:

.. code-block:: text

   /etc/cron.allow      # Explicitly allowed users (one per line)
   /etc/cron.deny       # Explicitly denied users

If ``cron.allow`` exists, only users listed in it can use ``crontab``.
If only ``cron.deny`` exists, all users except those listed can use cron.

4.8.2.3 System-Wide Crontab Directories

In addition to per-user crontabs, the system runs jobs from these
directories:

.. code-block:: text

   /etc/crontab                 # System crontab (has an extra "user" field)
   /etc/cron.d/                 # Package-specific crontabs (e.g., sysstat)
   /etc/cron.hourly/            # Scripts run every hour
   /etc/cron.daily/             # Scripts run daily
   /etc/cron.weekly/            # Scripts run weekly
   /etc/cron.monthly/           # Scripts run monthly

The system crontab (``/etc/crontab``) has an **extra column** for the user:

.. code-block:: text
   :caption: ``/etc/crontab``

   SHELL=/bin/sh
   PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

   # Example of job definition:
   # .---------------- minute (0-59)
   # |  .------------- hour (0-23)
   # |  |  .---------- day of month (1-31)
   # |  |  |  .------- month (1-12)
   # |  |  |  |  .---- day of week (0-7)
   # |  |  |  |  |
   # *  *  *  *  * user command
   17 *  *  *  * root cd / && run-parts --report /etc/cron.hourly
   25 6  *  *  * root test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.daily )
   47 6  *  * 7 root test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.weekly )
   52 6  1 * * root test -x /usr/sbin/anacron || ( cd / && run-parts --report /etc/cron.monthly )

The ``run-parts`` command runs every executable script in a directory. This
is how packages can drop scripts into ``/etc/cron.daily/`` and have them
run automatically.

4.8.2.4 Cron Environment and Common Pitfalls

.. code-block:: text
   :caption: Common cron debugging checklist

   ✓ Use absolute paths: /usr/local/bin/script, not ./script
   ✓ Set PATH explicitly at the top of the crontab
   ✓ Set SHELL if you need bash features
   ✓ Ensure the script is executable (chmod +x)
   ✓ Redirect output: 0 3 * * * /script.sh > /tmp/cron.log 2>&1
   ✓ Or use MAILTO: MAILTO=admin@example.com
   ✓ Test the script manually before installing in cron
   ✓ Check /var/log/syslog or /var/log/cron for cron execution records

**Capturing output:**

By default, cron mails stdout and stderr to the user's mailbox
(``MAILTO`` variable). To prevent this, redirect output:

.. code-block:: text

   # Discard all output (silence)
   0 3 * * * /usr/local/bin/script.sh > /dev/null 2>&1

   # Log to a file
   0 3 * * * /usr/local/bin/script.sh >> /var/log/script.log 2>&1

4.8.3 Anacron — Handling Missed Jobs
=======================================

Cron assumes the system is **always running**. On a laptop or a workstation
that is turned off at night, a cron job scheduled for 3:00 AM will simply
be skipped if the system was powered off.

**``anacron(8)``** solves this. It maintains a timestamp file for each job
and runs jobs that were missed when the system was off.

.. code-block:: console

   # anacron runs daily, weekly, and monthly jobs
   # It is invoked from /etc/crontab (see above — the
   # "test -x /usr/sbin/anacron || ..." pattern)

**anacron configuration:** ``/etc/anacrontab``

.. code-block:: text
   :caption: ``/etc/anacrontab``

   # period  delay  job-identifier  command
   1         5      cron.daily      run-parts /etc/cron.daily
   7         10     cron.weekly     run-parts /etc/cron.weekly
   30        15     cron.monthly    run-parts /etc/cron.monthly

   # Fields:
   # period:  How often (in days) the job should run.
   # delay:   How long (in minutes) to wait after boot before running.
   # job-identifier:  A unique name for timestamp tracking.
   # command: The command to execute.

**How anacron works:**

1. On boot, anacron reads ``/var/spool/anacron/`` timestamp files.
2. If the last run time of ``cron.daily`` is more than 1 day ago, anacron
   waits 5 minutes (the ``delay``) and then runs ``run-parts /etc/cron.daily``.
3. After successful execution, it updates the timestamp file.

.. note::

   Anacron only handles **daily, weekly, and monthly** granularity. It
   cannot handle hourly jobs. For that, cron is still needed. Many
   distributions use both: cron runs hourly jobs directly, and triggers
   anacron for daily/weekly/monthly batches (as shown in the ``/etc/crontab``
   example above).

4.8.4 ``at`` and ``batch`` — One-Time Future Execution
=========================================================

While cron handles recurring tasks, ``at(1)`` schedules a command to run
**once at a specific time**. ``batch(1)`` schedules a job to run when the
system load is low.

.. code-block:: console
   :caption: ``at`` — one-time scheduling

   # Run a command at a specific time
   $ echo "systemctl restart nginx" | at 03:00
   $ at 03:00 <<< "systemctl restart nginx"

   # Run a command at a relative time
   $ at now + 1 hour
   at> ./deploy.sh
   at> Ctrl+D

   $ at now + 30 minutes
   $ at now + 2 days
   $ at 09:00 tomorrow

   # Run a command next Tuesday
   $ at 10:00 next Tuesday

   # List pending jobs
   $ atq
   1234    Wed Jul 15 15:00:00 2026 a jdoe

   # Remove a pending job
   $ atrm 1234

**``batch`` — load-dependent execution:**

.. code-block:: console

   $ batch
   at> /usr/local/bin/compile-large-project.sh
   at> Ctrl+D

   # The job runs when the system load average drops below 1.5
   # (or whatever is in /proc/sys/kernel/sched_load_latency)

**Security:** Access to ``at`` and ``batch`` is controlled by
``/etc/at.allow`` and ``/etc/at.deny`` (analogous to cron).

4.8.5 systemd Timers — The Modern Replacement for Cron
=========================================================

systemd timers (``.timer`` units) provide all the functionality of cron,
anacron, and ``at`` combined, with several significant advantages:

* **Integration with systemd**: Timers can depend on services, targets,
  and other timers. Logging is via the journal.
* **Monotonic timers**: "Run 30 minutes after boot" or "Run 5 minutes after
  the previous activation finishes" — not possible with cron.
* **Calendar-based timers**: Same as cron, but more readable.
* **Persistent timers**: Catch up on missed runs (like anacron).
* **Failure handling**: The systemd journal records whether a timer's
  triggered service succeeded or failed.
* **Randomised delays**: Avoid "thundering herd" problems (many systems
  running the same job at exactly the same second).

4.8.5.1 Anatomy of a systemd Timer

A timer unit works by **activating** another unit (usually a
``.service``). The timer file and the service file have the same base name:

.. code-block:: text

   myapp-backup.timer    → triggers →   myapp-backup.service
   └── same name ────┘

**Example: ``myapp-backup.timer``:**

.. code-block:: ini
   :caption: ``/etc/systemd/system/myapp-backup.timer``

   [Unit]
   Description=Run myapp backup daily at 3 AM
   Requires=myapp-backup.service

   [Timer]
   OnCalendar=daily
   Persistent=true
   RandomizedDelaySec=300
   Unit=myapp-backup.service

   [Install]
   WantedBy=timers.target

**Example: ``myapp-backup.service`` (the triggered unit):**

.. code-block:: ini
   :caption: ``/etc/systemd/system/myapp-backup.service``

   [Unit]
   Description=MyApp daily backup
   Wants=network-online.target
   After=network-online.target

   [Service]
   Type=oneshot
   ExecStart=/usr/local/bin/myapp-backup.sh
   User=myapp
   Group=myapp

   [Install]
   WantedBy=multi-user.target

.. note::

   The service unit must be a ``Type=oneshot`` service — it runs once and
   exits. It does **not** need to be enabled (no symlink in
   ``multi-user.target.wants/``) because the timer will activate it. Only
   the timer unit is enabled.

4.8.5.2 Timer Directives

.. table:: Key ``[Timer]`` Directives
   :widths: 30 70

   +----------------------------+------------------------------------------------+
   | Directive                 | Description                                    |
   +============================+================================================+
   | ``OnCalendar=``            | Calendar-based expression (like cron).         |
   |                            | Examples:                                      |
   |                            | ``OnCalendar=daily``                           |
   |                            | ``OnCalendar=Mon..Fri 09:00:00``               |
   |                            | ``OnCalendar=*-*-* 03:00:00`` (every day 3 AM)|
   +----------------------------+------------------------------------------------+
   | ``OnBootSec=``             | Run a specified amount of time after boot.     |
   |                            | ``OnBootSec=10min``, ``OnBootSec=5s``          |
   +----------------------------+------------------------------------------------+
   | ``OnUnitActiveSec=``       | Run a specified time after the previous        |
   |                            | activation of the service.                     |
   |                            | ``OnUnitActiveSec=1h`` (1 hour after last run) |
   +----------------------------+------------------------------------------------+
   | ``OnUnitInactiveSec=``     | Run a specified time after the service         |
   |                            | becomes inactive (different from active).      |
   +----------------------------+------------------------------------------------+
   | ``Persistent=``            | If ``true``, the timer will catch up on missed |
   |                            | runs (like anacron). Works with OnCalendar.    |
   +----------------------------+------------------------------------------------+
   | ``RandomizedDelaySec=``    | Add a random delay (in seconds) before running |
   |                            | the service. ``RandomizedDelaySec=300`` adds   |
   |                            | 0–300 seconds randomised delay.               |
   +----------------------------+------------------------------------------------+
   | ``AccuracySec=``           | The timer's accuracy. Default is 1 minute.     |
   |                            | ``AccuracySec=1us`` for high precision.        |
   +----------------------------+------------------------------------------------+
   | ``FixedRandomDelay=``      | Use a fixed random seed (same delay every      |
   |                            | boot). For reproducibility.                    |
   +----------------------------+------------------------------------------------+
   | ``Unit=``                  | Override the default unit (by default, the     |
   |                            | timer triggers ``same-name.service``).         |
   +----------------------------+------------------------------------------------+

4.8.5.3 Calendar Expression Syntax

systemd calendar expressions are far more readable than cron:

.. code-block:: text

   # Daily at midnight
   OnCalendar=daily

   # Every day at 3:30 AM
   OnCalendar=*-*-* 03:30:00

   # Every weekday at 9 AM
   OnCalendar=Mon..Fri 09:00:00

   # First day of every month at midnight
   OnCalendar=*-*-01 00:00:00

   # Every hour
   OnCalendar=*-*-* *:00:00

   # Every 15 minutes
   OnCalendar=*-*-* *:00/15:00

   # Specific date/time
   OnCalendar=2026-12-31 23:59:00

   # Twice daily at 6 AM and 6 PM
   OnCalendar=daily
   OnCalendar=*-*-* 06:00:00,18:00:00

   # Every Monday
   OnCalendar=Mon *-*-* 00:00:00

**Testing calendar expressions:**

.. code-block:: console

   # Test when a calendar expression will fire
   $ systemd-analyze calendar "Mon..Fri 09:00:00"
     Original form: Mon..Fri 09:00:00
     Normalized form: Mon..Fri 09:00:00
     Next elapse: Wed 2026-07-15 09:00:00 EDT
       (in 3h 55min 47s)
     From now: 3h 55min 47s left

   # Show the next 5 fire times
   $ systemd-analyze calendar --iterations=5 "Mon..Fri 09:00:00"
     Next elapse: Wed 2026-07-15 09:00:00 EDT
       (in 3h 55min 47s)
     From now: 3h 55min 47s left
     Iteration #2: Thu 2026-07-16 09:00:00 EDT
     Iteration #3: Fri 2026-07-17 09:00:00 EDT
     Iteration #4: Mon 2026-07-20 09:00:00 EDT
     Iteration #5: Tue 2026-07-21 09:00:00 EDT

4.8.5.4 Managing Timers with ``systemctl``

.. code-block:: console

   # Enable and start a timer
   # systemctl enable --now myapp-backup.timer

   # List all active timers
   $ systemctl list-timers
   NEXT                          LEFT     LAST                          PASSED  UNIT                 ACTIVATES
   Wed 2026-07-15 03:00:00 UTC  14h left Tue 2026-07-14 03:00:00 UTC  10h ago myapp-backup.timer    myapp-backup.service
   Wed 2026-07-15 06:00:00 UTC  17h left Tue 2026-07-14 06:00:00 UTC  7h ago  systemd-tmpfiles-clean.timer  systemd-tmpfiles-clean.service

   # Show all timers (including inactive)
   $ systemctl list-timers --all

   # View timer status
   $ systemctl status myapp-backup.timer

   # View the next fire time
   $ systemctl show myapp-backup.timer -p NextElapseUSecRealtime

   # Manually trigger a timer (run the service now)
   $ systemctl start myapp-backup.service

4.8.6 systemd Timers vs. Cron — A Practical Comparison
==========================================================

Let us compare the same job — run a backup at 3:00 AM daily — in both
systems:

.. table:: Cron vs. systemd Timer — Side by Side
   :widths: 30 35 35

   +---------------------------+--------------------------------+--------------------------------+
   | Aspect                    | Cron                           | systemd Timer                  |
   +===========================+================================+================================+
   | Configuration             | ``0 3 * * * /usr/local/bin/backup.sh`` | ``[Timer]``                   |
   |                           | (one line)                     | ``OnCalendar=daily``          |
   |                           |                                | ``Persistent=true``           |
   |                           |                                | Two files: ``.timer`` +       |
   |                           |                                | ``.service``.                 |
   +---------------------------+--------------------------------+--------------------------------+
   | Environment               | Limited PATH, SHELL=/bin/sh    | Full systemd environment.     |
   |                           | Must set PATH manually.        | Can set in service unit.      |
   +---------------------------+--------------------------------+--------------------------------+
   | Missed runs (system off)  | **No** — job is skipped.       | **Yes** — ``Persistent=true`` |
   |                           | Use anacron for this.          | catches up on boot.           |
   +---------------------------+--------------------------------+--------------------------------+
   | Random delay              | Not available.                 | ``RandomizedDelaySec=300``    |
   +---------------------------+--------------------------------+--------------------------------+
   | Logging                   | Syslog or mail.                | Journal (``journalctl -u``).  |
   +---------------------------+--------------------------------+--------------------------------+
   | Dependency support        | None.                          | Full systemd dependency model |
   |                           |                                | (After, Requires, etc.).      |
   +---------------------------+--------------------------------+--------------------------------+
   | Monotonic timers          | Not available.                 | ``OnBootSec=``,               |
   | ("30 min after boot")     |                                | ``OnUnitActiveSec=``.         |
   +---------------------------+--------------------------------+--------------------------------+
   | Integration with system   | Standalone daemon.             | Part of systemd — unified     |
   |                           |                                | management (``systemctl``).   |
   +---------------------------+--------------------------------+--------------------------------+
   | Complexity                | One line (simple).             | Two files (more boilerplate,  |
   |                           |                                | more flexibility).            |
   +---------------------------+--------------------------------+--------------------------------+
   | Portability               | Every Unix-like system ever.   | systemd-only.                 |
   +---------------------------+--------------------------------+--------------------------------+

**When to use cron:**

* You need compatibility with non-systemd systems (Alpine, containers).
* You want a single-line configuration (quick and simple).
* You are maintaining legacy infrastructure with existing crontabs.
* You need second-level granularity (``* * * * * sleep 30; ...`` — though
  this is a hack).

**When to use systemd timers:**

* You want reliable execution with missed-job catching (``Persistent=true``).
* You need advanced scheduling (monotonic timers, randomised delays).
* You want integrated logging, dependency management, and security hardening.
* You are writing a package or deployment that targets systemd-based
  distributions (the majority of modern Linux).
* You need to avoid "thundering herd" problems with distributed systems.

4.8.7 Summary
==============

* **Cron** is the classic Unix scheduler: five time fields followed by a
  command. It is simple, universal, and widely understood.
* ``crontab -e`` edits user crontabs; ``/etc/crontab`` and
  ``/etc/cron.d/`` handle system jobs.
* Cron runs with a minimal environment. Always use absolute paths and set
  ``PATH`` explicitly.
* **Anacron** fills cron's gap for systems that are not always on. It runs
  daily/weekly/monthly jobs that were missed.
* **``at``** schedules one-time future jobs. **``batch``** runs jobs when
  load is low.
* **systemd timers** (``.timer`` units) are the modern, integrated
  replacement for cron. They offer persistent, monotonic, and calendar-based
  scheduling with full systemd integration.
* Use ``systemd-analyze calendar`` to test timer expressions.
* Choose cron for simplicity and portability; choose systemd timers for
  reliability, dependency management, and advanced features.

