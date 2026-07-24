.. _app-b-audit:

------------------------------------------------------------------------------
System Auditing (auditd)
------------------------------------------------------------------------------

The Linux Audit subsystem (``auditd``) provides detailed logging of security-
relevant events: file access, system calls, user logins, configuration changes.

------------------------------------------------------------------------------
Architecture & Components
------------------------------------------------------------------------------

.. list-table:: Audit System Components
   :header-rows: 1
   :widths: 20 30 50

   * - Component
     - Daemon / File
     - Purpose
   * - ``auditd``
     - ``/sbin/auditd``
     - The daemon that writes audit events to disk
   * - ``auditctl``
     - ``/sbin/auditctl``
     - Control the kernel audit system (add/delete/list rules)
   * - ``ausearch``
     - ``/sbin/ausearch``
     - Search the audit log file (``/var/log/audit/audit.log``)
   * - ``aureport``
     - ``/sbin/aureport``
     - Generate summary reports from audit logs
   * - ``autrace``
     - ``/sbin/autrace``
     - Trace a specific process (similar to ``strace`` but via audit)
   * - ``audispd``
     - ``/sbin/audispd``
     - Audit dispatch daemon — forwards events to external programs (e.g., ``ausearch -i`` via syslog)
   * - Rules file
     - ``/etc/audit/rules.d/``
     - Persistent audit rules loaded at boot

------------------------------------------------------------------------------
auditctl — Rule Management
------------------------------------------------------------------------------

.. rubric:: Rule syntax

.. code-block:: text

   auditctl -a <list,action> -S <syscall> -F <field=value> -k <key_name>

.. list-table:: auditctl rule components
   :header-rows: 1
   :widths: 20 35 45

   * - Component
     - Options
     - Description
   * - List
     - ``task``, ``exit``, ``user``, ``exclude``
     - Which audit list to add to; ``exit`` is most common for syscalls
   * - Action
     - ``always``, ``never``
     - Whether to always audit or never audit this event
   * - Syscall
     - ``-S open``, ``-S openat``, ``-S all``, etc.
     - System call number or name (``/usr/include/asm/unistd_64.h``)
   * - Field filters
     - ``-F uid=0``, ``-F arch=b64``, ``-F success=0``, ``-F path=/etc/shadow``
     - Filter by user, architecture, success/fail, file path, etc.
   * - Key
     - ``-k my_event``
     - Free-text label for grouping/searching events

.. rubric:: Essential audit rules

.. code-block:: bash

   # Monitor /etc/passwd, /etc/shadow, /etc/group for writes (security critical)
   auditctl -w /etc/passwd -p wa -k passwd_changes
   auditctl -w /etc/shadow -p wa -k shadow_changes
   auditctl -w /etc/group -p wa -k group_changes

   # Monitor /etc/sudoers and sudo config
   auditctl -w /etc/sudoers -p wa -k sudoers_changes
   auditctl -w /etc/sudoers.d/ -p wa -k sudoers_d_changes

   # Monitor SSH configuration
   auditctl -w /etc/ssh/sshd_config -p wa -k sshd_config

   # Monitor command execution (audit all executions)
   auditctl -a exit,always -S execve -k command_exec

   # Track all root logins
   auditctl -a exit,always -S login -k root_login -F uid=0

   # Monitor changes to system binaries
   auditctl -w /usr/bin/passwd -p x -k passwd_exec
   auditctl -w /usr/bin/su -p x -k su_exec
   auditctl -w /usr/bin/sudo -p x -k sudo_exec

   # Failed file open attempts (useful for intrusion detection)
   auditctl -a exit,always -S open -S openat -F success=0 -k failed_file_open

   # Monitor kernel module loading
   auditctl -w /sbin/insmod -p x -k kernel_module
   auditctl -w /sbin/modprobe -p x -k kernel_module

.. rubric:: Viewing rules

.. code-block:: bash

   sudo auditctl -l              # List all rules
   sudo auditctl -s              # Show status (enabled, pid, backlog, etc.)

------------------------------------------------------------------------------
ausearch — Searching Audit Logs
------------------------------------------------------------------------------

.. list-table:: ausearch options
   :header-rows: 1
   :widths: 25 35 40

   * - Option
     - Example
     - Purpose
   * - ``-k``
     - ``ausearch -k command_exec``
     - Search by rule key
   * - ``-ua``
     - ``ausearch -ua 1001``
     - Search by user ID (logical OR for uid, euid, suid, fsuid)
   * - ``-ui``
     - ``ausearch -ui 0``
     - Search by UID only
   * - ``-f``
     - ``ausearch -f /etc/shadow``
     - Search by file name
   * - ``-p``
     - ``ausearch -p 12345``
     - Search by process PID
   * - ``-ts``
     - ``ausearch -ts 10:00:00``
     - Start time (``-ts yesterday``, ``-ts 01/01/2026 00:00:00``)
   * - ``-te``
     - ``ausearch -te now``
     - End time
   * - ``-m``
     - ``ausearch -m avc``
     - Search by message type (``AVC``, ``LOGIN``, ``EXECVE``, ``SYSCALL``, etc.)
   * - ``-sv``
     - ``ausearch -sv no``
     - Search by success value (yes/no)
   * - ``-i``
     - ``ausearch -i``
     - Interpret numeric values to text (UID→names, times, etc.)
   * - ``--raw``
     - ``ausearch --raw``
     - Raw output format (for programmatic processing)

.. rubric:: Common ausearch queries

.. code-block:: bash

   # Recent sudo executions
   ausearch -k sudo_exec -ts recent -i

   # Failed file opens in last hour
   ausearch -k failed_file_open -ts 60 minutes ago -i

   # All events for user "alice" today
   ausearch -ua alice -ts today -i

   # Who modified /etc/shadow
   ausearch -f /etc/shadow -i

.. rubric:: Creating persistent audit rules

.. code-block:: bash

   # Write rules to /etc/audit/rules.d/
   echo '-w /etc/passwd -p wa -k passwd_changes' | sudo tee /etc/audit/rules.d/passwd.rules
   echo '-w /etc/shadow -p wa -k shadow_changes' | sudo tee /etc/audit/rules.d/shadow.rules

   # Restart auditd
   sudo systemctl restart auditd

   # Verify rules loaded
   sudo auditctl -l

------------------------------------------------------------------------------
aureport — Summary Reports
------------------------------------------------------------------------------

.. code-block:: bash

   aureport --summary                     # Summary of all events
   aureport -au                           # Authentication report
   aureport -l                            # Login report
   aureport -f                            # File access report
   aureport -x                            # Executable report
   aureport -tm                           # Time-based report
   aureport -m                            # Event types summary
   aureport -k                            # Key summary
   aureport -p                            # PID summary

   # Failed authentication attempts today
   aureport -au -ts today -i --failed

   # Top 10 executables run
   aureport -x -i --summary | head -10

------------------------------------------------------------------------------
Audit Log Rotation (``/etc/audit/auditd.conf``)
------------------------------------------------------------------------------

.. code-block:: text

   # Key configuration parameters
   log_file = /var/log/audit/audit.log
   log_format = RAW                   # RAW or NOLOG (for auditd disabled)
   max_log_file = 8                   # Max size in MB
   max_log_file_action = ROTATE       # ROTATE, IGNORE, SUSPEND, STOP
   num_logs = 5                       # Number of rotated logs to retain
   space_left_action = SYSLOG         # SYSLOG, EMAIL, SUSPEND, EXEC
   admin_space_left_action = SUSPEND  # When almost full
   disk_full_action = SUSPEND         # When disk fully fills
   disk_error_action = SUSPEND        # On I/O errors
