.. _sec9_3:

###########################################################
9.3 SELinux (Security-Enhanced Linux)
###########################################################

**SELinux is the most powerful mandatory access control (MAC) system ever**
**implemented in a general-purpose operating system.** Developed originally
by the **National Security Agency (NSA)** and released to the open source
community in 2000, SELinux implements a **Flask security architecture** that
enables fine-grained, type-enforcement-based access control over every
system resource—processes, files, sockets, IPC, and even kernel objects.

9.3.1 Why SELinux? The NSA's Motivations
=========================================

The NSA's mission includes protecting classified national security systems
(NSS). In the late 1990s, the agency recognized that **Discretionary Access
Control (DAC)** —the standard Unix ``rwx`` permission model—was fundamentally
insufficient. DAC allows users to delegate permissions to others (``chmod``,
``chown``). If a user's account is compromised, the attacker inherits all of
that user's discretionary rights.

**Mandatory Access Control (MAC)** solves this by defining a system-wide
policy that neither users nor processes can override. Even the ``root`` user
is constrained by SELinux policy. This is critical for environments where a
compromised root account must be contained—exactly the scenario the NSA
confronts daily.

**Deployment across the US Government:**

- **Department of Defense (DoD):** SELinux is mandatory on all RHEL-based
  systems under DoD Instruction 8500.01 and DISA STIGs.
- **Central Intelligence Agency (CIA) & FBI:** Classified networks use
  SELinux with **Multi-Level Security (MLS)** policies to enforce
  classification labels (Unclassified, Confidential, Secret, Top Secret).
- **US Cyber Command:** Active defense platforms run SELinux in enforcing
  mode.
- **International adoption:** NATO, the UK's GCHQ, and South Korea's
  National Intelligence Service have published guidelines recommending
  SELinux for high-security Linux deployments.

9.3.2 Core Concepts: Labels, Contexts, and Types
=================================================

SELinux associates a **security context** (also called a label) with every
subject (process) and object (file, socket, device). The context is a
colon-delimited string of four fields:

::

    user:role:type:level

**Example:**
::

    system_u:object_r:httpd_sys_content_t:s0

+-----------------+---------------------------------------------------+
| Field           | Description                                       |
+=================+===================================================+
| ``user``        | SELinux user identity (e.g., ``system_u``,        |
|                 | ``unconfined_u``, ``user_u``). Maps to Linux      |
|                 | users via ``semanage login``.                     |
+-----------------+---------------------------------------------------+
| ``role``        | Role-based access control (RBAC) component.       |
|                 | ``object_r`` for files, ``system_r`` for system   |
|                 | processes, ``user_r`` for regular users.          |
+-----------------+---------------------------------------------------+
| ``type``        | **The core of TE (Type Enforcement).** A type is  |
|                 | an identifier that SELinux uses to make access    |
|                 | decisions. For subjects (processes) this is the   |
|                 | **domain**; for objects (files) this is the type. |
+-----------------+---------------------------------------------------+
| ``level``       | Sensitivity level for MLS/MCS (Multi-Category     |
|                 | Security). ``s0`` is the default single level;    |
|                 | ``s0-s3:c0.c1023`` defines a range for MLS.      |
+-----------------+---------------------------------------------------+

**Type Enforcement (TE)** is the heart of SELinux. Access is governed by
rules in the form:

::

    allow SOURCE_TYPE TARGET_TYPE:CLASS { PERMISSIONS };

For example, the rule that allows Apache (domain ``httpd_t``) to read
web content:
::

    allow httpd_t httpd_sys_content_t:file { read getattr open };

If a file is labeled ``httpd_sys_content_t``, Apache can read it. If a
file accidentally labeled ``shadow_t`` ends up in ``/var/www/html/``,
Apache is **denied** —even if file permissions say ``644`` and the owner
is ``root``. This is MAC in action.

9.3.3 SELinux Modes
====================

SELinux operates in one of three modes:

+-----------------+----------------------------------------------------+
| Mode            | Behaviour                                          |
+=================+====================================================+
| ``Enforcing``   | Policy is enforced. Denied operations are blocked  |
|                 | and logged to ``audit.log``.                       |
+-----------------+----------------------------------------------------+
| ``Permissive``  | Policy is *not* enforced. Denials are logged but   |
|                 | allowed. Used for troubleshooting and policy       |
|                 | development.                                       |
+-----------------+----------------------------------------------------+
| ``Disabled``    | SELinux is completely turned off. No policy loaded |
|                 | and no logging. Not recommended — files remain     |
|                 | labeled, but tools like ``restorecon`` will not    |
|                 | work correctly.                                    |
+-----------------+----------------------------------------------------+

Check and set mode:
::

    getenforce          # Enforcing | Permissive | Disabled
    setenforce 0        # Switch to Permissive (immediate, non-persistent)
    setenforce 1        # Switch to Enforcing

Persistent mode is configured in ``/etc/selinux/config``:
::

    SELINUX=enforcing
    SELINUXTYPE=targeted   # Or: mls, minimum

9.3.4 SELinux Policy Types
===========================

**Targeted Policy (default)**
    Only specific daemon processes (httpd, sshd, named, etc.) are confined in
    their own domains. User processes and unlabeled processes run in
    ``unconfined_t``, which is **not** constrained (though newer targeted
    policies do confine user domains via ``user_t``, ``staff_t``, etc.).
    This is the right choice for 95% of servers.

**MLS (Multi-Level Security) Policy**
    Enforces the Bell-LaPadula model: "no read up, no write down."
    Every process and file has a sensitivity label (s0 through s15).
    A process cleared for ``s3`` can read files labeled ``s0`` through
    ``s3`` but not ``s4``. It can write to ``s3`` and above but not below.
    Used in classified government environments. The MLS policy is extremely
    complex and requires deep policy customization.

**Minimum Policy**
    A lightweight version of targeted that loads only a small set of
    rules. Suitable for embedded systems with very constrained resources.

9.3.5 SELinux Booleans
=======================

Booleans toggle predefined sets of policy rules without writing new policy.
They are the primary way administrators customize SELinux behaviour.

List and examine booleans:
::

    semanage boolean -l              # List all booleans with descriptions
    getsebool -a                     # List current boolean values

Common booleans:

+---------------------------------------+-------+-----------------------------------+
| Boolean                               | Default | Effect when On                    |
+=======================================+=========+===================================+
| ``httpd_can_network_connect``         | off    | Apache can make outbound          |
|                                       |        | TCP connections (needed for       |
|                                       |        | proxying, connecting to DB).      |
+---------------------------------------+-------+-----------------------------------+
| ``httpd_enable_homedirs``             | off    | Apache can read user home         |
|                                       |        | directories (e.g., ``~/public_html``).|
+---------------------------------------+-------+-----------------------------------+
| ``ssh_chroot_rw_homes``               | off    | Allow SSH chroot to have          |
|                                       |        | writeable home directories.       |
+---------------------------------------+-------+-----------------------------------+
| ``virt_use_nfs``                      | off    | KVM/libvirt can use NFS mounts    |
|                                       |        | for VM storage.                   |
+---------------------------------------+-------+-----------------------------------+
| ``domain_can_mmap_files``             | off    | Confined domains can use memory-  |
|                                       |        | mapped files (on by default in    |
|                                       |        | recent policies).                 |
+---------------------------------------+-------+-----------------------------------+

Set a boolean persistently:
::

    setsebool -P httpd_can_network_connect on

The ``-P`` flag writes to the persistent policy store (``/etc/selinux/targeted/booleans``).
Without ``-P``, the change is lost on reboot.

9.3.6 Troubleshooting SELinux
==============================

SELinux's greatest strength—its comprehensiveness—is also its greatest
challenge. New services almost always trigger denials during initial setup.
The toolkit for resolving denials:

**1. Identify the denial:**
::

    ausearch -m avc -ts recent    # Recent AVC denials from audit.log
    journalctl -t setroubleshoot   # SELinux trouble-shooter messages (prettier)

**2. Interpret with ``sealert``:**
::

    sealert -l $(journalctl -t setroubleshoot -n1 | grep -oP '[0-9a-f\-]{36}')

   ``sealert`` provides human-readable explanations and recommended fix commands.

**3. Generate a custom policy module with ``audit2allow``:**
::

    ausearch -m avc -ts recent | audit2allow -M myapp
    semodule -i myapp.pp

   This creates a Type Enforcement file (``myapp.te``), compiles it to a
   policy package (``myapp.pp``), and installs it.
   
   **WARNING:** ``audit2allow`` generates an *allow-all* policy for the
   observed denials. Never use the generated module blindly in production.
   Audit the ``.te`` file first to ensure it grants only necessary
   permissions.

**4. Correct file labels:**
   
   The most common SELinux issue is an incorrect label on a file or
   directory. Fix with:
   ::

       restorecon -Rv /path/to/directory
       restorecon -v /path/to/file

   To change the default label for a path persistently:
   ::

       semanage fcontext -a -t httpd_sys_content_t "/var/www/html(/.*)?"
       restorecon -Rv /var/www/html

**5. Temporarily set permissive mode for a specific domain:**
::

    semanage permissive -a httpd_t   # httpd_t runs permissive; all else enforcing

   Use this to test a service without disabling SELinux entirely.

9.3.7 SELinux in Container Environments
========================================

Containers present a unique challenge: they share a kernel with the host.
SELinux provides critical isolation. On Red Hat OpenShift and RHEL 9+,
every container runs under ``container_t`` (or a custom ``svirt_*`` domain
for KVM). The policy prevents a container from reading host filesystem
content even if the mount namespace is misconfigured.

**User Namespace + SELinux interaction (2026):**

Since Linux 6.6, the interaction between user namespaces and SELinux has
been improved. The ``selinuxfs`` is now namespace-aware, allowing
user-namespaced containers to query SELinux state without compromising the
host. However, the **``unconfined_u`` user namespace escape** remains a
concern—ensure ``container_t`` is the default domain for all container
runtime processes (``runc``, ``crun``, ``containerd``).

9.3.8 Real-World: MLS in a Classified Environment
==================================================

Consider a **SCI (Sensitive Compartmented Information)** facility running
RHEL 9 with SELinux MLS:

+-------------------+------------------------+-------------------------------+
| Level             | Example Data           | SELinux Context               |
+===================+========================+===============================+
| TS//SI/TK         | Sigint, HUMINT reports | ``user_u:user_r:user_t:s15``  |
+-------------------+------------------------+-------------------------------+
| SECRET            | Operational plans      | ``user_u:user_r:user_t:s10``  |
+-------------------+------------------------+-------------------------------+
| CONFIDENTIAL      | Procurement records    | ``user_u:user_r:user_t:s5``   |
+-------------------+------------------------+-------------------------------+
| UNCLASSIFIED      | Published research     | ``user_u:user_r:user_t:s0``   |
+-------------------+------------------------+-------------------------------+

A user logged in at ``s10`` (SECRET) can read UNCLASSIFIED and CONFIDENTIAL
documents (no read up). They can write to SECRET and TOP SECRET (no write
down, preventing data leakage to lower levels). If a TOP SECRET document
is accidentally placed in a world-readable directory, SELinux MLS prevents
anyone below ``s15`` from opening it.

**This is not theoretical.** The US Intelligence Community's **JWICS**
(Joint Worldwide Intelligence Communications System) and **NSANet** use
variants of this model across tens of thousands of Linux workstations.

9.3.9 SELinux vs. Alternatives
===============================

The perennial debate: *SELinux or AppArmor?* We provide a detailed comparison
in :ref:`Section 9.4 <sec9_4>`. For now, note the strategic calculus:

- **Choose SELinux if:** You are in a DoD/IC environment, RHEL/CentOS shop,
  require MLS, or need fine-grained control over every system object
  including kernel subsystems.
- **Choose AppArmor if:** You use Ubuntu/Debian/SUSE, want path-based
  simplicity, or need to confine application profiles rapidly.

**Bottom line:** In 2026, both are battle-tested and production-ready. The
choice is primarily ecosystem-driven. Learn both; deploy whichever your
distribution supports best.
