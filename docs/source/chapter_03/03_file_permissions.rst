.. _section-3-3:

================================================
3.3 File Permissions
================================================

.. rst-class:: lead

   In Chapter 1, we learned that "everything is a file" in Linux. Here we
   discover the corollary: "every file has an owner, a group, and a set of
   permissions." The traditional Unix permission model—nine bits, three
   triads, three classes—is deceptively simple, profoundly elegant, and
   absolutely essential to master.

3.3.1 The Permission Triad
============================

Every file and directory on a Linux system is tagged with three classes of
permissions, each class having three bits:

.. code-block:: text

   Owner (u)   Group (g)   Others (o)
   ──────────  ──────────  ──────────
     r w x       r w x       r w x
    (4)(2)(1)   (4)(2)(1)   (4)(2)(1)

**The three permission bits:**

.. list-table:: Permission Bit Meanings
   :widths: 10 20 70

   * - ``r``
     - Read
     - **File**: View the file's contents.
       **Directory**: List the directory's entries (i.e., ``ls`` works).
       Without ``r`` on a directory, you cannot see what files it contains.
   * - ``w``
     - Write
     - **File**: Modify the file's contents (but not delete it — that
       requires ``w`` on the *directory*).
       **Directory**: Create, rename, or delete files within the directory.
       This is a common source of confusion: deleting a file requires write
       permission on the **directory**, not on the file itself.
   * - ``x``
     - Execute
     - **File**: Run the file as a program or script.
       **Directory**: Traverse (enter) the directory. Without ``x`` on a
       directory, you cannot access any files within it, even if you know
       their names. This is often called the "search" bit on directories.

.. note::

   The **execute bit on directories** is the most frequently misunderstood
   permission. Consider:

   .. code-block:: bash

      $ mkdir mydir; chmod 644 mydir; ls -ld mydir
      drw-r--r--. 2 alice alice 4096 Jul 15 12:00 mydir
      $ ls mydir
      ls: cannot access 'mydir': Permission denied

   Even though ``mydir`` is readable (``r``), it lacks the execute (``x``)
   bit. Without ``x``, the kernel refuses to traverse (``chdir(2)`` into)
   the directory, so ``ls`` cannot read its contents. **Directory ``r``
   without ``x`` is nearly useless.**

**Displaying permissions with ``ls -l``:**

.. code-block:: bash

   $ ls -ld /home/jdoe /etc/shadow /bin/ls /tmp
   drwxr-xr-x  5 jdoe  jdoe   4096 Jul 15 12:00 /home/jdoe
   -rw-r-----  1 root shadow   1650 Jul 15 12:00 /etc/shadow
   -rwxr-xr-x  1 root root   142248 Jul 15 12:00 /bin/ls
   drwxrwxrwt 10 root root    4096 Jul 15 12:00 /tmp

Let us parse each column:

.. code-block:: text

   drwxr-xr-x
   │└┬┘└┬┘└┬┘
   │ │  │  └── Others (``o``): r-x
   │ │  └───── Group (``g``): r-x
   │ └──────── Owner (``u``): rwx
   └────────── File type: d = directory, - = regular file, l = symlink,
                           b = block device, c = character device, s = socket,
                           p = named pipe

3.3.2 Changing Permissions with ``chmod``
==========================================

The ``chmod(1)`` command changes file permissions. It supports two syntaxes:
**symbolic** (human-readable) and **octal** (numeric).

3.3.2.1 Symbolic Mode
---------------------

The symbolic syntax is: ``[ugo][+-=][rwx]``

.. code-block:: bash
   :caption: Symbolic ``chmod`` examples

   # Add execute permission for the owner
   chmod u+x script.sh

   # Remove write permission for group and others
   chmod go-w report.txt

   # Set (exactly) read and execute for group
   chmod g=rx shared_data

   # Add write permission for everyone
   chmod a+w shared_dir     # a = all (ugo combined)

   # Remove all permissions for others
   chmod o= secret.key

   # Multiple operations in one command
   chmod u+rwx,g+rx,o-rwx myfile

   # Recursive (affects files and directories — careful!)
   chmod -R g+w /home/alice/data

.. caution::

   ``chmod -R`` applies permissions to every file and directory in the tree.
   A classic mistake is ``chmod -R 777 /`` which makes the entire system
   world-writable. Never do this.

3.3.2.2 Octal (Numeric) Mode
----------------------------

Each permission bit has a numeric value:

.. list-table:: Permission Numeric Values
   :header-rows: 1
   :widths: 20 15 65

   * - Permission
     - Value
     - Meaning
   * - ``r``
     - 4
     - Read bit (2²)
   * - ``w``
     - 2
     - Write bit (2¹)
   * - ``x``
     - 1
     - Execute bit (2⁰)
   * - ``rwx``
     - 7
     - Read + write + execute (4+2+1)
   * - ``rw-``
     - 6
     - Read + write (4+2)
   * - ``r-x``
     - 5
     - Read + execute (4+1)
   * - ``r--``
     - 4
     - Read only
   * - ``-wx``
     - 3
     - Write + execute (2+1)
   * - ``--x``
     - 1
     - Execute only
   * - ``---``
     - 0
     - No permissions

A three-digit octal number encodes all three triads:

.. code-block:: text

   chmod 755 script.sh
   │    │││
   │    ││└── Others (o): 5 = r-x
   │    │└─── Group (g):  5 = r-x
   │    └──── Owner (u):  7 = rwx

Converting between symbolic and octal is a skill that becomes automatic:

.. code-block:: text

   rwx r-x r-x   =   7   5   5   =  755
   rw- r-- r--   =   6   4   4   =  644
   rw- --- ---   =   6   0   0   =  600
   rwx ------    =   7   0   0   =  700
   rwx rwx rwx   =   7   7   7   =  777   (world-writable — almost never needed)
   rwx rwx rwt   =   1   7   7   7   =  1777   (sticky bit + full perms)

**Common permission patterns in practice:**

.. list-table:: Standard Permission Patterns
   :header-rows: 1
   :widths: 15 20 65

   * - Octal
     - Symbolic
     - Typical Use Case
   * - 755
     - ``rwxr-xr-x``
     - Executable binaries, public scripts, directories (world-traversable).
   * - 644
     - ``rw-r--r--``
     - Regular files, configuration files, documents (world-readable).
   * - 600
     - ``rw-------``
     - Private files (SSH keys, authentication tokens, password managers).
   * - 700
     - ``rwx------``
     - Private directories (``~/.gnupg``, ``~/.ssh``).
   * - 640
     - ``rw-r-----``
     - Group-readable files (e.g., project configs).
   * - 750
     - ``rwxr-x---``
     - Group-collaboration directories.
   * - 555
     - ``r-xr-xr-x``
     - Shared executables that should not be modified (world-executable but not writable).
   * - 444
     - ``r--r--r--``
     - World-readable but unmodifiable reference files.

.. admonition:: The 755/644 Convention

   On any Linux system, the vast majority of files are ``644`` and the vast
   majority of directories and binaries are ``755``. This is the "default
   secure" pattern: the owner can write, everyone can read/traverse, and
   no one else can write. It is the baseline from which you deviate only
   when you have a specific reason.

3.3.3 Changing Ownership with ``chown`` and ``chgrp``
=======================================================

3.3.3.1 ``chown``
-----------------

The ``chown(1)`` command changes ownership. Only ``root`` can change a
file's **owner**; a user may change the **group** of files they own (to a
group they belong to).

.. code-block:: bash
   :caption: ``chown`` syntax

   # Change the owner
   chown alice report.txt

   # Change the owner and group
   chown alice:developers report.txt

   # Change only the group (equivalent to chgrp)
   chown :developers report.txt

   # Recursive ownership change
   chown -R alice:alice /home/alice

   # Preserve root ownership, change only group
   chown --from=root :wheel /usr/local/bin/*

   # Using a reference file's ownership
   chown --reference=template.conf config.conf

.. caution::

   Be extremely careful with recursive ``chown`` on system directories. A
   mistaken ``chown -R alice /usr`` would break the system's package
   manager and installed software. Always double-check the path.

3.3.3.2 ``chgrp``
-----------------

The ``chgrp(1)`` command changes **only** the group ownership.

.. code-block:: bash

   # Change the group
   chgrp developers project_report.odt

   # Recursive
   chgrp -R www-data /var/www/html

   # Symbolic link handling (by default, chgrp changes the target)
   chgrp -h developers symlink_to_file   # Change the link itself

3.3.4 The ``umask``: Default Permissions
==========================================

When you create a new file or directory, Linux assigns default permissions
based on a **base permission** minus the current **umask**.

This is one of the most misunderstood concepts in Linux permissions. Let us
demystify it mathematically.

**The formula:**

.. code-block:: text

   Final Permissions = Base Permissions - umask
                      (where "-" means "clear the bits set in umask")

The **base permissions** are:

*   **Files**: ``666`` (``rw-rw-rw-``) — because files are not executable
    by default. The execute bit must be explicitly added with ``chmod +x``.
*   **Directories**: ``777`` (``rwxrwxrwx``) — because the ``x`` bit on a
    directory is the "traverse" bit, and directories need to be traversable
    to be useful.

The **umask** is a three-digit octal number that *clears* permission bits.
It is not an additive mask; it is a **bit-clearing mask**.

**Computing the result — step by step:**

Given ``umask 022``:

.. code-block:: text

   Base:  666  =  rw- rw- rw-   (intended maximum)
   Umask: 022  =  --- -w- -w-   (bits to CLEAR)
            ─────────────────
   Result: 644  =  rw- r-- r--   (actual permission)

Let us derive this mathematically:

.. code-block:: text

   Octal subtraction (bitwise): 666 - 022 = 644?  No — it's bit-clearing.
   Correct method:  6 & ~0 = 6
                    6 & ~2 = 4   (because ~2 clears bit 1, i.e., write)
                    6 & ~2 = 4
                    Result: 644

In boolean terms: the umask bits that are set to ``1`` indicate "remove
this permission." So ``umask 022`` means "remove write permission for group
and others."

**Common umask values:**

.. list-table:: umask Values and Their Effects
   :header-rows: 1
   :widths: 15 25 25 35

   * - Umask
     - File Result
     - Directory Result
     - Use Case
   * - 000
     - 666 (``rw-rw-rw-``)
     - 777 (``rwxrwxrwx``)
     - No restrictions (dangerous — use only for temp dirs)
   * - 002
     - 664 (``rw-rw-r--``)
     - 775 (``rwxrwxr-x``)
     - Group collaboration (default for many shared environments)
   * - 022
     - 644 (``rw-r--r--``)
     - 755 (``rwxr-xr-x``)
     - Default for most single-user Linux systems. Group cannot write.
   * - 027
     - 640 (``rw-r-----``)
     - 750 (``rwxr-x---``)
     - Group can read but others denied.
   * - 077
     - 600 (``rw-------``)
     - 700 (``rwx------``)
     - Private files only.

**Setting umask:**

.. code-block:: bash

   # Set umask for the current shell session
   $ umask 022

   # Display current umask
   $ umask
   0022

   # Display in symbolic form
   $ umask -S
   u=rwx,g=rx,o=rx

**Where to set umask permanently:**

The umask is inherited from the parent process. To make it permanent for
all users, it can be set in:

1. ``/etc/profile`` — system-wide for login shells (Bourne-compatible).
2. ``/etc/bash.bashrc`` — system-wide for interactive shells.
3. ``/etc/login.defs`` — the ``UMASK`` setting affects ``useradd`` and
   related tools, but not the shell itself.
4. ``~/.bashrc``, ``~/.zshrc``, etc. — per-user.
5. ``~/.profile`` — per-user login shell.
6. ``/etc/pam.d/common-session`` — via ``pam_umask.so``, which can set
   umask based on user type.

.. note::

   Modern Linux systems using the **User Private Group (UPG)** scheme benefit
   from a umask of ``002`` or ``022``. With UPG (where each user has their
   own group), ``umask 002`` means files created by user ``jdoe`` are
   writable by group ``jdoe`` — but since only ``jdoe`` is in that group,
   no other user gains write access. It is a safe default that simplifies
   later group sharing.

3.3.5 Understanding User Private Groups (UPG)
===============================================

The User Private Group scheme, enabled by ``USERGROUPS_ENAB yes`` in
``/etc/login.defs``, creates a **private group** for each new user with the
same name as the user and the same GID as the UID.

**Why UPG exists:**

Before UPG, the default umask was typically ``022``, and a newly created
user's primary group was often ``users`` (GID 100). This meant every file you
created was group-owned by ``users``—and every other user in the ``users``
group had ``r--`` access by default. This was a leak.

With UPG:

.. code-block:: bash

   $ id alice
   uid=1001(alice) gid=1001(alice) groups=1001(alice),27(sudo)

   $ touch test; ls -l test
   -rw-r--r-- 1 alice alice 0 Jul 15 12:00 test

The file is owned by group ``alice``. Only ``alice`` is a member of group
``alice``. A umask of ``022`` gives group ``r--`` which is harmless. If
Alice later wants to share files with a project group, she can:

.. code-block:: bash

   $ chgrp developers project_file
   $ chmod g+w project_file

Now, members of ``developers`` can write to the file, and Alice's own files
remain private because her UPG owns them by default.

3.3.6 Special Cases: Permissions on Symbolic Links and Directories
====================================================================

**Symbolic links:**

Symbolic links (symlinks) **always** show permissions as ``lrwxrwxrwx``
(``777``). This is not a security hole — the permissions on a symlink are
never used. The kernel always follows the symlink and evaluates the
permissions of the **target** file. You cannot change a symlink's permissions
with ``chmod`` (``chmod`` will change the target).

**Directories vs files — the critical differences:**

.. list-table:: Permission Semantics: Files vs. Directories
   :header-rows: 1
   :widths: 15 40 45

   * - Bit
     - File
     - Directory
   * - ``r``
     - Read the file content.
     - List the directory's contents (``ls``, ``readdir``).
   * - ``w``
     - Modify the file content (requires no directory perm). Can truncate or append.
     - Create, delete, or rename files **within** the directory. Requires ``x`` to be set!
   * - ``x``
     - Execute as a program/script.
     - Traverse the directory. Access files by name even without ``r``. Without ``x``, you cannot access *any* file inside.

This distinction has profound security implications. Consider a shared
directory ``/shared/project`` with permissions ``drwxrwx---`` (``770``)
owned by ``root:developers``. Alice (in ``developers``) can create and
delete files within. Bob (outside ``developers``) cannot even see the
directory's contents.

But **Alice can delete Bob's file**, even if Bob owns it. Why? Because
deleting a file requires ``w`` permission on the **directory**, not on the
file itself. To prevent this, you need the **sticky bit** (section 3.4).

3.3.7 Permission Checking Algorithm
=====================================

When a process attempts to access a file, the kernel follows this decision
tree (simplified):

.. code-block:: text

   1. Is the process UID == 0 (root)?
      → YES: Access granted (with some exceptions for execute).
      → NO: Continue.

   2. Does the process UID match the file's owner UID?
      → YES: Use owner (u) permissions.
            → Does the requested operation match the owner bits?
               → YES: Access granted.
               → NO: Access denied (do NOT continue to group/other!).
      → NO: Continue.

   3. Does the process GID (or any supplementary GID) match the file's
      group GID?
      → YES: Use group (g) permissions.
            → Does the requested operation match the group bits?
               → YES: Access granted.
               → NO: Access denied (do NOT continue to other!).
      → NO: Continue.

   4. Use others (o) permissions.
      → Does the requested operation match the others bits?
         → YES: Access granted.
         → NO: Access denied.

**Key insight:** The kernel evaluates permissions in order: owner → group →
others. Once a match is found, it uses that triad only. If you are the file
owner but lack read permission (``--x``), you **cannot read it**, even if
group or others have read access.

3.3.8 Summary
==============

*   Every file has three permission triads: owner (u), group (g), others (o).
*   ``r`` = read, ``w`` = write, ``x`` = execute (traverse for directories).
*   ``chmod`` accepts symbolic (``u+rwx``) and octal (``755``) modes.
*   ``chown`` changes owner and/or group (root only for owner changes).
*   ``chgrp`` changes group (user can change to a group they belong to).
*   ``umask`` defines default permissions by *clearing* bits from the base
    (666 for files, 777 for directories).
*   UPG (User Private Groups) gives each user a private group, enabling
    safe ``umask 022`` default.
*   The kernel checks owner → group → others, stopping at the first match.
*   Directory permissions are fundamentally different from file permissions.
