.. _chapter-06:

Chapter 6: Storage, Filesystems & Advanced Volume Management
=============================================================

Storage is the persistent backbone of every Linux system.
Whether you are
administering a single embedded device with 8 GB of eMMC flash, a
workstation with multiple NVMe drives, or a petabyte-scale Ceph cluster,
the abstractions you master in this chapter form the foundation of
reliable data management.
In Chapters 1 through 5, you learned to operate the terminal, navigate the
shell, manage users and permissions, control processes and init systems,
and install software through diverse package management strategies.
Those
skills assumed that storage *just worked*. Now we pull back the curtain.
This chapter takes you from the physical disk through the kernel I/O
stack, filesystem semantics, logical volume aggregation, RAID
redundancy, memory-backed swap compression, quota enforcement, and
finally into distributed network storage.
By the end, you will be able
to design a storage layout for any scenario — from a single-disk laptop
to a multi-node enterprise SAN — and articulate *why* each design
decision matters.
.. toctree::
   :maxdepth: 2
   :titlesonly:

   disk_anatomy
   filesystems_tuning
   mounting_fstab
   lvm
   raid
   swap_zram
   quotas_monitoring
   ceph_distributed

Key Learning Objectives
-----------------------

- Distinguish MBR from GPT partitioning and select the appropriate
  tool for each.
- Articulate the architectural difference between SATA/SAS and NVMe,
  including the role of PCIe lanes and kernel namespaces.
- Create and tune ext4, XFS, and Btrfs filesystems with an
  understanding of inode geometry, journaling modes, and SSD
  wear-leveling implications.
- Write robust ``/etc/fstab`` entries and contrast them with modern
  ``systemd.mount`` units.
- Build, extend, snapshot, and cache LVM volume groups spanning
  heterogeneous devices.
- Design and recover ``mdadm`` software RAID arrays, and compare them
  with integrated filesystem RAID in Btrfs and ZFS.
- Configure swap partitions, swap files, ``zram``, and ``zswap`` to
  optimise memory pressure behaviour.
- Enforce disk quotas and profile I/O with ``iostat`` and ``ncdu``.
- Describe Ceph RADOS architecture and the role of NVMe-over-Fabrics
  in modern data centres.
