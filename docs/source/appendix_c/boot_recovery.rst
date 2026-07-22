.. _app-c-boot:

------------------------------------------------------------------------------
C.1  Boot Process & System Recovery
------------------------------------------------------------------------------

------------------------------------------------------------------------------
C.1.1  Boot Process Overview
------------------------------------------------------------------------------

.. list-table:: Linux Boot Sequence (UEFI + GRUB + systemd)
   :header-rows: 1
   :widths: 10 25 25 40

   * - Step
     - Component
     - Location / Action
     - What can go wrong
   * - 1
     - UEFI firmware
     - Reads EFI partition (``/boot/efi``)
     - Corrupted NVRAM, wrong boot order, Secure Boot blocking GRUB
   * - 2
     - GRUB stage 1
     - ``/boot/efi/EFI/BOOT/grubx64.efi``
     - EFI partition missing or damaged
   * - 3
     - GRUB stage 2
     - ``/boot/grub/grub.cfg``, modules from ``/boot/grub/``
     - Missing or misconfigured ``grub.cfg``; corrupted modules
   * - 4
     - Kernel
     - ``/boot/vmlinuz-*`` loaded into memory
     - Missing kernel image; wrong ``initramfs`` version; bad kernel params
   * - 5
     - initramfs (initrd)
     - ``/boot/initramfs-*.img`` — temporary root filesystem
     - Missing drivers (disk, filesystem); wrong mkinitcpio/dracut config
   * - 6
     - init (PID 1)
     - ``/sbin/init`` → systemd
     - Corrupted systemd binary; missing ``/etc/systemd/system/default.target``
   * - 7
     - systemd targets
     - ``basic.target`` → ``multi-user.target`` → ``graphical.target``
     - Failing service in critical chain; broken mount unit; full disk
   * - 8
     - Login
     - getty / display manager
     - ``/etc/nologin`` exists; PAM misconfiguration; full ``/var/log``

------------------------------------------------------------------------------
C.1.2  GRUB Rescue & Recovery
------------------------------------------------------------------------------

.. rubric:: Scenario: GRUB drops to ``grub-rescue>`` prompt

.. code-block:: text

   # Common causes:
   # - /boot partition deleted or corrupted
   # - GRUB configuration file missing
   # - BIOS boot sector overwritten
   # - Disk reordered in BIOS (e.g., after adding a new drive)

   # Manual boot from grub-rescue prompt:
   grub-rescue> set root=(hd0,msdos1)          # Stage 1.5 — find /boot partition
   grub-rescue> set prefix=(hd0,msdos1)/grub   # GRUB modules location
   grub-rescue> insmod normal                  # Load normal GRUB mode
   grub-rescue> normal                         # Enter full GRUB menu

   # Once in full GRUB (or via GRUB menu pressing 'c'):
   grub> set root=(hd0,1)
   grub> linux /vmlinuz-6.1.0 root=/dev/sda2 ro
   grub> initrd /initramfs-6.1.0.img
   grub> boot

.. rubric:: Reinstalling GRUB

.. code-block:: bash

   # From a live CD/USB:

   # Identify the root partition
   lsblk
   # Assume: /dev/sda1 = /boot/efi, /dev/sda2 = /

   # Mount the system
   mount /dev/sda2 /mnt
   mount /dev/sda1 /mnt/boot/efi   # For UEFI

   # Bind essential filesystems
   mount --bind /dev /mnt/dev
   mount --bind /proc /mnt/proc
   mount --bind /sys /mnt/sys

   # Chroot into the system
   chroot /mnt

   # Reinstall GRUB
   # For UEFI:
   grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
   # For BIOS/legacy:
   grub-install /dev/sda

   # Regenerate GRUB config
   grub-mkconfig -o /boot/grub/grub.cfg   # Debian/Ubuntu
   # OR:
   grub2-mkconfig -o /boot/grub2/grub.cfg # RHEL/Fedora

   # Exit and reboot
   exit
   reboot

.. rubric:: GRUB configuration (``/etc/default/grub``)

.. code-block:: text

   # Common GRUB parameters (regenerate config after changes)
   GRUB_TIMEOUT=5                    # Seconds before auto-boot (set to 0 for instant)
   GRUB_DEFAULT=0                    # Default menu entry (0 = first, "saved" = last used)
   GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"  # Kernel params (add "single" for single-user)
   GRUB_CMDLINE_LINUX=""             # Kernel params always added
   GRUB_DISABLE_RECOVERY="false"     # Show recovery entries (single-user mode)

   # Useful kernel parameters for troubleshooting:
   # single          — Boot to single-user (maintenance) mode
   # emergency       — Boot to emergency shell
   # systemd.unit=rescue.target  — systemd rescue target
   # init=/bin/bash  — Bypass systemd entirely (drop to bash as root)
   # 3               — Boot to runlevel 3 (multi-user text mode)
   # nomodeset       — Disable kernel mode-setting (fixes black screen on boot)
   # acpi=off        — Disable ACPI (fixes boot hangs on some hardware)
   # noapic          — Disable APIC
   # nolapic         — Disable local APIC
   # maxcpus=1       — Limit to 1 CPU core
   # mem=4G          — Limit RAM to 4GB (for testing or broken DIMM)
   # root=/dev/sda2  — Override root device

.. rubric:: Regenerating initramfs

.. code-block:: bash

   # Debian/Ubuntu (update-initramfs)
   sudo update-initramfs -u -k all       # Update all kernels
   sudo update-initramfs -u -k 6.1.0-10-amd64  # Update specific kernel

   # RHEL/Fedora/CentOS (dracut)
   sudo dracut -f                        # Regenerate current kernel's initramfs
   sudo dracut -f --kver 6.1.0  # Specific kernel version
   sudo dracut --regenerate-all          # Rebuild for all kernels

   # Arch / Gentoo (mkinitcpio)
   sudo mkinitcpio -P                    # Regenerate for all kernels
   sudo mkinitcpio -p linux              # Specific preset

------------------------------------------------------------------------------
C.1.3  systemd Rescue & Emergency Targets
------------------------------------------------------------------------------

.. list-table:: systemd boot targets for recovery
   :header-rows: 1
   :widths: 25 25 50

   * - Target
     - How to boot
     - What you get
   * - ``rescue.target``
     - Append ``systemd.unit=rescue.target`` or ``1`` to kernel cmdline
     - Single-user root shell; filesystems mounted (some may be read-only); networking **disabled**
   * - ``emergency.target``
     - Append ``systemd.unit=emergency.target`` or ``emergency``
     - Minimal root shell; only ``/`` mounted (read-only); no services
   * - ``multi-user.target``
     - Append ``3`` or ``systemd.unit=multi-user.target``
     - Full multi-user text mode (no GUI) — good for fixing display manager
   * - ``graphical.target``
     - Default on desktop systems
     - Full GUI with display manager

.. rubric:: Working in rescue/emergency mode

.. code-block:: bash

   # Remount root as read-write (if mounted read-only)
   mount -o remount,rw /

   # Check what failed
   journalctl -xb                          # Boot log with explanations
   systemctl list-units --failed           # List failed services
   systemctl status <failed-service>       # Get service details

   # Fix and continue boot
   systemctl default              # Continue to default target
   systemctl rescue               # Switch to rescue (from emergency)
   systemctl isolate multi-user.target     # Jump to multi-user

.. rubric:: Forcing fsck on root filesystem

.. code-block:: bash

   # Method 1: Kernel boot parameter
   # Add "fsck.mode=force" to kernel command line

   # Method 2: Force fsck on next reboot
   sudo touch /forcefsck           # Triggers fsck on next boot
   sudo reboot

   # Method 3: Manual fsck from rescue shell
   # First identify the root device
   lsblk
   # Unmount root, run fsck, remount
   exit        # exit rescue shell
   # Boot from live USB, then:
   fsck -y /dev/sda2

------------------------------------------------------------------------------
C.1.4  Bypassing systemd (init=/bin/bash)
------------------------------------------------------------------------------

.. danger::
   This is a last-resort method to fix a system that is unbootable due to
   systemd or PAM issues. The root filesystem mounts read-only, and no
   services start (including networking).

.. code-block:: bash

   # At GRUB menu, press 'e' to edit the boot entry
   # Find the line starting with "linux" and append:
   init=/bin/bash

   # After booting:
   # Remount root writable:
   mount -o remount,rw /

   # Now you can fix files, edit configs, etc.

   # To boot normally after fixes:
   exec /sbin/init          # Start systemd manually
   # OR just reboot:
   reboot -f
