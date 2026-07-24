.. _section-3-7:

Privilege Escalation: ``sudo`` & ``doas``
==================================================

.. rst-class:: lead

   No matter how carefully you design user accounts and permissions, legitimate
   administrative tasks require elevated privileges. The traditional approach—
   logging in as ``root`` via ``su``—is a single point of failure and a
   security nightmare. Modern Linux systems use **privilege escalation**
   tools that grant specified users the ability to run specific commands as
   other users (typically root) while maintaining a full audit trail.

   This section covers the two dominant privilege escalation frameworks:
   the ubiquitous **``sudo``** and the minimalist modern alternative **``doas``**.

The Problem with ``su``
===============================

Before examining ``sudo`` and ``doas``, let us understand why ``su`` (the
traditional "substitute user" command) is problematic:

.. code-block:: bash

   $ su -           # Switch to root, requires root password
   Password:
   # whoami
   root
   # exit            # Back to unprivileged shell

**The problems with ``su``:**

1. **Shared secret**: Every administrator must know the root password. If
   ten people need admin access, all ten know the root password. When one
   leaves, you must change it and notify everyone.
2. **No granularity**: ``su`` is all-or-nothing. Either you have the root
   password (and unlimited power) or you do not. You cannot say "Alice can
   restart Apache but not edit ``/etc/shadow``."
3. **No audit trail**: Once a user runs ``su -``, all subsequent commands
   run as root. There is no per-command logging. If Bob runs ``rm -rf /``,
   the log says only "Bob became root at 12:00."
4. **Root password in the wild**: The root password is a single credential
   that must be entered across terminals, scripts, and remote sessions.
   Each exposure increases the risk of compromise.

Both ``sudo`` and ``doas`` solve these problems, though with different
philosophies.

``sudo`` — The Industry Standard
========================================

The name ``sudo`` stands for "**s**uperuser **do**" (historically
"substitute user do"). It was originally written by Bob Coggeshall and Cliff
Sparks at the State University of New York (SUNY) in the late 1980s. Today
it is maintained by Todd C. Miller and is the de facto standard privilege
escalation tool on Linux, macOS, and BSD systems.

Basic Usage

.. code-block:: bash
   :caption: ``sudo`` basics

   # Run a command as root
   $ sudo whoami
   root

   # Run a command as another user
   $ sudo -u alice whoami
   alice

   # Start a root shell
   $ sudo -s              # Root shell with the current user's environment
   $ sudo -i              # Root shell with root's login environment (like su -)

   # Run a command with a different group
   $ sudo -g developers id -ng
   developers

   # Run a command preserving the user's environment
   $ sudo -E mycommand    # Preserves $HOME, $PATH, etc.

   # List the current user's sudo privileges
   $ sudo -l
   Matching Defaults entries for alice on this-host:
       env_reset, mail_badpass, secure_path=/usr/local/sbin:/usr/local/...

   User alice may run the following commands on this-host:
       (ALL : ALL) ALL

   # Execute previous command with sudo
   $ !!
   $ sudo !!              # Re-run the last command as root

   # Edit a file as root (creates a temp copy, edits, then replaces)
   $ sudo -e /etc/ssh/sshd_config
   # This is equivalent to: sudoedit /etc/ssh/sshd_config

**The authentication ticket:**

When you run ``sudo`` for the first time in a session, it asks for **your**
password (not root's). Once authenticated, ``sudo`` caches the credential
for a period (default 5 minutes, configurable via ``timestamp_timeout``).
Subsequent ``sudo`` commands within this window do not prompt for a password.

.. code-block:: bash

   # Invalidate the sudo timestamp immediately (force password prompt next time)
   $ sudo -k

   # Keep the timestamp valid but run a command (reset the timer)
   $ sudo -v

The ``/etc/sudoers`` File — Central Configuration

The heart of sudo is the ``/etc/sudoers`` file. **Never edit this file
directly with a text editor** — syntax errors can lock everyone out of
administrative access. Always use ``visudo(8)``, which:

1. Locks the file against concurrent edits.
2. Validates syntax before saving.
3. Refuses to save an invalid configuration.

.. code-block:: bash

   # Edit the main sudoers file
   # visudo

   # Edit a file in the sudoers.d directory (modern practice)
   # visudo -f /etc/sudoers.d/myalias

Anatomy of a Sudoers Rule

A ``sudoers`` rule follows this basic structure:

.. code-block:: text

   who    where = (as_who : as_which) what
   ────   ─────   ──────── ────────   ────
    │       │         │         │        │
    │       │         │         │        └── Commands allowed
    │       │         │         └─────────── Group to run as (optional)
    │       │         └───────────────────── User to run as (optional)
    │       └─────────────────────────────── Host(s) this rule applies to
    └─────────────────────────────────────── User(s) the rule applies to

**Examples:**

.. code-block:: text
   :caption: Sample ``/etc/sudoers`` entries

   # Grant full sudo access to members of the wheel group
   %wheel ALL=(ALL:ALL) ALL

   # Grant full sudo access to the sudo group
   %sudo ALL=(ALL:ALL) ALL

   # Alice can run any command as root on any host
   alice ALL=(ALL) ALL

   # Bob can run only systemctl commands as root, without a password
   bob ALL=(root) NOPASSWD: /usr/bin/systemctl

   # Carol can run commands as the www-data user
   carol ALL=(www-data) ALL

   # Dave can run apt update and apt upgrade without password
   dave ALL=(root) NOPASSWD: /usr/bin/apt update, /usr/bin/apt upgrade

   # Restrict a user to a specific command with specific arguments
   eve ALL=(root) /usr/sbin/useradd, /usr/sbin/usermod, /usr/sbin/userdel

**Breaking it down:**

.. list-table:: Sudoers Rule Components
   :widths: 25 75

   * - ``%wheel``
     - The ``%`` prefix indicates a **group**; otherwise it is a username.
   * - ``ALL=``
     - The left side of the equals sign is the **host** (matching the
       hostname of the machine). ``ALL`` matches any host. This enables a
       single ``/etc/sudoers`` file to serve an entire network.
   * - ``(ALL:ALL)``
     - The first ``ALL`` is the **target user** (run as whom). The second
       (after the colon) is the **target group**. Omitting the parentheses
       defaults to ``(root)``.
   * - ``ALL``
     - The command specification. ``ALL`` means any command. Specific
       commands are written as absolute paths (``/usr/bin/apt``).
   * - ``NOPASSWD:``
     - A **tag** that modifies behaviour. ``NOPASSWD`` skips the password
       prompt. Other tags: ``PASSWD`` (default), ``SETENV``, ``NOEXEC``,
       ``LOG_INPUT``, ``LOG_OUTPUT``.

Sudoers Aliases

For complex configurations, sudoers supports four types of aliases:

.. code-block:: text

   # User_Alias — group users under a name
   User_Alias  ADMINS = alice, bob, carol
   User_Alias  JUNIORS = dave, eve, frank

   # Runas_Alias — group target users
   Runas_Alias  DB_USERS = oracle, postgres, mysql

   # Host_Alias — group hostnames (for network-wide sudoers)
   Host_Alias   WEBSERVERS = web01, web02, web03

   # Cmnd_Alias — group commands
   Cmnd_Alias   SERVICES = /usr/bin/systemctl *, /usr/sbin/service *
   Cmnd_Alias   PACKAGES = /usr/bin/apt *, /usr/bin/dpkg *
   Cmnd_Alias   SHUTDOWN = /usr/sbin/poweroff, /usr/sbin/reboot, /usr/sbin/shutdown

**Using aliases:**

.. code-block:: text

   # ADMINS have full sudo; JUNIORS can only manage services
   ADMINS  ALL=(ALL) ALL
   JUNIORS ALL=(root) SERVICES

   # A user can restart Apache but not anything else
   frank   ALL=(root) /usr/bin/systemctl restart apache2

.. note::

   While aliases can make large sudoers files more manageable, modern
   practice favours the ``/etc/sudoers.d/`` directory with one file per
   application or role. This is cleaner, easier to automate, and survives
   package updates to the main ``/etc/sudoers`` file.

The ``/etc/sudoers.d/`` Directory

Modern distributions include the directive ``#includedir /etc/sudoers.d`` in
the main ``/etc/sudoers`` file. This allows you to drop fragmented policy
files into ``/etc/sudoers.d/``, each containing specific rules.

**Best practice: One file per purpose:**

.. code-block:: bash

   # Create a file for web team privileges
   # visudo -f /etc/sudoers.d/web-team
   %web-team ALL=(root) /usr/bin/systemctl restart apache2, /usr/bin/systemctl reload apache2

   # Create a file for backup scripts
   # visudo -f /etc/sudoers.d/backups
   backupuser ALL=(root) NOPASSWD: /usr/local/sbin/backup.sh

**File naming conventions:**

* Files in ``/etc/sudoers.d/`` are alphabetically merged.
* Files ending in ``~`` or containing ``.`` are ignored (a security
  feature — backup files and package manager temp files are skipped).
* Convention: use descriptive names like ``10-web-team``, ``20-db-admins``,
  ``30-monitoring`` to control ordering.

**Example — granting a user passwordless sudo for specific commands:**

.. code-block:: bash

   # echo "deploy ALL=(root) NOPASSWD: /usr/bin/systemctl reload nginx" \
     | tee /etc/sudoers.d/deploy-nginx
   # chmod 440 /etc/sudoers.d/deploy-nginx
   # visudo -c -f /etc/sudoers.d/deploy-nginx
   >>> /etc/sudoers.d/deploy-nginx: syntax OK

.. warning::

   Files in ``/etc/sudoers.d/`` must have permissions **0440** (owner
   readable, group readable, no world access). Sudo will refuse to parse
   them otherwise. This is a safety feature — it prevents users from
   creating their own sudo rules.

   .. code-block:: bash

      # chmod 440 /etc/sudoers.d/deploy-nginx

Key Sudoers Defaults

The ``Defaults`` keyword controls sudo's runtime behaviour:

.. code-block:: text
   :caption: Common ``Defaults`` settings

   # Always require a password (this is the default)
   Defaults   passwd_timeout=5

   # Set the authentication timestamp timeout (minutes, 0 = always ask)
   Defaults   timestamp_timeout=15

   # Secure path — always reset PATH to a known value
   Defaults   secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

   # Preserve the user's SSH_AUTH_SOCK (for SSH agent forwarding)
   Defaults   env_keep += "SSH_AUTH_SOCK"

   # Keep proxy environment variables
   Defaults   env_keep += "http_proxy https_proxy ftp_proxy"

   # Preserve the user's HOME variable
   Defaults   env_reset
   Defaults   env_keep += "HOME"

   # Log all commands executed via sudo
   Defaults   logfile=/var/log/sudo.log
   Defaults   log_input, log_output

   # Mail warnings to root when bad passwords are entered
   Defaults   mail_badpass
   Defaults   mailto=admin@example.com

   # Require a TTY (no background sudo from cron scripts)
   Defaults   requiretty

The Secure Path

The ``secure_path`` default is one of sudo's most important security
features. It **replaces** the user's ``$PATH`` with a known, safe value
when running commands via sudo:

.. code-block:: text

   Defaults   secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

**Why this matters:**

Consider a user Alice who has a compromised ``~/bin`` directory:

.. code-block:: text

   $ echo '#!/bin/sh
   cp /bin/bash /tmp/.rootshell
   chmod u+s /tmp/.rootshell' > ~/bin/ls
   $ chmod +x ~/bin/ls
   $ export PATH=~/bin:$PATH

   # Without secure_path:
   $ sudo ls              # Runs ~/bin/ls as root! Installs SUID backdoor!

   # With secure_path:
   $ sudo ls              # Runs /bin/ls as root. Safe.

Always ensure ``secure_path`` is set and never disabled.

The ``env_keep`` Directive

By default, sudo resets the environment to a clean state (``env_reset`` is
on by default). The ``env_keep`` list specifies variables that are preserved
from the user's environment:

.. code-block:: text

   Defaults   env_keep += "DISPLAY XAUTHORITY"
   Defaults   env_keep += "SSH_AUTH_SOCK"
   Defaults   env_keep += "http_proxy https_proxy"

**Dangerous variables to never include in env_keep:**

- ``LD_PRELOAD`` — could inject a shared library into the sudo process.
- ``LD_LIBRARY_PATH`` — could redirect library loading.
- ``PYTHONPATH``, ``PERL5LIB``, ``RUBYLIB`` — module path injection.
- ``IFS`` — could alter command parsing.

Sudo explicitly ignores ``LD_*`` variables regardless of ``env_keep`` —
this is hardcoded for security. But other interpreter-specific variables
may not be blocked.

Sudo Logging and Auditing

Sudo can log every command execution:

.. code-block:: text

   # In /etc/sudoers:
   Defaults   logfile=/var/log/sudo.log

This produces entries like:

.. code-block:: text

   Jul 15 12:00:00 : alice : TTY=pts/0 ; PWD=/home/alice ; USER=root ;
                     COMMAND=/usr/bin/apt update

For even more detailed logging, enable input/output logging:

.. code-block:: text

   Defaults   log_input, log_output
   Defaults   iolog_dir=/var/log/sudo-io

This captures the entire terminal session — every keystroke and every
character of output — playable later with ``sudoreplay(8)``:

.. code-block:: bash

   # sudo sudoreplay -l          # List recorded sessions
   # sudo sudoreplay -d 12345    # Replay session ID 12345

Sudo Pitfalls and Security Considerations

**1. ``sudo`` vs. shell built-ins:**

Sudo runs an **external command**. Shell built-ins (``cd``, ``ulimit``,
``exec``, ``source``) cannot be used with sudo:

.. code-block:: bash

   $ sudo cd /root   # Fails — cd is a shell built-in, not a binary
   sudo: cd: command not found

   # Correct approach:
   $ sudo -s          # Get a root shell, then cd

**2. Wildcard dangers:**

A rule like ``/usr/bin/vim *`` allows editing **any** file:

.. code-block:: bash

   $ sudo vim ../../etc/shadow   # Vim opens /etc/shadow!

Always use absolute paths and avoid wildcards where possible. If wildcards
are necessary, use them carefully (e.g., ``/usr/bin/systemctl restart *`` is
less dangerous than ``/usr/bin/systemctl *``).

**3. The ``!`` negation trap:**

.. code-block:: text

   # Attempt to allow everything EXCEPT /sbin/shutdown
   alice ALL=(root) ALL, !/sbin/shutdown

An attacker can bypass this by copying ``/sbin/shutdown``:

.. code-block:: bash

   $ cp /sbin/shutdown /tmp/shutdown
   $ sudo /tmp/shutdown   # Not blocked by the rule!

Negation-based blacklisting is fundamentally flawed. Use **whitelisting**
instead:

.. code-block:: text

   # Whitelist approach — only allow specific commands
   alice ALL=(root) /usr/bin/systemctl *, /usr/bin/apt *

**4. The ``sudo`` SUID binary:**

The ``sudo`` binary itself has the SUID bit set (``-rwsr-xr-x``). This is
necessary because normal users cannot create processes with different UIDs.
This also makes the ``sudo`` binary a high-value target — a vulnerability in
sudo can lead to full system compromise (as demonstrated by the Baron
Samedit CVE-2021-3156).

``doas`` — The Modern Minimalist Alternative
====================================================

While ``sudo`` is powerful, it is also **complex**. The sudo codebase has
grown to over 130,000 lines of code (as of version 1.9.x), with a
configuration syntax that can be arcane. This complexity has led to a
long history of CVEs.

**``doas``** (originally called ``doas`` for "do as") was developed by Ted
Unangst for **OpenBSD** (released in OpenBSD 5.8, October 2015). Its design
philosophy is:

* **Minimalism**: A few hundred lines of code vs. sudo's hundreds of
  thousands.
* **Simplicity**: The configuration file has only a handful of directives.
* **Security**: A smaller attack surface means fewer potential
  vulnerabilities.
* **Sane defaults**: ``doas`` is designed with secure defaults and fewer
  configuration traps.

**On Linux**, ``doas`` is available as the ``opendoas`` port (because the
OpenBSD project's license and naming conventions differ). On most Linux
distributions, you install ``opendoas``:

.. code-block:: bash

   # Debian/Ubuntu
   # apt install opendoas

   # Alpine Linux (doas is the default — sudo is not even installed!)
   # apk add doas

   # Arch Linux
   # pacman -S opendoas

   # Fedora/RHEL (via EPEL or copr)
   # dnf install opendoas

.. note::

   On **Alpine Linux**, ``doas`` is the **default** privilege escalation
   tool. The ``sudo`` package is not installed in the base system. This
   makes Alpine a showcase for the "doas way."

``doas`` Configuration — ``/etc/doas.conf`` or ``/etc/doas.d/doas.conf``

The configuration file is astonishingly simple compared to sudoers:

.. code-block:: text
   :caption: ``/etc/doas.d/doas.conf`` — a complete configuration

   # Allow members of the wheel group full root access
   permit persist :wheel

   # Allow alice to run systemctl commands without a password
   permit nopass alice as root cmd /usr/bin/systemctl

   # Allow bob to run backup.sh as root
   permit bob as root cmd /usr/local/sbin/backup.sh

   # Allow carol to run any command as the www-data user
   permit carol as www-data

**Syntax breakdown:**

.. code-block:: text

   permit|deny [options] identity [as target] [cmd command [args ...]]

**Directives:**


   .. list-table:: ``doas.conf`` Directives
      :widths: 20 20 60

   +=================+==================+====================================+
   | ``permit``      | ``permit :wheel``| Grant access.                      |

   .. list-table::

      * - ``deny``
        - ``deny bob``
        - Explicitly deny access. Deny rules take precedence over permit.
**Options:**


   .. list-table:: ``doas.conf`` Options
      :widths: 15 20 65

   +==============+========================+==================================+
   | ``persist``  | ``permit persist :wheel`` | Remember authentication for      |
   |              |                        | a period (default 5 minutes).    |
   |              |                        | Equivalent to sudo's timestamp.  |

   .. list-table::

      * - ``nopass``
        - ``permit nopass alice``
        - No password required.
      * - ``keepenv``
        - ``permit keepenv :wheel``
        - Preserve the user's environment variables (like ``sudo -E``).
**Identity:**


.. list-table::

   * - ``user``
     - A specific username (e.g., ``alice``).
   * - ``:group``
     - A group name with a colon prefix (e.g., ``:wheel``, ``:sudo``).
**Target user (optional):**


.. list-table::

   * - ``as target_user``
     - Run as the specified user. Default: root. You can also specify ``as target_user:target_group``.
**Command and arguments (optional):**


.. list-table::

   * - ``cmd /full/path/to/binary [args]``
     - The absolute path to the command. If ``args`` is omitted, any arguments are allowed. Specific arguments can be listed: ``cmd /usr/bin/systemctl restart nginx``
**The ``persist`` keyword:**

The ``persist`` option provides the equivalent of sudo's credential cache:

.. code-block:: text

   permit persist :wheel

When a user in the ``wheel`` group first runs ``doas``, they are prompted
for their password. Subsequent ``doas`` commands within the next 5 minutes
(default) succeed without a password. The timer is tracked by the ``doas``
process, which runs in the background as root and sends a signal to itself
when the timeout expires.

To manually clear the credential cache:

.. code-block:: bash

   $ doas -L        # Forget cached credentials

``doas`` Usage

.. code-block:: bash
   :caption: ``doas`` in action

   # Run a command as root
   $ doas whoami
   root

   # Run a command as another user
   $ doas -u alice whoami
   alice

   # Run a command with password caching
   $ doas apk update     # First time: prompts for password
   $ doas apk upgrade    # Subsequent: no password (within persist window)

   # Start a root shell
   $ doas -s             # Root shell (uses /bin/sh, not the target's shell)
   $ doas -s /bin/bash   # Root shell with bash

   # Clear the authentication cache
   $ doas -L

   # Check configuration syntax (useful after editing doas.conf)
   $ doas -C /etc/doas.d/doas.conf

``doas`` Configuration Best Practices

**Alpine Linux default configuration:**

On Alpine, the default ``/etc/doas.d/doas.conf`` is:

.. code-block:: text

   permit persist :wheel

That is it. One line. This gives the ``wheel`` group password-cached root
access.

**Minimal but secure:**

.. code-block:: text

   # Root can always do as root (prevents accidental lockout)
   permit nopass root as root

   # Administrators in the admin group
   permit persist :wheel

   # Specific commands for specific users
   permit nopass alice as root cmd /usr/bin/systemctl
   permit bob as www-data cmd /usr/local/bin/deploy

**Syntax checking:**

.. code-block:: bash

   # doas -C /etc/doas.d/doas.conf
   # (no output means no syntax errors)

   # Config file permissions (must be 0640 or stricter, owned by root)
   # chmod 0640 /etc/doas.d/doas.conf
   # chown root:root /etc/doas.d/doas.conf

``doas`` vs. ``sudo`` — When to Use Which


   .. list-table:: Comparative Analysis
      :widths: 30 35 35

   +=======================+================================+=================================+
   | **Configuration       | Complex, dozens of directives, | Minimal, 4-5 directives,        |
   | complexity**          | aliases, defaults, tagging.    | one-syntax-fits-all.            |

   .. list-table::

      * - **Codebase size**
        - ~130,000+ lines (sudo 1.9.x)
        - ~3,000 lines (opendoas 6.9)
      * - **History of CVEs**
        - Numerous high-severity CVEs (CVE-2021-3156, CVE-2019-18634, CVE-2017-1000367, etc.).
        - Very few CVEs (smaller attack surface).
      * - **Configuration validation**
        - ``visudo`` with syntax validation.
        - ``doas -C`` syntax check. Simpler but less strict.
      * - **Input/output logging**
        - Built-in (``log_input``, ``log_output``, ``sudoreplay``)
        - Not available. You must rely on system auditd or script wrappers.
      * - **Environment management**
        - Complex ``env_keep`` / ``env_check`` / ``env_delete`` system. Fine-grained control.
        - ``keepenv`` option (all or nothing). Simpler but less granular.
      * - **Aliases**
        - User_Alias, Host_Alias, Cmnd_Alias, Runas_Alias.
        - Not available. Use groups (``:groupname``) instead.
      * - **Multi-host configuration**
        - Built-in (Host_Alias, single file for N machines).
        - Not designed for network-wide config. Manage per-host.
      * - **LDAP/SSSD integration**
        - Yes (pam_ldap, sudo-ldap).
        - No.
      * - **Default on**
        - Almost every Linux distribution, macOS, BSDs (with sudo pkg).
        - **Alpine Linux** (default), OpenBSD, Void Linux (optional).
      * - **Best for**
        - Enterprise environments, multi-admin teams, complex compliance requirements, Centralised LDAP/AD integration.
        - Single-user workstations, minimalist setups, containers, embedded systems, users who prefer simplicity over features.
**When to choose ``sudo``:**

* You manage a team of 10+ administrators with different roles.
* You need fine-grained logging and session recording for compliance
  (PCI-DSS, SOC2, HIPAA).
* You need LDAP/AD integration for centralised sudoers management.
* You need complex command restrictions (specific arguments, negation
  patterns).
* You are maintaining an existing enterprise deployment where sudo is
  standardised.

**When to choose ``doas``:**

* You are setting up a personal workstation or a small server.
* You value minimalism and want the smallest possible attack surface.
* You are building a container image or an embedded Linux system.
* You are on Alpine Linux (where doas is the default).
* You find sudo's configuration syntax overly complex for your needs.
* You want to spend less time debugging privilege escalation issues.

Migrating from ``sudo`` to ``doas``

If you decide to migrate, the process is straightforward:

**Step 1: Install ``opendoas``.**

**Step 2: Create ``/etc/doas.d/doas.conf``** (mapping your sudoers rules):

.. code-block:: text

   # Original sudo rule:       %sudo   ALL=(ALL:ALL) ALL
   # Equivalent doas rule:
   permit persist :sudo

   # Original sudo rule:       alice   ALL=(root) NOPASSWD: /usr/bin/systemctl
   # Equivalent doas rule:
   permit nopass alice as root cmd /usr/bin/systemctl

**Step 3: Test** — ``doas whoami`` should print ``root``.

**Step 4: Optionally remove sudo** — ``apt remove sudo`` (Debian) /
``apk del sudo`` (Alpine) / etc.

.. caution::

   Before removing sudo, ensure that scripts or tools that hardcode
   ``sudo ...`` are updated or aliased. A common approach is to create
   an alias:

   .. code-block:: bash

      $ alias sudo='doas'

   Or create a symlink:

   .. code-block:: bash

      # ln -s /usr/bin/doas /usr/local/bin/sudo

Comparing ``su``, ``sudo``, and ``doas``
================================================


   .. list-table:: Quick Comparison
      :widths: 12 28 30 30

   +============+============================+============================+===============================+
   | Requires   | Target user's password     | **Your** password          | **Your** password             |
   | password   | (usually root's).          | (user's own).              | (user's own).                 |

   .. list-table::

      * - Granularity
        - None (all or nothing).
        - Per-user, per-group, per-command, per-host.
        - Per-user, per-group, per-command. No per-host.
      * - Audit trail
        - None (who became root, then nothing).
        - Full logging (command, args, user, host, PWD). Optional I/O logging.
        - Basic logging (syslog). No input/output logging.
      * - Config files
        - None (hardcoded by PAM).
        - /etc/sudoers, /etc/sudoers.d/*.
        - /etc/doas.conf or /etc/doas.d/doas.conf.
      * - Credential caching
        - Unlimited (once root, stays root).
        - Timed (default 5 min). Configurable.
        - Timed (default 5 min, ``persist`` option).
      * - Use case
        - Emergency access, single- user recovery mode, legacy workflows.
        - Standard multi-user admin, enterprise.
        - Minimalist setups, single- user systems, Alpine/OpenBSD.
Practical Privilege Escalation Workflows
================================================

**Workflow 1: Granting passwordless service restart to a web team member**

.. code-block:: bash

   # Using sudo:
   # echo "%web-team ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx, \
   #       /usr/bin/systemctl restart apache2" \
   #   | tee /etc/sudoers.d/web-team
   # chmod 440 /etc/sudoers.d/web-team

   # Using doas:
   # echo "permit nopass :web-team as root cmd /usr/bin/systemctl" \
   #   | tee /etc/doas.d/doas.conf

**Workflow 2: Deploying a script that needs root for one specific action**

.. code-block:: bash

   # Create a dedicated sudoers file for the deploy user
   # visudo -f /etc/sudoers.d/deploy
   deploy ALL=(root) NOPASSWD: /usr/local/sbin/deploy.sh

   # In deploy.sh, call the specific privileged command:
   # sudo /usr/local/bin/restart-service

   # Or with doas:
   # echo "permit nopass deploy as root cmd /usr/local/sbin/deploy.sh" \
   #   >> /etc/doas.d/doas.conf

**Workflow 3: Auditing who has sudo/doas access**

.. code-block:: bash

   # List all sudoers files
   $ ls -la /etc/sudoers.d/
   $ cat /etc/sudoers /etc/sudoers.d/* | grep -v '^#' | grep -v '^$'

   # List all doas configurations
   $ cat /etc/doas.conf /etc/doas.d/*.conf 2>/dev/null | grep -v '^#' | grep -v '^$'

   # Find users in the sudo/wheel groups
   $ getent group sudo wheel
   sudo:x:27:alice,bob
   wheel:x:10:carol,dave

Summary
==============

*   **``sudo``** is the industry-standard privilege escalation tool with
    granular configuration, comprehensive logging, and multi-host support.
*   The **``/etc/sudoers``** file (edited via ``visudo``) and
    ``/etc/sudoers.d/`` directory define who can run what, as whom, and on
    which hosts.
*   Key sudo features: aliases, command restriction, ``NOPASSWD``,
    ``secure_path``, ``env_keep``, input/output logging, ``sudoreplay``.
*   **``doas``** is the modern, minimalist alternative from OpenBSD with a
    configuration file of only a few lines.
*   ``doas`` is the **default on Alpine Linux** and ideal for personal
    workstations, containers, and users who value simplicity over features.
*   Both tools ask for **your** password (not root's), cache credentials
    temporarily, and provide audit trails (``sudo`` more extensively).
*   ``doas`` configuration uses ``permit``/``deny`` with options
    ``persist``, ``nopass``, ``keepenv``, and the ``:group`` notation.
*   Choose ``sudo`` for enterprise, compliance-heavy, LDAP-integrated
    environments. Choose ``doas`` for minimalism, Alpine Linux, personal
    workstations, and smaller setups.

