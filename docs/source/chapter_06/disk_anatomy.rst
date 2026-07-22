.. _disk-anatomy:

6.1 Disk Anatomy & Hardware Interfaces
=======================================

Before a single byte of data can be stored, the kernel must discover,
identify, and partition the physical medium.
This section dissects
the hardware and low-level software abstractions that make that
possible.
6.1.1 Physical Media: HDD vs. SSD
----------------------------------

**Rotational Hard Disk Drives (HDDs)** store data on magnetised
platters spinning at 5,400 to 15,000 RPM.
A mechanical actuator arm
positions read/write heads over concentric **tracks**, each divided
into **sectors** — traditionally 512 bytes, though modern "Advanced
Format" drives use 4,096-byte (4K) physical sectors while emulating
512-byte logical sectors (512e) for compatibility.
The key performance implication is **seek time**: the head must
physically move to the correct track (typically 4–9 ms) and wait for
the sector to rotate under it (rotational latency, ~2–4 ms at 7,200
RPM).
Sequential I/O can reach 200–250 MB/s on modern enterprise
drives, but random I/O collapses to ~1–2 MB/s because of the
mechanical penalty for each seek.
**Solid State Drives (SSDs)** eliminate moving parts by storing data
in NAND flash cells.
Reads and writes are electronic, yielding
sub-100-µs latency and throughput limited primarily by the
interface — 550 MB/s for SATA III, or several GB/s for NVMe.
The
penalty shifts from mechanical seek to **write amplification**: flash
cells must be erased in large blocks before they can be rewritten, so
the drive's internal Flash Translation Layer (FTL) remaps logical
blocks to physical pages, often writing extra data to consolidate
free space (garbage collection).
6.1.2 Partition Tables: MBR vs. GPT
-------------------------------------

A **partition table** carves a block device into disjoint regions.
Two standards dominate:

**Master Boot Record (MBR)**
  Originating with the IBM PC in 1983, the MBR occupies the first
  512-byte sector of the disk (LBA 0).
The first 446 bytes hold
  bootstrap code; the next 64 bytes define four **primary**
  partition entries (16 bytes each);
the final two bytes are the
  magic signature ``0x55AA``.
Each 16-byte entry encodes:

  - 1 byte: bootable flag (``0x80`` = active, ``0x00`` = inactive).
- 3 bytes: CHS (Cylinder-Head-Sector) start address (legacy).
  - 1 byte: partition type ID (e.g., ``0x83`` = Linux, ``0x82`` =
    Linux swap, ``0x8E`` = Linux LVM).
- 3 bytes: CHS end address.
  - 4 bytes: LBA of first sector (32-bit).
- 4 bytes: number of sectors (32-bit).

  The 32-bit sector count limits MBR to 2 TiB (2³² × 512 bytes).
To exceed four partitions, one primary partition is designated an
  **extended** partition, inside which **logical** partitions are
  chained via Extended Boot Records (EBRs).
This chain is fragile
  and no longer recommended.

**GUID Partition Table (GPT)**
  Part of the UEFI specification, GPT uses 64-bit LBA addresses,
  supporting disks up to 8 ZiB (9.4 × 10²¹ bytes).
The table is
  stored in two locations for redundancy:

  - **LBA 0**: Protective MBR — a valid MBR with a single partition
    of type ``0xEE`` covering the entire disk, preventing legacy
    tools from corrupting the GPT.
- **LBA 1**: GPT header, containing a CRC32, the table's starting
    LBA, number of entries, and entry size.
- **LBA 2–33**: Partition entries (typically 128 entries × 128
    bytes each).
Each entry holds a partition type GUID
    (e.g., ``0FC63DAF-8483-4772-8E79-3D69D8477DE4`` for Linux
    filesystem data), a unique partition GUID, start/end LBAs,
    attributes (64-bit flags), and a UTF-16LE name.
- **Last LBA**: Backup GPT header.
  - **Penultimate LBAs**: Backup partition entry array.
GPT is the default for modern systems and is required for booting
  in native UEFI mode.
6.1.3 Partitioning Tools: ``fdisk``, ``gdisk``, ``parted``
-----------------------------------------------------------

``fdisk``
  The traditional MBR tool, now also GPT-aware.
Invoke it on a
  device (e.g., ``fdisk /dev/sda``) to enter its interactive shell.
Key sub-commands:

  - ``p`` — print the current partition table.
- ``g`` — create a new empty GPT partition table.
  - ``n`` — create a new partition;
you are prompted for partition
    number, first sector, and last sector (or size, e.g., ``+20G``).
- ``t`` — change partition type (use ``L`` to list hex codes or
    GUID aliases).
- ``w`` — write the table to disk and exit.
.. code-block:: bash

     # Create a GPT table with two partitions
     sudo fdisk /dev/sdb
     Command (m for help): g           # new GPT table
     Command (m for help): n           # partition 1, default first
     Partition number (1-128, default 1):
     First sector (2048-..., default 2048):
     Last sector, +/-sectors or +/-size{...} (2048-..., default ...): +500M
 
     Command (m for help): t           # set type to EFI System
     Partition type or alias (type L to list all): 1
     Command (m for help): n           # partition 2
     Partition number (2-128, default 2):
     First sector (..., default ...):
     Last sector, +/-sectors or +/-size{...}: +10G
     Command (m for help): w

  .. 
note::

     ``fdisk`` does **not** write changes until ``w`` is issued.
If you make a mistake, ``q`` quits without saving.

``gdisk``
  A GPT-specific tool with an interface nearly identical to
  ``fdisk``.
Use it when you want full GPT-feature access (e.g.,
  setting partition attributes or names) without the legacy MBR
  baggage.
The sub-commands mirror ``fdisk`` (``n``, ``d``, ``p``,
  ``w``), and ``?`` lists all available commands.
``parted``
  A higher-level, scriptable tool supporting both MBR and GPT:

  .. code-block:: bash

     # Non-interactive: create a GPT label and a single ext4 partition
     sudo parted /dev/sdc mklabel gpt
     sudo parted /dev/sdc mkpart primary ext4 0% 100%

  The ``-s`` flag suppresses prompts.
``parted`` supports unit
  specifications (``s`` for sectors, ``B``, ``KiB``, ``MiB``,
  ``GiB``, ``%`` for percentage of device) and alignment control
  (``align-check optimal 1``).
6.1.4 Querying Block Devices: ``lsblk`` and ``blkid``
------------------------------------------------------

``lsblk`` (list block devices) prints a tree of block devices and
their relationships.
The default output shows name, major:minor,
size, read-only status, type, and mount point.
Essential options:

.. code-block:: bash

   lsblk                          # tree view
   lsblk -f                       # include filesystem UUIDs and labels
   lsblk -o +MODEL,SERIAL,TRAN    # add hardware details
   lsblk -d -o NAME,ROTA          # 1=rotational (HDD), 0=non-rotational (SSD)
  
 lsblk -J                       # JSON output for scripting

``blkid`` queries or prints block device attributes — UUID, label,
filesystem type, and PARTUUID:

.. code-block:: bash

   blkid /dev/sda1                # query one device
   blkid -L "rootfs"              # find device by label
   blkid -U "550e8400-..."      
  # find device by UUID
   sudo blkid                     # scan all devices (needs root for probing)

.. tip::

   Always use UUIDs or labels in ``/etc/fstab`` and bootloader
   configurations rather than ``/dev/sdX`` nodes, because the kernel
   assigns ``sdX`` names in discovery order, which can change across
   reboots or when disks are added or removed.
6.1.5 Interface Architectures: SATA/SAS vs. NVMe
-------------------------------------------------

**SATA (Serial ATA)** is the legacy consumer/prosumer interface.
The
AHCI (Advanced Host Controller Interface) driver provides a single
command queue up to 32 commands deep per port.
The SATA III
theoretical ceiling is 6 Gbps (~550 MB/s after 8b/10b encoding).
SATA SSDs are bottlenecked by this bus, not by the NAND.
**SAS (Serial Attached SCSI)** extends the SCSI command set over a
serial physical layer, targeting enterprise workloads.
SAS supports
dual-porting for multipath failover, higher signal voltages for
longer cables, and the SCSI command set's rich error handling.
SAS
controllers typically appear as ``/dev/sdX`` devices through the
SCSI mid-layer.

**NVMe (Non-Volatile Memory Express)** is a protocol, not a physical
connector, designed from scratch for non-volatile memory connected
directly to the CPU via PCI Express (PCIe) lanes.
Unlike AHCI, NVMe
supports up to 65,535 I/O queues, each 65,536 commands deep,
exploiting the massive parallelism of modern multi-core CPUs and
flash dies.
NVMe devices appear as ``/dev/nvme0n1``, ``/dev/nvme1n1``, etc. The
naming convention is:

.. code-block:: text

   nvme<controller>n<namespace>

A single NVMe controller can expose multiple **namespaces** — logical
block devices carved from the same physical NAND, analogous to SCSI
Logical Units.
Namespaces are managed with ``nvme-cli``:

.. code-block:: bash

   sudo nvme list                          # list all NVMe devices
   sudo nvme id-ctrl /dev/nvme0            # controller identify data
   sudo nvme list-ns /dev/nvme0            # list namespace IDs
   sudo nvme id-ns /dev/nvme0 -n 1         
# namespace details
   sudo nvme create-ns /dev/nvme0 -s 100000000 -c 100000000 -f 0
   sudo nvme attach-ns /dev/nvme0 -n 1 -c 0

``smartctl`` (from ``smartmontools``) reads NVMe SMART/health data:

.. code-block:: bash

   sudo smartctl -a /dev/nvme0

Key NVMe health indicators include ``Percentage Used`` (endurance
consumed), ``Media Errors``, and ``Critical Warning`` bits.
.. admonition:: Architectural Decision: Where to Place What

   On modern servers, a common strategy is:

   - **NVMe namespace 1**: Operating system, databases, and
     latency-sensitive application data.
- **NVMe namespace 2** or a second NVMe drive: Write-ahead logs
     (WAL) for PostgreSQL, ZFS Intent Log (ZIL), or journal
     devices.
- **SATA/SAS HDDs**: Bulk, sequential-log data such as
     ``/var/log``, backup staging, and Ceph OSD backing devices.
- **NVMe as LVM cache**: Accelerate a large HDD-backed volume
     group with ``lvmcache`` (see :ref:`lvm-caching`).
