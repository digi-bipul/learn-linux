.. _section-3-5:

ACLs (Access Control Lists)
==================================================

.. rst-class:: lead

   The traditional Unix permission model—one owner, one group, one set of
   "other" bits—is elegantly simple, but insufficient for modern
   fine-grained access control. What if you need three different groups to
   have different permissions on the same file? What if a specific individual
   needs access without joining an existing group? **Access Control Lists
   (ACLs)** solve these problems by extending the permission model to
   support multiple named users and groups.

Why ACLs?
================

Consider a practical scenario: a file ``/shared/project/budget.ods`` owned by
``alice:finance`` with permissions ``640`` (``rw-r-----``). Alice needs:

*   **Bob** (in ``finance``) — read-only access (already granted by group).
*   **Carol** (in ``finance``) — read-write access.
*   **Dave** (in ``audit``) — read-only access, but he should **not** get
    any permissions via group membership.
*   **Eve** (a specific user, not in any relevant group) — no access.

With traditional Unix permissions, you would need to create new groups,
carefully manage membership, or resort to workarounds (symlinks, copies,
setgid helpers). ACLs solve this elegantly by allowing you to attach
permissions for arbitrary users and groups to any file.

Enabling ACL Support
============================

ACLs require support at two levels:

1. **Kernel**: The filesystem must be mounted with the ``acl`` option. On
   modern Linux (kernel 2.6+), ACL support is compiled into the default
   ``ext4``, ``xfs``, and ``btrfs`` drivers. However, on some older
   configurations, you may need to remount:

   .. code-block:: bash

      # mount -o remount,acl /home

   To make it permanent, add ``acl`` to the mount options in
   ``/etc/fstab``.

2. **Userspace**: You need the ACL utilities:
   - Debian/Ubuntu: ``apt install acl``
   - RHEL/Fedora: ``dnf install acl``
   - Arch: included in ``acl`` package (base system, usually installed)
   - Alpine: ``apk add acl``

   Check if the tools are available:

   .. code-block:: bash

      $ which setfacl getfacl
      /usr/bin/setfacl
      /usr/bin/getfacl

Viewing ACLs with ``getfacl``
=====================================

The ``getfacl(1)`` command displays the ACL entries for a file or directory:

.. code-block:: bash

   $ getfacl budget.ods
   # file: budget.ods
   # owner: alice
   # group: finance
   user::rw-
   user:bob:r--
   user:carol:rw-
   group::r--
   group:audit:r--
   mask::rw-
   other::---

Let us parse this output:

.. list-table:: ACL Entry Components
   :header-rows: 1
   :widths: 25 75

   * - Entry
     - Meaning
   * - ``user::rw-``
     - Permissions for the file owner (``alice``). Equivalent to the owner triad.
   * - ``user:bob:r--``
     - Named user ``bob`` gets read-only access.
   * - ``user:carol:rw-``
     - Named user ``carol`` gets read-write.
   * - ``group::r--``
     - Permissions for the owning group (``finance``). Equivalent to the group triad.
   * - ``group:audit:r--``
     - Named group ``audit`` gets read-only.
   * - ``mask::rw-``
     - The maximum permissions allowed for any named user, named group, or the owning group. **Crucial concept** — explained below.
   * - ``other::---``
     - Permissions for everyone else.

The ``ls -l`` View with ACLs
------------------------------------

When a file has ACL entries beyond the traditional three triads, ``ls -l``
appends a **plus sign (``+``)** to the permission string:

.. code-block:: bash

   $ ls -l budget.ods
   -rw-rw----+ 1 alice finance 4096 Jul 15 12:00 budget.ods
   ───┬───┘
      └─── The "+" indicates ACL entries exist

This is your visual cue: "this file has additional permissions that ``ls -l``
alone cannot show." Always inspect with ``getfacl`` when you see the ``+``.

Setting ACLs with ``setfacl``
=====================================

The ``setfacl(1)`` command modifies ACLs. Its syntax is:

.. code-block:: text

   setfacl [options] {m|x} [entries] FILE...

Modifying ACL Entries (``-m``)
--------------------------------------

.. code-block:: bash
   :caption: ``setfacl`` — modifying entries

   # Grant read access to user bob
   setfacl -m u:bob:r budget.ods

   # Grant read-write access to user carol
   setfacl -m u:carol:rw budget.ods

   # Grant read access to the audit group
   setfacl -m g:audit:r budget.ods

   # Set the mask (effective maximum for named users/groups)
   setfacl -m m::rx shared_script.sh

   # Remove all permissions for a named user
   setfacl -m u:bob:--- budget.ods     # Sets bob's perms to none

   # Grant execute permission to a specific user
   setfacl -m u:deploy:rx /usr/local/bin/deploy.sh

Removing ACL Entries (``-x``)
-------------------------------------

.. code-block:: bash

   # Remove a specific named user entry
   setfacl -x u:bob budget.ods

   # Remove a specific named group entry
   setfacl -x g:audit budget.ods

   # Remove the mask entry (kernel recalculates it)
   setfacl -x m:: budget.ods

Recursive ACLs
----------------------

.. code-block:: bash

   # Apply ACL recursively (files and directories)
   setfacl -R -m g:developers:rw /shared/project

   # Apply ACL to directories only (skipping regular files)
   find /shared/project -type d -exec setfacl -m g:developers:rx {} +

.. caution::

   Using ``setfacl -R`` on large directory trees can be slow. For
   production use, consider setting **default ACLs** on the parent
   directory instead (see section 3.5.6) so that new files automatically
   inherit the correct permissions without recursive operations.

Copying ACLs Between Files
----------------------------------

.. code-block:: bash

   # Copy ACLs from one file to another
   getfacl source_file | setfacl --set-file=- target_file

   # Backup all ACLs in a directory tree
   getfacl -R /shared/project > /root/acl-backup.txt

   # Restore ACLs from backup
   setfacl --restore=/root/acl-backup.txt

The ACL Mask: Understanding Effective Permissions
=========================================================

The **mask** is the most frequently misunderstood concept in the ACL system.
It acts as an **upper bound** on the permissions granted by:

* Named user entries (``user:name:perm``)
* Named group entries (``group:name:perm``)
* The owning group entry (``group::perm``)

It does **not** affect:

* The file owner entry (``user::perm``)
* The "other" entry (``other::perm``)

**How the mask is calculated:**

When you set an ACL entry, the kernel automatically **recalculates the
mask** as the **logical OR** of all permissions affected by the mask. If
you then explicitly set the mask to a more restrictive value, some named
entries will have **effective permissions** that are lower than their
requested permissions.

.. code-block:: bash

   $ getfacl budget.ods
   # file: budget.ods
   # owner: alice
   # group: finance
   user::rw-
   user:bob:rw-          # effective: r--
   user:carol:rwx        # effective: r--
   group::r--
   mask::r--
   other::---

Here, ``mask::r--`` limits the effective permissions of ``bob`` and
``carol`` to read-only, even though their ACL entries request more. To see
effective permissions:

.. code-block:: bash

   $ getfacl -e budget.ods
   # ...same output but with effective annotations...
   user:bob:rw-          # effective: r--
   user:carol:rwx        # effective: r--

**The mask vs. chmod interaction:**

When you run ``chmod`` on a file that has ACLs, the kernel **updates the
ACL mask** to reflect the new group permissions, rather than modifying the
owning group entry directly. This can lead to surprising behaviour:

.. code-block:: bash

   $ getfacl project.txt | grep -E '^(user:|group:|mask)'
   user::rw-
   user:bob:rw-
   group::r--
   mask::rw-

   $ chmod g-w project.txt   # Remove group write

   $ getfacl project.txt | grep -E '^(user:|group:|mask)'
   user::rw-
   user:bob:rw-              # effective: r--  (mask restricts it!)
   group::r--
   mask::r--                 # Mask was lowered by chmod

Bob now has **effective** read-only even though his ACL entry still says
``rw-``. This is why ``chmod`` and ACLs can produce confusing results.
The rule of thumb: **on files with ACLs, prefer ``setfacl`` over ``chmod``**
for modifying group permissions.

Default ACLs
====================

Default ACLs are a mechanism for **permission inheritance**. When you set a
default ACL on a **directory**, any file or subdirectory created inside it
automatically receives those ACL entries.

**Setting default ACLs:**

.. code-block:: bash

   # Set a default ACL for a directory
   setfacl -m d:u:bob:rwx /shared/project
   setfacl -m d:g:developers:rwx /shared/project

   # The 'd:' prefix indicates "default"

   # View default ACLs
   $ getfacl /shared/project
   # file: /shared/project
   # owner: alice
   # group: finance
   user::rwx
   user:bob:rwx
   group::r-x
   mask::rwx
   other::---
   default:user::rwx
   default:user:bob:rwx
   default:group::r-x
   default:mask::rwx
   default:other::---

**Verifying inheritance:**

.. code-block:: bash

   # Bob creates a file inside the directory
   $ su bob -c 'touch /shared/project/bob_file.txt'
   $ getfacl /shared/project/bob_file.txt
   # file: bob_file.txt
   # owner: bob
   # group: finance
   user::rw-
   user:bob:rwx                # effective: rw-
   group::r-x                  # effective: r--
   mask::rw-
   other::---

Notice: the default ACLs were inherited, and the mask was recalculated to
match the maximum permissions needed.

**Default ACLs and umask interaction:**

When a file is created in a directory with default ACLs, the **umask is
ignored** for any permission covered by the default ACL (on modern Linux
systems). The default ACL takes precedence. This is in contrast to
traditional directories where umask determines the initial permissions.

ACLs and Traditional Permissions — Coexistence
======================================================

The traditional permission bits and ACLs are not separate systems; the
owner, group, and other triads are simply special cases of ACL entries:

.. code-block:: text

   Traditional     →   ACL representation
   ─────────────────────────────────────
   Owner (u)       →   user::perm
   Group (g)       →   group::perm
   Other (o)       →   other::perm
   (none)          →   mask::perm

When you use ``chmod`` on an ACL-enabled file, you are modifying the
``user::``, ``group::``, and ``other::`` entries (and the mask). When you
use ``setfacl`` on these entries, you are effectively running ``chmod``.

Practical ACL Workflows
===============================

**Workflow 1: Shared project directory with multiple groups**

.. code-block:: bash

   # mkdir -p /srv/git/repos/project
   # chown root:developers /srv/git/repos/project
   # chmod 750 /srv/git/repos/project

   # Give the 'qa' group read-only access
   # setfacl -m g:qa:rx /srv/git/repos/project

   # Give the 'interns' group no access at all
   # setfacl -m g:interns:--- /srv/git/repos/project

   # Set default ACLs for inheritance
   # setfacl -m d:g:developers:rwx,d:g:qa:rx,d:g:interns:--- \
             /srv/git/repos/project

   # Verify
   # getfacl /srv/git/repos/project

**Workflow 2: Giving a single user access to a log file**

.. code-block:: bash

   # The syslog file is owned by root:adm, mode 640
   # The auditor 'jane' needs read access, but shouldn't join adm group
   # setfacl -m u:jane:r /var/log/syslog

   # Make it permanent across log rotation (requires logrotate config)
   # echo "su root adm" >> /etc/logrotate.d/rsyslog

**Workflow 3: Web server document root**

.. code-block:: bash

   # /var/www/html — owned by root:www-data
   # Developer 'alice' needs rwx
   # CI/CD user 'jenkins' needs rwx
   # setfacl -m u:alice:rwx,u:jenkins:rwx /var/www/html
   # setfacl -m d:u:alice:rwx,d:u:jenkins:rwx /var/www/html

ACL Limitations and Performance Considerations
======================================================

**Limitations:**

1. **NFS versions**: Older NFSv3 implementations have limited ACL support.
   NFSv4 has a different ACL model (richer but incompatible with POSIX ACLs).
2. **Too many entries**: Performance degrades on files with hundreds of ACL
   entries. The ext4 filesystem has a practical limit of around 500 ACL
   entries per file (limited by the filesystem block size).
3. **Backup/restore complexity**: Standard backup tools (``tar``, ``cpio``)
   may or may not preserve ACLs. Use ``--acls`` with ``tar`` or ``star``.
   ``rsync -A`` preserves ACLs.
4. **Filesystem compatibility**: Not all filesystems support POSIX ACLs
   (e.g., older FAT, exFAT, some FUSE filesystems).

**Performance:**

ACLs add a small overhead to file creation and permission checking because
the kernel must walk the ACL list. On a typical desktop or server workload,
this overhead is negligible (measured in microseconds). On high-performance
computing (HPC) scratch filesystems with millions of files and frequent
metadata operations, the overhead may become measurable—but such
environments typically have dedicated parallel filesystems (Lustre, GPFS)
with their own permission models.

Summary
===============

*   ACLs extend the traditional owner/group/other model with named users
    and named groups.
*   ``getfacl`` displays ACLs; ``setfacl -m`` modifies; ``setfacl -x``
    removes entries.
*   The **mask** sets an upper bound on named user, named group, and
    owning group permissions. It does **not** affect the file owner or
    "other" entries.
*   **Default ACLs** (prefix ``d:``) on directories cause new files and
    subdirectories to inherit the specified ACL entries.
*   When ACLs are present, ``ls -l`` shows a ``+`` in the permission
    string. Use ``getfacl`` to see the full picture.
*   ``chmod`` on ACL-enabled files modifies the mask, which can produce
    surprising limitations on named entries. Prefer ``setfacl``.
*   Default ACLs override the umask for inherited permissions.
*   Use ACLs for fine-grained sharing; use groups and traditional
    permissions for the common case.
