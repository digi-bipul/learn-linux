.. _lvm:

LVM (Logical Volume Manager)
================================

The Logical Volume Manager (LVM) abstracts physical storage devices
into a flexible pool from which logical volumes are allocated.
It is
the foundation of enterprise storage elasticity on Linux.

Architecture: PV, VG, LV
-------------------------------

LVM's layered model consists of three object types:

**Physical Volume (PV)**
  A block device (entire disk, partition, or even a loop device)
  initialised with LVM metadata in a header.
The metadata records a
  UUID, the PV's size, and a list of extents allocated to volume
  groups.
**Volume Group (VG)**
  A named pool aggregating one or more PVs.
The VG's total capacity
  is the sum of its PVs.
The VG is subdivided into **physical
  extents (PEs)** — the smallest unit of allocation, default 4 MiB.
**Logical Volume (LV)**
  A virtual block device allocated from a VG, consisting of a
  mapping of **logical extents (LEs)** to PEs.
An LV can be linear
  (simple concatenation of PEs), striped (round-robin across PVs for
  parallelism), mirrored, or cached.
The device mapper (``dm-*``) in the kernel implements the actual
block remapping. LVM tooling orchestrates device mapper tables.
.. figure:: /_static/lvm_architecture.svg
   :alt: LVM Architecture Diagram

   PVs aggregate into a VG;
LVs are carved from the VG and appear as
   ``/dev/vg_name/lv_name``.
Creating and Managing PVs, VGs, and LVs
-----------------------------------------------

**Initialise a Physical Volume**:

.. code-block:: bash

   sudo pvcreate /dev/sdb1 /dev/sdc1
   sudo pvs                         # list PVs with summary
   sudo pvdisplay /dev/sdb1         # detailed PV metadata
   sudo pvscan                      # scan all block devices for 
LVM headers

``pvcreate`` writes an LVM label to the device. The ``-ff`` flag
forces creation even if an existing filesystem signature is
detected.
The ``--dataalignment`` option (e.g., ``4M``) aligns data
to flash erase-block boundaries.
**Create a Volume Group**:

.. code-block:: bash

   sudo vgcreate my_vg /dev/sdb1 /dev/sdc1
   sudo vgcreate -s 16M my_vg /dev/sdb1 /dev/sdc1   # 16 MiB PE size

The ``-s`` (``--physicalextentsize``) flag sets the PE size.
Larger
PEs (e.g., 16 MiB) reduce metadata overhead for very large VGs (100+
TiB) but waste space if you create many small LVs.
The default 4 MiB
is suitable for VGs up to ~16 TiB (with 32-bit extent numbering in
LVM2 format lvm2).
**Extend a VG with new PVs**:

.. code-block:: bash

   sudo vgextend my_vg /dev/sdd1
   sudo vgreduce my_vg /dev/sdd1  # remove PV (after moving data with pvmove)

**Create a Logical Volume**:

.. code-block:: bash

   sudo lvcreate -n my_lv -L 10G my_vg
   sudo lvcreate -n striped_lv -L 20G -i 2 -I 256k my_vg  # striped
   sudo lvcreate -n thin_pool --type thin-pool -L 50G my_vg

Key ``lvcreate`` flags:

- ``-L SIZE``: Absolute size.
Suffixes: ``M``, ``G``, ``T``, ``P``.
- ``-l EXTENTS``: Size in PEs (e.g., ``-l 100%FREE`` uses all
  remaining space).
- ``-n NAME``: LV name.
- ``-i STRIPES``: Number of stripes for RAID 0-like parallelism.
- ``-I STRIPESIZE``: Stripe unit size (default 64 KiB).
- ``--type TYPE``: ``linear`` (default), ``striped``, ``mirror``,
  ``raid1``, ``raid5``, ``raid6``, ``raid10``, ``thin-pool``,
  ``thin``, ``cache``, ``cache-pool``, ``writecache``.
The resulting device node is ``/dev/my_vg/my_lv``, which you can
format and mount like any block device:

.. code-block:: bash

   sudo mkfs.xfs /dev/my_vg/my_lv
   sudo mount /dev/my_vg/my_lv /mnt/data

Resizing Logical Volumes
-------------------------------

**Extend an LV** (grow the block device, then grow the filesystem):

.. code-block:: bash

   sudo lvextend -L +5G /dev/my_vg/my_lv       # add 5 GiB
   sudo lvextend -L 50G /dev/my_vg/my_lv        # set absolute size to 50 GiB
   sudo lvextend -l +100%FREE /dev/my_vg/my_lv  # consume all free VG space

   # Then resize 
the filesystem:
   sudo resize2fs /dev/my_vg/my_lv              # ext4
   sudo xfs_growfs /mnt/data                    # XFS (must be mounted)

**Shrink an LV** (shrink filesystem first, then LV — only ext4/Btrfs
support shrinking; XFS does not):

.. code-block:: bash

   sudo umount /mnt/data
   sudo fsck.ext4 -f /dev/my_vg/my_lv           # mandatory check
   sudo resize2fs /dev/my_vg/my_lv 20G    
       # shrink fs to 20 GiB
   sudo lvreduce -L 20G /dev/my_vg/my_lv         # shrink LV to match

Snapshots
----------------

An LVM snapshot creates a point-in-time copy of an LV using
copy-on-write.
The snapshot initially shares all data with the
origin; as the origin is modified, original blocks are copied to the
snapshot's **exception store** before being overwritten.
Thus the
snapshot size determines how many changes can accumulate before the
snapshot becomes invalid.
.. code-block:: bash

   sudo lvcreate -n snap_my_lv -L 2G -s /dev/my_vg/my_lv

The snapshot appears as ``/dev/my_vg/snap_my_lv`` and can be mounted
read-only.
To merge the snapshot back (restore the origin to the
snapshot state):

.. code-block:: bash

   sudo lvconvert --merge /dev/my_vg/snap_my_lv

The merge executes on the next activation of the origin LV.
.. warning::

   If the snapshot's exception store fills completely, the snapshot
   is automatically invalidated and cannot be recovered.
Monitor
   snapshot usage with ``lvs -o +snapshot_percent``.

Thin Provisioning
------------------------

Traditional (thick) LVs allocate all PEs immediately.
**Thin
provisioning** over-commits space: a thin pool LV holds the
aggregate storage, and thin LVs draw from it on demand via a
two-level device-mapper target.
.. code-block:: bash

   # Create a thin pool
   sudo lvcreate -n thin_pool -L 100G my_vg

   # Create thin LVs from the pool (virtual size can exceed pool size)
   sudo lvcreate -n thin_vol1 -V 200G --thinpool thin_pool my_vg
   sudo lvcreate -n thin_vol2 -V 50G  --thinpool thin_pool my_vg

   # Monitor thin pool usage
   sudo lvs -o +data_percent,metadata_percent my_vg/thin_pool

Thin provisioning is ideal for virtual machine disk images: you can
present each VM with a 100 GiB virtual disk while only 20 GiB of
physical space is consumed, monitoring and expanding 
the pool as
needed.

Thin snapshots are also far more space-efficient than traditional
snapshots because they share a common pool and use the same metadata
mechanism for both origin and snapshot.
LVM Caching
-----------------

.. _lvm-caching:

LVM can use a fast block device (NVMe SSD) as a cache for a slower
volume group (HDD-backed).
The cache operates in one of two modes:

- **writethrough**: Reads are cached;
writes go to both cache and
  backing device. Safe — data is always on the backing device.
- **writeback**: Reads and writes are cached; writes are eventually
  flushed to backing.
Faster but risks data loss if the cache device
  fails before flushing.
.. code-block:: bash

   # 1. Create the slow (origin) LV
   sudo lvcreate -n slow_lv -L 500G slow_vg /dev/sdb

   # 2. Create the fast LV (metadata + data on same or separate devices)
   sudo vgcreate cache_vg /dev/nvme0n1p2
   sudo lvcreate -n cache_meta -L 1G cache_vg
   sudo lvcreate -n cache_data -L 50G cache_vg

   # 3. Combine into a cache pool and attach
   sudo lvconvert --type cache-pool --poolmetadata cache_vg/cache_meta \
        cache_vg/cache_data
   sudo lvconvert --type cache --cachepool cache_vg/cache_data slow_vg/slow_lv

The resulting 
``slow_lv`` is now I/O-accelerated. ``lvs -a`` shows
the internal cache components (``[slow_lv_corig]`` origin,
``[cache_data_cdata]`` data, ``[cache_data_cmeta]`` metadata).
To specify writeback mode:

.. code-block:: bash

   sudo lvconvert --type cache --cachemode writeback \
        --cachepool cache_vg/cache_data slow_vg/slow_lv

.. tip::

   A common production pattern: a 2 TB HDD VG with a 100–200 GB
   NVMe cache LV.
This provides near-SSD latency for the working set
   (hot data) while retaining HDD economics for cold and bulk data.
