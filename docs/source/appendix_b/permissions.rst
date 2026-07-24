.. _app-b-permissions:

------------------------------------------------------------------------------
File Permissions & ACLs
------------------------------------------------------------------------------

------------------------------------------------------------------------------
Traditional Unix Permissions
------------------------------------------------------------------------------

.. list-table:: Permission Modes
   :header-rows: 1
   :widths: 20 30 25 25

   * - Symbol
     - Meaning
     - Numeric (octal)
     - File vs. Directory effect
   * - ``r``
     - Read
     - 4
     - File: read content; Dir: list entries
   * - ``w``
     - Write
     - 2
     - File: modify content; Dir: create/delete entries
   * - ``x``
     - Execute
     - 1
     - File: run as program; Dir: traverse (enter)
   * - ``-``
     - None
     - 0
     - Permission denied

.. rubric:: Common Octal Modes

.. list-table:: Common Modes
   :header-rows: 1
   :widths: 20 30 50

   * - Mode
     - Octal
     - Usage
   * - ``-rw-------``
     - 600
     - Private files (e.g., SSH private keys)
   * - ``-rw-r-----``
     - 640
     - Group-readable files (e.g., ``/etc/shadow`` on some distros)
   * - ``-rw-r--r--``
     - 644
     - World-readable files (most static files)
   * - ``-rwx------``
     - 700
     - Private executables / directories
   * - ``-rwxr-x---``
     - 750
     - Group-executable directories (e.g., home directories wanting group access)
   * - ``-rwxr-xr-x``
     - 755
     - World-executable (binaries, scripts, shared directories)
   * - ``-rwxrwxrwx``
     - 777
     - Everyone can do everything — usually a security risk
   * - ``drwx------``
     - 700
     - Private directory (only owner can enter)
   * - ``drwxr-xr-x``
     - 755
     - World-readable/enterable directory (default for most ``/home``)

.. rubric:: Special Permissions (setuid, setgid, sticky)

.. list-table:: Special Bits
   :header-rows: 1
   :widths: 20 25 25 30

   * - Bit
     - Symbol (``ls -l``)
     - Octal prefix
     - Effect
   * - **setuid**
     - ``s`` in owner execute field
     - 4xxx (e.g., 4755)
     - Process runs with file owner's EUID (e.g., ``/usr/bin/passwd``)
   * - **setgid**
     - ``s`` in group execute field
     - 2xxx (e.g., 2755)
     - Process runs with file group's EGID; on directories, new files inherit group
   * - **sticky**
     - ``t`` in other execute field
     - 1xxx (e.g., 1755)
     - On directories: only file owner (or root) can delete/rename; classic on ``/tmp``

.. code-block:: bash
   :caption: Setting special bits

   chmod u+s /path/to/file        # setuid
   chmod g+s /path/to/dir         # setgid on directory
   chmod +t /tmp                  # sticky bit
   chmod 4755 /usr/bin/myapp      # setuid + rwxr-xr-x
   chmod 2755 /shared             # setgid + rwxr-xr-x
   chmod 1777 /tmp                # sticky + rwxrwxrwx

------------------------------------------------------------------------------
umask
------------------------------------------------------------------------------

The **umask** subtracts permissions from the base (666 for files, 777 for
directories). A umask of ``022`` yields ``644`` for files and ``755`` for
directories.

.. list-table:: Common umask Values
   :header-rows: 1
   :widths: 20 30 30

   * - umask
     - Resulting file mode
     - Resulting directory mode
   * - ``000``
     - 666 (rw-rw-rw-)
     - 777 (rwxrwxrwx) — insecure
   * - ``002``
     - 664 (rw-rw-r--)
     - 775 (rwxrwxr-x) — group-writable, good for shared projects
   * - ``007``
     - 660 (rw-rw----)
     - 770 (rwxrwx---) — group-only, no other access
   * - ``022``
     - 644 (rw-r--r--)
     - 755 (rwxr-xr-x) — default on most distros
   * - ``027``
     - 640 (rw-r-----)
     - 750 (rwxr-x---) — restrictive, no other
   * - ``077``
     - 600 (rw-------)
     - 700 (rwx------) — private only
   * - ``177``
     - 600 (rw-------)
     - 700 (rwx------) — plus sticky on dirs (unusual)

.. code-block:: bash
   :caption: Setting umask

   umask 0022                  # Leading 0 optional; same as 022
   umask -S                    # Display symbolically (u=rwx,g=rx,o=rx)
   umask -p                    # Output as command (for sourcing)

.. important::
   umask is per-process and inherited by child processes. Set it in
   ``~/.profile``, ``~/.bashrc``, or ``/etc/profile`` for persistence.

------------------------------------------------------------------------------
Access Control Lists (ACLs)
------------------------------------------------------------------------------

ACLs provide fine-grained permissions beyond the owner/group/other model.

.. rubric:: ACL Commands

.. list-table:: ACL Command Reference
   :header-rows: 1
   :widths: 25 35 40

   * - Command
     - Syntax
     - Description
   * - ``getfacl``
     - ``getfacl [options] file``
     - Display ACL entries
   * - ``setfacl -m``
     - ``setfacl -m u:alice:rwx file``
     - Modify: grant user ``alice`` rwx
   * - ``setfacl -m``
     - ``setfacl -m g:devs:rx file``
     - Modify: grant group ``devs`` rx
   * - ``setfacl -m``
     - ``setfacl -m o::- file``
     - Modify: remove all others' access
   * - ``setfacl -x``
     - ``setfacl -x u:alice file``
     - Remove specific ACL entry
   * - ``setfacl -b``
     - ``setfacl -b file``
     - Remove all ACL entries (revert to basic)
   * - ``setfacl -d``
     - ``setfacl -d -m u:bob:rx dir/``
     - Set **default** ACL (inherited by new files)
   * - ``setfacl -R``
     - ``setfacl -R -m u:alice:rx dir/``
     - Recursive modification

.. rubric:: ACL Mask

When ACLs are present, the **mask** defines the maximum permissions granted
to named users and groups (except the file owner). If the mask is more
restrictive than an ACL entry, the mask wins.

.. code-block:: bash
   :caption: Observing and adjusting the ACL mask

   getfacl myfile
   # Output includes: mask::r-x

   setfacl -m m::rw myfile     # Set mask to rw

.. rubric:: Checking ACL support

.. code-block:: bash

   # Filesystem must be mounted with "acl" option
   mount | grep acl
   # Also verify: tune2fs -l /dev/sda1 | grep "Default mount options"
