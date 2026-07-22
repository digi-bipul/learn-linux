.. _quotas-monitoring:

6.7 Disk Quotas & Monitoring
=============================

Storage systems are finite resources shared among users and
applications.
Without enforcement mechanisms, a single runaway
process or careless user can exhaust all available space, causing
cascading failures. Quotas impose limits;
monitoring tools provide
visibility.

6.7.1 Usage Analysis: ``df``, ``du``, and ``ncdu``
----------------------------------------------------

``df`` reports filesystem-level usage:

.. code-block:: bash

   df -h                          # human-readable sizes
   df -i                          # inode usage (critical for small-file
                   
               #   workloads — you can run out of inodes
                                  #   while df -h shows free space!)
   df -T                          # include filesystem 
type
   df -x tmpfs -x devtmpfs        # exclude pseudo-filesystems

``du`` estimates file and directory space usage:

.. code-block:: bash

   du -sh /home/* # summary per user directory
   du -h --max-depth=2 /var       # two levels deep
   du -ah --threshold=100M /      # files > 100 MiB anywhere under /
   du -sh --apparent-size *.log   # logical size (sparse files 
reported correctly)

``du`` reads the directory tree, stat-ing every file. On large
filesystems this can be slow.
``ncdu`` (NCurses Disk Usage) provides
an interactive, navigable interface with on-the-fly sorting and
deletion:

.. code-block:: bash

   sudo ncdu /home                # interactive analysis
   ncdu -x /                      # stay on one filesystem (don't cross mounts)

6.7.2 I/O Profiling with ``iostat``
------------------------------------

``iostat`` (from the ``sysstat`` package) reports per-device I/O
statistics derived from ``/proc/diskstats``:

.. code-block:: bash

   iostat -x 2         
           # extended stats, 2-second intervals
   iostat -p sda -x 1 5           # per-partition for sda, 5 samples
   iostat -m                      # output in MB/s instead of KB/s

Key fields in ``iostat -x`` output:

.. list-table::
   :header-rows: 1

   * - Field
     - Meaning
   * - ``r/s``, ``w/s``
  
     - Reads/writes per second (IOPS)
   * - ``rkB/s``, ``wkB/s``
     - Kilobytes read/written per second
   * - ``await``
     - Average I/O latency in ms (queue + service time)
   * - ``r_await``, ``w_await``
     - Read/write average latency
   * - ``%util``
     - Percentage of time the device had at least one request in
       flight (rough utilisation proxy;
misleading for
       multi-queue NVMe)

.. warning::

   ``%util`` is calculated as (busy time / elapsed time) × 100. For
   NVMe drives that can service many parallel requests, 100 %
   utilisation does not mean the drive is saturated — it means it
   was busy for every interval, but it may have significant spare
   parallelism.
Use ``avgqu-sz`` (average queue size) and
   ``await`` as better saturation indicators.
For deeper analysis, ``ioping`` measures per-I/O latency:

.. code-block:: bash

   sudo ioping -c 10 /mnt/data    # 10 I/O latency samples
   sudo ioping -R /dev/nvme0n1    # raw device, bypass filesystem

And ``fio`` benchmarks realistic mixed workloads:

.. code-block:: bash

   fio --name=randrw --ioengine=libaio --direct=1 --bs=4k \
       --rw=randrw --rwmixread=70 --size=1G --numjobs=4 \
       --runtime=60 --time_based --filename=/mnt/data/fio_test

6.7.3 User and Group Quotas
----------------------------

Linux quota support must be enabled both in the kernel
(``CONFIG_QUOTA``) and on the filesystem.
Quotas track and limit
two resources:

- **Blocks**: Disk space in KiB (``block hard limit`` / ``block soft limit``).
- **Inodes**: Number of files/directories (``inode hard limit`` /
  ``inode soft limit``).
A **soft limit** can be exceeded for a configurable grace period
(default 7 days), after which it is enforced as a hard limit.
The
**hard limit** is an absolute ceiling.

**Setup on ext4/XFS**:

1. Enable quota in ``/etc/fstab``:

   .. code-block:: text

      UUID=ghi789-...  /home  ext4  defaults,usrquota,grpquota  0  2
      # or for XFS:
      UUID=ghi789-...  /home  xfs   defaults,uquota,gquota,pquota  0  2

2. Remount and initialise:

   .. code-block:: bash

      sudo mount -o remount /home
      sudo quotacheck -cugm /home       # create quota database files
   
   sudo quotaon /home                 # enable enforcement

   On XFS, quotas are part of the filesystem metadata;
``quotacheck``
   is not needed. Simply mount with ``uquota``.
3. Set limits with ``edquota`` or ``setquota``:

   .. code-block:: bash

      # Interactive per-user editor
      sudo edquota -u alice

      # Non-interactive (block soft, block hard, inode soft, inode hard)
      sudo setquota -u alice 5000000 5500000 100000 110000 /home

   The block limits are in 1 KiB blocks.
The above grants Alice a
   5 GiB soft limit, 5.5 GiB hard limit, 100,000 inode soft limit,
   and 110,000 inode hard limit.
4. Set grace period:

   .. code-block:: bash

      sudo setquota -t 864000 864000 /home   # 10 days in seconds for blocks/inodes

5. Report:

   .. code-block:: bash

      sudo repquota /home            # per-user/group report
      sudo repquota -s /home         # human-readable sizes
      quota -s                 
      # current user's own usage vs. limits

For **project quotas** (XFS only), limits are applied to an
arbitrary directory tree identified by a project ID, rather than
to a user or group.
This is useful for shared project directories:

.. code-block:: bash

   echo "42:/srv/project-alpha" |
sudo tee -a /etc/projid
   echo "project-alpha:42" | sudo tee -a /etc/projects
   sudo xfs_quota -x -c 'project -s project-alpha' /srv
   sudo xfs_quota -x -c 'limit -p bsoft=100g bhard=110g project-alpha' /srv

6.7.4 Monitoring I/O Pressure
------------------------------

Beyond ``iostat``, modern kernels expose **pressure stall
information (PSI)** in ``/proc/pressure/``:

.. code-block:: bash

   cat /proc/pressure/io
   # some avg10=2.34 avg60=1.10 avg300=0.56 total=123456789
   # full avg10=1.20 avg60=0.50 avg300=0.22 total=98765432

The ``some`` line indicates the percentage of time *some* tasks were
stalled on I/O;
``full`` indicates all non-idle tasks were stalled.
Values above ~10 % ``avg10`` warrant investigation.
Tools like ``bpftrace`` can dynamically trace I/O latency
distributions:

.. code-block:: bash

   sudo bpftrace -e 'kprobe:blk_mq_start_request
       { @start[arg0] = nsecs;
}
       kprobe:blk_update_request
       { $ns = nsecs - @start[arg0];
delete(@start[arg0]);
         @lat_us = hist($ns / 1000); }'

This produces a microsecond-latency histogram of every block I/O
operation, invaluable for pinpointing outlier latencies.
