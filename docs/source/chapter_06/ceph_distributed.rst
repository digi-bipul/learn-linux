.. _ceph-distributed:

Distributed & Network Storage (Ceph & NVMe-oF)
====================================================

Individual server storage hits physical limits — chassis bays, power
envelopes, and single points of failure.
Distributed storage
clusters aggregate capacity, performance, and resilience across
dozens or thousands of nodes.
This section introduces the dominant
open-source distributed storage platform (Ceph) and the network
transport revolution (NVMe-oF) that is reshaping enterprise SAN
architectures.
Ceph Architecture
------------------------

Ceph is a unified, software-defined storage system providing object,
block, and file interfaces from a single cluster.
Its architecture
is built on four core daemon types:

**RADOS (Reliable Autonomic Distributed Object Store)**
  The lowest layer — a self-managing, self-healing object store
  spread across all nodes.
RADOS handles data placement, replication,
  failure detection, and recovery through the **CRUSH** algorithm
  (Controlled Replication Under Scalable Hashing).
CRUSH computes
  the location of every object pseudo-randomly but deterministically,
  eliminating any central metadata lookup bottleneck.
**OSDs (Object Storage Daemons)**
  One OSD daemon per physical storage device (typically an HDD or
  NVMe drive).
Each OSD stores objects belonging to a subset of the
  RADOS cluster's placement groups (PGs) and performs local
  checksumming, scrubbing, and replication.
A production cluster
  might run 36 OSDs per node (e.g., 36 × 16 TB HDDs), each with its
  own ``osd.X`` directory, journal (on NVMe), and service port.
**MONs (Monitors)**
  A small, odd-numbered quorum (typically 3 or 5) of monitor daemons
  maintaining the **cluster map** — a master record of which OSDs
  are up, the CRUSH map, and authentication keys.
The monitors use
  the Paxos consensus algorithm to ensure consistency.
Clients and
  OSDs consult the monitors to learn the current cluster topology,
  then communicate directly with OSDs for data transfers — there is
  no central data broker.
**MDS (Metadata Server)**
  Only required for the CephFS (POSIX filesystem) interface.
The MDS
  manages the filesystem namespace — directory hierarchy, inode
  attributes, and file-to-object mappings — while file data is
  stored directly in RADOS objects.
The MDS can be deployed
  active-standby for high availability.
**Ceph Interfaces**:

- **RADOS Gateway (RGW)**: S3-compatible and Swift-compatible
  object storage REST API, backed by RADOS pools.
Used as the
  foundation of private S3 clouds.
- **RBD (RADOS Block Device)**: A virtual block device striped
  across RADOS objects.
Linux kernel ``rbd`` module or
  ``librbd`` provides a ``/dev/rbdX`` device.
Used by QEMU/KVM,
  OpenStack Cinder, and Kubernetes (via Rook/Ceph-CSI).
- **CephFS**: A distributed POSIX filesystem with near-linear
  metadata performance scaling through dynamic MDS subtree
  partitioning.
**Deployment and Operation**:

Modern Ceph is almost always deployed via **Cephadm** (orchestrator
integrated with the Ceph Manager daemon) or **Rook** (Kubernetes
operator).
A minimal cluster bootstrap:

.. code-block:: bash

   # Bootstrap first monitor + manager on a seed node
   cephadm bootstrap --mon-ip 192.168.1.10

   # Add OSDs (auto-discovers unused block devices)
   ceph orch device ls
   ceph orch apply osd --all-available-devices

   # Create an RBD pool and image
   ceph osd pool create mypool 128 128
   rbd create mypool/myimage --size 1T
   rbd map mypool/myimage            # appears as /dev/rbd0

**Placement Groups (PGs)** are the sharding unit: each pool is
divided 
into ``pg_num`` PGs, and each PG is replicated (or
erasure-coded) across a subset of OSDs as specified by the CRUSH
rule and pool ``size`` (replication factor).
Tuning ``pg_num`` is
critical — too few PGs cause data imbalance; too many PGs waste
memory and CPU on OSDs.
A common guideline is 100–200 PGs per OSD.

**Erasure coding** (``k+m``) stores each object as ``k`` data chunks
plus ``m`` coding chunks (parity), tolerating any ``m`` failures
while consuming ``(k+m)/k`` × the original space — far more
efficient than full replication at the cost of CPU overhead and
higher latency.
The Shift from iSCSI to NVMe-oF
---------------------------------------

**Legacy iSCSI** encapsulates SCSI commands within TCP/IP, enabling
block storage over standard Ethernet.
While ubiquitous, iSCSI
suffers from:

- The SCSI command set's limited queue depth and per-command
  overhead.
- TCP's in-order delivery requirement causing head-of-line blocking.
- Context-switch-heavy kernel TCP stacks.
**NVMe-over-Fabrics (NVMe-oF)** extends the NVMe protocol across a
network fabric, preserving its massive parallelism and low overhead.
NVMe-oF can run over:

- **RDMA (RoCE v2 or InfiniBand)**: Kernel-bypass, sub-10-µs
  latency, ideal for high-performance computing and databases.
- **TCP**: NVMe/TCP provides the NVMe command set over standard
  TCP/IP, bringing NVMe-oF to any Ethernet infrastructure without
  RDMA hardware.
Latency is higher than RDMA (~50–100 µs) but still
  significantly lower than iSCSI.
- **FC (Fibre Channel)**: NVMe/FC for legacy SAN environments
  transitioning to NVMe.
The Linux kernel's ``nvmet`` (NVMe target) subsystem can export
local NVMe namespaces or block devices as NVMe-oF targets:

.. code-block:: bash

   # Load NVMe target subsystem
   sudo modprobe nvmet nvmet-rdma nvmet-tcp

   # Create an NVMe subsystem and namespace
   sudo mkdir /sys/kernel/config/nvmet/subsystems/mysubsystem
   echo 1 |
sudo tee /sys/kernel/config/nvmet/subsystems/mysubsystem/attr_allow_any_host

   sudo mkdir /sys/kernel/config/nvmet/subsystems/mysubsystem/namespaces/1
   echo /dev/nvme0n1 |
sudo tee \
        /sys/kernel/config/nvmet/subsystems/mysubsystem/namespaces/1/device_path
   echo 1 |
sudo tee \
        /sys/kernel/config/nvmet/subsystems/mysubsystem/namespaces/1/enable

   # Bind to a TCP port
   sudo mkdir /sys/kernel/config/nvmet/ports/1
   echo 192.168.1.10 |
sudo tee /sys/kernel/config/nvmet/ports/1/addr_traddr
   echo tcp | sudo tee /sys/kernel/config/nvmet/ports/1/addr_trtype
   echo 4420 |
sudo tee /sys/kernel/config/nvmet/ports/1/addr_trsvcid
   sudo ln -s /sys/kernel/config/nvmet/subsystems/mysubsystem \
        /sys/kernel/config/nvmet/ports/1/subsystems/mysubsystem

On the initiator side, ``nvme connect`` discovers and attaches:

.. code-block:: bash

   sudo nvme discover -t tcp -a 192.168.1.10 -s 4420
   sudo nvme connect -t tcp -n mysubsystem -a 192.168.1.10 -s 4420

The remote namespace appears as a local ``/dev/nvmeXnY`` device,
usable identically to a physically attached NVMe drive.
Converged Architecture: Ceph + NVMe
-----------------------------------------

A modern data centre storage design might combine:

- **Ceph OSDs on commodity HDDs** for bulk, cost-optimised capacity
  with erasure coding (e.g., 8+2 on 10 × 16 TB HDDs per node,
  yielding 128 TiB usable per chassis with 2-failure tolerance).
- **NVMe-based Ceph OSDs** (or ``bluestore_block_db`` on NVMe with
  HDD data) for the Ceph metadata pool and RBD pools serving
  latency-sensitive VMs.
- **NVMe-oF gateways** that re-export RBD images as NVMe namespaces
  over RDMA to compute nodes, achieving sub-100-µs remote block
  access.
This architecture eliminates the traditional dichotomy between
"local fast storage" and "network slow storage" — with NVMe-oF,
network-attached flash can rival local NVMe in latency while
retaining the manageability, snapshotting, and resilience of a
distributed storage system.
.. rubric:: Key Takeaways for Chapter 6

- Understand your hardware: NVMe vs. SATA determines the ceiling of
  your storage performance before a single line of configuration is
  written.
- Match filesystem to workload: ext4 for general purpose, XFS for
  large-scale sequential, Btrfs/ZFS for data integrity and
  snapshots.
- LVM decouples logical storage from physical devices — a
  prerequisite for elastic growth and caching.
- RAID provides redundancy, but only filesystem-native RAID
  (Btrfs/ZFS) protects against silent data corruption.
- Swap is not obsolete — zswap and zram make it smarter.
- Quotas are policy;
monitoring is visibility — both are
  operational necessities.
- At scale, Ceph and NVMe-oF dissolve the boundary between local
  and remote storage, enabling data centre-wide storage fabrics.
