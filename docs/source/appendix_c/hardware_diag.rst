.. _app-c-hardware:

------------------------------------------------------------------------------
C.10  Hardware Diagnostics
------------------------------------------------------------------------------

------------------------------------------------------------------------------
C.10.1  CPU Diagnostics

.. code-block:: bash
   :caption: CPU information and diagnostics

   # CPU model, cores, architecture
   cat /proc/cpuinfo | grep -E "model name|cpu cores|siblings|flags" | sort -u
   lscpu

   # CPU flags (check for security mitigations, hardware features)
   cat /proc/cpuinfo | grep flags | head -1 | tr ' ' '\n' | sort

   # Check for Meltdown/Spectre/L1TF mitigations
   cat /sys/devices/system/cpu/vulnerabilities/*
   # Expected: "Mitigation: ..." or "Not affected"
   # "Vulnerable" means kernel is not patched

   # CPU temperature
   sudo sensors                              # Requires lm-sensors package
   cat /sys/class/thermal/thermal_zone*/temp # Some systems (millidegrees C)

   # CPU frequency and throttling
   watch -n 1 "cat /proc/cpuinfo | grep 'cpu MHz'"
   # If frequencies are lower than max under load → thermal throttling

   # CPU stress test (for stability testing)
   sudo apt install stress-ng
   stress-ng --cpu 4 --timeout 60s           # Stress 4 cores for 60 seconds
   # Watch temperature during test: watch -n 1 sensors

.. rubric:: CPU error checking

.. code-block:: bash

   # Machine Check Exceptions (MCE) — CPU hardware errors
   sudo journalctl -k | grep -i "mce\|machine check"
   # Typical MCE messages:
   # "MCE: The CPU is not compatible with this system"
   # "mce: [Hardware Error]: Machine check events logged"

   # Check MCE log
   sudo mcelog --client                      # If mcelog is installed

   # Kernel warnings (may indicate hardware issues)
   sudo journalctl -k -p warning

------------------------------------------------------------------------------
C.10.2  Memory (RAM) Diagnostics

.. code-block:: bash
   :caption: Memory testing and diagnostics

   # Current memory health (from EDAC driver)
   sudo edac-util -s                         # If edac-utils installed
   # Look for: "mc0: 0 csrow(s), 0 CE(s), 0 UE(s)"
   # CE = correctable errors (ECC RAM — single-bit)
   # UE = uncorrectable errors (bad — data corruption risk)

   # Check for memory errors in dmesg
   sudo dmesg | grep -iE "edac|ecc|memory|DIMM" | grep -i "error\|fail"

   # Count memory errors over time
   sudo cat /sys/devices/system/edac/mc/mc*/ce_count
   sudo cat /sys/devices/system/edac/mc/mc*/ue_count
   # If counts are increasing, replace the corresponding DIMM

   # Memory info
   sudo dmidecode -t memory | grep -E "Size|Type|Speed|Locator|Manufacturer|Part Number"

   # Check for memory pressure (before OOM)
   cat /proc/meminfo | grep -E "Committed_AS|CommitLimit"
   # Committed_AS > CommitLimit → memory overcommit is high

.. rubric:: Memtest86 (requires reboot)

.. code-block:: text

   1. Install memtest86+:
      sudo apt install memtest86+          # Debian/Ubuntu
      sudo dnf install memtest86+          # RHEL/Fedora

   2. Update GRUB to include memtest86+:
      sudo grub-mkconfig -o /boot/grub/grub.cfg

   3. Reboot and select "Memory test (memtest86+)" from GRUB menu

   4. Run for at least 1 full pass (can take hours for large RAM)

   5. Any errors (red text) indicate faulty RAM — replace the defective DIMM

------------------------------------------------------------------------------
C.10.3  Disk Diagnostics (SMART)

.. code-block:: bash
   :caption: SMART monitoring for HDDs and SSDs

   # List disks with SMART support
   sudo smartctl --scan

   # Check overall disk health
   sudo smartctl -H /dev/sda
   # PASSED or FAILED

   # Detailed drive information
   sudo smartctl -i /dev/sda
   # Model, serial, firmware, form factor, rotation rate

   # Full SMART attributes
   sudo smartctl -A /dev/sda
   # Key attributes to watch:
   # - Reallocated_Sector_Ct  (raw value > 0 = failing drive)
   # - Current_Pending_Sector (sectors waiting to be remapped)
   # - Offline_Uncorrectable  (sectors that couldn't be read)
   # - Temperature_Celsius    (should be < 50°C for HDD, < 60°C for SSD)
   # - Wear_Leveling_Count    (SSD: raw value = % of lifespan used)
   # - SSD_Life_Left          (percentage remaining)
   # - CRC_Error_Count        (cable/interface errors — usually bad cable)

   # Self-test
   sudo smartctl -t short /dev/sda          # Short test (~2 min)
   sudo smartctl -t long /dev/sda           # Extended test (hours)
   sudo smartctl -t conveyance /dev/sda     # Quick transport test

   # Check test results
   sudo smartctl -l selftest /dev/sda

   # Enable SMART if disabled
   sudo smartctl -s on /dev/sda

   # Continuous monitoring with smartd
   sudo systemctl enable --now smartd
   # Configuration: /etc/smartd.conf
   # Example: /dev/sda -a -m admin@example.com

.. rubric:: SMART attribute thresholds

.. list-table:: Critical SMART metrics
   :header-rows: 1
   :widths: 25 25 25 25

   * - Attribute
     - HDD threshold
     - SSD threshold
     - Action
   * - Reallocated Sectors
     - Raw > 0
     - Raw > 0
     - Replace disk immediately
   * - Current Pending Sectors
     - Raw > 0
     - Raw > 0
     - Replace disk; data at risk
   * - Offline Uncorrectable
     - Raw > 0
     - Raw > 0
     - Replace disk; data loss already occurring
   * - Temperature
     - > 50°C
     - > 60°C
     - Improve cooling
   * - Wear Leveling Count
     - N/A
     - > 90 (i.e., > 90% worn)
     - Plan replacement; drive nearing end of life
   * - Power-on Hours (POH)
     - > 50,000 (consumer)
     - Vendor-specific
     - Drive aging; replace based on workload

.. rubric:: Bad block detection

.. code-block:: bash

   # Scan for bad blocks (read-only, non-destructive)
   sudo badblocks -v /dev/sda > badblocks.txt

   # Check output
   cat badblocks.txt
   # If any block numbers are listed, the disk is failing

   # For ext4: check and remap
   sudo e2fsck -c /dev/sda1               # -c = check for bad blocks and remap

------------------------------------------------------------------------------
C.10.4  GPU Diagnostics

.. code-block:: bash
   :caption: Graphics card diagnostics

   # GPU information
   lspci | grep -iE "VGA|3D|Display"
   ls -l /dev/dri/                        # DRM devices

   # NVIDIA-specific (if proprietary driver installed)
   nvidia-smi                             # GPU utilization, temperature, memory
   nvidia-smi -q -d TEMPERATURE           # Temperature details
   nvidia-smi -q -d MEMORY                # Memory usage per process

   # AMD-specific
   sudo radeontop                         # Live GPU usage (open-source driver)
   cat /sys/class/drm/card*/device/pp_dpm_mclk  # Memory clock

   # Intel integrated
   sudo intel_gpu_top                     # Intel GPU utilization (requires intel-gpu-tools)

   # GPU temperature (all vendors)
   sudo sensors                           # If driver supports it

   # Check for GPU crashes / driver issues
   sudo journalctl -k | grep -i "drm\|i915\|amdgpu\|nvidia\|nouveau" | grep -i "error\|fail\|hang"

------------------------------------------------------------------------------
C.10.5  Power Supply & Motherboard Diagnostics

.. code-block:: bash
   :caption: Power and system health

   # Power supply status (via IPMI/BMC on servers)
   sudo ipmitool sensor list              # Server BMC
   sudo ipmitool chassis status

   # System voltages (if sensor chip supported)
   sudo sensors                           # Look for: Vcore, +12V, +5V, +3.3V
   # Tolerances: +12V should be 11.4-12.6V; +5V 4.75-5.25V; +3.3V 3.14-3.47V

   # Check for hardware errors in kernel log
   sudo dmesg | grep -i "hardware\|error\|alert\|fail\|warn"

   # PCIe errors
   sudo journalctl -k | grep -i "pcie.*error\|aerdrv\|PCIe.*corrected"
   # Corrected errors = minor (may be normal); Uncorrected = bad

   # USB errors
   sudo journalctl -k | grep -i "usb.*error\|usb.*disconnect\|xhci_hcd"

   # ACPI (power management) errors
   sudo journalctl -k | grep -i "acpi.*error\|acpi.*fail"

------------------------------------------------------------------------------
C.10.6  Hardware Inventory

.. code-block:: bash
   :caption: Complete hardware inventory commands

   # Full system inventory
   sudo dmidecode                          # Complete DMI/SMBIOS table
   sudo dmidecode -t system                # Manufacturer, product, serial
   sudo dmidecode -t baseboard             # Motherboard info
   sudo dmidecode -t processor             # CPU info
   sudo dmidecode -t memory                # RAM modules
   sudo dmidecode -t chassis               # Chassis type and serial

   # PCI devices
   lspci                                   # List all PCI devices
   lspci -v                                # Verbose
   lspci -vvv                              # Very verbose (capabilities)
   lspci -t                                # Tree view
   lspci -k                                # Show kernel drivers

   # USB devices
   lsusb                                   # List USB devices
   lsusb -t                                # Tree view
   lsusb -v                                # Verbose

   # Block devices
   lsblk                                   # Storage devices and partitions
   lsblk -f                                # With filesystem info
   lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,MODEL,SERIAL

   # Kernel modules loaded
   lsmod                                   # Loaded kernel modules
   /sbin/lsmod | sort -k 3 -rn            # Sorted by dependency count

   # System architecture and capabilities
   uname -a                                # Kernel and architecture
   arch                                    # Architecture (x86_64, aarch64, etc.)
   nproc                                   # Number of processing units
   getconf _NPROCESSORS_ONLN              # Number of online processors

.. rubric:: Hardware diagnostic toolkit checklist

.. code-block:: text

   Essential diagnostic packages:
   ☐ stress-ng       — CPU/memory stress testing
   ☐ lm-sensors      — Temperature, voltage, fan sensors
   ☐ smartmontools   — S.M.A.R.T. disk monitoring (smartctl, smartd)
   ☐ memtest86+      — RAM testing (requires reboot)
   ☐ mcelog          — Machine Check Exception logging
   ☐ edac-utils      — ECC memory error reporting
   ☐ sysstat         — sar, iostat, mpstat, pidstat, sadf
   ☐ iotop           — Per-process I/O monitoring
   ☐ htop            — Interactive process viewer
   ☐ dmidecode       — Hardware inventory from BIOS/firmware
   ☐ ipmitool        — IPMI/BMC management (servers)
   ☐ lshw            — Comprehensive hardware listing
   ☐ nvme-cli        — NVMe SSD management and diagnostics
   ☐ nvidia-smi      — NVIDIA GPU monitoring (if NVIDIA hardware)
   ☐ radeontop       — AMD GPU monitoring (if AMD hardware)
   ☐ intel-gpu-tools — Intel GPU diagnostics
