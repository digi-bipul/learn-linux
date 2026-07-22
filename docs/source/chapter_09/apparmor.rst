.. _sec9_4:

###########################################################
9.4 AppArmor
###########################################################

**AppArmor (Application Armor)** is a mandatory access control (MAC) system
that, like SELinux, confines programs to a limited set of resources.
However, AppArmor takes a fundamentally different approach: instead of
labeling every object with a security context (type), AppArmor uses
**path-based** profiles that specify which files, network addresses, and
capabilities a given executable may access.

AppArmor originated at **Immunix** (later acquired by Novell and then SUSE)
and is the default MAC system on Debian, Ubuntu, and SUSE/openSUSE. It has
been in the mainline Linux kernel since 2.6.36.

9.4.1 Architecture: Path-Based MAC
===================================

AppArmor profiles are loaded into the kernel, where the **LSM (Linux Security
Module)** framework intercepts system calls and checks the profile of the
executing process before granting access. Unlike SELinux, which assigns
security contexts to *every* inode, AppArmor associates a profile with a
*path* (or an attachment condition like ``executable_name``).

**Key distinction:**
- **SELinux:** ``allow httpd_t httpd_sys_content_t:file read;`` — The
  decision depends on the *type label* of the file object.
- **AppArmor:** ``/var/www/html/** r,`` — The decision depends on the *path*
  accessed, resolved through the filesystem's dentry cache.

This path-based approach is simpler to understand and audit. An
administrator can read an AppArmor profile and immediately see which paths
a program may read, write, or execute.

9.4.2 Profile Modes
====================

Every AppArmor profile runs in one of two modes:

+-----------------+----------------------------------------------------+
| Mode            | Behaviour                                          |
+=================+====================================================+
| ``enforce``     | Policy is enforced. Violations are blocked and     |
|                 | logged to ``audit.log`` and ``/var/log/syslog``.   |
+-----------------+----------------------------------------------------+
| ``complain``    | Policy is *logged* but not enforced. Violations    |
|                 | appear in logs but access is granted. Used for     |
|                 | learning and profile development.                  |
+-----------------+----------------------------------------------------+

Profiles are stored as human-readable text files in ``/etc/apparmor.d/``.
The filename convention is the executable's absolute path with slashes
replaced by dots (e.g., ``/etc/apparmor.d/usr.sbin.ntpd`` for
``/usr/sbin/ntpd``).

9.4.3 Profile Syntax Deep Dive
===============================

Let us dissect a profile for a hypothetical web application binary.

::

    # /etc/apparmor.d/usr.local.bin.myapp
    include <tunables/global>

    /usr/local/bin/myapp {
        #include <abstractions/base>
        #include <abstractions/nameservice>
        #include <abstractions/openssl>

        # Capabilities
        capability dac_override,
        capability net_bind_service,
        capability setgid,
        capability setuid,

        # Filesystem access
        /etc/myapp/config.ini    r,
        /var/log/myapp/*.log     w,
        /var/lib/myapp/**        rwk,
        /usr/local/bin/myapp     mr,    # m = memory-map, r = read for exec
        /tmp/myapp_*.sock        rw,

        # Network access
        network inet tcp,
        network inet6 tcp,

        # Deny everything else (implicit)
    }

**Access modes:**

+----------+-------------------------------------------------------+
| Modifier | Meaning                                               |
+==========+=======================================================+
| ``r``    | Read                                                  |
+----------+-------------------------------------------------------+
| ``w``    | Write (implies append and truncate)                   |
+----------+-------------------------------------------------------+
| ``a``    | Append only (cannot truncate)                         |
+----------+-------------------------------------------------------+
| ``k``    | Lock (for file locking operations)                    |
+----------+-------------------------------------------------------+
| ``l``    | Link (hard link creation)                             |
+----------+-------------------------------------------------------+
| ``m``    | Memory-map executable (PROT_EXEC ``mmap``)            |
+----------+-------------------------------------------------------+
| ``x``    | Execute (transition to a new profile or unconfined)   |
+----------+-------------------------------------------------------+

**Globbing patterns:**

+------------------+----------------------------------------------------+
| Pattern          | Matches                                            |
+==================+====================================================+
| ``/dir/*``       | Direct children of ``/dir``                        |
+------------------+----------------------------------------------------+
| ``/dir/**``      | ``/dir`` and all children recursively              |
+------------------+----------------------------------------------------+
| ``/dir/a[bc]``   | ``/dir/ab`` or ``/dir/ac``                         |
+------------------+----------------------------------------------------+
| ``/dir/{foo,bar}``| ``/dir/foo`` or ``/dir/bar``                      |
+------------------+----------------------------------------------------+

9.4.4 Managing AppArmor: Essential Commands
============================================

::

    aa-status                 # List loaded profiles and their modes
    aa-enforce /path/to/bin   # Set profile to enforce mode
    aa-complain /path/to/bin  # Set profile to complain mode
    aa-disable /path/to/bin   # Unload profile
    aa-genprof /path/to/bin   # Generate a new profile interactively
    aa-logprof                # Review audit log and update profiles

**``aa-genprof`` — the profile generation workflow:**

1. Run ``aa-genprof /usr/bin/myapp``.
2. Execute the program and perform typical operations.
3. In another terminal, ``aa-genprof`` monitors ``audit.log`` for denials.
4. For each denial, you choose: **Allow**, **Deny**, **Glob** (widen the path),
   **Abstraction** (use a predefined set of rules), or **New** (create a
   custom rule).
5. After scanning, the profile is saved and set to enforce mode.

**``aa-logprof`` — the ongoing tuning workflow:**

After deploying a profile, services often trigger new denials during
edge cases. Run ``aa-logprof`` periodically to review and add rules.

9.4.5 AppArmor Abstractions and Tunables
=========================================

**Abstractions** are reusable profile fragments located in
``/etc/apparmor.d/abstractions/``:

- ``base`` — Essential system access (ld.so, libc, locale).
- ``nameservice`` — DNS resolution (``/etc/resolv.conf``, nsswitch, mDNS).
- ``openssl`` — OpenSSL configuration and random device access.
- ``python`` — Python standard library access.
- ``authentication`` — PAM stack access.
- ``X`` — X11 display server access.

**Tunables** in ``/etc/apparmor.d/tunables/`` define variables:

::

    # /etc/apparmor.d/tunables/var
    @{PROC}=/proc/
    @{SYS}=/sys/
    @{HOME}=/home/*/

Usage in profiles:
::

    @{HOME}/.ssh/** r,

This makes profiles portable across distributions where home directory paths
may differ.

9.4.6 AppArmor in Container Environments (2026)
================================================

AppArmor is the default LSM for Docker on Ubuntu and Debian. When you run:

::

    docker run --rm -it ubuntu bash

Docker automatically loads the ``docker-default`` AppArmor profile, which
restricts the container's filesystem access, capability set, and network
operations—even if running with ``--privileged``.

**Custom AppArmor profiles for Docker:**

1. Write a profile (e.g., ``/etc/apparmor.d/docker-custom``).
2. Load it: ``apparmor_parser -r -W /etc/apparmor.d/docker-custom``.
3. Run the container with: ``docker run --security-opt apparmor=docker-custom ...``

**Kubernetes (Podman/CRI-O):**

On Fedora CoreOS and RHEL for Edge, CRI-O applies AppArmor profiles to pods
via the ``container.apparmor.security.beta.kubernetes.io`` annotation
(graduated to stable in Kubernetes 1.30):

::

    metadata:
      annotations:
        container.apparmor.security.beta.kubernetes.io/nginx: local/profile-name

9.4.7 SELinux vs. AppArmor — The Definitive Comparison
=======================================================

+----------------------+---------------------------+---------------------------+
| Criterion            | SELinux                   | AppArmor                  |
+======================+===========================+===========================+
| **Labeling model**   | Label-based (type on      | Path-based (profile on    |
|                      | every inode)              | executable)               |
+----------------------+---------------------------+---------------------------+
| **Ease of use**      | Steep learning curve;     | Gentler curve; profiles   |
|                      | ``audit2allow`` and       | readable as plain text;   |
|                      | ``semanage`` required.    | ``aa-genprof`` guides.    |
+----------------------+---------------------------+---------------------------+
| **Granularity**      | Extremely fine: network   | Fine for filesystem;      |
|                      | sockets, IPC, kernel      | coarser for network       |
|                      | objects, capability sets.  | (only address + protocol).|
+----------------------+---------------------------+---------------------------+
| **MLS support**      | Full MLS (Bell-LaPadula)  | No MLS support.           |
|                      | in production use.        |                           |
+----------------------+---------------------------+---------------------------+
| **Performance**      | Slightly higher overhead  | Lower overhead; path      |
|                      | due to label lookup on    | lookup is a single        |
|                      | every object access.      | dentry walk.              |
+----------------------+---------------------------+---------------------------+
| **Distribution**     | RHEL, Fedora, CentOS,     | Ubuntu, Debian, SUSE,     |
|                      | Rocky, Alma (default).    | Arch (default on Debian   |
|                      |                           | derivatives).             |
+----------------------+---------------------------+---------------------------+
| **Policy language**  | TE (Type Enforcement) +   | Plain-text rules with     |
|                      | RBAC + MLS, compiled to   | C-like abstractions and   |
|                      | binary policy ``.pp``.    | tunables.                 |
+----------------------+---------------------------+---------------------------+
| **Container support**| OpenShift (``svirt_*``),  | Docker (default on        |
|                      | requires custom labels.   | Ubuntu), simpler to       |
|                      |                           | configure.                |
+----------------------+---------------------------+---------------------------+
| **Community &        | Larger in enterprise/RHEL | Strong in desktop/Ubuntu  |
| **Ecosystem**        | ecosystem.                | ecosystem.                |
+----------------------+---------------------------+---------------------------+

**Which to choose?**

- **Government/Military:** SELinux. MLS is a non-negotiable requirement
  for classified systems. The DoD mandates SELinux via STIGs.
- **Enterprise RHEL shop:** SELinux. It is already installed, enabled, and
  integrates with Red Hat Identity Management and OpenShift.
- **Ubuntu/Debian production server:** AppArmor. It is the default, well
  tested, and simpler to maintain. Use SELinux only if MLS is required.
- **Docker-focused workflow:** AppArmor is simpler to tune for container
  workloads on Ubuntu. On RHEL-based container hosts, stick with SELinux.

9.4.8 Real-World: AppArmor at Scale
====================================

**Canonical's Ubuntu Pro** includes AppArmor profiles for over 100
applications out of the box. In 2026, the **Certified AppArmor Profiles**
program provides vendor-verified profiles for NGINX, PostgreSQL, Redis,
RabbitMQ, and MongoDB.

**Case study — Payment card processing (PCI DSS):**

A European payment processor runs 2,000 Ubuntu Server nodes handling
SWIFT messages and card-present transactions. Every node enforces AppArmor
profiles for:

- ``java`` (the transaction processing JVM)
- ``nginx`` (TLS termination)
- ``postgresql`` (transaction database)
- ``opensshd`` (hardened remote access)

The AppArmor profiles, combined with ``auditd`` and ``falco``, satisfy the
PCI DSS requirement for "critical system components to be protected by
Mandatory Access Control." The compliance auditor can open
``/etc/apparmor.d/usr.lib.jvm.java-17-openjdk.bin.java`` and immediately
verify the JVM cannot write to ``/etc/passwd`` or read arbitrary files in
``/home/``.
