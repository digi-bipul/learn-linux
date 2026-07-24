.. _mounting-fstab:

Mounting & ``/etc/fstab``
==============================

Mounting is the act of attaching a filesystem into the kernel's
unified VFS (Virtual Filesystem Switch) directory tree.
Without
mounting, a filesystem exists as inert data on a block device; after
mounting, its contents appear seamlessly at a directory path.
The ``mount`` Command
----------------------------

The most common invocation:

.. code-block:: bash

   mount -t ext4 /dev/sda1 /mnt/data

The ``-t`` flag is optional — the kernel probes the device's
superblock to identify the filesystem using the ``blkid``
infrastructure.
The mount point must exist as an empty directory
beforehand.

**Key mount options** passed with ``-o``:

.. list-table::
   :header-rows: 1

   * - Option
     - Effect
   * - ``ro``
     - Read-only;
no writes permitted.
   * - ``rw``
     - Read-write (usually default).
* - ``noatime``
     - Do not update file access timestamps.
Dramatically reduces
       metadata writes, beneficial for SSDs and high-read workloads.
* - ``relatime``
     - Update atime only if it is older than mtime/ctime or older
       than 24 hours.
Default on most distributions; reasonable
       compromise.
* - ``nodev``
     - Ignore device nodes on this filesystem.
Essential for
       removable media and user-writable mounts.
* - ``nosuid``
     - Ignore setuid/setgid bits.
Prevents privilege escalation via
       user-controlled binaries.
* - ``noexec``
     - Disallow execution of binaries.
Use on ``/tmp`` or
       user-upload directories.
* - ``sync``
     - All I/O is synchronous (writes block until data hits stable
       storage).
Extremely slow; used only for removable media that
       must not be unsafely ejected.
* - ``async``
     - Writes are buffered and may be reordered (default).
* - ``discard``
     - Send TRIM commands on freed blocks (SSD).
Prefer periodic
       ``fstrim`` for most workloads.
* - ``nofail``
     - If the device is absent at boot, do not halt the boot
       process.
Critical for removable or networked storage in
       ``/etc/fstab``.
* - ``x-systemd.requires=``
     - systemd mount-unit dependency directive (e.g.,
       ``x-systemd.requires=network-online.target`` for NFS).
**Bind mounts** overlay one directory onto another within the same
filesystem:

.. code-block:: bash

   mount --bind /source/dir /target/dir

This is used extensively by containers to expose host directories
into namespaces.
**Remounting** changes options on an already-mounted filesystem:

.. code-block:: bash

   mount -o remount,ro /

This is the standard way to put the root filesystem into read-only
mode for maintenance.
``umount`` — Detaching Filesystems
-----------------------------------------

.. code-block:: bash

   umount /mnt/data               # by mount point
   umount /dev/sda1               # by device
   umount -l /mnt/data            # lazy unmount: detach now, clean up when idle
   umount -f /mnt/data            # force unmount (NFS only, typical use)

If ``umount`` reports 
"target is busy," identify the culprit(s):

.. code-block:: bash

   lsof +D /mnt/data              # list open files under mount
   fuser -vm /mnt/data            # list processes accessing the mount
   fuser -km /mnt/data            # kill all processes accessing (dangerous!)

``/etc/fstab`` — The Filesystem Table
--------------------------------------------

The file ``/etc/fstab`` is read by ``mount -a`` (and by systemd at
boot) to determine which filesystems to mount and with 
what options.
Each non-comment, non-blank line contains six whitespace-delimited
fields:

.. code-block:: text

   <device>  <mount_point>  <fs_type>  <options>  <dump>  <pass>

1. **device**: The block device.
Best practice: use UUID (``UUID=...``),
   PARTUUID (``PARTUUID=...``), or label (``LABEL=...``). Avoid
   ``/dev/sdX`` nodes.
2. **mount_point**: Absolute path where the filesystem is attached.
   Use ``none`` for swap.
3. **fs_type**: Filesystem type (``ext4``, ``xfs``, ``btrfs``,
   ``swap``, ``vfat``, ``nfs4``, ``tmpfs``, etc.).
Use ``auto`` to
   let the kernel probe.
4. **options**: Comma-separated mount options (see table above).
``defaults`` expands to ``rw,suid,dev,exec,auto,nouser,async``.
5. **dump**: ``1`` to enable ``dump`` backup utility (mostly
   obsolete); ``0`` to disable.
6. **pass**: ``fsck`` pass order. ``1`` for root (checked first),
   ``2`` for other filesystems (checked in parallel), ``0`` to skip
   ``fsck``.
**Example fstab**:

.. code-block:: text

   # device                            mount   type   options                       dump pass
   UUID=abc123-...                     /       ext4   defaults,noatime 
              0    1
   UUID=def456-...                     /boot   vfat   defaults,noatime               0    2
   UUID=ghi789-...                     /home   xfs    defaults,nodev,nosuid,noatime  
0    2
   UUID=jkl012-...                     none    swap   defaults,discard               0    0
   tmpfs                               /tmp    tmpfs  defaults,size=4G,nosuid,nodev  0    
0
   //nas.local/share                   /mnt/nas cifs  credentials=/root/.smbcred,iocharset=utf8,vers=3.0,nofail 0 0

.. tip::

   After editing ``/etc/fstab``, run ``sudo mount -a`` to mount all
   new entries without rebooting.
If the command returns silently,
   the syntax is valid and all devices were found.
Then run
   ``findmnt --verify`` for a comprehensive consistency check.
Systemd Mount Units
--------------------------

Systemd can manage mounts natively through **mount units**. When
systemd reads ``/etc/fstab``, it dynamically generates mount units
in ``/run/systemd/generator/``.
You can also write explicit
``.mount`` unit files in ``/etc/systemd/system/``.

A mount unit file is named after the mount point with the path
slashes replaced by dashes.
For ``/mnt/data``, the unit is
``mnt-data.mount``:

.. code-block:: ini

   # /etc/systemd/system/mnt-data.mount
   [Unit]
   Description=Data volume
   Requires=dev-disk-by\x2duuid-ghi789.device
   After=dev-disk-by\x2duuid-ghi789.device

   [Mount]
   What=/dev/disk/by-uuid/ghi789
   Where=/mnt/data
   Type=xfs
   Options=noatime,nodev,nosuid

   [Install]
   WantedBy=multi-user.target

Activate with:

.. code-block:: bash

   sudo systemctl daemon-reload
   sudo systemctl start mnt-data.mount
   sudo systemctl enable mnt-data.mount

**Advantages of mount units over fstab**:

- Explicit dependency ordering (``Requires=``, ``After=``,
  ``Before=``, ``BindsTo=``).
- Conditional activation (``ConditionPathExists=``,
  ``ConditionKernelCommandLine=``).
- Integration with systemd's transaction-based boot.
- Programmatic manipulation via ``systemctl`` (e.g., masking,
  enabling, or overriding with drop-ins).

Generally, ``/etc/fstab`` remains the simpler, more familiar
approach.
Use mount units when you need the precision of systemd's
dependency management — for example, ensuring a network filesystem
mounts only after DHCP has assigned an address, or that a decryption
service unlocks a LUKS volume before its filesystem is mounted.
