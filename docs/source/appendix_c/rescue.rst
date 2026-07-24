.. _app-c-rescue:

------------------------------------------------------------------------------
Rescue Procedures & Recovery Tools
------------------------------------------------------------------------------

------------------------------------------------------------------------------
Live USB/ISO Rescue Environment

.. rubric:: Essential live Linux distributions for rescue

.. list-table:: Rescue distros
   :header-rows: 1
   :widths: 20 30 50

   * - Distribution
     - Package
     - Strengths
   * - SystemRescue (formerly SystemRescueCd)
     - Arch-based live ISO
     - Full toolset: fsck, ddrescue, testdisk, parted, btrfs, ZFS, LVM, mdadm
   * - GParted Live
     - Debian-based live ISO
     - Focus on partition management; includes GParted, fsck, dd, testdisk
   * - Ubuntu Desktop Live
     - Ubuntu ISO
     - Familiar environment; good for chroot recovery; broad hardware support
   * - Finnix
     - Debian-based, ~300MB
     - Minimal but comprehensive CLI rescue tools
   * - Rescuezilla
     - Ubuntu-based
     - Clonezilla-like GUI for full disk backup/restore

.. rubric:: Chroot into a broken system from live USB

.. code-block:: bash

   # 1. Identify the root and boot partitions
   lsblk -f
   # Let's say: /dev/sda2 = root (/), /dev/sda1 = /boot/efi

   # 2. Mount the root filesystem
   mount /dev/sda2 /mnt

   # 3. Mount /boot (if separate partition)
   # mount /dev/sda1 /mnt/boot

   # 4. Mount the EFI partition (UEFI systems)
   mount /dev/sda1 /mnt/boot/efi

   # 5. Bind essential pseudo-filesystems
   mount --bind /dev /mnt/dev
   mount --bind /dev/pts /mnt/dev/pts
   mount --bind /proc /mnt/proc
   mount --bind /sys /mnt/sys
   mount --bind /run /mnt/run    # systemd needs this

   # 6. Copy DNS config (to have network inside chroot)
   cp -L /etc/resolv.conf /mnt/etc/resolv.conf

   # 7. Chroot
   chroot /mnt /bin/bash

   # 8. Now inside the broken system — fix what needs fixing
   # (reinstall GRUB, fix fstab, rebuild initramfs, etc.)

   # 9. Exit and unmount when done
   exit
   umount -R /mnt          # Recursive unmount
   reboot

------------------------------------------------------------------------------
Single-User Mode Recovery

.. rubric:: Booting to single-user (rescue) mode

.. code-block:: text

   Method 1: At GRUB menu, press 'e', add "single" to linux line
   Method 2: At GRUB menu, press 'e', add "1" to linux line
   Method 3: At GRUB menu, press 'e', add "systemd.unit=rescue.target"

   # You'll get a root shell. Filesystems may be read-only.
   mount -o remount,rw /

.. rubric:: Common fixes from single-user mode

.. code-block:: bash

   # Fix a broken fstab
   nano /etc/fstab          # Comment out the broken entry
   mount -a                 # Test all entries

   # Reset a forgotten root password
   passwd

   # Fix PAM configuration
   # If PAM is broken, restore from backup:
   cp /etc/pam.d/sshd.pam-bak /etc/pam.d/sshd 2>/dev/null
   # Or restore system-auth from /usr/share/doc/

   # Re-enable a disabled service
   systemctl enable sshd

   # Check and repair filesystems
   fsck -fy /dev/sda2

   # Reinstall bootloader (if system doesn't boot)
   grub-install /dev/sda
   grub-mkconfig -o /boot/grub/grub.cfg

------------------------------------------------------------------------------
Password Recovery

.. rubric:: Resetting a lost root password

.. code-block:: bash

   # Method 1: Single-user mode (most common)
   # Boot with "init=/bin/bash" kernel parameter at GRUB
   mount -o remount,rw /
   passwd

   # Method 2: Chroot from live USB
   # Follow chroot procedure above, then:
   chroot /mnt
   passwd root

   # Method 3: Using a live CD to directly edit shadow
   # Mount the root partition
   mount /dev/sda2 /mnt
   # Remove the 'x' from root's entry in /etc/passwd (disables password check)
   # WARNING: leaves root with NO password — fix immediately
   sed -i 's/^root:x:/root::/' /mnt/etc/passwd
   # Boot normally, login as root (no password), then:
   passwd root

.. rubric:: Locked out of sudo

.. code-block:: bash

   # If user is not in sudo group:
   # Boot to single-user mode, then:
   usermod -aG sudo <username>          # Debian/Ubuntu
   usermod -aG wheel <username>         # RHEL/Fedora

   # If sudoers file is corrupted:
   # Boot to single-user mode, then:
   visudo                               # Fix syntax
   # Or restore from backup:
   cp /etc/sudoers.bak /etc/sudoers
   chmod 440 /etc/sudoers

.. rubric:: Resetting a Windows password from Linux (dual-boot)

.. code-block:: bash

   # Mount Windows partition
   mount /dev/sda1 /mnt
   # Use chntpw
   sudo apt install chntpw
   cd /mnt/Windows/System32/config
   sudo chntpw -l SAM              # List users
   sudo chntpw -u Administrator SAM  # Reset Administrator password

------------------------------------------------------------------------------
Network Boot Issues

.. rubric:: System boots to "Network is unreachable"

.. code-block:: bash

   # Check if interface is up
   ip link show

   # Bring interface up manually
   sudo ip link set eth0 up

   # Check if DHCP client is running
   ps aux | grep dhcp

   # Request a lease manually
   sudo dhclient -v eth0

   # If using static IP, check config:
   cat /etc/network/interfaces              # Debian
   cat /etc/sysconfig/network-scripts/ifcfg-eth0  # RHEL
   cat /etc/netplan/*.yaml                  # Ubuntu 18.04+ (Netplan)

.. rubric:: NetworkManager issues

.. code-block:: bash

   # NetworkManager conflicts with systemd-networkd or ifupdown
   systemctl status NetworkManager
   journalctl -u NetworkManager | tail -50

   # Disable NetworkManager and switch to systemd-networkd:
   systemctl stop NetworkManager
   systemctl disable NetworkManager
   systemctl enable --now systemd-networkd
   systemctl enable --now systemd-resolved

   # Check connection profiles
   nmcli connection show
   nmcli device status

------------------------------------------------------------------------------
X Server / Display Issues

.. rubric:: "Failed to start the X server"

.. code-block:: bash

   # Check Xorg log
   cat /var/log/Xorg.0.log | grep -i "EE"   # EE = errors

   # Common causes:
   # - Missing or wrong GPU driver
   # - /tmp full (X needs /tmp for sockets)
   # - File permission issues on /tmp/.X11-unix
   # - Configuration file error

   # Fix: reconfigure X
   sudo dpkg-reconfigure xserver-xorg       # Debian
   # Or remove config and let X autodetect
   sudo rm /etc/X11/xorg.conf
   # Or switch to a different display manager
   sudo systemctl disable gdm3
   sudo systemctl enable lightdm

   # If GPU driver is the issue:
   # Check what driver is loaded
   lsmod | grep -iE "nvidia|amdgpu|i915|nouveau|radeon"
   # Blacklist problematic driver
   echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nvidia-nouveau.conf
   sudo update-initramfs -u
   reboot

.. rubric:: "Could not switch to monitor mode" / blank screen

.. code-block:: bash

   # Add nomodeset kernel parameter at GRUB:
   # Press 'e' at GRUB menu, add "nomodeset" to linux line
   # This disables kernel mode-setting and uses BIOS/UEFI modes

   # For NVIDIA specifically, use:
   # nouveau.modeset=0     (for open-source nouveau driver)
   # nvidia-drm.modeset=1  (for proprietary nvidia driver)
