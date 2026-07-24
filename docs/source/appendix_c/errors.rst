.. _app-c-errors:

------------------------------------------------------------------------------
Common Error Messages & Solutions
------------------------------------------------------------------------------

------------------------------------------------------------------------------
Kernel & Boot Errors

.. list-table:: Kernel panic / boot error diagnosis
   :header-rows: 1
   :widths: 40 30 30

   * - Error / Symptom
     - Most Likely Cause
     - Quick Fix
   * - ``Kernel panic - not syncing: VFS: Unable to mount root fs``
     - Missing filesystem driver in initramfs
     - Regenerate initramfs with correct drivers; check ``root=`` kernel parameter
   * - ``Kernel panic - not syncing: Attempted to kill init!``
     - Systemd or init binary corrupted
     - Boot with ``init=/bin/bash``, reinstall systemd
   * - ``BUG: unable to handle kernel NULL pointer dereference``
     - Kernel bug or faulty hardware/driver
     - Update kernel; check for known bugs; test memory
   * - ``General protection fault``
     - Usually hardware (RAM, CPU overheating)
     - Run memtest86; check CPU temperature (``sensors``)
   * - ``ACPI BIOS Error (bug)``
     - Buggy firmware ACPI tables
     - Add ``acpi=off`` or ``acpi=noirq`` to kernel command line
   * - ``soft lockup: CPU#N stuck for Xs!``
     - Interrupt storm, dead spinlock, or misbehaving driver
     - Check ``/proc/interrupts``; update drivers; check for IRQ conflicts
   * - ``Out of memory: Killed process ...``
     - System ran out of memory; OOM killer activated
     - Add swap; fix memory leak; increase RAM; adjust ``vm.overcommit``
   * - ``EXT4-fs error (device sda2): ext4_lookup: deleted inode referenced``
     - Filesystem corruption
     - Umount and run ``fsck -fy``
   * - ``Buffer I/O error on device sdX, logical block ...``
     - Disk sector failure or cable issue
     - Check SMART; replace cable; use ddrescue to backup; replace disk
   * - ``ataX.00: exception Emask 0x0 SAct 0x0``
     - SATA/ATA bus errors (cable, controller, or disk)
     - Reseat/data cable; check SATA controller; replace disk

------------------------------------------------------------------------------
Service & Daemon Errors

.. list-table:: Common service errors
   :header-rows: 1
   :widths: 40 30 30

   * - Error / Symptom
     - Most Likely Cause
     - Quick Fix
   * - ``Failed to start <service>: Unit not found``
     - Service doesn't exist, or name is wrong
     - ``systemctl list-unit-files | grep <name>`` to find exact name
   * - ``Job for <service>.service failed because the control process exited with error code``
     - Service crashed on start (config error, port in use, dependency missing)
     - ``journalctl -u <service> -xe`` for details
   * - ``Failed to start <service>: Unit is masked``
     - Service was intentionally masked (symlinked to /dev/null)
     - ``systemctl unmask <service>``
   * - ``Address already in use``
     - Port already occupied by another process
     - ``ss -tlnp | grep <port>`` to find the process; stop it or change config
   * - ``Permission denied``
     - Insufficient privileges to bind port (< 1024 for non-root, or file perms)
     - Use root, grant ``CAP_NET_BIND_SERVICE``, or change port
   * - ``Could not open configuration file: Permission denied``
     - Service cannot read its config (AppArmor/SELinux, or wrong file perms)
     - Check ``ls -Z`` (SELinux); check ``aa-status``; fix file ownership
   * - ``Connection refused to upstream``
     - Backend service not running or wrong port
     - ``systemctl status <backend>``; check ``nc -vz`` to upstream
   * - ``Too many open files``
     - Process hit file descriptor limit
     - Check ``ulimit -n``; increase in ``/etc/security/limits.conf`` or service unit ``LimitNOFILE=``
   * - ``Resource temporarily unavailable``
     - Out of file descriptors, PIDs, or threads
     - ``cat /proc/sys/fs/file-nr``; increase ``fs.file-max`` or ``kernel.pid_max``
   * - ``bind: Cannot assign requested address``
     - IP address not configured on this machine
     - Verify IP with ``ip addr``; check ``bind`` directive in config

------------------------------------------------------------------------------
Network Errors

.. list-table:: Network error messages
   :header-rows: 1
   :widths: 40 30 30

   * - Error / Symptom
     - Most Likely Cause
     - Quick Fix
   * - ``ping: sendmsg: Operation not permitted``
     - ICMP blocked by firewall or sysctl
     - Check ``iptables -L``; check ``net.ipv4.ping_group_range``
   * - ``ssh: connect to host <host> port 22: Connection refused``
     - SSH server not running, wrong port, firewall dropping
     - ``systemctl status sshd``; ``ss -tlnp | grep 22``; check firewall
   * - ``ssh: connect to host <host> port 22: Connection timed out``
     - Network unreachable, host down, or firewall dropping SYN
     - ``ping`` to host; ``traceroute`` to find where it stops
   * - ``Host key verification failed``
     - Server's host key changed (reinstall, MITM, or IP reuse)
     - Verify key fingerprint with admin; ``ssh-keygen -R <host>`` to remove old key
   * - ``WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!``
     - Same as above — server's SSH host key doesn't match known_hosts
     - Contact admin to verify; then ``ssh-keygen -R <host>``
   * - ``Permission denied (publickey,password)``
     - Authentication failed (wrong key, no key loaded, or password wrong)
     - ``ssh -v user@host`` to see which auth method fails; check ``authorized_keys``
   * - ``DHCPDISCOVER: No DHCPOFFERS received``
     - No DHCP server reachable on the network
     - Check physical connection; verify DHCP server is running; try static IP
   * - ``DNS resolution failed: Temporary failure in name resolution``
     - DNS server unreachable or misconfigured
     - ``ping 8.8.8.8`` (bypass DNS); check ``/etc/resolv.conf``; restart systemd-resolved
   * - ``curl: (35) SSL connect error`` / ``error:14094410:SSL routines:ssl3_read_bytes:sslv3 alert handshake failure``
     - TLS version mismatch, cipher incompatibility, or expired certificate
     - ``openssl s_client -connect host:443 -tls1_2`` to test specific TLS version
   * - ``nfs: server <host> not responding, still trying``
     - NFS server overloaded or network issue
     - ``showmount -e <host>``; check server load; ``nfsstat``; look for packet loss

------------------------------------------------------------------------------
Filesystem & Storage Errors

.. list-table:: Storage error messages
   :header-rows: 1
   :widths: 40 30 30

   * - Error / Symptom
     - Most Likely Cause
     - Quick Fix
   * - ``No space left on device``
     - Disk full or inodes exhausted
     - ``df -h`` / ``df -i``; find and remove large files or many small files
   * - ``Read-only file system``
     - Filesystem has errors, mounted ro by kernel
     - ``mount -o remount,rw /`` (may fail); ``fsck -fy``; reboot
   * - ``Structure needs cleaning``
     - ext4 filesystem corruption
     - ``fsck -fy /dev/<device>``
   * - ``Input/output error``
     - Hardware failure or bad sector
     - Check ``dmesg``; ``smartctl -a /dev/sda``; replace disk
   * - ``File too large``
     - Filesystem doesn't support large files (>2GB on older FS, or ulimit)
     - Check filesystem type (FAT32 max 4GB); use ext4/XFS
   * - ``Disk quota exceeded``
     - User has exceeded their allocated quota
     - ``quota -u <user>``; increase quota or user cleans up
   * - ``Device or resource busy``
     - Process is using the device or mount point
     - ``lsof /mountpoint``; ``fuser -m /mountpoint``; kill the process

------------------------------------------------------------------------------
Package Manager Errors

.. list-table:: Package management errors
   :header-rows: 1
   :widths: 40 30 30

   * - Error / Symptom
     - Most Likely Cause
     - Quick Fix
   * - ``Could not get lock /var/lib/dpkg/lock`` (Debian)
     - Another apt process running
     - Wait or ``sudo rm /var/lib/dpkg/lock`` (if no apt running)
   * - ``Another package manager is running`` (RHEL)
     - Another yum/dnf process running
     - Wait or ``sudo rm -f /var/run/yum.pid`` (if no dnf running)
   * - ``dpkg: error processing package <pkg> (--configure)``
     - Post-install script failed, package left half-configured
     - ``sudo dpkg --configure -a``; ``sudo apt-get install -f``
   * - ``rpm: rpmdb open failed``
     - RPM database corrupted
     - ``sudo rpm --rebuilddb``; restore backup from ``/var/lib/rpm``
   * - ``The repository ... does not have a Release file``
     - Repository URL wrong, or repo not available for this distro version
     - Check ``/etc/apt/sources.list``; update to correct distro codename
   * - ``Failed to download metadata for repo ...``
     - Network issue or repository down
     - ``curl -I <repo_url>``; check network; try ``dnf clean all``
   * - ``snap: command not found``
     - snapd not installed
     - ``sudo apt install snapd`` / ``sudo dnf install snapd``
   * - ``flatpak: command not found``
     - flatpak not installed
     - ``sudo apt install flatpak`` / ``sudo dnf install flatpak``
