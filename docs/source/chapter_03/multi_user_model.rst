.. _section-3-1:

The Linux Multi-User Model
==================================================

.. rst-class:: lead

   Linux is not a single-user operating system dressed up to look multi-user;
   it is a true multi-user system, inheriting and extending the design forged
   at Bell Labs in the 1970s. Understanding the user model is the foundation
   upon which all security, resource management, and accountability rests.

The Philosophy of Multi-User Systems
===========================================

Why did Unix—and by extension Linux—embrace multiple users from the very
beginning? The answer lies in the historical context of the early 1970s.
Computers were **expensive, room-sized mainframes**. A single PDP-7 or
PDP-11 might cost hundreds of thousands of dollars (in 1970s currency). It
made no economic sense for one person to monopolise such a machine.

The Unix designers solved this with three key abstractions:

*   **Users**: Distinct identities with unique credentials.
*   **Groups**: Collections of users sharing common access needs.
*   **Permissions**: Rules governing which users and groups can access which
    resources.

These abstractions are so deeply embedded that every running process, every
file, every socket, and every shared memory segment is stamped with a **user
identity** (UID) and a **group identity** (GID). There is no anonymous
execution; even the most humble background daemon runs as *someone*.

.. note::

   The principle of **least privilege** dictates that a user or process should
   be granted no more authority than necessary to perform its task. This
   principle permeates every design decision we will study in this chapter.

The ``/etc/passwd`` File
===============================

The cornerstone of user identity on Linux is the ``/etc/passwd`` file.
Despite its name, this file no longer stores *passwords* in any modern
distribution. Historically it did, but the security implications of a
world-readable file containing password hashes became obvious very quickly.
Today, ``/etc/passwd`` stores **user account metadata**, and actual secrets
live in ``/etc/shadow``.

Let us examine the anatomy of a single line from ``/etc/passwd``:

.. code-block:: text
   :caption: A typical line from ``/etc/passwd`` (line-wrapped for annotation)

   jdoe:x:1001:1001:Jane Doe,Office 4A,555-1234,:/home/jdoe:/bin/bash
   ├───┐ ├ ─┬─ ─┬─ ──────────┬─────────────────┐ ──────┬───── ────┬─────
   │   │  │   │   │            │                  │         │          │
   │   │  │   │   │            │                  │         │          └── 7. Shell
   │   │  │   │   │            │                  │         └──────────── 6. Home directory
   │   │  │   │   │            │                  └────────────────────── 5. GECOS field
   │   │  │   │   └────────────┴───────────────────────────────────────── 4. UID
   │   │  │   └────────────────────────────────────────────────────────── 3. GID
   │   │  └────────────────────────────────────────────────────────────── 2. Password placeholder
   │   └────────────────────────────────────────────────────────────────── 1. Username

**Field-by-field breakdown:**

1. **Username** (``jdoe``): The human-readable login name. Must be unique on
   the system. Typically 1–32 characters, alphanumeric with underscores and
   hyphens. Case-sensitive (though traditionally lowercase).

2. **Password placeholder** (``x``): A single ``x`` indicates that the actual
   password hash is stored in ``/etc/shadow``. If this field contains an
   asterisk (``*``) or exclamation mark (``!``), the account is **locked**
   and no password-based login is possible. An empty field means no password
   is required—an extreme security risk.

3. **UID** (User ID, ``1001``): A numeric identifier. The kernel tracks
   *UIDs*, not usernames. Two usernames sharing the same UID are treated as
   the same user by the kernel (useful for migration scenarios, but generally
   to be avoided).

4. **GID** (Primary Group ID, ``1001``): The numeric ID of the user's
   **primary group**. When the user creates a file, its group ownership is
   set to this GID (unless the parent directory's SGID bit dictates otherwise
   —see section 3.4).

5. **GECOS field**: An archaic name inherited from the General Electric
   Comprehensive Operating Supervisor. Historically used for mainframe user
   information. Today it is a comma-separated grab-bag of user metadata: full
   name, office location, office phone, home phone. Not relied upon by the
   kernel; accessible via ``finger(1)`` and ``chfn(1)``.

6. **Home directory** (``/home/jdoe``): The user's initial working directory
   upon login. If it does not exist, most login mechanisms will fall back to
   ``/``.

7. **Login shell** (``/bin/bash``): The program started after authentication
   succeeds. Common values: ``/bin/bash``, ``/bin/zsh``, ``/bin/sh``,
   ``/usr/bin/fish``. A value of ``/sbin/nologin`` or ``/usr/sbin/nologin``
   disables interactive login but allows system services to run. ``/bin/false``
   is a common way to disable an account entirely (returns exit code 1
   immediately).

.. warning::

   Never edit ``/etc/passwd`` directly with a text editor. Use the dedicated
   tools (``vipw``, ``useradd``, ``usermod``) which acquire the necessary
   file locks. A half-written ``/etc/passwd`` can lock every user out of
   the system. ``vipw`` (and its shadow counterpart ``vipw -s``) open the
   file in ``vi`` after acquiring an ``flock`` advisory lock.

The ``/etc/shadow`` File
===============================

The ``/etc/shadow`` file holds the **actual password hashes** and password
policy metadata. It is readable only by ``root`` and members of the ``shadow``
group (if so configured). This is not paranoia—a leaked password hash is
vulnerable to offline dictionary and brute-force attacks. Keeping it
root-readable is a minimum requirement.

A typical shadow line:

.. code-block:: text
   :caption: A typical line from ``/etc/shadow``

   jdoe:$y$j9T$eD...hash...X1:19876:0:90:7:30:20000:
   ├──┐ ───────────┬────────── ─┬─ ─┬─ ─┬─ ─┬── ─┬─── ─┬─ ─┬─
   │  │             │            │    │    │    │     │    │   │
   │  │             │            │    │    │    │     │    │   └── 9. Reserved
   │  │             │            │    │    │    │     │    └───── 8. Account expiration
   │  │             │            │    │    │    │     └─────────── 7. Inactivity days
   │  │             │            │    │    │    └───────────────── 6. Warning days
   │  │             │            │    │    └─────────────────────── 5. Max days
   │  │             │            │    └─────────────────────────── 4. Min days
   │  │             │            └──────────────────────────────── 3. Last change (epoch days)
   │  │             └───────────────────────────────────────────── 2. Password hash
   │  └─────────────────────────────────────────────────────────── 1. Username

**Field-by-field breakdown:**

1. **Username**: Matches the corresponding entry in ``/etc/passwd``.
2. **Password hash**: The salted, hashed password. Formats include:
   * ``$y$...`` — yescrypt (default on modern Debian, Fedora 30+).
   * ``$6$...`` — SHA-512 (common on older systems).
   * ``$5$...`` — SHA-256.
   * ``$2b$...`` / ``$2y$...`` — bcrypt.
   * ``$1$...`` — MD5 (legacy, considered weak).
   * ``!`` or ``*`` — account locked, no login possible.
   * Empty — no password required (highly insecure).
3. **Last change**: The date of the last password change, expressed as days
   since the Unix epoch (1970-01-01). Use ``chage -l username`` to see it
   in human-readable form.
4. **Minimum days**: How long the user must wait before changing the password
   again. A value of ``0`` means no restriction.
5. **Maximum days**: After how many days the password expires and *must* be
   changed. Default of ``99999`` means effectively never.
6. **Warning days**: Number of days before expiry during which the user is
   warned at login time. Default ``7``.
7. **Inactivity days**: Days after password expiry before the account is
   **disabled**. The user can still login if they change the password within
   this window.
8. **Account expiration**: An absolute expiration date (epoch days). After
   this date, the account cannot log in regardless of password validity.
9. **Reserved**: Unused, reserved for future use.

.. warning::

   Password hashes in ``/etc/shadow`` use **salted hashing**. The salt (a
   random string prepended or embedded in the hash output) ensures that two
   users with the same password will have entirely different hash values. This
   prevents attackers from cracking all passwords simultaneously with a single
   rainbow table or precomputed dictionary.

The ``/etc/group`` File
==============================

Groups are Linux's mechanism for **collective permissions**. Instead of
granting access to a resource for each individual user, you create a group,
add users to it, and assign the resource to the group.

A line from ``/etc/group``:

.. code-block:: text

   developers:x:1102:alice,bob,carol
   ├───────┐ ├ ───┬─ ───────┬─────────┐
   │       │    │          │           │
   │       │    │          │           └── 4. Group members (comma-separated)
   │       │    │          └─────────────── 3. GID
   │       │    └────────────────────────── 2. Group password placeholder
   │       └─────────────────────────────── 1. Group name

*   **Group name**: Human-readable identifier (e.g., ``developers``, ``sudo``,
    ``docker``).
*   **Password placeholder** (``x``): Analogous to ``/etc/passwd``. Rarely
    used. A group password lets non-members temporarily join the group via
    ``newgrp(1)`` (legacy, almost never used in practice).
*   **GID**: Numeric group ID.
*   **Member list**: Comma-separated list of usernames who are **supplementary
    members** of this group. The **primary group** membership (from
    ``/etc/passwd``) is *not* duplicated here.

.. note::

   A user's **effective groups** at any moment are the union of:
   1. Their primary group (from ``/etc/passwd`` field 4).
   2. All supplementary groups (from ``/etc/group`` where the username appears
      in the member list).

   The command ``groups username`` or ``id username`` will display the full
   set.

UIDs and GIDs: The Kernel's View
========================================

The kernel does **not** care about usernames. When a process makes a system
call—say, ``open(2)`` on a file—the kernel checks only the numeric UID and
GID of the calling process against the ownership and permission bits of the
inode. Usernames are a *user-space convenience*.

**UID ranges** are standardised across Linux distributions (see
``/etc/login.defs`` for local configuration):

.. list-table:: Conventional UID Ranges
   :header-rows: 1
   :widths: 15 25 60

   * - Range
     - Type
     - Purpose
   * - ``0``
     - Root
     - The superuser. Absolute power.
   * - ``1–999``
     - System users (pseudo-users)
     - Reserved for daemons and system services. No home directory, no login shell (``/sbin/nologin``).
   * - ``65534``
     - The ``nobody`` user
     - Unprivileged user for mapping anonymous NFS or unprivileged container workloads.
   * - ``1000+``
     - Regular users
     - Human users. On Debian/Ubuntu, the first created user gets UID ``1000``.

.. note::

   The exact boundary between system UIDs and regular UIDs varies:
   * **Debian/Ubuntu**: System UIDs 0–999, regular users start at 1000.
   * **RHEL/CentOS/Fedora**: System UIDs 0–999, regular users start at 1000
     (some older versions used 500 as the boundary).
   * **Arch Linux**: System UIDs 0–999, regular users start at 1000.

   These values are configured in ``/etc/login.defs`` via ``UID_MIN`` and
   ``UID_MAX``.

**Why does the ``nobody`` user have UID ``65534``?** Historically, UID 65535
(``-1`` as a signed 16-bit integer) was the "invalid" or "overflow" UID. As
systems moved to 32-bit UIDs, 65534 became the conventional "anonymous"
mapping—a user with deliberately no special privileges, used by NFS for
anonymous access and by some daemons as the ultimate sandbox.

System Users and the Principle of Least Privilege
=========================================================

Every network service running on your machine (SSH server, web server,
database server, DHCP client, cron daemon) has a dedicated **system user**.
This is not accidental; it is a deliberate application of the **principle of
least privilege**.

Consider: if the ``sshd`` (SSH daemon) process ran as ``root`` and a buffer
overflow vulnerability was exploited, the attacker would gain **full root
access**. By running ``sshd`` as the ``sshd`` user (UID ``106`` on Debian),
the blast radius is contained—the attacker now has the privileges of a
dedicated, restricted system user.

Let's examine some common system users on a typical Linux installation:

.. code-block:: text
   :caption: Selected system users from a Debian system

   root:x:0:0:root:/root:/bin/bash
   daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
   bin:x:2:2:bin:/bin:/usr/sbin/nologin
   sys:x:3:3:sys:/dev:/usr/sbin/nologin
   sync:x:4:65534:sync:/bin:/bin/sync
   games:x:5:60:games:/usr/games:/usr/sbin/nologin
   man:x:6:12:man:/var/cache/man:/usr/sbin/nologin
   lp:x:7:7:lp:/var/spool/lpd:/usr/sbin/nologin
   mail:x:8:8:mail:/var/mail:/usr/sbin/nologin
   news:x:9:9:news:/var/spool/news:/usr/sbin/nologin
   _ssh:x:106:65534:SSH daemon,,,:/run/sshd:/usr/sbin/nologin
   _chrony:x:113:120:Chrony daemon,,,:/var/lib/chrony:/usr/sbin/nologin

Notice the pattern:

*   **Shells**: Almost all system users have ``/usr/sbin/nologin`` as their
    shell—preventing interactive login.
*   **Home directories**: Minimal, often pointing to runtime directories
    (``/run/sshd``, ``/var/lib/chrony``).
*   **UIDs**: Below 1000, reserving the high range for human users.
*   **Underscore prefix**: Modern Debian (and some others) prefix system
    usernames with an underscore for clarity (``_ssh``, ``_chrony``,
    ``_apt``).

The Pluggable Authentication Module (PAM) Ecosystem
==========================================================

While not the focus of this chapter, it is essential to know that
authentication on modern Linux systems is handled by **PAM (Pluggable
Authentication Modules)**, configured in ``/etc/pam.d/``. The
``/etc/passwd``, ``/etc/shadow``, and ``/etc/group`` files are the
**Name Service Switch (NSS)** data sources—one of several possible backends.
Other backends include LDAP, SSSD, or NIS (legacy). The ``getent`` command
abstracts over these backends:

.. code-block:: bash

   $ getent passwd jdoe
   jdoe:x:1001:1001:Jane Doe,,,:/home/jdoe:/bin/bash

   $ getent group developers
   developers:x:1102:alice,bob,carol

``getent`` queries whatever NSS sources are configured in
``/etc/nsswitch.conf``, making it the **correct** way to look up user and
group information in a distribution-agnostic manner. Use it instead of
grepping flat files directly.

Checking Your Identity
=============================

Before we move on to managing users, let us cement understanding with a few
diagnostic commands:

.. code-block:: bash
   :caption: Commands for examining identity

   $ whoami          # Print the current user name
   jdoe

   $ id              # Comprehensive identity information
   uid=1001(jdoe) gid=1001(jdoe) groups=1001(jdoe),27(sudo),1002(developers)

   $ id -u           # Just the numeric UID
   1001

   $ id -g           # Just the numeric GID of the primary group
   1001

   $ id -G           # All supplementary GIDs
   1001 27 1002

   $ id -nG          # Supplementary group names
   jdoe sudo developers

   $ groups          # Short form of group membership
   jdoe : jdoe sudo developers

   $ logname         # Original login user (even after su/sudo)
   jdoe

Summary
==============

*   Linux is a true multi-user system built on the abstractions of users,
    groups, and permissions.
*   ``/etc/passwd`` stores user metadata (world-readable).
*   ``/etc/shadow`` stores password hashes and policy (root-readable only).
*   ``/etc/group`` defines groups and supplementary memberships.
*   UIDs and GIDs are numeric; the kernel works with numbers, not names.
*   System users (UIDs 0–999) isolate daemon privileges.
*   Use ``getent`` for portable lookups, ``id`` for current identity.
*   The principle of least privilege dictates that every process runs with the
    minimum UID/GID necessary to function.
