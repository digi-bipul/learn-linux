.. _section-4-5:

================================================
4.5 Writing systemd Unit Files
================================================

.. rst-class:: lead

   Understanding how to read unit files is useful; knowing how to *write*
   them is the mark of a skilled Linux administrator. systemd unit files are
   declarative INI-style configurations that tell systemd *what* to run,
   *how* to run it, *when* to start it, and *what* security boundaries to
   enforce. This section builds a complete custom service unit file
   line-by-line, explaining every directive.

4.5.1 Unit File Anatomy
==========================

A systemd unit file is divided into sections, each prefixed with
``[SectionName]``. The three most common sections are:

.. code-block:: text

   [Unit]        # Metadata, dependencies, ordering
   [Service]     # How to start/stop/restart the service (type-specific)
   [Install]     # How to enable the service (usually WantedBy)

Other sections exist for other unit types:
``[Socket]``, ``[Timer]``, ``[Mount]``, ``[Path]``, etc.

4.5.2 Building a Custom Service: ``myapp.service``
======================================================

We will create a unit file for a hypothetical Python web application called
``myapp``. The application runs as a daemon, writes logs to a dedicated
directory, and should be automatically restarted on failure.

4.5.2.1 The ``[Unit]`` Section

.. code-block:: ini
   :caption: ``[Unit]`` section — metadata and dependencies

   [Unit]
   Description=MyApp Web Service - A demonstration application
   Documentation=https://docs.example.com/myapp
   Documentation=man:myapp(1)
   Wants=network-online.target
   After=network-online.target postgresql.service
   Requires=postgresql.service

**Directive by directive:**

.. list-table:: ``[Unit]`` Directives
   :widths: 25 75

   * - ``Description=``
     - A human-readable name for the unit. Shown by ``systemctl status``.
       Should be clear enough for an administrator to understand what this
       service does at a glance.
   * - ``Documentation=``
     - URIs to documentation. May be repeated. Supports ``http://``,
       ``https://``, ``man:``, ``info:``.
   * - ``Wants=``
     - **Weak dependency**: if the specified unit (``network-online.target``)
       fails to start, this unit will still start. systemd will attempt to
       start the wanted unit, but failure does not block this service.
   * - ``After=``
     - **Ordering only**: This service starts **after** the listed units.
       Does not create a dependency. Use ``After=`` combined with ``Wants=``
       or ``Requires=`` to get both ordering and dependency.
   * - ``Requires=``
     - **Strong dependency**: If the required unit (``postgresql.service``)
       fails to start or stops, this unit will also be stopped. If the
       dependency cannot be satisfied, this service will fail.

**Ordering vs. dependency — critical distinction:**

.. code-block:: text

   Wants=network-online.target
   After=network-online.target

   # This means: "Try to start network-online.target before myapp.
   # If network-online.target fails, myapp still starts."

   Requires=postgresql.service
   After=postgresql.service

   # This means: "Start postgresql before myapp, and if postgresql
   # is not running, myapp cannot run."

Additional common ``[Unit]`` directives:

.. list-table:: Additional ``[Unit]`` Directives
   :widths: 25 75

   * - ``Before=``
     - Opposite of ``After=``. This service starts before the listed units.
   * - ``BindsTo=``
     - Stronger than ``Requires=``. If the bound unit stops for any reason,
       this unit is stopped *and* cannot be restarted independently.
   * - ``PartOf=``
     - When the listed unit is stopped or restarted, this unit follows.
   * - ``Conflicts=``
     - Mutual exclusion: if the listed unit starts, this unit is stopped.
   * - ``ConditionPathExists=``
     - The service will only start if the specified file/directory exists.
     - ``ConditionPathExists=/etc/myapp/config.yml``
   * - ``ConditionHost=``
     - Only start on specific hostname matches.
   * - ``DefaultDependencies=``
     - Set to ``no`` for low-level services that should not pull in
       ``basic.target`` (e.g., early boot services).

4.5.2.2 The ``[Service]`` Section

.. code-block:: ini
   :caption: ``[Service]`` section — execution and lifecycle

   [Service]
   Type=notify
   User=myapp
   Group=myapp
   RuntimeDirectory=myapp
   StateDirectory=myapp
   LogsDirectory=myapp

   WorkingDirectory=/opt/myapp
   EnvironmentFile=-/etc/myapp/environment
   Environment="APP_ENV=production"
   Environment="LOG_LEVEL=info"

   ExecStart=/opt/myapp/venv/bin/python /opt/myapp/app.py
   ExecReload=/bin/kill -HUP $MAINPID
   ExecStop=/bin/kill -TERM $MAINPID

   Restart=on-failure
   RestartSec=5
   TimeoutStartSec=30
   TimeoutStopSec=15

   # Security hardening
   ProtectSystem=strict
   ProtectHome=true
   PrivateTmp=true
   NoNewPrivileges=true
   CapabilityBoundingSet=CAP_NET_BIND_SERVICE
   AmbientCapabilities=CAP_NET_BIND_SERVICE

**The ``Type=`` directive:**

This is the most important ``[Service]`` directive. It tells systemd *how*
the service reports its readiness:

.. table:: Service Types
   :widths: 15 85

   +----------------+------------------------------------------------------+
   | Type           | Behaviour                                            |
   +================+======================================================+
   | ``simple``     | The service is considered started as soon as the      |
   |                | ``ExecStart`` process is forked. This is the default. |
   |                | systemd does **not** wait for any readiness signal.  |
   |                | Use for simple daemons that stay in the foreground.   |
   +----------------+------------------------------------------------------+
   | ``forking``    | The ``ExecStart`` process forks, and the parent exits |
   |                | (the traditional Unix daemonisation pattern). systemd |
   |                | waits for the parent to exit. Requires ``PIDFile=``   |
   |                | so systemd can track the child.                       |
   +----------------+------------------------------------------------------+
   | ``oneshot``    | The service runs ``ExecStart`` once and exits. systemd|
   |                | considers it "active" while the command runs, then    |
   |                | "active (exited)" when it finishes. Used for setup    |
   |                | tasks, filesystem checks, and one-time actions.       |
   |                | Often combined with ``RemainAfterExit=yes``.          |
   +----------------+------------------------------------------------------+
   | ``notify``     | The service sends a readiness notification via        |
   |                | ``sd_notify(3)`` (``"READY=1"`` over a Unix socket).  |
   |                | **Requires** the service to link against ``libsystemd``|
   |                | or implement the ``sd_notify`` protocol. Preferred for|
   |                | modern services.                                      |
   +----------------+------------------------------------------------------+
   | ``dbus``       | systemd waits for the service to register on the D-Bus|
   |                | bus. Used by D-Bus-activated services.                |
   +----------------+------------------------------------------------------+
   | ``idle``       | Like ``simple``, but the service is not started until |
   |                | all other jobs are dispatched. Avoids interleaved     |
   |                | output on the console. (Rarely used.)                  |
   +----------------+------------------------------------------------------+

**User, group, and directory management:**

.. code-block:: ini

   User=myapp
   Group=myapp

These drop privileges **before** ``ExecStart`` runs. The service runs as an
unprivileged user — never run services as root unless absolutely necessary.

.. code-block:: ini

   RuntimeDirectory=myapp         # Creates /run/myapp (rw, tmpfs)
   StateDirectory=myapp           # Creates /var/lib/myapp (persistent data)
   LogsDirectory=myapp            # Creates /var/log/myapp (log output)

These are **state directory** directives — they automatically create and
manage directories with correct ownership (``myapp:myapp``) and
permissions. This is far cleaner than having start scripts manually
``mkdir`` directories.

The directories created:

.. code-block:: text

   # These are automatically created before ExecStart runs:
   /run/myapp       (tmpfs, cleared on reboot)
   /var/lib/myapp   (persistent state)
   /var/log/myapp   (log directory)

.. note::

   The ``RuntimeDirectory``, ``StateDirectory``, ``CacheDirectory``,
   ``LogsDirectory``, and ``ConfigurationDirectory`` directives were added
   in systemd v239+. They eliminate the need for ``ExecStartPre=mkdir -p``
   hacks.

**Environment management:**

.. code-block:: ini

   EnvironmentFile=-/etc/myapp/environment
   # The leading "-" means: "ignore if the file does not exist"
   # The file should contain KEY=value pairs, one per line.

   Environment="APP_ENV=production"
   Environment="LOG_LEVEL=info"

Environment variables set here are available to the service. This is the
correct way to pass configuration to services (not shell scripts that
``source`` config files, which pollute the global namespace).

**Exec\* directives:**

.. code-block:: ini

   ExecStart=/opt/myapp/venv/bin/python /opt/myapp/app.py
   ExecReload=/bin/kill -HUP $MAINPID
   ExecStop=/bin/kill -TERM $MAINPID

* ``ExecStart`` — **Required**. The command to start the service. Must be an
  absolute path.
* ``ExecReload`` — Command run when ``systemctl reload`` is called.
  Typically sends a SIGHUP.
* ``ExecStop`` — Command run when ``systemctl stop`` is called. If omitted,
  systemd sends SIGTERM, waits ``TimeoutStopSec``, then SIGKILL.
* ``ExecStartPre`` — Commands run *before* ``ExecStart``. Useful for config
  validation (e.g., ``nginx -t``).
* ``ExecStartPost`` — Commands run *after* the service enters the "active"
  state.
* ``ExecStopPost`` — Commands run *after* the service stops, regardless of
  exit status (cleanup).

**Restart behaviour:**

.. code-block:: ini

   Restart=on-failure
   RestartSec=5
   TimeoutStartSec=30
   TimeoutStopSec=15

.. table:: ``Restart=`` Policies
   :widths: 20 80

   +------------------+---------------------------------------------------+
   | Value            | Meaning                                           |
   +==================+===================================================+
   | ``no``           | (Default) Do not restart the service              |
   |                  | regardless of exit status.                        |
   +------------------+---------------------------------------------------+
   | ``on-success``   | Restart only if the process exits with a          |
   |                  | clean exit code (0).                              |
   +------------------+---------------------------------------------------+
   | ``on-failure``   | Restart if the process exits with a non-zero      |
   |                  | exit code, is terminated by a signal,             |
   |                  | or exceeds ``WatchdogSec``.                       |
   +------------------+---------------------------------------------------+
   | ``on-abnormal``  | Restart on signals and watchdog, but not           |
   |                  | clean exits or unclean exit codes.                |
   +------------------+---------------------------------------------------+
   | ``on-abort``     | Restart only if terminated by an uncatchable      |
   |                  | signal (``SIGKILL``, ``SIGSEGV``).                |
   +------------------+---------------------------------------------------+
   | ``always``       | Restart unconditionally, even if the service      |
   |                  | exits cleanly. Useful for containers and          |
   |                  | transient services.                               |
   +------------------+---------------------------------------------------+

.. warning::

   ``Restart=always`` combined with a service that fails immediately
   (e.g., a config error) creates a **restart loop**. systemd detects this
   and, after 5 failed starts within 10 seconds (``StartLimitIntervalSec`` /
   ``StartLimitBurst``), will stop attempting to restart. The service enters
   the ``failed`` state. Check ``systemctl status`` for "start-limit-hit".

4.5.2.3 The ``[Install]`` Section

.. code-block:: ini
   :caption: ``[Install]`` section — enabling the service

   [Install]
   WantedBy=multi-user.target

**What ``WantedBy`` does:**

When you run ``systemctl enable myapp``, systemd:

1. Reads ``WantedBy=multi-user.target``.
2. Creates a symlink:
   ``/etc/systemd/system/multi-user.target.wants/myapp.service``
   → ``/etc/systemd/system/myapp.service``
3. This symlink ensures that when ``multi-user.target`` is loaded (on
   normal boot), ``myapp.service`` is automatically started.

The alternative ``RequiredBy=`` creates a dependency with ``Requires=``
semantics (stricter).

**Summary of the full ``[Install]`` directives:**

.. list-table:: ``[Install]`` Directives
   :widths: 25 75

   * - ``WantedBy=``
     - The target (or other unit) that "wants" this unit. Creates a
       symlink in ``<target>.wants/`` directory.
   * - ``RequiredBy=``
     - Like ``WantedBy`` but uses ``Requires=`` semantics. Symlink goes to
       ``<target>.requires/``.
   * - ``Also=``
     - Additional units to enable/disable when this unit is
       enabled/disabled.
   * - ``Alias=``
     - Alternative names for the unit (e.g., ``Alias=dbus.service``).

4.5.3 Complete Example: ``myapp.service``
===========================================

Putting it all together:

.. code-block:: ini
   :caption: ``/etc/systemd/system/myapp.service`` (complete)

   [Unit]
   Description=MyApp Web Service - A demonstration application
   Documentation=https://docs.example.com/myapp
   Wants=network-online.target
   After=network-online.target postgresql.service
   Requires=postgresql.service

   [Service]
   Type=notify
   User=myapp
   Group=myapp
   RuntimeDirectory=myapp
   StateDirectory=myapp
   LogsDirectory=myapp

   WorkingDirectory=/opt/myapp
   EnvironmentFile=-/etc/myapp/environment
   Environment="APP_ENV=production"

   ExecStart=/opt/myapp/venv/bin/python /opt/myapp/app.py
   ExecReload=/bin/kill -HUP $MAINPID
   ExecStop=/bin/kill -TERM $MAINPID

   Restart=on-failure
   RestartSec=5
   TimeoutStartSec=30
   TimeoutStopSec=15

   # Security hardening
   ProtectSystem=strict
   ProtectHome=true
   PrivateTmp=true
   NoNewPrivileges=true
   CapabilityBoundingSet=CAP_NET_BIND_SERVICE
   AmbientCapabilities=CAP_NET_BIND_SERVICE

   [Install]
   WantedBy=multi-user.target

**Deploying the service:**

.. code-block:: console
   :caption: Steps to activate a new unit file

   # 1. Create the service account
   # useradd -r -s /usr/sbin/nologin -M myapp

   # 2. Create the app directory and set ownership
   # mkdir -p /opt/myapp /etc/myapp
   # chown -R myapp:myapp /opt/myapp /etc/myapp

   # 3. Create the unit file
   # vim /etc/systemd/system/myapp.service   (paste the above)

   # 4. Reload systemd to pick up the new unit
   # systemctl daemon-reload

   # 5. Enable and start the service
   # systemctl enable --now myapp

   # 6. Verify
   # systemctl status myapp
   ● myapp.service - MyApp Web Service - A demonstration application
        Loaded: loaded (/etc/systemd/system/myapp.service; enabled; preset: enabled)
        Active: active (running) since Wed 2026-07-15 12:30:00 UTC; 5min ago
        ...

4.5.4 Security Hardening Directives
======================================

systemd provides a comprehensive set of security directives that restrict
what a service can do — a feature that has no equivalent in SysV init
scripts. These are configured in the ``[Service]`` section.

.. table:: Essential systemd Security Hardening Directives
   :widths: 25 20 55

   +----------------------------+----------+----------------------------------+
   | Directive                  | Example  | Effect                           |
   +============================+==========+==================================+
   | ``ProtectSystem=``         | ``strict``| Restricts write access to the    |
   |                            |           | filesystem. ``full`` = read-only |
   |                            |           | ``/usr`` and ``/etc``;           |
   |                            |           | ``strict`` = read-only ``/``,    |
   |                            |           | ``/usr``, ``/etc``, ``/boot``.   |
   +----------------------------+----------+----------------------------------+
   | ``ProtectHome=``           | ``true``  | Makes ``/home``, ``/root``, and  |
   |                            |           | ``/run/user`` inaccessible       |
   |                            |           | (returns empty or EACCES).       |
   +----------------------------+----------+----------------------------------+
   | ``PrivateTmp=``            | ``true``  | Mounts a private ``/tmp`` and    |
   |                            |           | ``/var/tmp`` namespace for the   |
   |                            |           | service. Prevents information    |
   |                            |           | leakage between services via tmp.|
   +----------------------------+----------+----------------------------------+
   | ``NoNewPrivileges=``       | ``true``  | Prevents the process and its     |
   |                            |           | children from gaining new        |
   |                            |           | privileges (no ``su``, ``sudo``, |
   |                            |           | ``setuid`` binary execution).    |
   +----------------------------+----------+----------------------------------+
   | ``CapabilityBoundingSet=`` |          | The maximum set of capabilities  |
   |                            |          | the process (and its children)   |
   |                            |          | can ever obtain. List only the   |
   |                            |          | capabilities needed.             |
   +----------------------------+----------+----------------------------------+
   | ``AmbientCapabilities=``   |          | Capabilities that are passed to  |
   |                            |          | the ``ExecStart`` process (for   |
   |                            |          | non-root services that need      |
   |                            |          | specific capabilities).          |
   +----------------------------+----------+----------------------------------+
   | ``ReadWritePaths=``        |          | Explicitly allow write access to |
   |                            |          | specific paths when              |
   |                            |          | ``ProtectSystem=strict``.        |
   +----------------------------+----------+----------------------------------+
   | ``MemoryMax=``             | ``512M`` | Cgroup memory limit. Service     |
   |                            |          | cannot exceed this amount of RAM.|
   +----------------------------+----------+----------------------------------+
   | ``MemoryHigh=``            | ``400M`` | Soft memory limit. Systemd will  |
   |                            |          | aggressively reclaim memory from |
   |                            |          | processes above this threshold.  |
   +----------------------------+----------+----------------------------------+
   | ``CPUQuota=``              | ``50%``  | Cgroup CPU limit. Service cannot |
   |                            |          | use more than 50% of a single    |
   |                            |          | CPU core.                        |
   +----------------------------+----------+----------------------------------+
   | ``PrivateDevices=``        | ``true`` | Hides most hardware devices from |
   |                            |          | the service (no access to disk   |
   |                            |          | devices, only ``/dev/null``,     |
   |                            |          | ``/dev/zero``, etc.).            |
   +----------------------------+----------+----------------------------------+
   | ``RestrictAddressFamilies=``|          | Restricts socket address families|
   |                            |          | (``AF_INET``, ``AF_UNIX``, etc.).|
   +----------------------------+----------+----------------------------------+
   | ``SystemCallFilter=``      |          | Restrict system calls (allowlist |
   |                            |          | or deny list). E.g.,             |
   |                            |          | ``@system-service`` for common   |
   |                            |          | service syscalls.                |
   +----------------------------+----------+----------------------------------+

**Applying security hardening — analysis of our example:**

.. code-block:: ini

   ProtectSystem=strict
   # The service can only write to:
   # - /var/lib/myapp (StateDirectory)
   # - /var/log/myapp (LogsDirectory)
   # - /run/myapp     (RuntimeDirectory)
   # - /tmp (private namespace, if PrivateTmp=yes)
   # Everything else is read-only.

   ProtectHome=true
   # /home, /root, /run/user are hidden. The service cannot
   # access user home directories even if there is a path traversal
   # vulnerability.

   NoNewPrivileges=true
   # Even if the service has a SUID binary available, it cannot
   # escalate privileges. This contains potential exploits.

   CapabilityBoundingSet=CAP_NET_BIND_SERVICE
   # The only elevated capability: bind to privileged ports (<1024).
   # The service cannot: change ownership, modify the clock,
   # load kernel modules, or do anything else requiring privilege.

   AmbientCapabilities=CAP_NET_BIND_SERVICE
   # For a non-root service (User=myapp), ambient capabilities
   # ensure that the ExecStart process inherits CAP_NET_BIND_SERVICE
   # even though it runs as an unprivileged user.

.. note::

   You can verify the security settings of any running service with:

   .. code-block:: console

      $ systemd-analyze security myapp
        → Overall exposure level for myapp.service: 2.9 SAFE 😀

      $ systemd-analyze security --json=pretty myapp

   The output scores each security directive and provides a
   "security exposure level" rating from 0.0 (most secure) to
   10.0 (least secure).

4.5.5 Unit File Templates (Instantiated Units)
=================================================

systemd supports **template unit files** using the ``@`` character. A
template file is named like ``myapp@.service``. When instantiated as
``myapp@instance1.service``, the ``%i`` specifier inside the file expands
to ``instance1``.

**Template example — ``myapp@.service``:**

.. code-block:: ini

   [Unit]
   Description=MyApp Instance %i
   After=network.target

   [Service]
   Type=simple
   User=myapp
   ExecStart=/opt/myapp/run.sh --instance %i
   Restart=on-failure

   [Install]
   WantedBy=multi-user.target

**Using the template:**

.. code-block:: console

   # systemctl enable --now myapp@web01.service
   # systemctl enable --now myapp@web02.service
   # systemctl enable --now myapp@worker.service

   $ systemctl status myapp@web01.service
   ● myapp@web01.service - MyApp Instance web01
        Active: active (running)
        ...

**Common specifiers in unit files:**

.. table:: Useful Specifiers in Unit Files
   :widths: 15 85

   +---------+------------------------------------------------------------+
   | Spec    | Expands To                                                 |
   +=========+============================================================+
   | ``%n``  | Full unit name (e.g., ``myapp@web01.service``)             |
   +---------+------------------------------------------------------------+
   | ``%N``  | Unit name without the suffix (e.g., ``myapp@web01``)       |
   +---------+------------------------------------------------------------+
   | ``%i``  | Instance name for template units (e.g., ``web01``)         |
   +---------+------------------------------------------------------------+
   | ``%p``  | Prefix (before the ``@``, e.g., ``myapp``)                 |
   +---------+------------------------------------------------------------+
   | ``%H``  | Hostname                                                    |
   +---------+------------------------------------------------------------+
   | ``%u``  | User name the service runs as                               |
   +---------+------------------------------------------------------------+
   | ``%U``  | UID of the user the service runs as                         |
   +---------+------------------------------------------------------------+
   | ``%t``  | Runtime directory root (``/run``)                           |
   +---------+------------------------------------------------------------+
   | ``%S``  | State directory root (``/var/lib``)                         |
   +---------+------------------------------------------------------------+
   | ``%E``  | Temporary directory root (``/var/tmp``)                     |
   +---------+------------------------------------------------------------+

4.5.6 Drop-In Overrides and Customisations
=============================================

The recommended way to customise a distribution-provided unit file (e.g.,
``/usr/lib/systemd/system/nginx.service``) is **not** to edit it directly,
but to create a **drop-in override**.

**Method 1: ``systemctl edit`` (preferred)**

.. code-block:: console

   # systemctl edit nginx

This opens an editor for ``/etc/systemd/system/nginx.service.d/override.conf``.
Add only the directives you wish to override:

.. code-block:: ini

   [Service]
   Restart=always
   RestartSec=10

**Method 2: Manual drop-in**

.. code-block:: console

   # mkdir -p /etc/systemd/system/nginx.service.d/
   # cat > /etc/systemd/system/nginx.service.d/override.conf << EOF
   [Service]
   LimitNOFILE=65535
   MemoryMax=512M
   EOF

   # systemctl daemon-reload
   # systemctl restart nginx

**Drop-in precedence:**

* Drop-in directives **add to** or **override** directives from the main
  unit file.
* For directives that accept a single value (e.g., ``Type=``), the last
  assigned value wins.
* For directives that accept multiple values (e.g., ``Environment=``),
  drop-in values are appended to the main unit's values.

**To see the effective (merged) configuration:**

.. code-block:: console

   # systemctl cat nginx
   # /usr/lib/systemd/system/nginx.service
   # ... (original unit) ...
   # /etc/systemd/system/nginx.service.d/override.conf
   [Service]
   Restart=always
   RestartSec=10

   # systemctl show nginx -p Restart
   Restart=always

4.5.7 Summary
==============

* Unit files have ``[Unit]`` (metadata/dependencies), ``[Service]``
  (execution/lifecycle), and ``[Install]`` (enablement) sections.
* The ``Type=`` directive (``simple``, ``forking``, ``oneshot``,
  ``notify``) tells systemd how to detect service readiness.
* Use ``User=`` and ``Group=`` to drop privileges. Use
  ``RuntimeDirectory=``, ``StateDirectory=``, ``LogsDirectory=`` for
  automatic directory management.
* ``Restart=on-failure`` is the best choice for long-running services.
  Avoid ``Restart=always`` unless you understand the restart loop
  protection mechanism.
* systemd's security hardening directives (``ProtectSystem=``,
  ``PrivateTmp=``, ``NoNewPrivileges=``, ``CapabilityBoundingSet=``)
  provide sandboxing capabilities far beyond traditional init scripts.
* Use ``systemctl edit`` for customising distribution-provided units.
* Template units (``myapp@.service``) enable running multiple instances
  with a single unit file and the ``%i`` specifier.
* ``systemd-analyze security UNIT`` audits the security posture of a unit.

