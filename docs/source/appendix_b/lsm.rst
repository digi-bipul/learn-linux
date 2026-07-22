.. _app-b-lsm:

------------------------------------------------------------------------------
B.2  Linux Security Modules (AppArmor, SELinux)
------------------------------------------------------------------------------

LSMs provide Mandatory Access Control (MAC) on top of the standard DAC
(owner/group/other). Two major LSMs ship with modern Linux distros:
**AppArmor** (Ubuntu, openSUSE, Debian) and **SELinux** (RHEL, Fedora,
CentOS). They are **mutually exclusive** — only one can be active at a time.

------------------------------------------------------------------------------
B.2.1  AppArmor
------------------------------------------------------------------------------

AppArmor confines programs to a set of allowed files, capabilities, and
network operations defined in **profiles** (stored in ``/etc/apparmor.d/``).

.. list-table:: AppArmor Command Reference
   :header-rows: 1
   :widths: 30 35 35

   * - Command
     - Example
     - Description
   * - ``apparmor_status``
     - ``apparmor_status``
     - Show loaded profiles, processes in enforce/complain
   * - ``aa-enforce``
     - ``sudo aa-enforce /usr/sbin/nginx``
     - Set profile to enforce mode (active blocking)
   * - ``aa-complain``
     - ``sudo aa-complain /usr/sbin/nginx``
     - Set profile to complain mode (log violations, allow)
   * - ``aa-disable``
     - ``sudo aa-disable /usr/sbin/nginx``
     - Disable profile
   * - ``aa-logprof``
     - ``sudo aa-logprof``
     - Interactive tool to generate/modify profiles from logs
   * - ``aa-genprof``
     - ``sudo aa-genprof /usr/sbin/nginx``
     - Generate a new profile (wizard)
   * - ``aa-autodep``
     - ``sudo aa-autodep /usr/sbin/nginx``
     - Generate a minimal profile (auto-dependencies)

.. rubric:: Profile syntax (example: ``/etc/apparmor.d/usr.sbin.nginx``)

.. code-block:: text

   #include <tunables/global>

   /usr/sbin/nginx {
     #include <abstractions/base>
     #include <abstractions/nameservice>

     capability dac_override,
     capability net_bind_service,
     capability setgid,
     capability setuid,

     /etc/nginx/** r,
     /var/log/nginx/** w,
     /var/run/nginx.pid w,
     /usr/sbin/nginx r,
   }

.. rubric:: Profile modes (per binary)

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Mode
     - Behaviour
   * - **Enforce**
     - Violations are **blocked** and logged to ``/var/log/syslog`` or ``audit.log``
   * - **Complain**
     - Violations are **logged only** — process continues. Used for profiling/testing
   * - **Unconfined**
     - No AppArmor profile loaded (runs under standard DAC)

.. code-block:: bash
   :caption: Checking AppArmor status

   sudo aa-status             # Short summary
   sudo apparmor_status       # Same, more verbose
   cat /sys/module/apparmor/parameters/enabled   # Returns "Y" if enabled

------------------------------------------------------------------------------
B.2.2  SELinux
------------------------------------------------------------------------------

SELinux (Security-Enhanced Linux) labels every object (files, processes,
sockets, devices) with a **security context** (user:role:type:level). Policy
rules define which types can access which other types.

.. rubric:: SELinux modes

.. list-table::
   :header-rows: 1
   :widths: 15 25 60

   * - Mode
     - ``getenforce`` output
     - Behaviour
   * - **Enforcing**
     - ``Enforcing``
     - Policy is enforced; violations are denied and logged
   * - **Permissive**
     - ``Permissive``
     - Violations are logged but **allowed** (troubleshooting mode)
   * - **Disabled**
     - ``Disabled``
     - SELinux is completely off (requires reboot to re-enable)

.. code-block:: bash
   :caption: SELinux mode commands

   getenforce                # Check current mode
   setenforce 0              # Switch to Permissive (until reboot)
   setenforce 1              # Switch to Enforcing

   # Persistent: edit /etc/selinux/config
   # SELINUX=enforcing|permissive|disabled

.. rubric:: SELinux commands at a glance

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - Command
     - Example
     - Description
   * - ``sestatus``
     - ``sestatus``
     - Full status: mode, policy version, loaded policy name
   * - ``ls -Z``
     - ``ls -Z /var/www/html``
     - Show SELinux context of files
   * - ``ps -Z``
     - ``ps auxZ | grep nginx``
     - Show SELinux context of processes
   * - ``id -Z``
     - ``id -Z``
     - Show current user's security context
   * - ``chcon``
     - ``chcon -t httpd_sys_content_t index.html``
     - Change file context (temporary)
   * - ``restorecon``
     - ``restorecon -Rv /var/www/html``
     - Restore default file context (per policy)
   * - ``semanage fcontext``
     - ``semanage fcontext -a -t httpd_sys_content_t '/web(/.*)?'``
     - Add custom file context mapping (persistent)
   * - ``semanage boolean``
     - ``semanage boolean -l``
     - List and toggle SELinux booleans
   * - ``getsebool``
     - ``getsebool httpd_enable_homedirs``
     - Get boolean value
   * - ``setsebool``
     - ``setsebool -P httpd_enable_homedirs on``
     - Set boolean persistently (``-P``)
   * - ``audit2why``
     - ``audit2why < /var/log/audit/audit.log``
     - Explain why an AVC denial occurred
   * - ``audit2allow``
     - ``audit2allow -a -M mypol``
     - Generate a policy module to allow logged denials

.. rubric:: Common SELinux boolean controls for web servers

.. code-block:: bash

   setsebool -P httpd_can_network_connect on      # Allow Apache to make outbound connections
   setsebool -P httpd_enable_homedirs on          # Allow Apache to access user home dirs
   setsebool -P httpd_use_nfs on                  # Allow Apache to use NFS filesystems

.. rubric:: SELinux troubleshooting flow

.. code-block:: text

   1. Check:  ls -Z file     (file context)
              ps -Z pid      (process context)

   2. If mismatch, check the default policy:
      seinfo -t | grep httpd      # list httpd-related types
      sesearch -A -s httpd_t      # show rules for httpd_t

   3. Quick fix (temporary):
      chcon -t httpd_sys_content_t /path/to/file

   4. Permanent fix:
      semanage fcontext -a -t httpd_sys_content_t '/path(/.*)?'
      restorecon -Rv /path/

   5. If still denied, run:
      ausearch -m avc -ts recent | audit2why       # Explanation
      ausearch -m avc -ts recent | audit2allow -M mymodule  # Create .pp module
      semodule -i mymodule.pp                       # Load it
