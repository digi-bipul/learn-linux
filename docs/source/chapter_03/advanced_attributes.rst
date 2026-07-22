.. _section-3-6:

3.6 Advanced File Attributes
==================================================

.. rst-class:: lead

   Beyond permissions and ACLs, the Linux kernel provides two additional
   layers of file metadata: **filesystem attributes** (managed by
   ``chattr``/``lsattr``) and **extended attributes** (``xattr``). These
   mechanisms give administrators control over file behaviour at the
   VFS (Virtual Filesystem) layer — controlling properties such as
   immutability, append-only mode, and arbitrary key-value metadata.

3.6.1 Filesystem Attributes: ``chattr`` and ``lsattr``
========================================================

The ``chattr(1)`` (change attribute) and ``lsattr(1)`` (list attribute)
commands modify and display **filesystem attribute flags**. Unlike
permissions (which are enforced by the security subsystem), these attributes
are enforced at the **VFS layer** within the kernel. They operate on the
inode directly, meaning they survive file moves and renames (within the same
filesystem).

.. note::

   ``chattr`` is not a POSIX standard. It originated in the **ext2**
   filesystem and has since been adopted by ext3, ext4, btrfs, and (partially)
   XFS. It is not available on ZFS (which has its own ``zfs`` property
   system) or on FUSE filesystems like ``sshfs``.

3.6.1.1 Viewing Attributes with ``lsattr``
------------------------------------------

.. code-block:: bash

   $ lsattr /etc/shadow
   ----i--------e-- /etc/shadow

   $ lsattr -R /etc/ | head -10     # Recursive
   $ lsattr -a /etc/                # Include dotfiles
   $ lsattr -d /etc/                # Show directory attributes, not contents

The output consists of a 20-character attribute string followed by the
filename. Each position corresponds to a specific attribute flag. A
lowercase letter indicates the attribute is set; a hyphen (``-``) indicates
it is not.

3.6.1.2 Essential Attribute Flags
---------------------------------

.. list-table:: Important ``chattr`` Attribute Flags
   :header-rows: 1
   :widths: 10 20 70

   * - Flag
     - Short Name
     - Meaning
   * - ``i``
     - Immutable
     - The file cannot be modified, deleted, renamed, or linked. Even root cannot write to it. **Only root** can set or clear this.
   * - ``a``
     - Append-only
     - The file can only be opened in append mode. Existing data cannot be modified, truncated, or deleted. Perfect for log files.
   * - ``e``
     - Extent format
     - The file uses extents for block mapping. This is the default on ext4 for most files. You will see this on nearly every ext4 file.
   * - ``c``
     - Compressed
     - The filesystem transparently compresses the file on write and decompresses on read. Only valid on filesystems that support per-file compression (e.g., btrfs, ext2/3/4 with ``e2compr`` patches, rarely used).
   * - ``s``
     - Secure deletion
     - When the file is deleted, its blocks are zeroed and returned to the filesystem. Replaces ``rm``'s "unlink" with overwrite. (Performance cost; not commonly used.)
   * - ``u``
     - Undeletable
     - When the file is deleted, its contents are saved for possible later undeletion. (Counterpart to ``s``; not commonly used.)
   * - ``A``
     - No atime update
     - The file's access time (``atime``) is not updated when the file is read. Reduces disk writes; useful for frequently accessed files (man pages, libraries).
   * - ``d``
     - No dump
     - The ``dump(8)`` backup program will skip this file. Avoids backing up swap files, caches, and temporary data.
   * - ``S``
     - Synchronous
     - Modifications are written to disk immediately (like ``O_SYNC`` open flag). Slower but safer for critical data.

3.6.1.3 Setting Attributes with ``chattr``
------------------------------------------

.. code-block:: bash
   :caption: ``chattr`` in action

   # Make a critical configuration file immutable
   # chattr +i /etc/ssh/sshd_config
   # lsattr /etc/ssh/sshd_config
   ----i--------e-- /etc/ssh/sshd_config

   # Try to modify it (even as root)
   # echo "Port 2222" >> /etc/ssh/sshd_config
   bash: /etc/ssh/sshd_config: Operation not permitted

   # Remove the immutable attribute
   # chattr -i /etc/ssh/sshd_config

   # Make a log file append-only
   # chattr +a /var/log/myapp/audit.log
   # lsattr /var/log/myapp/audit.log
   ----a--------e-- /var/log/myapp/audit.log

   # Logging works (appends allowed)
   # echo "2026-07-15: User login" >> /var/log/myapp/audit.log

   # But overwriting or truncating is blocked
   # > /var/log/myapp/audit.log
   bash: /var/log/myapp/audit.log: Operation not permitted

   # Set multiple attributes
   # chattr +a +S /var/log/secure

   # Recursive: set immutable on a directory and all contents
   # chattr -R +i /etc/ssl/private

   # View the attributes of a directory
   $ lsattr -d /var/log
   --------e-- /var/log

3.6.1.4 Security and Practical Applications
-------------------------------------------

**The immutable bit (``+i``)** is one of the strongest security tools
available on Linux:

.. code-block:: bash

   # Protect SSH host keys and server configuration
   # chattr +i /etc/ssh/ssh_host_* /etc/ssh/sshd_config

   # Protect DNS resolver configuration
   # chattr +i /etc/resolv.conf

   # Protect system binaries from tampering (on read-only filesystems
   # that don't already enforce this at the mount level)
   # chattr -R +i /usr/bin /usr/lib /bin /sbin   (be careful!)

.. warning::

   The immutable bit is **not a security boundary** against a determined
   attacker with root access. An attacker with root can simply:

   .. code-block:: bash

      # chattr -i /etc/ssh/sshd_config   # Remove immutable bit
      # echo "PermitRootLogin yes" >> /etc/ssh/sshd_config

   The attacker needs ``CAP_LINUX_IMMUTABLE`` capability (which root has).
   However, the immutable bit **does** protect against:

   * Accidental deletion or modification by root.
   * Ransomware that runs as root (if it is naive enough not to call
     ``chattr -i`` first — many modern variants do).
   * Automated system daemons or installer scripts that unexpectedly modify
     protected files.

   For true tamper-proofing, combine with:

   * Filesystem mount options (``ro``, ``nodev``, ``nosuid``, ``noexec``).
   * Read-only root filesystem (``ro`` in ``/etc/fstab``, remount rw only
     for updates).
   * ``dm-verity`` or ``IMA`` (Integrity Measurement Architecture).

**The append-only bit (``+a``)** is particularly valuable for audit logs:

.. code-block:: bash

   # Protect syslog and audit logs from tampering
   # chattr +a /var/log/syslog /var/log/auth.log /var/log/kern.log

   # Important: logrotate may fail to rotate append-only files.
   # Configure logrotate with 'copytruncate' instead of the default
   # 'create' method:

   # /etc/logrotate.d/rsyslog:
   # /var/log/syslog
   # {
   #     rotate 7
   #     daily
   #     copytruncate        # Copy then truncate (works with +a)
   #     compress
   #     missingok
   #     notifempty
   # }

3.6.1.5 Caveats and Limitations
-------------------------------

*   **Not supported on all filesystems**: ``chattr`` works on ext2/3/4,
    btrfs (subset of flags), and partially on XFS (via ``xfs_io``). It does
    **not** work on ZFS, F2FS, or most FUSE filesystems.
*   **Not preserved across all operations**: File attributes are preserved
    on ``cp -a``, ``rsync -X``, and ``tar --xattrs`` (if configured). But a
    simple ``cp`` will **not** preserve them.
*   **Kernel version dependent**: Some flags are only available on newer
    kernels. For example, ``F`` (``FALLOC_FL_KEEP_SIZE``) for preallocation
    was added relatively recently.
*   **NFS caveat**: NFS does **not** propagate ``chattr`` flags. A file that
    is immutable on the NFS server is **not** immutable when accessed via
    NFS from a client. The client kernel enforces its own attributes (or lack
    thereof).

3.6.2 Extended Attributes (xattr)
====================================

Extended attributes (``xattr``) are arbitrary **key-value metadata** stored
on files and directories. They are the mechanism through which ACLs,
SELinux labels, and capabilities are implemented. You can also create your
own custom extended attributes for application use.

Extended attributes live in **namespaces**. The Linux kernel defines four:

.. list-table:: Extended Attribute Namespaces
   :header-rows: 1
   :widths: 15 25 60

   * - Namespace
     - Prefix
     - Purpose
   * - ``user``
     - ``user.*``
     - Arbitrary user-defined attributes. Any process can read/write (subject to file permissions).
   * - ``trusted``
     - ``trusted.*``
     - As ``user``, but only accessible by processes with ``CAP_SYS_ADMIN`` (effectively root).
   * - ``system``
     - ``system.*``
     - Used by the kernel for system metadata (ACLs: ``system.posix_acl_*`` , SELinux: ``system.selinux``).
   * - ``security``
     - ``security.*``
     - Used by security modules: SELinux, AppArmor, Smack, IMA.

3.6.2.1 Viewing and Setting Extended Attributes
-----------------------------------------------

The ``getfattr(1)`` and ``setfattr(1)`` commands (from the ``attr`` package)
manage extended attributes.

.. code-block:: bash
   :caption: Working with extended attributes

   # Set a custom user attribute
   $ setfattr -n user.myapp.version -v "3.2.1" document.odt

   # Set a binary attribute
   $ setfattr -n user.checksum -v "$(sha256sum document.odt | cut -d' ' -f1)" \
               document.odt

   # View all extended attributes
   $ getfattr -d document.odt
   # file: document.odt
   user.myapp.version="3.2.1"
   user.checksum="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

   # View a specific attribute
   $ getfattr -n user.myapp.version document.odt
   # file: document.odt
   user.myapp.version="3.2.1"

   # Remove an attribute
   $ setfattr -x user.checksum document.odt

   # View all attributes (including security/system) — requires root
   # getfattr -d -m - /etc/shadow
   # file: /etc/shadow
   security.selinux="system_u:object_r:shadow_t:s0"

.. note::

   The ``-m -`` flag to ``getfattr`` sets the regex pattern to match
   **all** attributes across all namespaces, not just ``user.*`` which is
   the default.

3.6.2.2 Extended Attributes and ``cp``/``mv``/``tar``/``rsync``
---------------------------------------------------------------

.. list-table:: xattr Preservation by Common Tools
   :header-rows: 1
   :widths: 20 35 45

   * - Command
     - Preserves xattrs?
     - How to enable
   * - ``cp``
     - Yes, with ``-a`` or ``--preserve=all`` or ``--preserve=xattr``
     - Default ``cp -a`` on many distros.
   * - ``mv``
     - Yes (same filesystem — the inode doesn't change).
     - Automatic.
   * - ``tar``
     - Yes, with ``--xattrs``
     - ``tar --xattrs -cf archive.tar files``
   * - ``rsync``
     - Yes, with ``-X``
     - ``rsync -aX source/ dest/``
   * - ``scp``
     - **No** (legacy SCP protocol)
     - Use ``rsync`` over SSH or ``sftp`` instead.

3.6.2.3 Practical Use Cases
---------------------------

**Version labelling:**

.. code-block:: bash

   # Attach version metadata to files for CI/CD pipelines
   setfattr -n user.build_id -v "$CI_BUILD_ID" artifact.bin
   setfattr -n user.commit_hash -v "$GIT_COMMIT" artifact.bin

**Checksum storage:**

.. code-block:: bash

   # Store checksums alongside files for integrity checking
   setfattr -n user.sha256 -v "$(sha256sum important.pdf | cut -d' ' -f1)" \
             important.pdf

**Tag-based file organisation:**

.. code-block:: bash

   # Tag files with custom metadata for search/index tools
   setfattr -n user.tags -v "photo,vacation,2026" img_1234.jpg

**Capabilities (``security.*`` namespace):**

.. code-block:: bash

   # View capabilities stored as extended attributes
   $ getfattr -d -m - /usr/bin/ping
   # file: /usr/bin/ping
   security.capability=0sAAAACIAAgAAAAAAAAAAAAAAAAAAA=

   # The raw output is hex-encoded. Use getcap for human-readable:
   $ getcap /usr/bin/ping
   /usr/bin/ping = cap_net_raw+ep

   # Set a capability using setcap (which wraps setfattr)
   # setcap cap_net_raw+ep /usr/local/bin/custom_ping

.. warning::

   Manually manipulating ``security.capability`` with ``setfattr`` is
   strongly discouraged. Always use ``setcap(8)`` from the ``libcap``
   package, which validates the attribute format and maintains kernel
   compatibility.

3.6.2.4 Filesystem Requirements
-------------------------------

Extended attributes require:

* **Kernel support**: ``CONFIG_EXT4_FS_XATTR``, ``CONFIG_XFS_FS_XATTR``, etc.
  (all standard distribution kernels include these).
* **Filesystem format**: On ext2/3/4, extended attributes consume additional
  filesystem blocks. Very old ext2 filesystems may lack xattr support
  entirely (recreate with ``mkfs.ext4 -O xattr``). Btrfs and XFS support
  xattrs natively.
* **Storage limit**: Most filesystems impose a maximum size for all extended
  attributes on a single file. On ext4, the total is bounded by the
  filesystem block size (typically 4096 bytes per file for inline xattrs).
  On XFS, the limit is one filesystem block (up to 64 KiB on systems with
  64 KiB block size).

3.6.3 Summary
==============

*   ``chattr``/``lsattr`` manage low-level filesystem attribute flags
    at the VFS layer.
*   The **immutable flag (``+i``)** prevents any modification to a file,
    even by root. The **append-only flag (``+a``)** restricts writes to
    append mode only.
*   ``chattr`` flags are powerful but filesystem-dependent, NFS-unfriendly,
    and removable by a privileged attacker.
*   **Extended attributes (xattr)** store arbitrary key-value metadata on
    files, divided into ``user``, ``trusted``, ``system``, and ``security``
    namespaces.
*   Use ``getfattr`` and ``setfattr`` for user-defined attributes; use the
    dedicated tools (``setcap``, ``getcap``, ``setfacl``, ``getfacl``) for
    security-related namespaces.
*   Both mechanisms require filesystem and kernel support, and both are
    preserved by ``cp -a``, ``rsync -X``, and ``tar --xattrs``.
