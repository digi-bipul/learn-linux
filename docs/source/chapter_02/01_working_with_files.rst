Working with Files and Directories
==================================

The filesystem hierarchy you explored in Chapter 1 is not a static museum —
it is a living structure that you constantly reshape.  Whether you are
organising a project, writing a script, or cleaning up old logs, the five
commands introduced in this section — ``mkdir``, ``touch``, ``cp``, ``mv``,
and ``rm`` — are the verbs of filesystem life.

.. contents:: :local:
   :depth: 2


Creating Directories with ``mkdir``
-----------------------------------

The ``mkdir`` (make directory) command creates one or more new directories.
Its simplest form is:

.. code-block:: bash

   mkdir project

This creates a single directory named ``project`` inside the current working
directory.  You may also create several directories at once:

.. code-block:: bash

   mkdir docs src tests

By default, ``mkdir`` requires every component of the path *except the last*
to already exist.  Attempting to create ``a/b/c`` when ``a`` does not exist
produces an error:

.. code-block:: bash

   $ mkdir a/b/c
   mkdir: cannot create directory 'a/b/c': No such file or directory

The ``-p`` (*parents*) flag tells ``mkdir`` to create any missing intermediate
directories silently:

.. code-block:: bash

   mkdir -p a/b/c

After this single command, ``a``, ``a/b``, and ``a/b/c`` all exist.  The
``-p`` flag is idempotent: if the directory already exists, ``mkdir -p``
does nothing and does not complain.  This makes it invaluable in shell scripts
where you want to ensure a directory tree exists without checking each level
manually.

Two other useful options:

``-v`` (*verbose*)
   Prints a message for each directory created.  Helpful when you are building
   a deep tree and want confirmation.

``-m *mode*`` (*mode*)
   Sets the permissions of the new directory at creation time, overriding the
   default ``umask``.  The argument is an octal permission mask (see
   :doc:`04_file_permissions`).  For example, ``mkdir -m 700 private`` creates
   a directory accessible only to its owner.

.. tip::

   The ``-p`` flag is one of the most frequently used options in system
   administration scripts.  Always reach for ``mkdir -p`` unless you
   specifically need the error when a parent is missing.


Creating Empty Files and Updating Timestamps with ``touch``
-----------------------------------------------------------

Despite its name, ``touch`` does far more than create empty files.  Its
primary purpose is to update the *access time* (atime) and *modification time*
(mtime) of a file.  If the file does not exist, ``touch`` creates it as an
empty file — a convenient side effect that has become its most popular use.

Create one or more empty files:

.. code-block:: bash

   touch file1.txt file2.txt

Update the timestamp of an existing file to the current time without changing
its content:

.. code-block:: bash

   touch existing_file

Key options:

``-a``
   Change only the access time (atime), leaving the modification time alone.
   On many modern systems the access time is not updated on every read
   (the ``noatime`` mount option is common), so this flag is less used today
   than it once was.

``-m``
   Change only the modification time (mtime), leaving the access time alone.

``-t *stamp*``
   Set the timestamp to an arbitrary value instead of the current time.  The
   format is ``[[CC]YY]MMDDhhmm[.ss]``.  For example, to set a file's
   timestamp to 15:30 on 1 January 2025:

   .. code-block:: bash

      touch -t 202501011530 report.txt

``-r *reference*``
   Use the timestamp of *reference* instead of the current time.  Handy for
   making two files appear to have been modified at the same moment:

   .. code-block:: bash

      touch -r original.txt copy.txt

.. note::

   Why is the command called ``touch``?  It comes from the early Unix
   philosophy of small, composable tools: the command's original job was
   to "touch" a file (update its timestamp) as a side effect.  Creating a
   new file was just a convenient consequence.  The name stuck.


Copying Files and Directories with ``cp``
------------------------------------------

The ``cp`` (copy) command duplicates files and directories.  Its basic syntax
is:

.. code-block:: bash

   cp source destination

If *destination* is an existing directory, the source file is placed inside it
with the same name.  If *destination* is a path that does not refer to an
existing directory, the source is copied to that exact path (potentially
renaming it).

Examples:

.. code-block:: bash

   cp notes.txt backup.txt          # Copy to a new file name
   cp notes.txt backup/             # Copy into an existing directory
   cp a.txt b.txt backup/           # Copy multiple files into a directory

The real power of ``cp`` lies in its options.  Understanding the difference
between ``-r`` and ``-a`` is essential for any Linux user.

``-r``, ``-R``, ``--recursive``
   Copy directories recursively.  Without this flag, ``cp`` refuses to copy
   a directory:

   .. code-block:: bash

      $ cp mydir/ backup/
      cp: -r not specified; omitting directory 'mydir/'

   With ``-r``, the entire subtree is duplicated.

``-a``, ``--archive``
   Archive mode.  This is ``-dR --preserve=all`` rolled into one flag and is
   almost always what you want when copying directory trees.  It preserves:

   * Symbolic links *as* links (``-d`` / ``--no-dereference``).
   * File permissions, ownership, and timestamps.
   * Extended attributes and SELinux contexts (where applicable).

   Contrast ``cp -r`` (which may dereference symlinks and does not guarantee
   preservation of metadata) with ``cp -a`` (which creates a faithful
   snapshot).  For backups and system migrations, **always prefer** ``cp -a``.

``-i``, ``--interactive``
   Prompt before overwriting an existing destination file.

``-n``, ``--no-clobber``
   Never overwrite an existing file.  Silently skip.

``-u``, ``--update``
   Copy only when the source file is newer than the destination file *or*
   when the destination is missing.  Useful for incremental backups:

   .. code-block:: bash

      cp -ru source/ backup/

``-v``, ``--verbose``
   Print the name of each file as it is copied.

``-p`` (no argument), ``--preserve=mode,ownership,timestamps``
   Preserve mode, ownership, and timestamps (but not other extended
   attributes).  This is a subset of what ``-a`` does.

``-l``, ``--link``
   Instead of copying file contents, create hard links.  Both the original
   and the "copy" point to the same inode and data blocks.  This is extremely
   fast and saves disk space.

``-s``, ``--symbolic-link``
   Instead of copying, create symbolic links pointing to the source files.

.. warning::

   On some older or non‑GNU systems (e.g., BusyBox‑based distributions like
   Alpine Linux), ``cp -a`` may not be available or may behave slightly
   differently.  If portability is a concern, use ``cp -pR`` as a fallback
   — it preserves permissions and timestamps but does not handle symlinks
   specially.


Moving and Renaming with ``mv``
-------------------------------

The ``mv`` (move) command serves double duty: it renames files and
directories, and it moves them between locations.  In fact, "rename" and
"move" are the same operation at the filesystem level — both modify the
*directory entry* that points to the file's inode.

.. code-block:: bash

   mv oldname newname               # Rename within same directory
   mv file.txt /path/to/dest/       # Move to another directory

When source and destination are on the **same filesystem**, ``mv`` simply
renames the directory entry — the file's data never moves.  This is a nearly
instantaneous operation regardless of file size.  When source and destination
are on **different filesystems**, ``mv`` must copy the file's data to the new
filesystem and then delete the original.  This can be slow for large files.

Important options:

``-i``, ``--interactive``
   Prompt before overwriting an existing file.

``-n``, ``--no-clobber``
   Never overwrite.  Skip silently.

``-v``, ``--verbose``
   Report each file as it is moved.

``-b``, ``--backup``
   Make a backup copy of any file that would be overwritten.  The backup file
   has a tilde (``~``) appended to its name.

.. tip::

   To rename a file safely in a script, use ``mv -n``.  It prevents
   accidental data loss if the target name already exists, without
   requiring user interaction (unlike ``mv -i``).


Removing Files and Directories with ``rm``
------------------------------------------

The ``rm`` (remove) command deletes files.  It does *not* move files to a
"trash" or "recycle bin" — once removed, a file is gone (barring forensic
tools).  Treat ``rm`` with healthy respect.

.. code-block:: bash

   rm file.txt                       # Remove a single file
   rm file1.txt file2.txt            # Remove multiple files

Key options:

``-r``, ``-R``, ``--recursive``
   Remove directories and their contents recursively.  Without ``-r``, ``rm``
   refuses to delete a directory (use ``rmdir`` for empty ones — see below).

``-f``, ``--force``
   Ignore nonexistent files, never prompt.  This flag overrides interactive
   mode and silences errors about missing files.  **Use with caution.**

``-i``, ``--interactive``
   Prompt before every removal.  On many distributions, ``rm`` is aliased to
   ``rm -i`` by default for the root user, and sometimes for regular users as
   well.  Check with ``alias rm``.

``-v``, ``--verbose``
   Report each file as it is removed.

``-d``, ``--dir``
   Remove empty directories (equivalent to ``rmdir``).

.. warning::

   The combination ``rm -rf`` is infamous.  It silently and recursively
   deletes everything you point it at, ignoring all warnings.  A single typo
   — such as a space in ``rm -rf / tmp/`` instead of ``rm -rf /tmp/`` — can
   destroy an entire system.  Modern GNU ``rm`` protects against the
   catastrophic ``rm -rf /`` with the ``--preserve-root`` option (enabled
   by default), but ``rm -rf /*`` is still dangerous.

   **Best practice:** Take a breath before running ``rm -rf``.  Consider
   using a safer alias in your shell:

   .. code-block:: bash

      alias rm='rm -I'

   The ``-I`` (capital i) prompts once before removing more than three files
   or when removing recursively — a sensible middle ground.

What actually happens when you delete a file?  ``rm`` calls the ``unlink()``
system call, which removes the directory entry (the hard link) that points to
the file's inode.  If that was the last hard link *and* no process has the
file open, the kernel frees the inode and the associated data blocks.  If a
process still has the file open, the data remains on disk (accessible to that
process) until the file descriptor is closed — a useful property that explains
why you can delete a large log file and still have the writing process
continue without interruption.  The disk space is freed only after the last
file descriptor is closed.


Removing Empty Directories with ``rmdir``
-----------------------------------------

The ``rmdir`` command removes **empty** directories.  It is safer than
``rm -r`` because it refuses to delete a directory that still contains files:

.. code-block:: bash

   rmdir emptydir

``rmdir`` can also remove a whole chain of empty directories with ``-p``:

.. code-block:: bash

   rmdir -p a/b/c

This removes ``a/b/c``, then ``a/b`` (if now empty), then ``a`` (if now
empty).  In practice, ``rmdir`` is less common than ``rm -r``, but it
remains useful in scripts where you want an explicit safety check against
deleting non‑empty directories.


Quick Reference
---------------

.. list-table::
   :header-rows: 1

   * - Command
     - Purpose
     - Most Used Flags
   * - ``mkdir``
     - Create directories
     - ``-p`` (parents), ``-v`` (verbose)
   * - ``touch``
     - Create empty files / update timestamps
     - ``-t`` (set time), ``-r`` (reference)
   * - ``cp``
     - Copy files and directories
     - ``-a`` (archive), ``-r`` (recursive), ``-u`` (update), ``-v``
   * - ``mv``
     - Move / rename files
     - ``-i`` (interactive), ``-n`` (no clobber), ``-v``
   * - ``rm``
     - Remove files and directories
     - ``-r`` (recursive), ``-f`` (force), ``-i`` (interactive)
   * - ``rmdir``
     - Remove empty directories
     - ``-p`` (parents)


Practical Exercises
-------------------

#. Create the following directory tree in your home directory using the fewest
   commands possible:

   ::

      ~/workshop/
      ├── src/
      │   └── lib/
      └── data/

#. Create three empty files inside ``workshop/src/`` named ``a.c``, ``b.c``,
   and ``c.c`` with a single ``touch`` command.

#. Copy the entire ``workshop/`` tree to ``workshop_backup/`` using archive
   mode.  Confirm with ``ls -lR`` that permissions and timestamps are
   preserved.

#. Rename ``workshop/data/`` to ``workshop/datadir/``.

#. Attempt to delete ``workshop/datadir/`` with ``rmdir``.  Why does it
   succeed?  Now attempt to delete ``workshop/src/`` with ``rmdir``.  Why
   does it fail?

#. Remove the entire ``workshop/`` and ``workshop_backup/`` trees with a
   single ``rm`` command.  (Think carefully about the flags you need.)
