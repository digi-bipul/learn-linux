.. _section-3-2:

User & Group Management
==================================================

.. rst-class:: lead

   Knowing how the system *models* users is essential; knowing how to
   *create, modify, and remove* them is the practical skill of a system
   administrator. This section covers the complete toolkit for user and group
   management: the low-level POSIX tools (``useradd``, ``groupadd``, etc.)
   and their distribution-specific wrappers.

The Low-Level vs. High-Level Tools
===================================

Two parallel universes of user management tools exist on Linux:

.. list-table:: Management Tool Comparison
   :header-rows: 1
   :widths: 25 25 50

   * - Low-Level (Standard)
     - High-Level (Convenience)
     - Notes
   * - ``useradd``
     - ``adduser`` (Perl script)
     - ``adduser`` is interactive; prompts for full name, password, etc.
   * - ``usermod``
     - (none)
     - ``usermod`` modifies existing users
   * - ``userdel``
     - ``deluser``
     - ``deluser`` can also remove home directories and mail spools
   * - ``groupadd``
     - ``addgroup``
     - Similar distinction
   * - ``groupdel``
     - ``delgroup``
     -

**Distribution differences:**

*   **Debian / Ubuntu**: ``adduser`` and ``deluser`` are Perl scripts that
    wrap the low-level tools. They provide interactive prompts, sensible
    defaults, and extra safety checks. They are considered the **default**
    user management tools on Debian derivatives.
*   **RHEL / CentOS / Fedora**: ``useradd`` is the standard tool. An
    ``adduser`` symlink to ``useradd`` may exist, but it is *not* the Debian
    Perl script—it is simply ``useradd`` under a different name. No
    interactive prompting.
*   **Arch Linux**: ``useradd`` from the ``shadow`` package. No
    ``adduser`` Perl script in the base install (though it can be installed
    from AUR). Arch expects you to use the low-level tools directly.
*   **Alpine Linux**: Uses ``busybox`` implementations of ``adduser`` and
    ``addgroup``—minimal but functional shell-based versions.

In this section, we teach the **low-level POSIX tools** (``useradd``,
``usermod``, ``userdel``, ``groupadd``, ``groupmod``, ``groupdel``) since
they are universal. We then describe the high-level wrappers where
relevant.

Creating Users with ``useradd``
======================================

The ``useradd(8)`` command creates a new user. Despite its apparent
simplicity, it has approximately forty options. Understanding the most
important ones saves hours of debugging.

**Syntax:**

.. code-block:: text

   useradd [options] USERNAME

**Essential options:**

.. list-table:: Key ``useradd`` Options
   :widths: 20 80

   * - ``-u UID``
     - Specify the numeric UID. If omitted, the next available UID >=
       ``UID_MIN`` (from ``/etc/login.defs``) is assigned automatically.
   * - ``-g GROUP``
     - Specify the **primary group** by name or GID. If omitted, the
       behaviour depends on ``USERGROUPS_ENAB`` in ``/etc/login.defs``:
       if enabled (default on most distros), a new group with the same name
       as the user is created and assigned as the primary group (the **user
       private group** or UPG scheme).
   * - ``-G GROUP1[,GROUP2,...]``
     - Supplementary group memberships. The user is added to these groups
       in addition to the primary group.
   * - ``-d HOME``
     - Home directory path. Default: ``/home/USERNAME``.
   * - ``-m``
     - Create the home directory (``mkdir -p`` mode). Without this flag, no
       home directory is created! This is a common trap for newcomers.
   * - ``-s SHELL``
     - Login shell. Default is ``/bin/bash`` on most systems, or the value
       of ``SHELL`` in ``/etc/default/useradd``.
   * - ``-c COMMENT``
     - GECOS comment (full name, office info, etc.).
   * - ``-e YYYY-MM-DD``
     - Account expiration date.
   * - ``-f DAYS``
     - Inactivity days before account disable (after password expiry).
   * - ``-N``
     - No user private group. The user's primary group becomes ``users``
       (GID 100) or whatever ``GROUP`` is specified in ``/etc/default/useradd``.
   * - ``-r``
     - Create a **system account** (UID in the system range, no home
       directory by default, no password ageing).
   * - ``-M``
     - Do **not** create a home directory (overrides ``CREATE_HOME`` in
       ``/etc/login.defs``).
   * - ``-k SKEL_DIR``
     - Copy skeleton files from ``SKEL_DIR`` instead of the default
       ``/etc/skel``.
   * - ``-K KEY=VALUE``
     - Override ``/etc/login.defs`` defaults (e.g.,
       ``-K UID_MIN=2000``).

**Practical example — creating a regular user:**

.. code-block:: bash
   :caption: Creating a user with explicit control

   # useradd -u 1500 -g users -G wheel,developers -m -d /home/alice \
             -s /bin/zsh -c "Alice Johnson,Engineering" alice

   # passwd alice
   New password:
   Retype new password:
   passwd: password updated successfully

Let us verify:

.. code-block:: bash

   $ id alice
   uid=1500(alice) gid=100(users) groups=100(users),10(wheel),1102(developers)

   $ getent passwd alice
   alice:x:1500:100:Alice Johnson,Engineering,,:/home/alice:/bin/zsh

**The default behaviour trap:**

On a system where ``USERGROUPS_ENAB`` is ``yes`` (most modern distros),
running ``useradd`` *without* ``-g``:

.. code-block:: bash

   # useradd -m bob
   # id bob
   uid=1501(bob) gid=1501(bob) groups=1501(bob)

A new group ``bob`` with GID ``1501`` was created automatically. This is the
**User Private Group** (UPG) scheme. It is explained in detail in
section 3.3.5 because it directly affects the default ``umask``.

.. note::

   The defaults for ``useradd`` are stored in ``/etc/default/useradd`` and
   ``/etc/login.defs``. Inspect these files on your system:

   .. code-block:: bash

      $ cat /etc/default/useradd
      # useradd defaults file
      GROUP=100
      HOME=/home
      INACTIVE=-1
      EXPIRE=
      SHELL=/bin/bash
      SKEL=/etc/skel
      CREATE_MAIL_SPOOL=no

The ``adduser`` Wrapper (Debian/Ubuntu)
-----------------------------------------------

On Debian and Ubuntu, the recommended way to create users is ``adduser``:

.. code-block:: bash
   :caption: ``adduser`` in action (Debian)

   # adduser alice
   Adding user `alice' ...
   Adding new group `alice' (1001) ...
   Adding new user `alice' (1001) with group `alice' ...
   Creating home directory `/home/alice' ...
   Copying files from `/etc/skel' ...
   New password:
   Retype new password:
   passwd: password updated successfully
   Changing the user information for alice
   Enter the new value, or press ENTER for the default:
           Full Name []: Alice Johnson
           Room Number []: 4A
           Work Phone []:
           Home Phone []:
           Other []:
   Is the information correct? [Y/n] y

The script handles:
- Interactive prompts.
- Password setting (saving a separate ``passwd`` call).
- GECOS field collection.
- ``/etc/skel`` file copy.
- Mail spool creation (if configured).
- Sanity checks (existing user, UID conflicts, etc.).

Use ``adduser`` when you want convenience and interactive setup. Use
``useradd`` when scripting or needing precise control.

Modifying Users with ``usermod``
=======================================

The ``usermod(8)`` command modifies **existing** user accounts. It shares
most options with ``useradd`` but applies changes to an existing entry.

**Common operations:**

.. code-block:: bash
   :caption: ``usermod`` in practice

   # Lock an account (prevents all password-based login)
   usermod -L alice

   # Unlock an account
   usermod -U alice

   # Change the primary group
   usermod -g staff alice

   # Replace supplementary groups (note: this *replaces* all current groups!)
   usermod -G docker,sudo alice

   # Append to supplementary groups (preserves existing groups!)
   usermod -aG kvm alice

   # Change the home directory (does NOT move files—use with -m to move)
   usermod -d /data/home/alice -m alice

   # Change the login shell
   usermod -s /bin/fish alice

   # Change the UID
   usermod -u 2000 alice

   # Change the username (yes, you can rename users)
   usermod -l alicia alice     # Renames alice → alicia

   # Set an account expiration date
   usermod -e 2026-12-31 alice

.. warning::

   The ``-G`` flag (without ``-a``) **replaces the entire supplementary
   group list**. This is one of the most common administrative mistakes.
   Always use ``-aG`` to append:

   .. code-block:: bash

      # Correct: adds to existing groups
      usermod -aG docker alice

      # WRONG: alice is now *only* in the docker group!
      usermod -G docker alice

Deleting Users with ``userdel``
=======================================

The ``userdel(8)`` command removes user accounts.

.. code-block:: bash
   :caption: ``userdel`` options

   # Remove user but leave home directory and mail spool
   userdel alice

   # Remove user AND home directory and mail spool
   userdel -r alice

   # Force removal (even if logged in, or if files exist outside /home)
   userdel -f alice

.. caution::

   ``userdel -r`` removes the home directory permanently and
   **irrecoverably**. There is no trash bin. Always confirm before running.
   Consider archiving the home directory first:

   .. code-block:: bash

      # tar cf /backup/alice-2026-07-15.tar /home/alice
      # userdel -r alice

   Furthermore, ``userdel`` does **not** remove files owned by the user
   outside their home directory (e.g., files in ``/tmp``, cron jobs in
   ``/var/spool/cron/crontabs``, mail in ``/var/mail``). Use ``find / -uid
   OLD_UID`` after deletion to identify orphaned files.

The Debian wrapper ``deluser`` provides additional safety:

.. code-block:: bash

   # deluser --remove-home alice
   # deluser --remove-all-files alice   # Also finds files outside /home
   # deluser --backup alice             # Backs up before removing

Managing Groups
=======================

``groupadd``
--------------------

.. code-block:: bash
   :caption: Creating groups

   # Create a group with automatic GID
   groupadd developers

   # Create a group with a specific GID
   groupadd -g 2500 devops

   # Create a system group (GID in system range)
   groupadd -r mydaemon

   # Create a group with a password (rare)
   groupadd -p ENCRYPTED_PASSWORD restricted

``groupmod``
--------------------

.. code-block:: bash
   :caption: Modifying groups

   # Rename a group
   groupmod -n devops dev-ops

   # Change GID
   groupmod -g 2600 devops

.. warning::

   Changing a GID with ``groupmod -g`` updates the group file but does
   **not** update the GID of existing files on disk. You must run
   ``find / -gid OLD_GID -exec chgrp NEW_GID {} +`` afterwards, or live
   with files owned by a numeric GID that no longer maps to a group name.

``groupdel``
--------------------

.. code-block:: bash

   # Remove a group
   groupdel developers

.. caution::

   You **cannot** delete a group that is the primary group of any existing
   user. You must first reassign those users to a different primary group
   (with ``usermod -g``) or delete the users. However, a group that has
   *supplementary* members can be deleted—those users will simply lose that
   supplementary membership.

Managing Passwords with ``passwd``
=========================================

The ``passwd(1)`` command is the primary interface for password management.

.. code-block:: bash
   :caption: ``passwd`` operations

   # Change your own password (prompts for current password)
   $ passwd

   # Root changes another user's password (no current password required)
   # passwd alice

   # Lock an account (prepends ! to the hash in /etc/shadow)
   # passwd -l alice

   # Unlock an account
   # passwd -u alice

   # Delete a password (removes the hash entirely — no password login!)
   # passwd -d alice

   # Force password change at next login (sets last change to 0)
   # passwd -e alice

   # Set minimum and maximum password age
   # passwd -n 7 -x 90 alice   # 7 day min, 90 day max

   # Inquire about password status
   # passwd -S alice
   alice P 03/14/2026 0 90 7 -1

   # Status fields: username, P(assword), last change, min, max, warn, inactive

.. note::

   The ``-S`` status flag indicates:
   * ``P`` – Usable password (``PS`` for SHA-512, ``PK`` for yescrypt, etc.)
   * ``L`` – Locked password (``!`` prepended to hash).
   * ``NP`` – No password.

Password Ageing with ``chage``
======================================

While ``passwd -n``/``-x`` can set basic age constraints, the ``chage(1)``
command offers far more comprehensive password policy management.

.. code-block:: bash
   :caption: ``chage`` usage

   # View expiry information
   # chage -l alice
   Last password change                                    : Mar 14, 2026
   Password expires                                        : Jun 12, 2026
   Password inactive                                       : never
   Account expires                                         : never
   Minimum number of days between password change          : 7
   Maximum number of days between password change          : 90
   Number of days of warning before password expires       : 7

   # Set interactive mode (prompts for each value)
   # chage alice

   # Set maximum days between password changes
   # chage -M 90 alice

   # Set minimum days before password can be changed again
   # chage -m 7 alice

   # Set warning days
   # chage -W 14 alice

   # Set inactivity days (days after expiry before account lock)
   # chage -I 10 alice

   # Set absolute account expiration
   # chage -E 2026-12-31 alice

   # Force password change at next login
   # chage -d 0 alice

**Practical security policies:**

.. code-block:: bash

   # Create a guest account that expires after 30 days
   # useradd -m -e 2026-08-14 guest
   # passwd guest

   # Create an account where the password must be changed every 60 days
   # useradd -m intern
   # chage -M 60 -W 14 intern
   # passwd intern

The ``gpasswd`` Command
===============================

The ``gpasswd(1)`` command manages group membership and group passwords.

.. code-block:: bash
   :caption: ``gpasswd`` in action

   # Add a user to a group
   # gpasswd -a alice docker
   Adding user alice to group docker

   # Remove a user from a group
   # gpasswd -d alice docker
   Removing user alice from group docker

   # Set a group administrator (user who can add/remove members)
   # gpasswd -A bob developers

   # Set group members (replaces the member list entirely)
   # gpasswd -M alice,carol,dave developers

   # Set/remove a group password (allows `newgrp` access)
   # gpasswd developers
   # gpasswd -r developers    # Remove group password

.. caution::

   ``gpasswd`` is considered a low-level tool. For everyday administration,
   ``usermod -aG`` is simpler and more common. However, ``gpasswd -A``
   (group administrators) has no equivalent in ``usermod`` and is the only
   way to delegate group management without granting full root.

Distribution-Specific Group Conventions
==============================================

One of the most practically important differences between distributions is
which group grants **administrative (sudo) privileges**:

.. list-table:: Admin Group Conventions
   :header-rows: 1
   :widths: 25 25 50

   * - Distribution Family
     - Admin Group
     - Notes
   * - Debian / Ubuntu
     - ``sudo``
     - ``%sudo ALL=(ALL:ALL) ALL`` in ``/etc/sudoers``. ``wheel`` not used by default.
   * - RHEL / CentOS / Fedora
     - ``wheel``
     - ``%wheel ALL=(ALL) ALL`` in ``/etc/sudoers`` (commented out by default on some versions).
   * - Arch Linux
     - ``wheel``
     - Must uncomment ``%wheel`` line in ``/etc/sudoers`` after install.
   * - Alpine Linux
     - ``wheel``
     - Uses ``doas`` (not sudo) by default; the ``wheel`` group is granted ``permit persist :wheel`` in ``/etc/doas.d/doas.conf``.
   * - SUSE / openSUSE
     - ``wheel``
     - Similar to RHEL.
   * - Void Linux
     - ``wheel``
     - Standard pattern.

.. admonition:: Best Practice

   Always check your distribution's ``/etc/sudoers`` (or ``/etc/doas.conf``)
   before assuming which group grants administrative privileges. The
   convention is:
   * **Debian family**: ``sudo`` group.
   * **Everyone else**: ``wheel`` group.

   When in doubt, ``grep`` the sudoers file:

   .. code-block:: bash

      $ grep -E '^(%sudo|%wheel)' /etc/sudoers
      %sudo ALL=(ALL:ALL) ALL

Common Workflows and Troubleshooting
=============================================

**Workflow 1: Creating a sudo user on Debian/Ubuntu**

.. code-block:: bash

   # adduser alice
   # usermod -aG sudo alice
   # su - alice
   $ sudo whoami
   root

**Workflow 2: Creating a sudo user on RHEL/Fedora**

.. code-block:: bash

   # useradd -m -G wheel alice
   # passwd alice
   # visudo -f /etc/sudoers.d/10-alice
   # Add: %wheel ALL=(ALL) ALL    (if not already present)

**Workflow 3: Creating a system user for a custom daemon**

.. code-block:: bash

   # useradd -r -s /usr/sbin/nologin -M -d /var/empty myapp
   # id myapp
   uid=997(myapp) gid=997(myapp) groups=997(myapp)

**Troubleshooting: "user xxx is currently logged in"**

When you attempt to modify or delete a user who is logged in:

.. code-block:: bash

   # userdel -r alice
   userdel: user alice is currently used by process 1234

Options:
1. Ask the user to log out (``who`` to find their terminal).
2. Kill their processes (``pkill -u alice`` — be careful).
3. Force with ``userdel -f alice`` (use as last resort).

**Troubleshooting: "useradd: cannot lock /etc/passwd"**

This indicates another process (another ``useradd``, ``vipw``, or system
tool) holds the lock. Check for stale lock files:

.. code-block:: bash

   # ls -la /etc/passwd.lock /etc/.pwd.lock
   # rm -f /etc/passwd.lock /etc/.pwd.lock   # Only if you are SURE no
                                             # other process is running!

Summary
===============

*   Use ``useradd`` (universal) for scripting; use ``adduser`` (Debian) for
    interactive use.
*   Always use ``-aG`` with ``usermod`` to append groups, never ``-G`` alone.
*   The ``-r`` flag to ``userdel`` removes the home directory — handle with
    care.
*   ``chage`` provides comprehensive password policy controls.
*   ``gpasswd`` supports group administrators and password-protected groups.
*   Know your distribution's admin group: ``sudo`` (Debian) vs. ``wheel``
    (everyone else).
*   User management operations require root privileges.
