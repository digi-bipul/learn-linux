.. _app-c-storage:

------------------------------------------------------------------------------
C.3  Storage & Filesystem Recovery
------------------------------------------------------------------------------

------------------------------------------------------------------------------
C.3.1  Filesystem Full or Inode Exhaustion

.. code-block:: bash
   :caption: "No space left on device" — but ``df`` shows free space

   # Check inode usage (files, not blocks)
   df -i /
   # If IUse% is 100%, you've exhausted inodes (too many tiny files)

   # Find directories with many files
   sudo find / -xdev -type d -size +10M -exec sh -c 'echo "$(ls -f "{}" | wc -l) {}"' \; | sort -rn | head -10

   # Alternative: count files per directory
   sudo ls -la /var/spool/ | wc -l   # Check mail spool
   sudo ls -la /tmp/ | wc -l          # Check temp
   sudo find /var -type f | wc -l     # Count files under /var

   # Common inode hogs:
   # /var/spool/postfix/ — stuck mail queue
   # /var/log/          — rotated logs not cleaned
   # /tmp/              — abandoned temp files
   # Docker overlay2    — orphaned container layers
   # ~/.cache/          — browser or application cache

.. code-block:: bash
   :caption: Finding large files when disk is full

   # Top-level directory usage (quick overview)
   sudo du -sh /* | sort -rh | head -20

   # Find the largest files anywhere (run as root)
   sudo find / -xdev -type f -size +500M -exec ls -lh {} \; 2>/dev/null | sort -k5 -rh | head -20

   # Check for deleted files still held open
   sudo lsof +L1 | grep -E '^[^ ]+ *[0-9]+ *[0-9]+' | head -20
   # These files are deleted but still held open by a process
   # The disk space won't be freed until the process releases them

   # Free space held by deleted files:
   sudo lsof -nP | grep '(deleted)' | awk '{print $2}' | sort -u | while read pid; do
       echo "PID $pid ($(ps -p $pid -o comm=)): $(sudo ls -l /proc/$pid/fd/ 2>/dev/null | grep deleted | awk '{print $5}' | paste -sd+ | bc)"
   done

   # Solution: restart the process holding the deleted file
   # sudo systemctl restart <service>

.. rubric:: Truncating a large log file safely

.. code-block:: bash

   # Wrong way (removes file, process continues writing to deleted inode):
   rm /var/log/nginx/access.log

   # Right way (truncates in place, log rotation compatible):
   truncate -s 0 /var/log/nginx/access.log
   # OR:
   : > /var/log/nginx/access.log
   # OR (if using logrotate):
   sudo logrotate -f /etc/logrotate.d/nginx

------------------------------------------------------------------------------
C.3.2  Filesystem Corruption & fsck

.. code-block:: bash
   :caption: Filesystem check procedures

   # Check if a filesystem needs fsck
   sudo tune2fs -l /dev/sda2 | grep -i "mount count\|check interval"
   # "Maximum mount count" shows fsck frequency (-1 = disabled)
   # "Check interval" shows time-based check

   # Force fsck on next boot
   sudo touch /forcefsck
   sudo reboot

   # Manual fsck (filesystem MUST be unmounted)
   sudo umount /dev/sda1
   sudo fsck -y /dev/sda1              # -y = auto-yes to all questions
   sudo fsck -f /dev/sda1              # Force check even if clean
   sudo fsck -C /dev/sda1              # Show progress bar

   # For ext4, more aggressive recovery:
   sudo fsck -fy /dev/sda1             # Force + auto-yes
   sudo fsck -fy -C 0 /dev/sda1        # Force + progress + verbose

   # If fsck fails badly, use debugfs to recover specific files:
   sudo debugfs -w /dev/sda1
   # Inside debugfs: ls -l, cd, dump <inode> <outfile>, rd <directory>

.. rubric:: Filesystem types and their fsck commands

.. list-table::
   :header-rows: 1
   :widths: 20 35 45

   * - Filesystem
     - fsck command
     - Notes
   * - ext2/3/4
     - ``fsck.ext4`` (or ``e2fsck``)
     - ``-f`` force; ``-y`` auto-yes; ``-p`` auto-repair safe issues
   * - XFS
     - ``xfs_repair``
     - Must be **unmounted**; ``-n`` = dry-run; ``-v`` = verbose
   * - Btrfs
     - ``btrfs check`` (read-only) / ``btrfs check --repair``
     - ``--repair`` is dangerous; use ``--readonly`` first
   * - ZFS
     - ``zpool scrub``
     - No fsck needed; scrub checks and repairs checksums
   * - FAT32 / exFAT
     - ``fsck.fat`` (``dosfsck``)
     - ``-a`` = auto-repair; ``-r`` = interactive repair
   * - NTFS
     - ``ntfsfix`` (basic) or Windows ``chkdsk``
     - ``ntfsfix`` fixes common issues; use Windows for complex repair

.. code-block:: bash
   :caption: XFS repair example

   # Check without modifying
   sudo xfs_repair -n /dev/sda3

   # Full repair (filesystem must be unmounted)
   sudo xfs_repair -v /dev/sda3

   # Recover from log corruption
   sudo xfs_repair -L /dev/sda3         # -L = zero log (loses recent changes)
   # WARNING: -L discards any metadata operations in the log

.. code-block:: bash
   :caption: Btrfs troubleshooting

   # Check filesystem integrity (read-only, safe)
   sudo btrfs check /dev/sda4

   # Scrub (online, checksums verified, errors repaired)
   sudo btrfs scrub start /mount/point
   sudo btrfs scrub status /mount/point

   # Balance (rebalances data across devices)
   sudo btrfs balance start /mount/point
   sudo btrfs balance status /mount/point

   # Check for device errors
   sudo btrfs device stats /mount/point

------------------------------------------------------------------------------
C.3.3  Mount Problems

.. list-table:: Common mount errors and solutions
   :header-rows: 1
   :widths: 35 35 30

   * - Error
     - Cause
     - Fix
   * - ``mount: /dev/sda1 is write-protected, mounting read-only``
     - Filesystem has errors; kernel mounted it read-only to prevent damage
     - Unmount, run ``fsck``, remount
   * - ``mount: wrong fs type, bad option, bad superblock``
     - Missing filesystem driver, wrong ``-t`` type, or superblock corrupted
     - ``modprobe <fstype>``; check ``lsblk -f``; use ``-t`` explicitly; try alternate superblock
   * - ``mount: can't find UUID=<uuid>``
     - UUID changed (e.g., after reformat), or wrong entry in ``/etc/fstab``
     - ``blkid`` to get current UUID; update ``/etc/fstab``
   * - ``mount: /mountpoint: special device does not exist``
     - Device node missing or device not connected
     - Check ``lsblk``; for LVM, ``vgchange -ay``; for mdadm, ``mdadm --assemble --scan``
   * - ``mount: /mountpoint: mount point does not exist``
     - Mount point directory missing
     - ``mkdir -p /mountpoint``
   * - ``mount.nfs: access denied by server``
     - NFS export restrictions or permissions
     - Check ``/etc/exports`` on server; verify ``root_squash`` and network ACLs
   * - ``mount.nfs: Connection refused``
     - NFS server not running or port blocked
     - ``systemctl status nfs-server``; ``rpcinfo -p``; open firewall

.. rubric:: Recovering from a broken ``/etc/fstab``

.. code-block:: bash

   # Scenario: System won't boot because of a bad fstab entry
   # Boot with "single" or "emergency" kernel parameter

   # Remount root read-write
   mount -o remount,rw /

   # Check fstab for errors (comment out suspicious entries with #)
   cat /etc/fstab
   # Or rename and restore:
   cp /etc/fstab /etc/fstab.bak
   # Create minimal fstab:
   echo "UUID=$(blkid -s UUID -o value /dev/sda2) / ext4 defaults 0 1" > /etc/fstab

   # Test fstab entries without reboot:
   sudo mount -a        # Mount all entries in fstab
   # If it hangs, use Ctrl+C and fix the offending entry

.. rubric:: Mounting with an alternate superblock (ext4)

.. code-block:: bash

   # If the primary superblock is corrupted, use a backup:
   # List backup superblock locations
   sudo mke2fs -n /dev/sda1 | grep -i superblock

   # Mount using backup superblock
   sudo mount -o sb=32768 /dev/sda1 /mnt

   # Or use fsck with alternate superblock
   sudo e2fsck -b 32768 /dev/sda1

------------------------------------------------------------------------------
C.3.4  RAID & LVM Recovery

.. rubric:: MD RAID (mdadm)

.. code-block:: bash
   :caption: RAID diagnostics and recovery

   # Check RAID status
   cat /proc/mdstat
   sudo mdadm --detail /dev/md0

   # Re-add a failed disk
   sudo mdadm --manage /dev/md0 --re-add /dev/sdb1

   # Remove a failed disk
   sudo mdadm --manage /dev/md0 --fail /dev/sdb1
   sudo mdadm --manage /dev/md0 --remove /dev/sdb1

   # Add a replacement disk
   sudo mdadm --manage /dev/md0 --add /dev/sdc1

   # Assemble a RAID array manually
   sudo mdadm --assemble --scan                    # Auto-detect
   sudo mdadm --assemble /dev/md0 /dev/sdb1 /dev/sdc1 /dev/sdd1
   sudo mdadm --assemble --force /dev/md0          # Force assembly if one disk is missing

   # Stop an array
   sudo mdadm --stop /dev/md0

.. rubric:: LVM recovery

.. code-block:: bash
   :caption: LVM volume recovery steps

   # Scan for LVM volumes (discovers PVs, VGs, LVs)
   sudo pvscan
   sudo vgscan
   sudo lvscan

   # Activate all volume groups
   sudo vgchange -ay

   # If a physical volume is missing
   sudo vgreduce --removemissing <vgname>
   # WARNING: This removes missing PVs; data on them is unrecoverable

   # Recover a Logical Volume that won't activate
   sudo lvchange -ay <vgname>/<lvname> --partial
   # --partial allows activation with missing PVs

   # Extend an LV (when PV has free space)
   sudo lvextend -L +10G <vgname>/<lvname>
   sudo resize2fs /dev/<vgname>/<lvname>   # ext4
   sudo xfs_growfs /mount/point            # XFS

   # Reduce an LV (MUST unmount, backup, check fs first)
   sudo umount /mount/point
   sudo e2fsck -f /dev/<vgname>/<lvname>
   sudo resize2fs /dev/<vgname>/<lvname> 100G   # Shrink fs to 100G
   sudo lvreduce -L 100G /dev/<vgname>/<lvname>  # Shrink LV to 100G
   sudo mount /mount/point

   # Move PV data off a failing disk
   sudo pvmove /dev/sdb1                         # Move extents to other PVs in VG

------------------------------------------------------------------------------
C.3.5  Data Recovery Tools

.. list-table:: Linux data recovery tools
   :header-rows: 1
   :widths: 20 30 50

   * - Tool
     - Package
     - Use case
   * - ``testdisk``
     - ``testdisk``
     - Recover deleted partitions, fix partition table
   * - ``photorec``
     - ``testdisk`` (includes photorec)
     - Recover deleted files by content signature (ignores filesystem)
   * - ``ddrescue``
     - ``ddrescue``
     - Clone a failing disk, skipping bad sectors, retrying later
   * - ``extundelete``
     - ``extundelete``
     - Recover deleted files from ext3/ext4 (if inodes not overwritten)
   * - ``scalpel``
     - ``scalpel``
     - File carving (recover based on file headers/footers)
   * - ``foremost``
     - ``foremost``
     - Similar to scalpel; file carving by headers
   * - ``debugfs``
     - ``e2fsprogs``
     - Low-level ext4 recovery and file manipulation
   * - ``strings``
     - ``binutils``
     - Extract human-readable strings from binary/raw devices
   * - ``safecopy``
     - ``safecopy``
     - Safer alternative to dd for damaged media

.. code-block:: bash
   :caption: Using ddrescue to clone a failing disk

   # Step 1: First pass (skip bad sectors quickly)
   sudo ddrescue -d /dev/sdb /dev/sdc rescue.map

   # Step 2: Second pass (retry bad sectors)
   sudo ddrescue -d -r 3 /dev/sdb /dev/sdc rescue.map

   # Step 3: Try to recover remaining bad sectors (direct)
   sudo ddrescue -d -d -r 5 /dev/sdb /dev/sdc rescue.map

   # Check mapfile status
   cat rescue.map
   # Green = recovered, Red = bad sectors remaining
