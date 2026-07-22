.. _swap-zram:

6.6 Swap & Memory Compression
==============================

Swap is the kernel's mechanism for extending virtual memory beyond
physical RAM by paging anonymous (non-file-backed) pages to a
secondary storage device.
Swap is not a substitute for RAM — it is a
safety valve that allows the system to survive transient memory
spikes and to evict cold anonymous pages, freeing RAM for active
working sets and filesystem cache.
6.6.1 Swap Partitions vs. Swap Files
-------------------------------------

**Swap partitions** are dedicated block devices (a partition of type
``0x82`` on MBR or GUID ``0657FD6D-A4AB-43C4-84E5-0933C84B4F4F`` on
GPT).
They are created during partitioning and enabled with:

.. code-block:: bash

   sudo mkswap /dev/sda2
   sudo swapon /dev/sda2

Advantages: contiguous, cannot fragment, independent of filesystem,
and can be used for hibernation (suspend-to-disk) as the kernel can
address the swap area directly during early resume.
**Swap files** reside on a mounted filesystem. They are created with
``fallocate`` or ``dd`` and enabled identically:

.. code-block:: bash

   sudo fallocate -l 4G /swapfile
   sudo chmod 600 /swapfile
   sudo mkswap /swapfile
   sudo swapon /swapfile

Advantages: can be created, resized, or removed without repartitioning.
Disadvantages on older filesystems: fragmentation risk; Btrfs
requires special handling (CoW and compression must be disabled —
use ``chattr +C /swapfile`` before allocation, and do not use
``fallocate`` on Btrfs; use ``dd if=/dev/zero`` instead).
.. warning::

   Btrfs does not support swap files in kernels before Linux 5.0.
Even on 5.0+, you must disable CoW and compression. On Btrfs,
   strongly prefer a swap partition or a dedicated swap LV in LVM.
6.6.2 Managing Swap with ``swapon`` and ``swapoff``
----------------------------------------------------

.. code-block:: bash

   swapon --show                    # list active swap areas
   swapon -s                        # summary (equivalent to cat /proc/swaps)
   swapon -p 10 /dev/sdc1           # enable with priority 10
   swapoff /dev/sdc1      
           # disable (pages are paged back into RAM)
   swapoff -a && swapon -a          # cycle all swap (reclaim fragmented swap)

**Swap priority** (-1 to 32767) determines the order in which swap
areas are used.
Higher-priority areas are filled first. This allows
**tiered swap** — for example, a small, fast NVMe swap area (priority
100) for burst overflow, backed by a large HDD swap (priority 1)
for sustained memory pressure.
6.6.3 ``vm.swappiness`` Tuning
-------------------------------

The kernel parameter ``vm.swappiness`` (range 0–200, default 60)
controls the relative weight given to reclaiming anonymous pages
(swapping) versus reclaiming file-backed pages (dropping clean page
cache).
A higher value favours swapping; a lower value favours
keeping anonymous pages in RAM and evicting page cache.
.. code-block:: bash

   cat /proc/sys/vm/swappiness
   sudo sysctl vm.swappiness=10           # runtime change
   echo "vm.swappiness=10" |
sudo tee -a /etc/sysctl.d/99-swap.conf  # persistent

Guidelines:

- **Desktop/laptop with SSD**: 10–30. Keep hot anonymous pages in
  RAM;
the SSD is fast enough to handle occasional swapping.
- **Database server**: 0–10. Databases manage their own caching;
system swapping is almost always harmful to latency.
- **HDD-only system**: 60–100.
The performance gap between RAM and
  HDD is so large that the kernel should aggressively evict page
  cache to avoid the multi-millisecond penalty of paging anonymous
  memory to HDD.
6.6.4 Modern Memory Compression: ``zram`` and ``zswap``
--------------------------------------------------------

Traditional swap to disk incurs I/O latency measured in microseconds
(NVMe) or milliseconds (HDD).
Compression-based alternatives keep
swap data in RAM, trading a modest CPU cost for a dramatic reduction
in effective memory pressure.
**zram** creates a compressed block device in RAM. It appears as a
regular block device (``/dev/zram0``) and can be used as swap or
formatted with a filesystem:

.. code-block:: bash

   sudo modprobe zram num_devices=1
   echo 4G |
sudo tee /sys/block/zram0/disksize
   sudo mkswap /dev/zram0
   sudo swapon -p 32767 /dev/zram0   # highest priority

Internally, zram allocates memory only for the compressed data, not
the uncompressed slab.
Typical compression ratios range from 2:1 to
5:1 for general workloads (using lz4, lzo-rle, zstd, or deflate).
Thus a 4 GiB zram swap may only consume 1–2 GiB of physical RAM.
.. code-block:: bash

   cat /sys/block/zram0/mm_stat
   # orig_data_size  compr_data_size  mem_used_total  mem_limit  mem_used_max
   #     4194304000      1048576000       1100000000          0    1100000000

``zramctl`` provides a human-readable summary:

.. code-block:: bash

   zramctl /dev/zram0

**zswap** is a compressed write-back cache *in front of* a physical
swap device.
Pages being swapped out are compressed and stored in a
RAM pool;
when the pool fills, the *least recently used* compressed
pages are evicted to the physical swap device.
This provides the
speed advantage of compression without consuming unbounded RAM.
Enable zswap with:

.. code-block:: bash

   sudo sh -c 'echo 1 > /sys/module/zswap/parameters/enabled'
   sudo sh -c 'echo lz4 > /sys/module/zswap/parameters/compressor'
   sudo sh -c 'echo z3fold > /sys/module/zswap/parameters/zpool'

Key parameters:

- ``compressor``: ``lzo``, ``lz4`` (recommended), ``zstd``,
  ``deflate``.
``lz4`` offers the best speed/ratio trade-off.
- ``max_pool_percent``: Maximum percentage of total RAM the zswap
  pool may occupy (default 20 %).
- ``accept_threshold_percent``: Pages compressing above this
  threshold are rejected (stored uncompressed on the backing swap
  device).
Default 90 % — pages that don't compress to 90 % of
  original size are not worth the RAM cost.
**Comparison**:

.. list-table::
   :header-rows: 1

   * - Feature
     - zram
     - zswap
   * - Requires backing swap device
     - No
     - **Yes** (physical swap partition or file)
   * - Memory consumed
     - Bounded by ``disksize`` / compression ratio
     - Bounded by ``max_pool_percent`` of RAM
   * - Eviction when pool full
     - I/O error (swap full)
     - Writes to backing 
swap device
   * - Use case
     - Embedded, single-drive systems without disk swap
     - Servers with SSD/NVMe swap backing storage
   * - CPU overhead
     - Moderate (all pages compressed/decompressed)
     - Moderate (hottest pages stay compressed in RAM)

.. tip::

   For a modern desktop or server with NVMe swap, use **zswap** — it
   combines the speed of RAM-based compression with the safety of
   disk-backed overflow.
For an embedded or container host where
   disk swap is unavailable or undesirable, use **zram**.
