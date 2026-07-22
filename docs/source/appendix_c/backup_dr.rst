.. _app-c-backup:

------------------------------------------------------------------------------
C.8  Backup & Disaster Recovery
------------------------------------------------------------------------------

------------------------------------------------------------------------------
C.8.1  Backup Strategy Design (3-2-1 Rule)

.. list-table:: The 3-2-1 Backup Rule
   :header-rows: 1
   :widths: 15 85

   * - Rule
     - Meaning
   * - **3** copies
     - 1 primary + 2 backups (e.g., live data + local backup + remote backup)
   * - **2** different media
     - Different storage types (e.g., external HDD + cloud storage, or tape + NAS)
   * - **1** off-site
     - At least one copy stored at a different physical location

.. rubric:: Recovery Point Objective (RPO) vs. Recovery Time Objective (RTO)

.. list-table::
   :header-rows: 1
   :widths: 15 40 45

   * - Metric
     - Definition
     - Example
   * - RPO
     - Maximum acceptable data loss (time between backups)
     - 1 hour → hourly backups; 24 hours → daily backups
   * - RTO
     - Maximum acceptable downtime until service is restored
     - 15 minutes → hot standby; 4 hours → restore from backup

------------------------------------------------------------------------------
C.8.2  Command-Line Backup Tools

.. list-table:: Linux backup tools comparison
   :header-rows: 1
   :widths: 15 25 30 30

   * - Tool
     - Use case
     - Pros
     - Cons
   * - ``rsync``
     - File-level, incremental
     - Fast, delta-transfer, over SSH, widely available
     - No built-in dedup, no compression at source
   * - ``tar``
     - Full directory archives
     - Pipe to compression (gz/bz2/xz); preserves permissions
     - No incremental (unless using ``--listed-incremental``)
   * - ``dd``
     - Block-level clones
     - Bit-perfect, copies everything including boot sector
     - No compression, copies empty space, slow over network
   * - ``duplicity``
     - Encrypted, incremental
     - GPG encryption; supports S3, SFTP, rsync
     - Slower for large datasets; complex command syntax
   * - ``borgbackup``
     - Deduplicating, compressed, encrypted
     - Excellent dedup; mountable archives; fast
     - Not pre-installed; remote repos need borg on both ends
   * - ``restic``
     - Deduplicating, encrypted to many backends
     - Supports S3, B2, Azure, Google Cloud, local, SFTP
     - Slower than borg for local backups; no compression levels
   * - ``rclone``
     - Cloud sync
     - Supports 40+ providers; encrypted; mounts as FUSE
     - No versioning built-in; sync is one-way or two-way

.. code-block:: bash
   :caption: rsync backup recipes

   # Local backup with archive, compression, progress
   rsync -avz --progress /source/dir/ /backup/dir/

   # Remote backup over SSH
   rsync -avz -e ssh /local/dir/ user@server:/backup/dir/

   # Incremental backup with hardlinks (time-machine style)
   # Requires: mkdir -p /backup/{current,latest}
   rsync -av --delete --link-dest=/backup/latest /source/dir/ /backup/current/
   # Then rotate: rm -f latest; ln -s current latest

   # Exclude patterns
   rsync -av --exclude='*.tmp' --exclude='.cache/' /source/ /dest/

   # Bandwidth limit (100 KB/s)
   rsync -av --bwlimit=100 /source/ /dest/

   # Dry-run (test before actual execution)
   rsync -av --dry-run /source/ /dest/

.. code-block:: bash
   :caption: tar backup recipes

   # Create compressed archive
   tar -czf backup.tar.gz /path/to/dir           # gzip
   tar -cjf backup.tar.bz2 /path/to/dir          # bzip2
   tar -cJf backup.tar.xz /path/to/dir           # xz (best compression, slowest)

   # Exclude directories
   tar -czf backup.tar.gz --exclude='.cache' --exclude='temp' /home/user

   # Backup with date stamp
   tar -czf "backup-$(date +%Y%m%d-%H%M%S).tar.gz" /important/dir

   # Incremental backup (using snapshot file)
   tar -czg backup.snap -f monday.tar.gz /var/www
   tar -czg backup.snap -f tuesday.tar.gz /var/www  # Only changes since Monday

   # Extract archive
   tar -xzf backup.tar.gz              # -C /target/dir for custom location

   # List contents without extracting
   tar -tzf backup.tar.gz | head -20

.. code-block:: bash
   :caption: dd disk cloning

   # Clone entire disk to another disk
   sudo dd if=/dev/sda of=/dev/sdb bs=64K conv=noerror,sync status=progress

   # Clone to an image file (with compression)
   sudo dd if=/dev/sda bs=64K conv=noerror,sync status=progress | gzip > disk_image.img.gz

   # Restore from compressed image
   gunzip -c disk_image.img.gz | sudo dd of=/dev/sda bs=64K status=progress

   # Clone MBR only (first 512 bytes)
   sudo dd if=/dev/sda of=mbr_backup.bin bs=512 count=1

   # Clone a partition
   sudo dd if=/dev/sda1 of=/backup/sda1.img bs=64K status=progress

   # WARNING: dd has no safety checks — verify input and output device carefully
   # "if" = input file (source), "of" = output file (DESTINATION — will be overwritten!)

.. code-block:: bash
   :caption: Borg backup example

   # Initialize a repository
   borg init --encryption=repokey-blake2 /mnt/backup/borg_repo

   # Create a backup
   borg create --verbose --list --stats --compression lz4 \
       /mnt/backup/borg_repo::{hostname}-{now:%Y-%m-%d_%H:%M} \
       /home /etc /var/www

   # List archives
   borg list /mnt/backup/borg_repo

   # Mount an archive (FUSE)
   mkdir /tmp/borgmount
   borg mount /mnt/backup/borg_repo::archive-name /tmp/borgmount
   ls -la /tmp/borgmount
   borg umount /tmp/borgmount

   # Prune old backups (keep 7 daily, 4 weekly, 6 monthly)
   borg prune --verbose --list \
       --keep-daily=7 --keep-weekly=4 --keep-monthly=6 \
       /mnt/backup/borg_repo

   # Extract specific files from an archive
   borg extract /mnt/backup/borg_repo::archive-name etc/nginx/nginx.conf

.. code-block:: bash
   :caption: Restic backup example

   # Initialize a repository
   restic init --repo /mnt/backup/restic_repo

   # Create a backup
   restic --repo /mnt/backup/restic_repo backup /home /etc

   # List snapshots
   restic --repo /mnt/backup/restic_repo snapshots

   # Restore a snapshot
   restic --repo /mnt/backup/restic_repo restore latest --target /mnt/restore

   # Mount a snapshot
   mkdir /tmp/resticmount
   restic --repo /mnt/backup/restic_repo mount /tmp/resticmount

   # Forget old snapshots
   restic --repo /mnt/backup/restic_repo forget --keep-daily 7 --keep-weekly 4 --prune

------------------------------------------------------------------------------
C.8.3  Disaster Recovery Plan Template

.. rubric:: DR Plan Checklist

.. code-block:: text

   PRE-INCIDENT:
   ☐ Documented backup schedule and retention policy
   ☐ Backup monitoring and alerting in place
   ☐ Backup restore tested at least quarterly
   ☐ Off-site backups verified (can you actually read them?)
   ☐ RPO and RTO documented and agreed with stakeholders
   ☐ Contact list for key personnel (sysadmin, DBA, manager)
   ☐ DR runbook printed (hard copy — don't depend on network access)

   INCIDENT RESPONSE:
   ☐ Assess scope: single server, datacenter, region?
   ☐ Notify stakeholders
   ☐ Isolate affected systems (disconnect network if needed)
   ☐ Determine root cause (don't restore while vulnerability exists)
   ☐ Provision replacement hardware/VM
   ☐ Restore OS from backup or reimage
   ☐ Restore data from latest good backup
   ☐ Verify data integrity and service functionality
   ☐ Switch DNS/LB to restored system
   ☐ Monitor for issues

   POST-INCIDENT:
   ☐ Root cause analysis document
   ☐ Backup/restore procedure improvement
   ☐ Update RPO/RTO if needed
   ☐ Schedule additional recovery tests

------------------------------------------------------------------------------
C.8.4  Testing Backup Restores

.. code-block:: bash
   :caption: Backup verification procedures

   # Test 1: Check archive integrity
   tar -tzf backup.tar.gz > /dev/null && echo "Archive is valid" || echo "Archive corrupted"
   borg check /mnt/backup/borg_repo
   restic check --repo /mnt/backup/restic_repo

   # Test 2: Restore to a temporary directory
   mkdir /tmp/restore_test
   tar -xzf backup.tar.gz -C /tmp/restore_test
   # Verify file counts and sizes
   diff -r --brief /original/dir /tmp/restore_test/dir 2>/dev/null | head

   # Test 3: Database restore test
   # MySQL
   mysql -u root -p < backup.sql
   # PostgreSQL
   pg_restore -d testdb backup.dump
   # Verify with a SELECT query
   psql -d testdb -c "SELECT count(*) FROM some_table;"

   # Test 4: Boot from a full disk backup
   # Restore disk image to a spare disk or VM, boot and verify services
   sudo dd if=/backup/disk.img of=/dev/sdb bs=64K status=progress
   # Boot /dev/sdb on test hardware or VM
