File Permissions and Ownership
===============================

Every file and directory on a Linux system carries metadata that tells the
kernel *who* may access it and *how*.  This permission model — simple in
structure, powerful in combination — is the bedrock of Linux security.  In
this section we decode the cryptic ``-rwxr-xr--`` strings you see in ``ls
-l`` output and learn to set permissions deliberately.

.. contents:: :local:
   :depth: 2


The Linux Discretionary Access Control Model
----------------------------------------------

Linux uses Discretionary Access Control (DAC): the owner of a file
*chooses* (at their discretion) who else may read, write, or execute it.
The kernel enforces these choices, but it does not override them.  This is
in contrast to Mandatory Access Control (MAC) systems like SELinux or
AppArmor, which impose system‑wide policies that even the file owner cannot
bypass.  MAC is an additional layer; DAC is the foundation.

Under DAC, every file has three attributes that govern access:

1. **Owning user** (the UID).
2. **Owning group** (the GID).
3. **Permission bits** — twelve bits that encode read, write, and execute
   for three categories of users, plus three special‑purpose bits.

These bits are most commonly displayed in two notations: *symbolic*
(``rwxr-xr-x``) and *octal* (``755``).  We will cover both.


Reading the Output of ``ls -l``
-------------------------------

Let us dissect a single line of ``ls -l`` output:

.. code-block:: text

   -rwxr-xr-- 1 alice developers 4096 Jul 11 10:00 script.sh

The ten‑character string at the start encodes the file type and the nine
permission bits:

.. code-block:: text

   -   rwx   r-x   r--
   │   │││   │││   │││
   │   │││   │││   └└└── Others (everyone else)
   │   │││   └└└── Group
   │   └└└── Owner (user)
   └── File type

The **file type** character can be:

=====  ============================================
Char   Meaning
=====  ============================================
``-``  Regular file
``d``  Directory
``l``  Symbolic link
``b``  Block device (e.g., a hard disk)
``c``  Character device (e.g., a terminal)
``s``  Unix domain socket
``p``  Named pipe (FIFO)
=====  ============================================

The remaining nine characters are three triplets: **owner**, **group**, and
**others** (sometimes called "world").  Each triplet contains:

* ``r`` or ``-`` — read permission.
* ``w`` or ``-`` — write permission.
* ``x`` or ``-`` — execute permission.

From the example above:

* Owner (``alice``): ``rwx`` — read, write, and execute.
* Group (``developers``): ``r-x`` — read and execute, but *not* write.
* Others: ``r--`` — read only.

What ``r``, ``w``, and ``x`` actually *mean* depends on whether the file is a
regular file or a directory.


Understanding ``r``, ``w``, and ``x``
-------------------------------------

For Regular Files
~~~~~~~~~~~~~~~~~

===========  ================================================================
Permission   On a regular file, allows you to…
===========  ================================================================
``r``        View the file's contents (e.g., with ``cat``, ``less``, or by
             opening it in an editor).
``w``        Modify the file's contents — write new data, truncate it, or
             delete it.  Note: deleting a file is actually a write operation
             on the *directory* containing it (see below).
``x``        Execute the file as a program.  For a compiled binary, this
             means the kernel loads it into memory and runs it.  For a
             script, the kernel reads the shebang line (``#!``) and invokes
             the interpreter.  Without execute permission, you cannot run the
             file even if it contains valid code.
===========  ================================================================

For Directories
~~~~~~~~~~~~~~~

The same bits mean something subtly different for directories:

===========  ================================================================
Permission   On a directory, allows you to…
===========  ================================================================
``r``        List the directory's contents (the names of files inside it).
             Without ``r``, you cannot ``ls`` the directory, though you
             may still access files inside it if you know their names.
``w``        Create, delete, and rename files *inside* the directory,
             regardless of who owns those files.  Yes — if you have write
             permission on a directory, you can delete *any* file inside it,
             even one owned by ``root``, **provided the directory itself
             is not protected by the sticky bit** (see
             :doc:`05_special_permissions`).
``x``        Enter the directory — ``cd`` into it — and access files within
             it by path.  Without ``x`` on a directory, you cannot traverse
             it, even if you have ``r`` permission.  Conversely, with ``x``
             alone (no ``r``), you can access files by name but cannot list
             the directory.  This is sometimes called a "search‑only" or
             "blind" directory.
===========  ================================================================

.. warning::

   A common misconception: many newcomers believe removing read permission
   from a directory makes its contents private.  If a user still has execute
   permission on the directory and knows the paths of files inside, they
   can access those files.  True privacy requires removing *both* ``r``
   and ``x``, or — better — using the ownership and permission system at the
   file level.


Octal (Numeric) Notation
-------------------------

Octal notation represents each permission triplet as a single digit (0–7):

====  ======  ==================================
Octal  Binary  Permissions
====  ======  ==================================
0      000    ``---`` (no permissions)
1      001    ``--x`` (execute only)
2      010    ``-w-`` (write only)
3      011    ``-wx`` (write and execute)
4      100    ``r--`` (read only)
5      101    ``r-x`` (read and execute)
6      110    ``rw-`` (read and write)
7      111    ``rwx`` (read, write, and execute)
====  ======  ==================================

The mnemonic: **r**\ ead = 4, **w**\ rite = 2, e\ **x**\ ecute = 1.  Add the
numbers for the permissions you want.

Three digits specify owner, group, and others in that order.  For example:

* ``755`` = owner: ``rwx`` (7), group: ``r-x`` (5), others: ``r-x`` (5).
* ``644`` = owner: ``rw-`` (6), group: ``r--`` (4), others: ``r--`` (4).
* ``600`` = owner: ``rw-`` (6), group: ``---`` (0), others: ``---`` (0).
* ``700`` = owner: ``rwx`` (7), group: ``---`` (0), others: ``---`` (0).

Common conventions:

========  =========================================
Mode      Typical use
========  =========================================
``755``   Executable programs and directories
``644``   Regular files (not executable)
``600``   Sensitive data files (SSH private keys)
``700``   Private directories and personal scripts
``777``   World‑writable (almost always a bad idea)
========  =========================================


Symbolic Notation
-----------------

Symbolic notation uses letters and operators to modify permissions relative
to their current state.  It is more expressive than octal for incremental
changes — adding or removing a single permission without recalculating the
whole mask.

The syntax is:

.. code-block:: text

   [ugoa...][+-=][rwxXst...]

**Who** (the scope):

=====  ============================================
Letter  Affects
=====  ============================================
``u``  Owner (user)
``g``  Group
``o``  Others
``a``  All three (equivalent to ``ugo``)
=====  ============================================

**Operator:**

=====  ============================================
Symbol  Meaning
=====  ============================================
``+``  Add the specified permissions
``-``  Remove the specified permissions
``=``  Set exactly the specified permissions (clear others)
=====  ============================================

**What** (the permissions):

=====  ============================================
Letter  Permission
=====  ============================================
``r``  Read
``w``  Write
``x``  Execute
``X``  Execute only if the file is a directory *or*
       already has at least one execute bit set
``s``  SUID or SGID (see :doc:`05_special_permissions`)
``t``  Sticky bit
=====  ============================================

Examples of symbolic notation:

=====================  ======================================================
Command                Effect
=====================  ======================================================
``chmod u+x file``     Add execute permission for the owner.
``chmod go-w file``    Remove write permission from group and others.
``chmod a+r file``     Grant everyone read permission.
``chmod a=rx file``    Set *exactly* read and execute for everyone (clears
                       write if it was set).
``chmod u=rwx,g=rx,o= file``  Owner gets rwx, group gets rx, others get
                       nothing.  The ``o=`` with no rhs clears all "other"
                       permissions.
``chmod +x file``      Add execute for *all* categories (``a`` is the
                       default when no scope letter is given).  However,
                       the exact behaviour is influenced by ``umask`` —
                       see below.
=====================  ======================================================

The ``X`` permission deserves special mention.  It grants execute permission
only where it is "sensible" — on directories (which need ``x`` to be
traversed) and on files that already have execute permission for some user.
This is useful for recursive operations:

.. code-block:: bash

   chmod -R a+rX project/

This makes all files readable and adds execute permission on directories
(so you can ``cd`` into them) without accidentally making data files
executable.


Changing Permissions with ``chmod``
------------------------------------

The ``chmod`` (change mode) command accepts both octal and symbolic
notation.  Which you use is a matter of context and taste.

.. code-block:: bash

   # Octal: set permissions to exactly 755
   chmod 755 script.sh

   # Symbolic: add execute for owner
   chmod u+x script.sh

Key options:

``-R``, ``--recursive``
   Apply the change to all files and directories under the given path.
   Use with care — it is easy to make an entire tree executable or
   unreadable with a single command.

   .. code-block:: bash

      chmod -R g+rX shared_docs/

``-v``, ``--verbose``
   Print a message for every file processed.

``-c``, ``--changes``
   Like ``-v``, but only reports files whose permissions actually changed.

``--reference=*rfile*``
   Copy the permission bits from *rfile* instead of specifying them
   manually:

   .. code-block:: bash

      chmod --reference=template.sh new_script.sh


Changing Ownership with ``chown`` and ``chgrp``
------------------------------------------------

Ownership answers the question: *who* does the permission system apply to?

``chown`` (change owner) changes both the owning user and, optionally, the
owning group:

.. code-block:: bash

   chown alice file.txt                # Change owner to alice
   chown alice:developers file.txt     # Change owner and group
   chown :developers file.txt          # Change only the group (like chgrp)

``chgrp`` changes only the group:

.. code-block:: bash

   chgrp developers file.txt

Both commands accept ``-R`` for recursive operation and ``-v`` / ``-c`` for
verbosity.

.. note::

   On most systems, only ``root`` can change the owner of a file.  A regular
   user cannot "give away" a file to another user — this prevents users from
   circumventing disk quota limits or planting incriminating files in
   someone else's name.  A regular user *can* change the group of a file they
   own, but only to a group of which they themselves are a member.

To see which groups you belong to:

.. code-block:: bash

   groups


Default Permissions and ``umask``
----------------------------------

When you create a file or directory, where do its initial permissions come
from?  The answer is the *umask* — a bitmask that the kernel applies to
strip away permissions that should *not* be granted by default.

The **umask** is a three‑digit octal value (or four‑digit, when special
permissions are involved) that specifies which permission bits to *remove*
from a default starting point:

* For **files**, the starting point is ``666`` (``rw-rw-rw-``).  Files are
  not created executable by default, for obvious security reasons.
* For **directories**, the starting point is ``777`` (``rwxrwxrwx``).
  Directories need the execute bit to be traversed.

The effective permission is:  **base permission & ~umask**  (where ``~`` is
bitwise NOT).

For example, with ``umask 022``:

* Files are created as ``666 & ~022`` = ``666 & 755`` = ``644`` (``rw-r--r--``).
* Directories are created as ``777 & ~022`` = ``777 & 755`` = ``755`` (``rwxr-xr-x``).

With ``umask 002`` (common in group‑collaboration environments):

* Files: ``666 & ~002`` = ``664`` (``rw-rw-r--``).
* Directories: ``777 & ~002`` = ``775`` (``rwxrwxr-x``).

With ``umask 077`` (paranoid / private):

* Files: ``666 & ~077`` = ``600`` (``rw-------``).
* Directories: ``777 & ~077`` = ``700`` (``rwx------``).

Check your current umask:

.. code-block:: bash

   umask            # Prints the mask (e.g., 0022)
   umask -S         # Prints in symbolic form (e.g., u=rwx,g=rx,o=rx)

Set a new umask for the current shell session:

.. code-block:: bash

   umask 027        # Owner: rwx, Group: rx, Others: nothing

To make a umask permanent, add the ``umask`` command to your shell's
initialisation file (``~/.profile``, ``~/.bashrc``, etc.).

.. tip::

   The default umask on most desktop distributions is ``022``.  On many
   server distributions it is ``002`` (so that members of a shared group
   can edit each other's files by default).  Check your distribution's
   ``/etc/login.defs`` or ``/etc/profile`` for the system‑wide default.


Practical Exercises
-------------------

#. Create a file with ``touch secret.txt`` and examine its permissions with
   ``ls -l``.  What are they?  Why is there no execute bit?

#. Change the permissions of ``secret.txt`` so that only the owner can read
   and write it, and no one else has any access.  Use both octal and symbolic
   notation and confirm the result is the same.

#. Create a directory called ``shared/``.  Set its permissions so that the
   owner and group have full access and others can enter and list but not
   create files.  What octal mode is this?

#. Create a file inside ``shared/`` as the owner.  Then, if you have access
   to a second user account on the system (or a friend's machine), verify
   that the group can read but not delete the file.  (You may simulate this
   with ``sudo -u username``.)

#. Check your current umask with ``umask`` and ``umask -S``.  Create a new
   file and directory and observe their permissions.  Do they match the
   formula?

#. Set your umask to ``077``, create a file, verify its permissions, then
   restore the original umask.  Why might ``077`` be a good umask for a
   single‑user workstation?
