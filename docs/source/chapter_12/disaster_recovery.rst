============================================================
12.3 Disaster Recovery & Ransomware Defences
============================================================

12.3.1 The Threat Landscape in 2026
=====================================

Ransomware operators now exfiltrate data before encrypting (double extortion), delete
backup catalogs, and linger inside networks for months. A disaster recovery plan that
assumes "we will restore from tape" is obsolete.

12.3.2 The 3-2-1-1 Rule
==========================

* **3** copies of your data.
* **2** different storage media types.
* **1** copy off-site.
* **1** copy **immutable** (cannot be modified or deleted, even by root).

+----------+----------------------------+-----------------------------------+
| Copy #   | Location                   | Characteristics                  |
+==========+============================+===================================+
| 1        | Production server (local)  | Hot, online, fast restore         |
+----------+----------------------------+-----------------------------------+
| 2        | Local backup server        | Different machine, deduplicated   |
+----------+----------------------------+-----------------------------------+
| 3        | Remote (cloud/colocation)  | Encrypted in transit and at rest  |
+----------+----------------------------+-----------------------------------+
| 1 (Imm)  | Object lock / WORM media   | Append-only, non-erasable         |
+----------+----------------------------+-----------------------------------+

.. note::
   True immutability requires hardware WORM media, S3 Object Lock with retention
   policies, or a physically air-gapped system. Read-only permissions are insufficient
   against a compromised root account.

12.3.3 BorgBackup: Deduplicating, Encrypted Backups
=====================================================

`BorgBackup <https://www.borgbackup.org/>`_ splits data into chunks, hashes them, and
stores unique chunks only once. Supports authenticated encryption (chacha20-poly1305).

Installation
------------

.. code-block:: bash

    # RHEL 9 (EPEL)
    dnf install -y epel-release dnf install -y borgbackup
    # Debian 12
    apt-get install -y borgbackup

Creating a Repository
---------------------

.. code-block:: bash

    borg init --encryption=keyfile /mnt/backup/borg-repo
    borg key export /mnt/backup/borg-repo /root/borg-repo.key

Automated Backup Script
-----------------------

.. code-block:: bash

    #!/bin/bash
    export BORG_REPO="/mnt/backup/borg-repo"
    export BORG_PASSPHRASE="$(cat /root/borg-passphrase)"
    BACKUP_NAME="$(hostname)-$(date +%Y-%m-%d_%H%M%S)"
    borg create --verbose --stats --compression zstd,6 \
        --exclude '/dev' --exclude '/proc' --exclude '/sys' \
        --exclude '/tmp' --exclude '/run' --exclude '/mnt' \
        --exclude '/var/cache' --exclude '/var/tmp' \
        "::{BACKUP_NAME}" /etc /var /home /root /srv
    borg prune --verbose --list --keep-daily=7 --keep-weekly=4 --keep-monthly=6
    borg check --verbose

Restoring from Borg
-------------------

.. code-block:: bash

    borg list /mnt/backup/borg-repo
    borg extract /mnt/backup/borg-repo::myhost-2026-07-18_020000

12.3.4 Restic: Backups to Cloud and Object Storage
=====================================================

`Restic <https://restic.net/>`_ natively supports S3, GCS, Azure Blob, B2, and SFTP.

.. code-block:: bash

    export AWS_ACCESS_KEY_ID="minioadmin"
    export AWS_SECRET_ACCESS_KEY="minioadmin"
    restic init --repo s3:https://s3.example.com/restic-repo
    restic backup /etc /home --exclude="*.cache" --tag production
    restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
    restic restore latest --target /tmp/restore

.. important::
   Enable **S3 Object Lock** to enforce immutability:

   .. code-block:: bash

        aws s3api put-object-lock-configuration \
            --bucket my-backup-bucket \
            --object-lock-configuration '{"ObjectLockEnabled": "Enabled",
              "Rule": {"DefaultRetention": {"Mode": "GOVERNANCE", "Days": 30}}}'

12.3.5 Database Backup Strategies
====================================

Logical Backups (pg_dump / mysqldump)
--------------------------------------

Portable across versions, can restore single table. Slow for large databases.

.. code-block:: bash

    pg_dump -Fc -h localhost -U postgres mydb > /backup/mydb.dump
    pg_restore -d mydb /backup/mydb.dump
    mysqldump --single-transaction -h localhost -u root mydb > /backup/mydb.sql

Physical Backups (pg_basebackup / XtraBackup)
-----------------------------------------------

Fast, consistent point-in-time recovery. Binary format, version-specific.

.. code-block:: bash

    pg_basebackup -h localhost -D /backup/pg_phys -X stream -P
    # Point-in-Time Recovery via WAL archives
    # archive_command = 'cp %p /backup/wal/%f'
    # recovery_target_time = '2026-07-19 12:00:00'

    xtrabackup --backup --target-dir=/backup/mysql_phys
    xtrabackup --prepare --target-dir=/backup/mysql_phys

12.3.6 Filesystem Snapshots: ZFS and Btrfs Send/Recv
=======================================================

ZFS Send/Recv
-------------

.. code-block:: bash

    zfs snapshot -r tank/data@weekly-2026-07-19
    zfs send -R -i tank/data@weekly-2026-07-12 \
        tank/data@weekly-2026-07-19 \
        | ssh backup-host "zfs receive -F tank/backups/data"

Btrfs Send/Recv
---------------

.. code-block:: bash

    btrfs subvolume snapshot -r /mnt/data /mnt/data/.snapshots/weekly-2026-07-19
    btrfs send /mnt/data/.snapshots/weekly-2026-07-19 \
        | ssh backup-host "btrfs receive /mnt/backups/data"

.. caution::
   Use ``zfs hold`` to prevent snapshot deletion. Send snapshots to a separate
   air-gapped backup server with no interactive login.

12.3.7 Testing Your Disaster Recovery
========================================

An untested backup is not a backup. Schedule quarterly DR drills and measure:

+-----------------+------------------------------------+
| Metric          | Definition                         |
+=================+====================================+
| **RTO**         | Time to restore service.           |
|                 | Target: hours, not days.           |
+-----------------+------------------------------------+
| **RPO**         | Maximum acceptable data loss.      |
|                 | Target: minutes, not hours.        |
+-----------------+------------------------------------+

12.3.8 Summary
===============

1. **3-2-1-1** is non-negotiable. One copy must be immutable/air-gapped.
2. **Borg** for local, deduplicated, encrypted backups.
3. **Restic** for cloud-native backups with S3 Object Lock.
4. Database backups need **logical** AND **physical** strategies with WAL archiving.
5. **ZFS/Btrfs send/recv** for instant, incremental filesystem replication.
6. **Test everything** quarterly.
