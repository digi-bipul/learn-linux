.. _basic-navigation:

Basic Navigation and File Operations
=====================================

You know what the filesystem *is*.  Now you will learn to move through
it, inspect it, and manipulate it.  The commands in this section are the
"survival vocabulary" of Linux — you will use them hundreds of times a
day for the rest of your career.

.. contents::
   :local:
   :depth: 1


A Note on Conventions
-----------------------

Throughout this section, I use the following notation in examples:

* ``$`` — a command run as a normal user.
* ``#`` — a command run as root (via ``sudo`` or a root shell).
* Lines that do **not** start with ``$`` or ``#`` are output.

All examples are run from a Debian 12 system unless otherwise noted.
Where Alpine or Fedora differ, the differences are called out.


``pwd`` — Where Am I?
----------------------

**Print Working Directory.**  The simplest command in Linux.  It prints
the absolute path of your current location in the filesystem tree:

.. code-block:: bash

   $ pwd
   /home/alice

``pwd`` takes no meaningful options.  Its sole purpose is to answer the
question "where am I?" — an answer that is not always obvious when your
prompt is truncated or when you are deep inside a long path.

There are two variants, and the difference matters:

.. code-block:: bash

   $ pwd            # prints the logical working directory (shell built-in)
   /home/alice

   $ /bin/pwd       # prints the physical working directory (external binary)
   /home/alice

The distinction arises when you have navigated through a symbolic link.
The shell's built-in ``pwd`` remembers the logical path (through the
symlink); the external ``/bin/pwd`` resolves all symlinks and shows the
actual physical path.  We will revisit this when we discuss symbolic
links in a later chapter.


``ls`` — List Directory Contents
----------------------------------

**List.**  One of the two most-used commands in Linux (the other being
``cd``).  Without arguments, ``ls`` lists the contents of the current
directory:

.. code-block:: bash

   $ ls
   Documents  Downloads  Music  Pictures  notes.txt

With a path, it lists that directory:

.. code-block:: bash

   $ ls /etc
   adduser.conf  apt  cron.d  default  fstab  hosts  passwd  ...

.. rubric:: The ``-l`` Flag: Long Format

``-l`` (lowercase L) is the single most important flag.  It invokes the
**long listing** format, which reveals seven pieces of metadata for
every file:

.. code-block:: bash

   $ ls -l
   total 16
   drwxr-xr-x 2 alice alice 4096 Jul  9 14:30 Documents
   drwxr-xr-x 2 alice alice 4096 Jul  8 09:15 Downloads
   -rw-r--r-- 1 alice alice  214 Jul 10 11:42 notes.txt

Let us dissect a single line — ``notes.txt``:

.. code-block:: text

   -rw-r--r--  1  alice  alice  214  Jul 10 11:42  notes.txt
   └──┬───┘    │   └─┬─┘  └─┬─┘   │   └────┬────┘  └───┬───┘
    type +    link  owner  group  size   last modified   name
    permissions  count                        date

.. rubric:: Field 1: Type and Permissions (``-rw-r--r--``)

The first character is the **file type**:

.. list-table::
   :header-rows: 1

   * - Character
     - Meaning
   * - ``-``
     - Regular file
   * - ``d``
     - Directory
   * - ``l``
     - Symbolic link
   * - ``b``
     - Block device (e.g., a disk)
   * - ``c``
     - Character device (e.g., a terminal, ``/dev/null``)
   * - ``p``
     - Named pipe (FIFO)
   * - ``s``
     - Socket

The remaining nine characters are three triples representing **read
(r)**, **write (w)**, and **execute (x)** permissions for three
audiences:

* Characters 2–4: **User** (owner) permissions — ``rw-`` means read and
  write, but not execute.
* Characters 5–7: **Group** permissions — ``r--`` means read-only.
* Characters 8–10: **Other** (world) permissions — ``r--`` means
  read-only.

A dash (``-``) means "not granted."  We will explore permissions in
exhaustive detail in Chapter 5; for now, learn to recognise the
pattern.

.. rubric:: Field 2: Link Count (``1``)

The number of hard links pointing to this inode.  For a regular file,
this is usually ``1``.  For a directory, it is at least ``2`` (the
directory's own name plus ``.`` inside it).

.. rubric:: Fields 3 & 4: Owner and Group (``alice alice``)

Who owns the file, and which group it belongs to.

.. rubric:: Field 5: Size in Bytes (``214``)

The file's size.  For directories, this is the size of the directory
metadata itself, *not* the sum of its contents.

.. rubric:: Fields 6–8: Last Modification Time (``Jul 10 11:42``)

When the file's *content* was last changed (``mtime``).  There are also
``atime`` (access time) and ``ctime`` (metadata change time), which we
explore later.

.. rubric:: Field 9: Name (``notes.txt``)

The filename.  On Linux, filenames are case-sensitive: ``Notes.txt`` and
``notes.txt`` are different files.  Almost any character is allowed
except the null byte and the forward slash.

.. rubric:: Other Essential ``ls`` Flags

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Flag
     - Meaning and Why You Need It
   * - ``-a`` (``--all``)
     - Show **all** files, including hidden ones (names starting with
       ``.``).  Without ``-a``, ``ls`` hides dotfiles.
   * - ``-h`` (``--human-readable``)
     - Show sizes in human-readable format: ``2.1M`` instead of
       ``2145728``.  Only works in combination with ``-l``.
   * - ``-t``
     - Sort by modification time, newest first.  Invaluable for finding
       recently changed files.
   * - ``-r`` (``--reverse``)
     - Reverse the sort order.  Combine with ``-t`` to see the *oldest*
       files first: ``ls -ltr``.
   * - ``-S``
     - Sort by file size, largest first.
   * - ``-R`` (``--recursive``)
     - Recursively list subdirectories.  Be careful in large trees.
   * - ``-d``
     - List the directory *itself*, not its contents.  ``ls -ld /etc``
       shows permissions on ``/etc``, not the files inside it.
   * - ``-i`` (``--inode``)
     - Show the inode number of each file.  Useful for finding hard
       links.
   * - ``-1``
     - One entry per line.  Useful for piping into other commands:
       ``ls -1 | wc -l`` counts files.
   * - ``--color=auto``
     - Colourise output: directories in blue, executables in green,
       symlinks in cyan.  Usually enabled by default via an alias.

.. code-block:: bash
   :caption: Common ``ls`` combinations

   $ ls -la         # all files, long format
   $ ls -lh         # long format, human-readable sizes
   $ ls -ltr        # long format, sorted by time, reversed (oldest last)
   $ ls -lS         # long format, sorted by size
   $ ls -d .*/      # list only hidden directories in the current directory


``cd`` — Change Directory
--------------------------

**Change Directory.**  The command that moves you around the tree.

.. rubric:: Absolute vs. Relative Paths

An **absolute path** starts with ``/`` and specifies the full route
from the root:

.. code-block:: bash

   $ cd /usr/share/doc
   $ pwd
   /usr/share/doc

A **relative path** does *not* start with ``/`` and is interpreted
relative to your current directory:

.. code-block:: bash

   $ pwd
   /home/alice
   $ cd Documents
   $ pwd
   /home/alice/Documents

.. rubric:: Special Directory Shorthands

.. list-table::
   :header-rows: 1

   * - Symbol
     - Meaning
     - Example
   * - ``.``
     - The current directory
     - ``cd .`` (does nothing; sometimes used in scripts)
   * - ``..``
     - The parent directory
     - ``cd ..`` moves one level up
   * - ``~``
     - Your home directory
     - ``cd ~`` or just ``cd`` (with no arguments)
   * - ``~user``
     - The home directory of *user*
     - ``cd ~bob``
   * - ``-``
     - The previous working directory
     - ``cd -`` toggles between two directories

.. code-block:: bash
   :caption: Navigation in action

   $ pwd
   /home/alice/Documents/projects/linux-book

   $ cd ../..
   $ pwd
   /home/alice/Documents

   $ cd -
   /home/alice/Documents/projects/linux-book

   $ cd
   $ pwd
   /home/alice

.. tip::

   ``cd -`` is one of the most useful shortcuts you will ever learn.
   It lets you toggle between two directories with a single command.
   If you are working deeply in ``/etc`` and need to check something
   in ``/var/log``, you can bounce back and forth with ``cd -``.

.. rubric:: Tab Completion

You rarely type full paths.  Instead, type the first few characters and
press :kbd:`Tab`:

.. code-block:: text

   $ cd /usr/sh[TAB]
   $ cd /usr/share/

If multiple completions are possible, press :kbd:`Tab` twice to see all
options:

.. code-block:: text

   $ cd /usr/s[TAB][TAB]
   sbin/  share/  src/


Creating and Removing Directories
-----------------------------------

.. rubric:: ``mkdir`` — Make Directory

.. code-block:: bash

   $ mkdir new_directory
   $ ls -ld new_directory
   drwxr-xr-x 2 alice alice 4096 Jul 10 12:00 new_directory

Key flags:

.. list-table::
   :header-rows: 1

   * - Flag
     - Meaning
   * - ``-p`` (``--parents``)
     - Create parent directories as needed.  No error if the directory
       already exists.
   * - ``-v`` (``--verbose``)
     - Print a message for each created directory.
   * - ``-m MODE`` (``--mode=MODE``)
     - Set permissions (e.g., ``-m 755``) instead of the default.

.. code-block:: bash
   :caption: Creating nested directories in one command

   $ mkdir -p project/src/module/tests

   $ ls -R project/
   project/:
   src/

   project/src:
   module/

   project/src/module:
   tests/

   project/src/module/tests:

.. rubric:: ``rmdir`` — Remove Directory

Removes **empty** directories only:

.. code-block:: bash

   $ rmdir empty_dir        # succeeds
   $ rmdir non_empty_dir    # fails: "Directory not empty"

If you need to remove a directory and all its contents, use ``rm -r``
(see below).  ``rmdir`` is intentionally limited — it is a safety
feature, preventing you from accidentally deleting a directory full of
data.


``touch`` — Create Empty Files and Update Timestamps
------------------------------------------------------

Despite its name, ``touch`` does not "open" or "edit" files.  Its
primary purpose is to update a file's access and modification timestamps.
If the file does not exist, ``touch`` creates an empty file as a
convenient side effect:

.. code-block:: bash

   $ touch newfile.txt
   $ ls -l newfile.txt
   -rw-r--r-- 1 alice alice 0 Jul 10 12:05 newfile.txt

Useful flags:

.. list-table::
   :header-rows: 1

   * - Flag
     - Meaning
   * - ``-a``
     - Change only the access time (``atime``).
   * - ``-m``
     - Change only the modification time (``mtime``).
   * - ``-t STAMP``
     - Set a specific timestamp (format: ``[[CC]YY]MMDDhhmm[.ss]``).
   * - ``-r FILE``
     - Use the timestamp of another file as a reference.


``cp`` — Copy Files and Directories
-------------------------------------

**Copy.**  Syntax: ``cp [OPTIONS] SOURCE DESTINATION``.

.. code-block:: bash

   $ cp notes.txt notes_backup.txt
   $ ls
   notes.txt  notes_backup.txt

If the destination is an existing directory, the source file is copied
*into* it, keeping its original name:

.. code-block:: bash

   $ cp notes.txt Documents/
   $ ls Documents/
   notes.txt

Key flags:

.. list-table::
   :header-rows: 1

   * - Flag
     - Meaning
   * - ``-r`` (``--recursive``)
     - Copy directories recursively.  **Required** to copy a directory.
   * - ``-i`` (``--interactive``)
     - Prompt before overwriting an existing file.
   * - ``-n`` (``--no-clobber``)
     - Never overwrite an existing file (silently skip it).
   * - ``-u`` (``--update``)
     - Copy only when the source is newer than the destination, or when
       the destination is missing.
   * - ``-v`` (``--verbose``)
     - Print the name of each file as it is copied.
   * - ``-p`` (``--preserve``)
     - Preserve ownership, permissions, and timestamps of the original
       file.  Equivalent to ``--preserve=mode,ownership,timestamps``.
   * - ``-a`` (``--archive``)
     - **Archive mode**.  Equivalent to ``-dR --preserve=all``.  This is
       the flag you want for backups: recursive, preserves everything
       (permissions, ownership, timestamps, symlinks), and does not
       follow symlinks.

.. code-block:: bash
   :caption: Common ``cp`` patterns

   $ cp file1 file2 file3 dest_dir/      # copy multiple files into a directory
   $ cp -r project/ project_backup/      # recursive copy of a directory tree
   $ cp -a /etc /backup/etc-$(date +%F)  # archive-mode backup with date stamp

.. warning::

   Without ``-i`` or ``-n``, ``cp`` silently overwrites the destination.
   There is no "undo."  Many distributions alias ``cp`` to ``cp -i`` in
   the default shell configuration (``~/.bashrc``).  Check with
   ``alias cp``.  On Alpine, this alias is usually absent.


``mv`` — Move and Rename Files
--------------------------------

**Move.**  Syntax: ``mv [OPTIONS] SOURCE DESTINATION``.

Despite having two conceptual jobs (moving and renaming), ``mv`` is a
single command because, on a Unix filesystem, moving a file to a
different name in the same directory *is* renaming, and moving it to a
different directory *is* relocating.  Both are the same underlying
operation: changing the directory entry (the "link") that points to the
file's data.

.. code-block:: bash
   :caption: Renaming (same directory)

   $ mv old_name.txt new_name.txt

.. code-block:: bash
   :caption: Moving (different directory)

   $ mv document.txt ~/Documents/

``mv`` can also move *and* rename simultaneously:

.. code-block:: bash

   $ mv draft.txt ~/Documents/final_version.txt

.. code-block:: bash
   :caption: Moving multiple files into a directory

   $ mv file1.txt file2.txt file3.txt target_dir/

Key flags:

.. list-table::
   :header-rows: 1

   * - Flag
     - Meaning
   * - ``-i`` (``--interactive``)
     - Prompt before overwriting.
   * - ``-n`` (``--no-clobber``)
     - Never overwrite.
   * - ``-u`` (``--update``)
     - Move only when the source is newer.
   * - ``-v`` (``--verbose``)
     - Print each move as it happens.

.. tip::

   ``mv`` is *extremely fast* when source and destination are on the
   same filesystem — it only updates directory entries, not the actual
   data blocks.  When moving across filesystems, ``mv`` falls back to a
   copy-then-delete operation, which is much slower.


``rm`` — Remove Files and Directories
---------------------------------------

**Remove.**  Syntax: ``rm [OPTIONS] FILE...``

.. code-block:: bash

   $ rm old_file.txt
   $ ls old_file.txt
   ls: cannot access 'old_file.txt': No such file or directory

Key flags:

.. list-table::
   :header-rows: 1

   * - Flag
     - Meaning
   * - ``-r`` (``--recursive``)
     - Remove directories and their contents recursively.  Required to
       delete a directory.
   * - ``-f`` (``--force``)
     - Ignore nonexistent files and never prompt.  Overrides ``-i``.
   * - ``-i`` (``--interactive``)
     - Prompt before every removal.
   * - ``-v`` (``--verbose``)
     - Print each file as it is removed.

.. warning::

   **The Danger of** ``rm -rf``

   The combination ``rm -rf`` is famously dangerous.  It will
   recursively, silently delete everything you point it at — no
   confirmation, no recycle bin, no undo.

   .. code-block:: text

      # NEVER RUN THIS:
      $ sudo rm -rf /          # destroys the entire system
      $ sudo rm -rf / home/    # destroys the system AND the home directory

   The space between ``/`` and ``home`` in the second example is the
   difference between a working system and a catastrophe.  Always pause
   before pressing :kbd:`Enter` on an ``rm -rf`` command.  Many
   administrators have a personal rule: never type ``rm -rf`` with
   ``sudo`` unless they have physically stood up from the desk and sat
   back down again.

   Some modern systems ship with ``--preserve-root`` enabled by default
   (``rm -rf /`` is rejected), but do not rely on this.  Alpine's
   BusyBox ``rm`` may not have the same safeguards.

.. rubric:: Safer alternatives to ``rm``

.. code-block:: bash

   # Use 'rm -i' for interactive confirmation:
   $ rm -i *.txt

   # Move to a trash directory instead of deleting:
   $ mkdir -p ~/.trash
   $ mv unwanted_file ~/.trash/
   # Clean up the trash periodically.

   # Install 'trash-cli' (desktop trash from the command line):
   # Debian/Ubuntu:   sudo apt install trash-cli
   # Fedora/RHEL:      sudo dnf install trash-cli
   # Alpine:           sudo apk add trash-cli
   $ trash unwanted_file


Viewing File Contents
-----------------------

.. rubric:: ``cat`` — Concatenate and Print

**Concatenate.**  Reads one or more files and writes their contents to
standard output (the terminal):

.. code-block:: bash

   $ cat notes.txt
   This is the content of notes.txt.
   It can span multiple lines.

``cat`` can also concatenate multiple files:

.. code-block:: bash

   $ cat file1.txt file2.txt > combined.txt

Or create a small file directly from the terminal:

.. code-block:: bash

   $ cat > newfile.txt
   Type some text here.
   Press Ctrl+D when done.

Useful flags:

.. list-table::
   :header-rows: 1

   * - Flag
     - Meaning
   * - ``-n`` (``--number``)
     - Number all output lines.
   * - ``-b`` (``--number-nonblank``)
     - Number non-empty lines only.
   * - ``-s`` (``--squeeze-blank``)
     - Suppress repeated empty output lines.
   * - ``-A`` (``--show-all``)
     - Show all non-printing characters (tabs as ``^I``, line ends as
       ``$``).  Equivalent to ``-vET``.

.. note::

   ``cat`` is fine for short files, but it dumps the entire file to the
   screen at once.  For anything longer than a screenful, use ``less``.

.. rubric:: ``less`` — The Pager

**Less** is a *pager* — it displays content one screen at a time and
lets you scroll forward and backward:

.. code-block:: bash

   $ less /var/log/syslog

Navigation inside ``less`` is identical to navigation in ``man`` pages
(they share the same pager):

.. list-table::
   :header-rows: 1

   * - Key
     - Action
   * - :kbd:`Space` / :kbd:`f` / :kbd:`Page Down`
     - Scroll forward one screen
   * - :kbd:`b` / :kbd:`Page Up`
     - Scroll backward one screen
   * - :kbd:`↓` / :kbd:`j` / :kbd:`Enter`
     - Scroll forward one line
   * - :kbd:`↑` / :kbd:`k`
     - Scroll backward one line
   * - :kbd:`g`
     - Jump to the **beginning** of the file
   * - :kbd:`G`
     - Jump to the **end** of the file
   * - :kbd:`/pattern`
     - Search **forward** for *pattern*
   * - :kbd:`?pattern`
     - Search **backward** for *pattern*
   * - :kbd:`n`
     - Jump to the next search match
   * - :kbd:`N`
     - Jump to the previous search match
   * - :kbd:`q`
     - Quit

``less`` has a superpower that surprises newcomers: it can read from
standard input, not just from files.  This means you can pipe the output
of *any* command into ``less`` for scrollable viewing:

.. code-block:: bash

   $ dmesg | less                    # scroll through kernel ring buffer
   $ ls -la /usr/bin | less          # scroll through a huge directory listing
   $ find / -name "*.conf" | less    # scroll through search results

.. tip::

   The name "less" is a playful successor to an older pager called
   **more**.  ``more`` could only scroll forward; ``less`` can scroll
   both directions.  Hence the pun: "less is more, but more than more."

.. rubric:: ``head`` and ``tail`` — Preview the Edges

**Head** prints the first 10 lines of a file; **tail** prints the last
10:

.. code-block:: bash

   $ head /etc/passwd
   root:x:0:0:root:/root:/bin/bash
   daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
   bin:x:2:2:bin:/bin:/usr/sbin/nologin
   ... (7 more lines)

   $ tail /etc/passwd
   ... (last 10 lines of the file)

The number of lines is adjustable with ``-n``:

.. code-block:: bash

   $ head -n 3 /etc/passwd        # first 3 lines
   $ tail -n 20 /var/log/syslog   # last 20 lines
   $ head -n -5 report.txt        # all lines EXCEPT the last 5 (GNU extension)

``tail`` has one flag that makes it indispensable for system
administration:

.. describe:: ``-f`` (``--follow``)

   **Follow** the file as it grows.  ``tail -f`` does not exit after
   printing the last 10 lines; instead, it stays open and prints new
   lines as they are appended.  This is how administrators watch log
   files in real time:

   .. code-block:: bash

      $ tail -f /var/log/syslog
      Jul 10 12:11:43 thinkpad systemd[1]: Starting Cleanup of Temporary...
      Jul 10 12:11:44 thinkpad systemd[1]: Finished Cleanup of Temporary...
      Jul 10 12:11:45 thinkpad sshd[2219]: Accepted publickey for alice...
      (press Ctrl+C to stop following)

   On a busy server, watching ``tail -f /var/log/nginx/access.log``
   shows you every HTTP request in real time.  It is hypnotic and
   enormously useful.

.. note::

   **Distro differences**

   On **Alpine** (BusyBox), ``head`` and ``tail`` support fewer options.
   The ``-n N`` and ``-f`` flags work as expected, but ``-n -N``
   (negative line counts, e.g., "all lines except the last N") is a GNU
   extension and is **not** available.  If you need GNU ``head`` /
   ``tail`` on Alpine, install the ``coreutils`` package:

   .. code-block:: bash

      # Alpine: replace BusyBox head/tail with GNU versions
      $ sudo apk add coreutils


``file`` — Determine File Type
--------------------------------

Linux does not rely on filename extensions to determine file type (unlike
Windows, which treats ``.exe``, ``.docx``, or ``.jpg`` as authoritative).
Instead, ``file`` inspects the *content* of the file — typically the
first few bytes, known as the **magic number** — to identify its true
type:

.. code-block:: bash

   $ file notes.txt
   notes.txt: ASCII text

   $ file /bin/ls
   /bin/ls: ELF 64-bit LSB pie executable, x86-64, version 1 (SYSV),
   dynamically linked, interpreter /lib64/ld-linux-x86-64.so.2, for
   GNU/Linux 3.2.0, stripped

   $ file picture.png
   picture.png: PNG image data, 1920 x 1080, 8-bit/color RGBA, non-interlaced

   $ file /dev/null
   /dev/null: character special (1/3)

   $ file archive.tar.gz
   archive.tar.gz: gzip compressed data, from Unix, original size modulo 2^32 10240

``file`` reads a database of magic patterns (typically
``/usr/share/misc/magic`` or ``/usr/share/file/misc/magic.mgc``) to
identify thousands of formats.  It is invaluable when a file has a
misleading or missing extension, or when you are investigating an unknown
binary.

.. rubric:: Why ``file`` exists: design philosophy

``file`` embodies the Unix principle of **content over convention**.
A file named ``payload.pdf`` might actually be a shell script; a
file named ``data`` might be a JPEG.  The filesystem trusts the data
inside, not the label outside.  ``file`` gives you a reliable way to
peek at that data.


Wildcards (Globbing) — Pattern Matching on the Shell
------------------------------------------------------

The shell itself — not the individual commands — performs filename
expansion using **wildcards** before the command ever runs.  This
process is called **globbing**, and it is one of the shell's most
powerful features.

The shell expands a pattern into a sorted list of matching filenames,
then passes that list as arguments to the command.  The command never
sees the wildcards; it only sees the expanded list.

.. rubric:: The Three Core Wildcards

.. list-table::
   :header-rows: 1
   :widths: 20 40 40

   * - Wildcard
     - Meaning
     - Example
   * - ``*``
     - Matches **any** sequence of characters (including none)
     - ``*.txt`` matches ``notes.txt``, ``readme.txt``, ``a.txt``
   * - ``?``
     - Matches **exactly one** character
     - ``file?.txt`` matches ``file1.txt``, ``fileA.txt`` but not
       ``file10.txt``
   * - ``[chars]``
     - Matches **any one** character in the set
     - ``file[0-9].txt`` matches ``file1.txt`` through ``file9.txt``

.. code-block:: bash
   :caption: Wildcards in action

   $ ls *.txt
   notes.txt  todo.txt  readme.txt

   $ ls file?.txt
   file1.txt  fileA.txt

   $ ls file[0-9].txt
   file1.txt  file2.txt  file3.txt

   $ ls report_202[3-6]*.pdf
   report_2023Q1.pdf  report_2024_annual.pdf  report_2025_draft.pdf

.. rubric:: Negation and Character Classes

.. describe:: ``[!chars]`` or ``[^chars]``

   Matches any one character **not** in the set:

   .. code-block:: bash

      $ ls file[!0-9].txt
      fileA.txt  fileB.txt  file_test.txt

.. describe:: Named character classes

   Inside brackets, you can use POSIX character classes:

   .. code-block:: bash

      $ ls *[[:digit:]]*      # filenames containing at least one digit
      $ ls *[[:upper:]]*      # filenames containing at least one uppercase letter

.. rubric:: Brace Expansion (not technically globbing, but related)

Brace expansion generates arbitrary strings — it is *not* filename
matching; it generates strings whether or not matching files exist:

.. code-block:: bash

   $ echo file_{a,b,c}.txt
   file_a.txt file_b.txt file_c.txt

   $ echo {1..5}
   1 2 3 4 5

   $ echo {01..10}
   01 02 03 04 05 06 07 08 09 10

   $ mkdir -p project/{src,doc,test}/{core,utils}
   # Creates: project/src/core, project/src/utils, project/doc/core, ...

.. note::

   **Distro differences**

   Brace expansion is a **Bash** feature.  It works identically on
   Debian, Ubuntu, Fedora, Arch, and openSUSE (all of which use Bash
   as the default interactive shell).  On Alpine, the default shell is
   **Ash** (BusyBox), which supports basic globbing (``*``, ``?``,
   ``[ ]``) but may have limited brace expansion support.  Install
   ``bash`` on Alpine if you need full brace expansion:

   .. code-block:: bash

      # Alpine
      $ sudo apk add bash
      $ bash


Putting It All Together: A Practical Exercise
-----------------------------------------------

Let us consolidate everything we have learned in a realistic workflow.
Open a terminal and follow along:

.. code-block:: bash

   # 1. Where am I?
   $ pwd
   /home/alice

   # 2. Create a project directory structure
   $ mkdir -p ~/projects/linux-practice/{data,scripts,output}
   $ cd ~/projects/linux-practice
   $ pwd
   /home/alice/projects/linux-practice

   # 3. Populate some files
   $ echo "server=192.168.1.100" > data/config.ini
   $ echo "port=8080" >> data/config.ini
   $ echo "debug=true" >> data/config.ini
   $ touch data/log_2026-07-10.txt data/log_2026-07-09.txt data/log_2026-07-08.txt

   # 4. Inspect what we created
   $ ls -lR
   .:
   total 12
   drwxr-xr-x 2 alice alice 4096 Jul 10 12:15 data
   drwxr-xr-x 2 alice alice 4096 Jul 10 12:15 output
   drwxr-xr-x 2 alice alice 4096 Jul 10 12:15 scripts

   ./data:
   total 16
   -rw-r--r-- 1 alice alice  44 Jul 10 12:15 config.ini
   -rw-r--r-- 1 alice alice   0 Jul 10 12:15 log_2026-07-08.txt
   -rw-r--r-- 1 alice alice   0 Jul 10 12:15 log_2026-07-09.txt
   -rw-r--r-- 1 alice alice   0 Jul 10 12:15 log_2026-07-10.txt

   # 5. Examine file contents
   $ cat data/config.ini
   server=192.168.1.100
   port=8080
   debug=true

   $ file data/config.ini
   data/config.ini: ASCII text

   # 6. Copy and rename
   $ cp data/config.ini data/config_backup.ini
   $ mv data/log_2026-07-08.txt data/log_2026-07-08_archived.txt

   # 7. Use wildcards
   $ ls data/log_*.txt
   data/log_2026-07-09.txt  data/log_2026-07-10.txt

   # 8. Navigate back home
   $ cd
   $ pwd
   /home/alice

   # 9. Return to the project
   $ cd -
   /home/alice/projects/linux-practice

   # 10. Clean up (carefully!)
   $ cd ~
   $ rm -r ~/projects/linux-practice


Chapter Summary
---------------

You now possess the "survival vocabulary" of the Linux command line.
Let us review the essential commands:

.. list-table::
   :header-rows: 1
   :widths: 25 25 50

   * - Command
     - Mnemonic
     - Purpose
   * - ``pwd``
     - **P**\ rint **W**\ orking **D**\ irectory
     - Show current location
   * - ``ls``
     - **L**\ i\ **s**\ t
     - List directory contents
   * - ``cd``
     - **C**\ hange **D**\ irectory
     - Move to another directory
   * - ``mkdir``
     - **M**\ a\ **k**\ e **Dir**\ ectory
     - Create a new directory
   * - ``rmdir``
     - **R**\ e\ **m**\ ove **Dir**\ ectory
     - Delete an empty directory
   * - ``touch``
     - (updates timestamps)
     - Create empty file / update timestamps
   * - ``cp``
     - **C**\ o\ **p**\ y
     - Copy files and directories
   * - ``mv``
     - **M**\ o\ **v**\ e
     - Move / rename files and directories
   * - ``rm``
     - **R**\ e\ **m**\ ove
     - Delete files and directories
   * - ``cat``
     - Con\ **cat**\ enate
     - Print file contents to screen
   * - ``less``
     - (a better ``more``)
     - View file contents page by page
   * - ``head``
     - (the beginning)
     - Print first lines of a file
   * - ``tail``
     - (the end)
     - Print last lines of a file; ``-f`` to follow
   * - ``file``
     - (file type)
     - Determine the true type of a file

Beyond the commands themselves, you have internalised several deeper
principles that will serve you throughout this book:

* The filesystem is a **single tree rooted at ``/``**, governed by the
  Filesystem Hierarchy Standard.
* The shell **expands wildcards** before the command runs — the command
  never sees the ``*``.
* **Absolute paths** start at ``/``; **relative paths** start from
  where you stand.
* ``~`` means home; ``..`` means parent; ``-`` means "where I just was."
* ``rm -rf`` demands **respect**, not fear — pause before you press Enter.
* When in doubt, use ``man``, ``--help``, or ``file`` before acting.

.. admonition:: What Comes Next

   In Chapter 2, we will build on this foundation by exploring the
   Linux user and group model, file permissions in depth, and the
   superuser (``root``).  You will learn how Linux enforces security
   at the filesystem level — and how to bend those rules when you need
   to.

   For now, spend time in the terminal.  Create directories.  Move
   files.  Break things in a disposable virtual machine.  The commands
   in this chapter must become **muscle memory** before we proceed.

   See you in Chapter 2.
