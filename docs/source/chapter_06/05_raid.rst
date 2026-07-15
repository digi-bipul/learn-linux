.. _raid:

6.5 RAID Arrays
================

RAID (Redundant Array of Independent/Inexpensive Disks) improves
performance, capacity, or fault tolerance by combining multiple
physical drives into a single logical unit.
Linux supports hardware
RAID (controller-based), firmware RAID ("fake RAID," e.g., Intel
RST), and software RAID — the latter being the focus here thanks to
its flexibility and portability.
6.5.1 RAID Levels
------------------

.. list-table::
   :header-rows: 1

   * - Level
     - Min.
Disks
     - Capacity
     - Fault Tolerance
     - Read Perf.
- Write Perf.
   * - RAID 0 (striping)
     - 2
     - N × size
     - None
     - Excellent
     - Excellent
   * - RAID 1 (mirroring)
     - 2
     - 1 × size
     - N − 1 disks
     - Good
     - Slightly reduced
   * - RAID 5 (distributed parity)
     - 3
    
 - (N − 1) × size
     - 1 disk
     - Good
     - Poor (R-M-W penalty)
   * - RAID 6 (dual parity)
     - 4
     - (N − 2) × size
     - 2 disks
     - Good
     - Poor
   * - RAID 10 (stripe of mirrors)
     - 4
     - (N / 2) × size
     
- 1 per mirror pair
     - Excellent
     - Good

**RAID 0** distributes data in stripes across all disks.
A single
failure destroys the entire array. Suitable only for ephemeral data
(e.g., build caches, render scratch space).
**RAID 1** writes identical copies to each disk in the mirror set.
Reads can be distributed across mirrors for parallelism.
Survives
any single-disk failure. Overhead: 50 % of raw capacity.

**RAID 5** stripes data across N − 1 disks and writes parity to the
remaining disk, rotating the parity location.
Parity is the XOR of
the data blocks, allowing reconstruction of any single missing
block.
The **read-modify-write (R-M-W) penalty** on small writes
significantly degrades performance because the controller must read
the old data and parity, compute the new parity, and write both.
**RAID 6** extends RAID 5 with a second parity stripe (typically
Reed-Solomon coding), surviving two simultaneous disk failures.
The
dual-parity computation is CPU-intensive in software RAID.

**RAID 10** first mirrors pairs of disks, then stripes across the
mirrors.
It combines RAID 1's fast rebuild times with RAID 0's
throughput. Typically the best choice for database workloads.
6.5.2 Software RAID with ``mdadm``
-----------------------------------

``mdadm`` manages **Multiple Device (md)** arrays. The kernel's
``md`` driver implements the RAID personality in software.
**Create arrays**:

.. code-block:: bash

   # RAID 1 mirror
   sudo mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb1 /dev/sdc1

   # RAID 5 with a hot spare
   sudo mdadm --create /dev/md1 --level=5 --raid-devices=3 \
        --spare-devices=1 /dev/sdd1 /dev/sde1 /dev/sdf1 /dev/sdg1

   # RAID 10 (near layout: one copy per chunk, then next copy — default)
   sudo mdadm --create /dev/md2 --level=10 --raid-devices=4 \
        /dev/sdh1 /dev/sdi1 /dev/sdj1 /dev/sdk1

Key ``--create`` flags:

- ``--level=``: RAID level.
- ``--raid-devices=``: Number of active devices.
- ``--spare-devices=``: Extra devices that automatically replace
  failed members.
- ``--chunk=``: Stripe chunk size in KiB (default 512 KiB).
  Smaller chunks benefit random I/O;
larger chunks benefit
  sequential I/O.
- ``--metadata=``: Superblock format. ``0.90`` for legacy
  compatibility;
``1.2`` (default) stores metadata at the start of
  the device — better for growing arrays but incompatible with very
  old bootloaders.
- ``--bitmap=internal``: Write-intent bitmap for drastically faster
  resync after an unclean shutdown. Trade-off: slight write
  performance penalty.
**Assembly and auto-detection**:

.. code-block:: bash

   sudo mdadm --assemble --scan            # assemble all arrays from config
   sudo mdadm --assemble /dev/md0 /dev/sdb1 /dev/sdc1

The configuration file ``/etc/mdadm/mdadm.conf`` (or
``/etc/mdadm.conf``) stores array UUIDs and device lists:

.. code-block:: bash

   sudo mdadm --detail --scan >> /etc/mdadm/mdadm.conf
   sudo update-initramfs -u                 # include in initramfs for boot

**Monitoring**:

.. code-block:: bash

   cat /proc/mdstat            
              # brief status
   sudo mdadm --detail /dev/md0              # per-array detail
   sudo mdadm --monitor --scan --daemonise   # background monitoring daemon

The ``--detail`` output includes each component device's state,
the array's UUID, creation time, raid level, chunk size, and
resync/rebuild progress:

.. code-block:: text

   /dev/md0:
              Version : 1.2
        Creation Time : 
Wed Jul 12 14:22:00 2026
           Raid Level : raid1
           Array Size : 976629760 (931.39 GiB 1000.07 GB)
        Used Dev Size : 976629760 (931.39 GiB 1000.07 GB)
         Raid Devices : 2
        Total Devices : 2
          Persistence : Superblock is persistent
        Intent Bitmap : 
Internal
          Update Time : Wed Jul 15 21:50:03 2026
                State : clean
       Active Devices : 2
      Working Devices : 2
       Failed Devices : 0
        Spare Devices : 0

6.5.3 Failure and Recovery
---------------------------

**Simulate a failure** (for testing):

.. code-block:: bash

   sudo mdadm --manage /dev/md0 --fail /dev/sdc1
   sudo mdadm --manage /dev/md0 --remove 
/dev/sdc1

**Replace a failed disk**:

.. code-block:: bash

   # Physically replace the disk, partition identically, then:
   sudo mdadm --manage /dev/md0 --add /dev/sdc1

The array automatically begins rebuilding onto the new device.
Monitor progress with ``cat /proc/mdstat`` or
``mdadm --detail /dev/md0``.

**Force assembly with missing devices** (when a disk is temporarily
removed):

.. code-block:: bash

   sudo mdadm --assemble --force --run /dev/md0 /dev/sdb1 missing

**Grow an array** (add devices to increase capacity):

.. code-block:: bash

   sudo mdadm --grow /dev/md0 --raid-devices=3 --add /dev/sdd1

After the reshape, grow the filesystem with ``resize2fs`` or
``xfs_growfs``.
6.5.4 Legacy ``mdadm`` vs. Filesystem-Native RAID
--------------------------------------------------

Modern copy-on-write filesystems integrate RAID directly into the
filesystem, offering compelling advantages over ``mdadm`` + separate
filesystem:

**Btrfs RAID**
  Btrfs stores metadata and data on separate block groups, each
  with its own replication profile.
You can mix profiles:

  .. code-block:: bash

     sudo mkfs.btrfs -d raid1 -m raid1c3 /dev/sda /dev/sdb /dev/sdc

  - ``-d raid1``: Data stored with two copies across devices.
- ``-m raid1c3``: Metadata stored with three copies (survives two
    failures).
Btrfs RAID is **self-healing**: during a read, if a checksum
  mismatch is detected on one copy, Btrfs fetches the alternate copy
  and repairs the corrupt one automatically.
**ZFS RAID-Z**
  ZFS's RAID-Z (RAID-Z1 = single parity, RAID-Z2 = dual parity,
  RAID-Z3 = triple parity) avoids the RAID-5 "write hole" problem —
  a partial-stripe write interrupted by power loss that corrupts
  parity — by using copy-on-write with variable stripe width.
.. code-block:: bash

     sudo zpool create tank raidz2 /dev/sda /dev/sdb /dev/sdc /dev/sdd

.. admonition:: When to Use Which

   - **mdadm**: Mature, battle-tested, supports all RAID levels,
     kernel-native, works with any filesystem on top.
Best for
     boot/root arrays and when you need a traditional block-device
     interface.
- **Btrfs RAID**: Integrated checksums, self-healing, online
     device addition/removal, conversion between profiles without
     unmounting.
Best for data volumes where snapshots and
     compression are also desired.
- **ZFS RAID-Z**: The gold standard for data integrity with
     maximum flexibility.
Best for NAS/SAN appliances and any
     scenario where data corruption is unacceptable.
For most new deployments storing important data on Linux, either
   Btrfs or ZFS is preferable to ``mdadm`` + ext4/XFS, because
   ``mdadm`` alone cannot detect silent data corruption — only
   filesystem-level checksums can.
