.. _filesystems-tuning:

6.2 Filesystem Creation & Tuning
=================================

A filesystem imposes structure onto a raw block device — organising
space, tracking metadata, and enforcing consistency.
No single
filesystem is universally optimal; the choice depends on workload
patterns, hardware characteristics, and operational requirements.
6.2.1 Filesystem Architecture: The Big Picture
-----------------------------------------------

Every Unix-style filesystem shares a handful of architectural
concepts:

**Superblock**
  The root metadata structure.
It records the filesystem type, size,
  block size, inode count, free block/inode counts, mount state, and
  a magic number identifying the filesystem.
Because the superblock
  is critical, most filesystems store backup copies at fixed offsets
  throughout the device.
**Inodes (Index Nodes)**
  An inode describes exactly one filesystem object — a regular file,
  directory, symlink, device node, or FIFO.
It stores:

  - File type and permissions (the ``mode`` field).
  - Owner UID and GID.
  - Size in bytes.
- Timestamps: ``atime`` (access), ``mtime`` (modification),
    ``ctime`` (metadata change), and optionally ``crtime``
    (creation/birth time on ext4/XFS/Btrfs).
- Pointers to data blocks: direct, indirect, double-indirect, and
    triple-indirect pointers (ext4), or extents (XFS, Btrfs).
- Extended attribute (xattr) block pointer.

  An inode does **not** store the filename — that lives in directory
  entries.
**Directory Entries**
  A directory is a special file whose data blocks contain an array
  of ``(inode_number, name)`` pairs.
When you open
  ``/home/alice/document.txt``, the kernel walks the dentry cache
  (dcache), resolving each path component to an inode.
**Journal**
  A journaling filesystem logs metadata (and optionally data)
  changes to a circular journal before committing them to the main
  filesystem structures.
After a crash, the journal is replayed to
  restore consistency, avoiding a full ``fsck``.
Journaling modes
  (on ext4) are:

  - ``data=ordered`` (default): metadata is journaled;
data blocks
    are written to disk before metadata is committed.
Guarantees
    that files never contain stale data from a previous allocation
    after a crash.
- ``data=writeback``: metadata is journaled; data may be written
    before or after.
Faster but risks exposing stale data.
  - ``data=journal``: all data and metadata are written to the
    journal twice (once to the journal, once to the final location).
Safest but slowest.

6.2.2 Creating Filesystems: ``mkfs``
-------------------------------------

The ``mkfs`` family is a front-end to filesystem-specific builders:

.. code-block:: bash

   mkfs -t ext4 /dev/sda1        # generic syntax
   mkfs.ext4 /dev/sda1           # filesystem-specific shortcut

**mkfs.ext4** — Fourth Extended Filesystem
  The workhorse of Linux for over a decade.
Key options:

  .. code-block:: bash

     mkfs.ext4 -L "rootfs" -m 1 -E lazy_itable_init=0,lazy_journal_init=0 /dev/sda1

  - ``-L LABEL``: Volume label (visible in ``lsblk -f``).
- ``-m reserved-blocks-percentage``: Percentage of blocks reserved
    for the root user. Default is 5 %.
On multi-terabyte data drives,
    reduce to 0–1 % to reclaim space (``tune2fs -m 0 /dev/sda1``).
- ``-b block-size``: 1024, 2048, or 4096. Larger blocks reduce
    indirect-pointer overhead for large files but waste space for
    many small files.
- ``-i bytes-per-inode``: Controls the inode-to-space ratio. The
    default (16,384) creates one inode per 16 KiB of disk space.
Lower this (e.g., ``-i 4096``) for filesystems hosting millions
    of small files (mail servers, Git hosts).
You cannot add inodes
    after creation.
  - ``-E lazy_itable_init=0``: Disables lazy inode table
    initialisation — useful for benchmarking or when you need the
    inode table to be fully zeroed from the start.
- ``-O ^has_journal``: Creates ext4 without a journal (effectively
    ext2).
Only for ephemeral or read-only data where journal
    overhead is unacceptable.
- ``-O encrypt``: Enables filesystem-level encryption support
    (requires kernel support and ``e4crypt``).
**mkfs.xfs** — XFS
  Originally from SGI IRIX, XFS excels at large files and high
  concurrency thanks to allocation groups (AGs) that partition the
  filesystem into independent regions, each with its own free-space
  tracking and inode management.
This design enables parallel I/O
  without a global lock.
.. code-block:: bash

     mkfs.xfs -L "data" -d agcount=8 -l size=128m /dev/sdb1

  - ``-d agcount=N``: Number of allocation groups.
More AGs improve
    parallelism on multi-socket machines with many NVMe drives.
  - ``-l size=SIZE``: Journal log size.
Larger journals smooth
    bursty metadata workloads at the cost of slightly longer mount
    times after a crash.
- ``-i maxpct=PCT``: Maximum percentage of space inodes may
    consume (default 25 % for small filesystems, 5 % for large).
- ``-m crc=1,reflink=1``: Enable metadata CRC checking and
    reflink/deduplication support.
  - ``-n size=SIZE``: Inode size.
Default is 512 bytes; increase to
    2048 or 4096 for extended attributes heavy workloads.
.. note::

     XFS **cannot be shrunk** (``xfs_growfs`` exists, but there is
     no shrink equivalent).
If filesystem shrinkage is a
     requirement, use ext4 or Btrfs.
**mkfs.btrfs** — B-tree Filesystem
  Btrfs is a copy-on-write (CoW) filesystem integrating volume
  management, snapshots, checksums, compression, and RAID directly
  into the filesystem layer.
Its data structures are B-trees,
  avoiding fixed-size allocation tables.
.. code-block:: bash

     mkfs.btrfs -L "data" -d single -m dup /dev/sdc1 /dev/sdc2

  - ``-d single|raid0|raid1|raid10|raid5|raid6``: Data profile.
- ``-m dup|single|raid1|raid10|raid5|raid6``: Metadata profile.
    ``dup`` stores two copies of metadata on a single device.
- ``-n SIZE``: Node size (default 16 KiB). Larger nodes improve
    sequential scan performance at the cost of more CoW overhead for
    small updates.
- ``-K``: Do not run whole-device TRIM during mkfs (useful for
    restoring data).
- ``--csum TYPE``: Checksum algorithm (``crc32c``, ``xxhash``,
    ``sha256``, ``blake2``).
6.2.3 Inode Deep Dive and Tuning with ``tune2fs``
--------------------------------------------------

Understanding inode structure helps you diagnose "No space left on
device" errors when ``df`` reports free space — the culprit is often
inode exhaustion.
.. code-block:: bash

   df -i /home                   # check inode usage
   tune2fs -l /dev/sda1 |
grep -i "inode count"

``tune2fs`` modifies ext4 filesystem parameters (the filesystem
should be unmounted or mounted read-only for most operations):

.. code-block:: bash

   sudo tune2fs -m 0 /dev/sda1               # zero reserved blocks
   sudo tune2fs -c 0 -i 0 /dev/sda1          # disable time/mount-based fsck
   sudo tune2fs -L "newlabel" /dev/sda1       # change label
   sudo tune2fs -o journal_data_writeback     # set default mount option
   
sudo tune2fs -O fast_commit /dev/sda1      # enable fast commits (ext4, kernel 5.10+)
   sudo tune2fs -e remount-ro /dev/sda1       # remount read-only on error

To view the extent tree of a specific file:

.. code-block:: bash

   sudo debugfs -R "stat /path/to/file" /dev/sda1

6.2.4 Filesystem Checking: ``fsck``
------------------------------------

``fsck`` is a front-end dispatcher:

.. code-block:: bash

   fsck -t ext4 /dev/sda1         # invokes fsck.ext4
   fsck -A -t noopts=ro           # check all fstab entries 
that aren't read-only
   fsck -N                        # dry-run: show what would be checked

``fsck.ext4`` will automatically replay the journal.
If the
superblock is corrupted, specify a backup location:

.. code-block:: bash

   sudo mke2fs -n /dev/sda1       # locate backup superblocks (dry-run)
   sudo fsck.ext4 -b 32768 /dev/sda1   # use backup at block 32768

For XFS, ``xfs_repair`` is the equivalent:

.. code-block:: bash

   sudo xfs_repair /dev/sdb1
   sudo xfs_repair -L /dev/sdb1   # zero the log (destructive, last resort)

For Btrfs, an online scrub is preferred:

.. code-block:: bash

   sudo btrfs scrub start /mnt/data
   sudo btrfs scrub status /mnt/data

6.2.5 SSD/NVMe-Specific Tuning
-------------------------------

**TRIM/Discard**
  When a file is deleted, the 
filesystem marks blocks as free in its
  own metadata, but the SSD's FTL does not know those pages are
  stale.
The TRIM (ATA) or Deallocate (NVMe) command informs the
  drive, reducing write amplification and improving sustained write
  performance.
- **Online discard** (``mount -o discard``): The kernel sends
    TRIM commands synchronously on every deletion.
This adds latency
    and is generally discouraged on modern drives.
- **Periodic fstrim** (recommended): Run a bulk discard on a
    schedule.
.. code-block:: bash

       sudo fstrim -v /              # trim the root filesystem
       sudo fstrim -av               # trim all mounted filesystems that support it

    Most distributions enable ``fstrim.timer`` (a systemd timer) to
    run ``fstrim.service`` weekly.
**I/O Scheduler**
  For NVMe and modern SSDs, use the ``none`` (also called
  ``noop`` or ``mq-deadline`` depending on kernel version) I/O
  scheduler, because the device's internal queuing is far more
  sophisticated than any host-side elevator algorithm:

  .. code-block:: bash

     cat /sys/block/nvme0n1/queue/scheduler
     # [none] mq-deadline kyber bfq
     echo none |
sudo tee /sys/block/nvme0n1/queue/scheduler

**Alignment**
  Ensure partitions start on erase-block boundaries (typically 1 MiB
  for modern SSDs).
Modern tools align to 1 MiB (2048 sectors) by
  default, but verify with:

  .. code-block:: bash

     sudo parted /dev/nvme0n1 align-check optimal 1

6.2.6 Enterprise Alternative: ZFS
----------------------------------

ZFS, originally from Sun Microsystems, combines the roles of
filesystem, volume manager, and RAID controller into a single,
transactional, copy-on-write system.
Its key innovations include:

- **128-bit addressing**: Theoretically unlimited capacity.
- **Copy-on-write**: All writes go to new blocks;
the uberblock is
  atomically updated. No ``fsck`` needed — only ``zpool scrub``.
- **Checksums**: Every block is checksummed, enabling self-healing
  when redundant copies exist.
- **Snapshots and clones**: Instantaneous, space-efficient.
- **Compression**: Transparent LZ4, GZIP, ZSTD.
- **ARC (Adaptive Replacement Cache)**: A sophisticated read cache
  in RAM distinct from the kernel's page cache.
ZFS is not in-tree on Linux due to a CDDL/GPL licensing
incompatibility, but is available through the OpenZFS project
(``zfs-dkms`` package).
Pools are created with:

.. code-block:: bash

   sudo zpool create -o ashift=12 tank mirror /dev/sda /dev/sdb
   sudo zfs create -o compression=lz4 -o recordsize=1M tank/data

The ``ashift`` parameter sets the sector alignment (``12`` = 4 KiB,
``13`` = 8 KiB) and is critical for "Advanced Format" and SSD
drives.
Setting it incorrectly causes severe write amplification.

.. warning::

   If you are designing a new storage system and can choose between
   Btrfs and ZFS, consider: ZFS is more mature and battle-tested in
   production;
Btrfs is in-tree (no kernel module compilation) and
   has native integration with Linux namespaces and send/receive.
Both are excellent; the choice depends on your operational
   ecosystem.
