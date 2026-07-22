.. _app-b-pam:

------------------------------------------------------------------------------
B.3  Pluggable Authentication Modules (PAM)
------------------------------------------------------------------------------

PAM provides a modular framework for authentication on Linux. Applications
link against ``libpam`` and delegate authentication to configured modules.

------------------------------------------------------------------------------
B.3.1  PAM Configuration Files
------------------------------------------------------------------------------

Configuration files reside in ``/etc/pam.d/``. Each service (``sshd``,
``login``, ``sudo``, ``passwd``) has its own file. The four **management
groups** are:

.. list-table:: PAM Management Groups
   :header-rows: 1
   :widths: 15 25 60

   * - Module Type
     - Description
     - Typical Modules
   * - ``auth``
     - Identity verification
     - ``pam_unix.so``, ``pam_ldap.so``, ``pam_google_authenticator.so``
   * - ``account``
     - Access restrictions (expiry, time-based, group)
     - ``pam_unix.so``, ``pam_time.so``, ``pam_access.so``
   * - ``password``
     - Password update policies
     - ``pam_unix.so``, ``pam_cracklib.so``, ``pam_pwquality.so``
   * - ``session``
     - Actions on login/logout
     - ``pam_unix.so``, ``pam_limits.so``, ``pam_mount.so``, ``pam_selinux.so``

------------------------------------------------------------------------------
B.3.2  Control Flags
------------------------------------------------------------------------------

Each module entry includes a control flag determining how the result affects
overall authentication:

.. list-table:: PAM Control Flags
   :header-rows: 1
   :widths: 15 30 55

   * - Flag
     - Behaviour
     - Use Case
   * - ``required``
     - Must succeed. If fails, other modules run but final result is failure.
     - Essential modules that should not short-circuit
   * - ``requisite``
     - Must succeed. If fails, return failure **immediately** (skip remaining).
     - Critical gate (e.g., password check)
   * - ``sufficient``
     - If succeeds, skip remaining modules for this type.
     - Alternative auth methods (e.g., fingerprint, then fallback to password)
   * - ``optional``
     - Result ignored unless this is the only module listed.
     - Logging or peripheral checks
   * - ``include``
     - Include all entries from another PAM service file.
     - E.g., ``include system-auth`` for centralized auth
   * - ``substack``
     - Like ``include`` but failure does not propagate to calling stack.
     - Isolating authentication sub-stanzas

.. rubric:: PAM config syntax

.. code-block:: text

   # /etc/pam.d/sshd (simplified)
   auth       required     pam_securetty.so
   auth       requisite    pam_nologin.so
   auth       sufficient   pam_unix.so nullok try_first_pass
   auth       required     pam_deny.so

   account    required     pam_unix.so
   account    required     pam_time.so

   password   requisite    pam_pwquality.so minlen=8 ucredit=-1 dcredit=-1
   password   sufficient   pam_unix.so sha512 shadow nullok try_first_pass use_authtok

   session    required     pam_limits.so
   session    required     pam_unix.so

------------------------------------------------------------------------------
B.3.3  Common PAM modules

.. list-table:: Common PAM Modules
   :header-rows: 1
   :widths: 25 30 45

   * - Module
     - Location
     - Purpose
   * - ``pam_unix.so``
     - ``/lib/security/``
     - Traditional Unix password/account management (``/etc/passwd``, ``/etc/shadow``)
   * - ``pam_pwquality.so``
     - ``/lib/security/``
     - Password strength checking (replaces ``pam_cracklib.so`` on modern distros)
   * - ``pam_tally2.so``
     - ``/lib/security/``
     - Failed login counting / account lockout
   * - ``pam_limits.so``
     - ``/lib/security/``
     - Enforce ``/etc/security/limits.conf`` (``nofile``, ``nproc``, etc.)
   * - ``pam_time.so``
     - ``/lib/security/``
     - Time-based access restrictions (``/etc/security/time.conf``)
   * - ``pam_access.so``
     - ``/lib/security/``
     - Host/user/group-based access control (``/etc/security/access.conf``)
   * - ``pam_google_authenticator.so``
     - ``/lib/security/``
     - TOTP 2FA (time-based one-time passwords)
   * - ``pam_ssh.so``
     - ``/lib/security/``
     - Use SSH agent for authentication
   * - ``pam_ldap.so``
     - ``/lib/security/``
     - Authenticate against LDAP directory
   * - ``pam_winbind.so``
     - ``/lib/security/``
     - Authenticate against Active Directory (via Samba Winbind)
   * - ``pam_mkhomedir.so``
     - ``/lib/security/``
     - Automatically create home directory on first login
   * - ``pam_nologin.so``
     - ``/lib/security/``
     - Deny non-root login if ``/etc/nologin`` exists
   * - ``pam_securetty.so``
     - ``/lib/security/``
     - Restrict root login to secure TTYs (``/etc/securetty``)
   * - ``pam_deny.so``
     - ``/lib/security/``
     - Always fail — used as default fallback
   * - ``pam_permit.so``
     - ``/lib/security/``
     - Always succeed — used as permissive placeholder
   * - ``pam_echo.so``
     - ``/lib/security/``
     - Print a message (used for banners)

.. rubric:: Example: enforcing password quality

.. code-block:: bash

   # /etc/security/pwquality.conf
   minlen = 12
   dcredit = -1        # At least one digit
   ucredit = -1        # At least one uppercase
   lcredit = -1        # At least one lowercase
   ocredit = -1        # At least one other character
   minclass = 4        # At least 4 character classes
   maxrepeat = 3       # No more than 3 identical chars in a row
   dictcheck = 1       # Check against dictionary

.. rubric:: Example: account lockout after 3 failed attempts

.. code-block:: bash

   # In /etc/pam.d/sshd (add before pam_unix.so):
   auth    required    pam_tally2.so deny=3 unlock_time=600 onerr=fail

   # View current count:
   pam_tally2 --user username

   # Reset counter:
   pam_tally2 --user username --reset
