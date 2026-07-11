Special Permissions: SUID, SGID, and the Sticky Bit
====================================================

The nine basic permission bits (``rwx`` × owner/group/others) cover most
everyday scenarios, but they have limitations.  Consider three problems:

1. How can a regular user change their own password when the password
   database (``/etc/shadow``) is writable only by root?
2. How can a team share a directory so that every file created inside it
   automatically belongs to the team's group, not the creator's primary
   group?
3. How can a world‑writable directory like ``/tmp`` be safe — allowing
   everyone to create files but preventing anyone from deleting someone
   else's files?

Linux solves these problems with three *special permission bits*: the Set
User ID (SUID), the Set Group ID (SGID), and the *sticky bit*.  They occupy
positions beyond the nine basic bits and are represented in both the
symbolic and octal permission systems.

.. contents:: :local:
   :depth: 2


Where Special Permissions Appear in ``ls -l``
-----------------------------------------------

Special permissions replace the ``x`` in the owner, group, or others
triplet with a different letter:

.. list-table::
   :header-rows: 1
   :widths: 20 20 60

   * - Bit
     - Position
     - Displayed As
   * - SUID
     - Owner
     - ``s`` (or ``S``)
   * - SGID
     - Group
     - ``s`` (or ``S``)
   * - Sticky
     - Others
     - ``t`` (or ``T``)

A **lowercase** ``s`` or ``t`` means the underlying execute bit *is* set
(``rws`` = ``rwx`` + SUID).  An **uppercase** ``S`` or ``T`` means the
underlying execute bit is *not* set — a configuration that is usually a
mistake, because a SUID file without execute permission serves no purpose
(the kernel needs the execute bit to run it).

Examples:

.. code-block:: text

   -rwsr-xr-x  1 root root  /usr/bin/passwd     # SUID (owner x + s)
   -rwxr-sr-x  1 root staff /usr/bin/write       # SGID (group x + s)
   drwxrwxrwt  1 root root  /tmp                 # Sticky (others x + t)
   -rw-rw-r-T  1 alice alice broken              # Sticky without x (suspicious)


The Set User ID (SUID) Bit
--------------------------

When the SUID bit is set on an **executable file**, the process runs with
the effective UID of the file's *owner*, not the user who launched it.  This
temporary privilege elevation is essential for a handful of system programs
that need to access protected resources on behalf of ordinary users.

The canonical example is ``/usr/bin/passwd``:

.. code-block:: bash

   $ ls -l /usr/bin/passwd
   -rwsr-xr-x 1 root root 59976 Feb  6  2025 /usr/bin/passwd

The ``passwd`` command must modify ``/etc/shadow``, which is writable only
by root.  But any user must be able to change their own password.  The
solution: ``passwd`` is owned by root with the SUID bit set.  When you run
``passwd``, the process temporarily gains root privileges, makes the
necessary changes to ``/etc/shadow`` (after verifying your identity), and
then the privilege is discarded.

Other common SUID binaries include:

* ``/usr/bin/su`` — must switch to any user ID.
* ``/usr/bin/sudo`` — must run commands as any user.
* ``/usr/bin/ping`` — needs raw socket access (though modern systems
  increasingly use Linux *capabilities* instead of SUID for ``ping``).
* ``/usr/bin/newgrp`` — must change the current group ID.

**How to set SUID:**

Symbolically:

.. code-block:: bash

   chmod u+s /path/to/program

With octal, SUID is a fourth octal digit prepended to the normal three:

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Digit
     - Meaning
   * - 4
     - SUID
   * - 2
     - SGID
   * - 1
     - Sticky bit

Thus ``chmod 4755 program`` sets SUID (4) with ``rwxr-xr-x`` (755).  The
octal digits for special permissions are cumulative: ``6755`` would be SUID
+ SGID (4+2=6) with ``rwxr-xr-x``.

**Security implications:**

SUID is dangerous when applied carelessly.  A SUID root binary that has a
bug — a buffer overflow, a command injection vulnerability, or an unsafe
``system()`` call — may be exploited to execute arbitrary code as root.
For this reason:

.. warning::

   * **Never write SUID root shell scripts on Linux.**  Most modern Linux
     kernels ignore the SUID bit on scripts (interpreted files) for security
     reasons — a script's interpreter (``/bin/bash``, ``/usr/bin/python``)
     would run with elevated privileges, but race conditions in the way the
     kernel opens scripts make this inherently unsafe.  Use a compiled
     wrapper or ``sudo`` instead.
   * Prefer *capabilities* over SUID where possible.  For example, modern
     ``ping`` uses ``CAP_NET_RAW`` rather than full SUID root.
   * Regularly audit SUID binaries on your system:

     .. code-block:: bash

        find / -perm -4000 -ls 2>/dev/null


The Set Group ID (SGID) Bit
----------------------------

SGID has two distinct behaviours depending on whether it is applied to a
**file** or a **directory**.

SGID on Executable Files
~~~~~~~~~~~~~~~~~~~~~~~~

Analogous to SUID, an executable file with SGID runs with the effective GID
of the file's owning group.  This is less common than SUID.  An example is
``/usr/bin/write`` (on systems where it is still SGID ``tty``), which needs
to write to other users' terminals.

.. code-block:: bash

   $ ls -l /usr/bin/write
   -rwxr-sr-x 1 root tty  /usr/bin/write

Set SGID on a file:

.. code-block:: bash

   chmod g+s program
   chmod 2755 program

SGID on Directories: The Shared‑Workspace Pattern
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

This is the **far more important** use of SGID.  When SGID is set on a
**directory**, every new file or subdirectory created inside it
automatically inherits the directory's *group ownership*, not the primary
group of the user who created the file.  This is exactly what collaborative
teams need.

Consider a shared project directory:

.. code-block:: bash

   mkdir /shared/project
   chown root:developers /shared/project
   chmod 2770 /shared/project          # SGID + rwx for owner and group

Now:

.. code-block:: bash

   # As alice (primary group "alice", supplementary group "developers"):
   touch /shared/project/alices_file.txt
   ls -l /shared/project/alices_file.txt
   # -rw-rw---- 1 alice developers 0 Jul 11 10:00 alices_file.txt
   #                     ^^^^^^^^^^ inherited from the directory, not alice's
   #                                primary group "alice"

Without SGID, that file would have been owned by group ``alice`` (the
creator's primary group), and other team members might not have had access
to it at all.  SGID on shared directories is one of the most useful and
under‑used features in everyday Linux system administration.

.. tip::

   A common pattern for shared team directories combines SGID with a
   permissive umask for the group:

   .. code-block:: bash

      mkdir /shared/project
      chown root:developers /shared/project
      chmod 2775 /shared/project
      # Members of "developers" should also set `umask 002` in their
      # shell profile so new files are group-writable by default.


The Sticky Bit
---------------

The sticky bit's original purpose — on very old Unix systems, it kept a
program's text segment "stuck" in swap space to speed up subsequent
launches — is obsolete on Linux.  Its modern meaning is entirely different
and applies almost exclusively to **directories**.

When the sticky bit is set on a directory, a user may delete or rename a
file inside that directory **only if** they are the file's owner (or the
directory's owner, or root) — even if the directory itself is
world‑writable.  Without the sticky bit, *any* user with write permission on
the directory could delete *any* file inside it, regardless of who owns that
file.

The canonical example is ``/tmp``:

.. code-block:: bash

   $ ls -ld /tmp
   drwxrwxrwt 12 root root 4096 Jul 11 10:00 /tmp

Notice the ``t`` at the very end.  ``/tmp`` must be writable by every user
on the system (so any program can create temporary files there), but without
the sticky bit, one user could delete another user's temporary files — a
recipe for chaos or malicious interference.  The sticky bit makes ``/tmp``
safe: everyone can create files, but only the owner of a file (or root) can
remove it.

**How to set the sticky bit:**

Symbolically:

.. code-block:: bash

   chmod +t /shared/dropbox

With octal, the sticky bit is digit ``1`` in the fourth (leading) position:

.. code-block:: bash

   chmod 1777 /shared/dropbox

This produces ``drwxrwxrwt`` — world‑writable, but delete‑protected per
file.

.. note::

   The sticky bit is occasionally combined with SGID on shared collaboration
   directories: SGID ensures new files inherit the team's group, and the
   sticky bit ensures team members cannot delete each other's files.  The
   combined octal mode would be ``3775`` (2 + 1 = 3 for SGID + sticky, with
   ``775`` for the base permissions).


Summary Table
--------------

.. list-table::
   :header-rows: 1

   * - Bit
     - Octal Value
     - Symbolic Flag
     - Effect on Files
     - Effect on Directories
   * - SUID
     - 4
     - ``u+s``
     - Runs as the file's owner
     - No effect (ignored on most Linux systems)
   * - SGID
     - 2
     - ``g+s``
     - Runs as the file's group
     - New files/dirs inherit the directory's group
   * - Sticky
     - 1
     - ``+t``
     - No effect on modern Linux
     - Only the file owner (or root) can delete/rename files inside


Auditing Special Permissions
------------------------------

Because SUID and SGID binaries are powerful attack surfaces, security‑minded
administrators periodically audit their systems for unexpected special
permissions:

.. code-block:: bash

   # Find all SUID files
   find / -perm -4000 -type f 2>/dev/null

   # Find all SGID files
   find / -perm -2000 -type f 2>/dev/null

   # Find all world-writable directories without the sticky bit
   # (a red flag — any user can delete any other user's files)
   find / -type d -perm -0002 ! -perm -1000 2>/dev/null

Comparing the output of these commands against a known‑good baseline (taken
right after installation, before the system is exposed to untrusted users or
the network) is a standard technique for detecting tampering or
misconfiguration.


Practical Exercises
-------------------

#. Run ``ls -l /usr/bin/passwd``.  Confirm the SUID bit is set.  What
   happens if you (temporarily, as root, in a disposable test environment)
   remove it with ``chmod u-s /usr/bin/passwd``?  Can a regular user still
   change their password?  (Restore the bit afterward with ``chmod u+s``.)

#. Create a shared directory, set its group to one you belong to, and apply
   SGID.  Create a file inside it and confirm the file's group ownership
   matches the directory, not your primary group.

#. Examine ``/tmp`` with ``ls -ld /tmp``.  Identify the sticky bit in the
   output.  Create a file there as your user, then (if you have access to a
   second account) attempt to delete it as that other user.  What happens?

#. Compute the octal mode for a directory that needs SGID, sticky bit, and
   ``rwxrwx---`` base permissions.  Apply it with ``chmod`` and verify with
   ``ls -ld``.

#. Run the SUID and SGID audit commands from this section on a Linux system
   you control.  How many results do you get?  Are any of them unfamiliar to
   you?  Investigate one with ``ls -l`` and consider whether it is
   necessary.
