.. _chapter-11-1:

============================================================
11.1 Virtualization & MicroVMs
============================================================

Virtualization is the cornerstone of cloud computing. Before we discuss containers —
which share a host kernel — we must understand how **virtual machines (VMs)** provide
strong hardware-level isolation by emulating or para-virtualising a complete physical
machine, including CPU, memory, storage, and networking devices. This section covers the
hypervisor models, the Linux-native KVM/QEMU stack, the ``libvirt`` management layer,
and the emerging class of **MicroVMs** that blur the line between VMs and containers.

11.1.1 The Hypervisor: Type 1 vs Type 2
========================================

A **hypervisor** (also called a Virtual Machine Monitor, or VMM) is the software layer
that creates and runs virtual machines. There are two architectural families:

.. list-table:: Hypervisor Types
   :header-rows: 1
   :widths: 20 40 40

   * - Property
     - Type 1 (Bare-Metal)
     - Type 2 (Hosted)
   * - Runs directly on
     - Physical hardware (no host OS)
     - Host operating system
   * - Examples
     - VMware ESXi, Microsoft Hyper‑V, **KVM**
     - VirtualBox, VMware Workstation, QEMU (without KVM)
   * - Performance
     - Near-native (direct hardware access)
     - Lower (hardware access mediated by host OS)
   * - Use case
     - Data centres, cloud providers
     - Development, testing, personal use

**KVM — Kernel-based Virtual Machine** — turned Linux into a Type 1 hypervisor when it
was merged into the mainline kernel in 2007 (Linux 2.6.20). KVM is a loadable kernel
module (``kvm.ko``, ``kvm_amd.ko``, or ``kvm_intel.ko``) that exposes the CPU's
virtualisation extensions (Intel VT-x or AMD V) via the ``/dev/kvm`` character device.
User-space processes can issue ``ioctl`` calls on ``/dev/kvm`` to create and run
guest VCPUs (virtual CPUs) with near-native performance.

.. warning::
   **Common misconception:** KVM is *not* a complete VM solution by itself. It only
   provides CPU and memory virtualisation. You need a user-space emulator — typically
   QEMU — to provide device emulation (disk, NIC, BIOS, etc.).

11.1.2 QEMU and the KVM/QEMU Stack
===================================

**QEMU** (Quick Emulator) is a user-space process that emulates hardware devices. When
used *without* KVM, QEMU performs full software emulation (very slow, but capable of
emulating any architecture on any host). When used *with* KVM, QEMU delegates CPU and
memory virtualisation to the kernel module and emulates only the I/O devices — this
combination is the de-facto standard for Linux virtualisation.

The anatomy of a running QEMU/KVM VM:

.. code-block:: none

   ┌─────────────────────────────────────────────┐
   │               Host Linux Kernel              │
   │  ┌────────────┐  ┌────────────┐             │
   │  │ kvm.ko     │  │ kvm_intel  │             │
   │  │ (KVM API)  │  │ (VT-x drv) │             │
   │  └─────┬──────┘  └────────────┘             │
   │        │ /dev/kvm                            │
   └────────┼─────────────────────────────────────┘
            │ ioctl
   ┌────────┴─────────────────────────────────────┐
   │           QEMU process (qemu-system-x86_64)   │
   │  ┌──────────────┐  ┌──────────┐               │
   │  │ KVM vCPUs    │  │ Devices  │               │
   │  │ (threads)    │  │ virtio   │               │
   │  └──────────────┘  │ e1000    │               │
   │                    │ virtio-blk │             │
   │                    │ UEFI/BIOS │              │
   │                    └──────────┘               │
   │  Guest RAM (allocated via mmap)               │
   └───────────────────────────────────────────────┘
            │
   ┌────────┴─────────────────────────────────────┐
   │              Guest Linux Kernel               │
   │  (paravirtualised virtio drivers)             │
   └───────────────────────────────────────────────┘

Key points about this architecture:

* Each VM is a **single QEMU process** on the host.
* VCPUs are implemented as **host threads** scheduled by the Linux CFS (Completely Fair
  Scheduler).
* Guest RAM is allocated as **huge pages** (``/dev/hugepages``) to reduce TLB pressure.
* I/O uses **virtio** — a paravirtualised I/O framework where the guest kernel
  cooperates with the host to bypass emulation overhead.

**Creating a VM manually:**

.. code-block:: bash

   # 1. Verify KVM support
   lsmod | grep kvm
   ls -l /dev/kvm

   # 2. Create a disk image
   qemu-img create -f qcow2 my-vm.qcow2 20G

   # 3. Install a guest
   qemu-system-x86_64 \
     -machine q35,accel=kvm \
     -cpu host \
     -smp cpus=4 \
     -m 8192 \
     -drive file=my-vm.qcow2,format=qcow2,if=virtio \
     -cdrom ubuntu-24.04-live-server.iso \
     -nic user,model=virtio-net-pci \
     -vga virtio

   # 4. Run (after install, remove -cdrom)
   qemu-system-x86_64 \
     -machine q35,accel=kvm \
     -cpu host \
     -smp cpus=4 \
     -m 8192 \
     -drive file=my-vm.qcow2,format=qcow2,if=virtio \
     -nic user,hostfwd=tcp::2222-:22,model=virtio-net-pci \
     -vga none -nographic

11.1.3 libvirt and virsh: The Management Layer
===============================================

While QEMU command lines are powerful, they are unwieldy for production use. **libvirt**
is a daemon (``libvirtd``) that provides a stable, language-agnostic API for managing
virtualisation hosts. It supports multiple hypervisors (KVM/QEMU, Xen, LXC, VMware)
through a driver model.

Key components:

* ``libvirtd`` — the system daemon that manages VMs.
* ``virsh`` — the command-line shell for interacting with libvirt.
* ``virt-manager`` — a GUI for desktop management.
* ``virt-install`` — a helper for provisioning new VMs.

**libvirt storage model:**

.. code-block:: bash

   # List storage pools
   virsh pool-list --all

   # Create a directory-based storage pool
   virsh pool-define-as --name default --type dir --target /var/lib/libvirt/images
   virsh pool-start default
   virsh pool-autostart default

   # List volumes in a pool
   virsh vol-list default

**libvirt networking:**

libvirt provides a NAT-based virtual network (``default``) that allows VMs to reach
the outside world. For host-to-guest communication, it sets up a bridge (``virbr0``)
on the host.

.. code-block:: bash

   # List networks
   virsh net-list --all

   # Create an isolated network
   cat > isolated-net.xml << 'EOF'
   <network>
     <name>isolated</name>
     <forward mode='bridge'/>
     <bridge name='br-iso'/>
   </network>
   EOF
   virsh net-define isolated-net.xml
   virsh net-start isolated-net

**Provisioning VMs with virt-install:**

.. code-block:: bash

   virt-install \
     --name ubuntu-vm \
     --ram 4096 \
     --vcpus 2 \
     --disk size=20,pool=default \
     --os-variant ubuntu24.04 \
     --cdrom /data/isos/ubuntu-24.04-live-server.iso \
     --network network=default \
     --graphics spice

**Virsh lifecycle operations:**

.. code-block:: bash

   virsh list --all               # List all VMs (running + stopped)
   virsh start ubuntu-vm          # Start a VM
   virsh shutdown ubuntu-vm       # ACPI shutdown (graceful)
   virsh destroy ubuntu-vm        # Force power-off
   virsh reboot ubuntu-vm         # Reboot
   virsh console ubuntu-vm        # Serial console access
   virsh edit ubuntu-vm           # Edit XML definition in $EDITOR
   virsh undefine ubuntu-vm       # Remove VM (but keep disks)

**The domain XML:**

libvirt represents every VM as an XML document. Here is a minimal example:

.. code-block:: xml

   <domain type='kvm'>
     <name>ubuntu-vm</name>
     <memory unit='KiB'>4194304</memory>
     <vcpu placement='static'>2</vcpu>
     <os>
       <type arch='x86_64' machine='q35'>hvm</type>
       <boot dev='hd'/>
     </os>
     <features><acpi/><apic/></features>
     <cpu mode='host-passthrough'/>
     <devices>
       <disk type='file' device='disk'>
         <driver name='qemu' type='qcow2'/>
         <source file='/var/lib/libvirt/images/ubuntu-vm.qcow2'/>
         <target dev='vda' bus='virtio'/>
       </disk>
       <interface type='network'>
         <mac address='52:54:00:11:22:33'/>
         <source network='default'/>
         <model type='virtio'/>
       </interface>
       <console type='pty'/>
     </devices>
   </domain>

11.1.4 MicroVMs: The Best of Both Worlds
=========================================

Traditional VMs provide strong security isolation but suffer from:

* **Slow boot times** (30–90 seconds for a full kernel + init system).
* **High memory overhead** (each VM duplicates kernel data structures, page tables).
* **Large attack surface** (QEMU emulates dozens of legacy devices — IDE controllers,
  PS/2 keyboards, VGA BIOS, ACPI tables).

**MicroVMs** are a new class of VMMs that discard device emulation entirely and
implement only the minimum hardware necessary to boot a Linux kernel. They boot in
**milliseconds** (not seconds) and have a memory overhead measured in single-digit
megabytes per VM — approaching container density while retaining hardware isolation.

AWS Firecracker
---------------

**Firecracker** is the MicroVM that powers AWS Lambda and AWS Fargate. It was
open-sourced by Amazon in 2018 and is written in Rust. Firecracker uses KVM under the
hood but replaces QEMU with a minimal, security-hardened VMM.

Key design decisions:

* **No device emulation.** Only virtio-vsock (for host/guest comms), virtio-block,
  virtio-net, and a serial console — approximately five device models versus the
  hundreds in QEMU.
* **RESTful API.** Firecracker exposes an HTTP API on a Unix domain socket for all
  lifecycle operations (create VM, attach disk, start, stop).
* **jailer process.** A helper binary that drops privileges, applies seccomp filters,
  and isolates each MicroVM using Linux namespaces *before* the VMM starts.
* **Guest kernel.** Must be a **5.10+ Linux kernel** compiled with a minimal
  Firecracker-specific config. No ACPI, no PCI hotplug, no legacy hardware.
* **Root filesystem.** Guests use a pre-built ext4 image backed by a file or block
  device.

Firecracker architecture:

.. code-block:: none

   ┌──────────────────────────────────────────────┐
   │               Host Userspace                  │
   │  ┌────────────────┐  ┌──────────────────┐     │
   │  │ firecracker-vm1 │  │ firecracker-vm2  │     │
   │  │ (Rust VMM)      │  │ (Rust VMM)       │     │
   │  └───────┬─────────┘  └──────┬───────────┘     │
   │          │                    │                  │
   │   ┌──────┴──────┐     ┌──────┴──────┐          │
   │   │ jailer (ns) │     │ jailer (ns) │          │
   │   │ ┌─┐         │     │ ┌─┐         │          │
   │   │ │V│guest    │     │ │V│guest    │          │
   │   │ │C│kernel   │     │ │C│kernel   │          │
   │   │ │P│+init    │     │ │P│+init    │          │
   │   │ │U│         │     │ │U│         │          │
   │   │ └─┘         │     │ └─┘         │          │
   │   └─────────────┘     └─────────────┘          │
   └────────────────────────────────────────────────┘
                        │
   ┌────────────────────────────────────────────────┐
   │              Host Kernel (KVM)                  │
   └────────────────────────────────────────────────┘

**Using Firecracker:**

.. code-block:: bash

   # Download Firecracker binary
   ARCH="$(uname -m)"
   LATEST=$(curl -s https://api.github.com/repos/firecracker-microvm/firecracker/releases/latest | grep tag_name | cut -d'"' -f4)
   curl -LO "https://github.com/firecracker-microvm/firecracker/releases/download/${LATEST}/firecracker-${ARCH}"
   curl -LO "https://github.com/firecracker-microvm/firecracker/releases/download/${LATEST}/kernel-${ARCH}.bin"
   install firecracker-${ARCH} /usr/local/bin/firecracker

   # Download a rootfs (hello-rootfs example)
   curl -fsSL -o hello-rootfs.ext4 \
     https://s3.amazonaws.com/spec.ccfc.min/ci-rootfs/ubuntu-22.04.ext4

   # Start Firecracker with a REST API socket
   TAP=$(sudo ip tuntap add mode tap user $USER)
   sudo ip link set tap0 up
   sudo ip addr add 172.16.0.1/24 dev tap0

   # In one terminal — run Firecracker
   rm -f /tmp/firecracker.socket
   firecracker --api-sock /tmp/firecracker.socket &

   # In another — configure via the API
   curl --unix-socket /tmp/firecracker.socket -i \
     -X PUT 'http://localhost/boot-source' \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/json' \
     -d "{
       \"kernel_image_path\": \"vmlinux-${ARCH}.bin\",
       \"boot_args\": \"console=ttyS0 reboot=k panic=1 pci=off\"
     }"

   curl --unix-socket /tmp/firecracker.socket -i \
     -X PUT 'http://localhost/drives/rootfs' \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/json' \
     -d '{
       "drive_id": "rootfs",
       "path_on_host": "hello-rootfs.ext4",
       "is_root_device": true,
       "is_read_only": false
     }'

   curl --unix-socket /tmp/firecracker.socket -i \
     -X PUT 'http://localhost/actions' \
     -H 'Accept: application/json' \
     -H 'Content-Type: application/json' \
     -d '{ "action_type": "InstanceStart" }'

   # Connect to the VM via the serial console (telnet-style)
   # (Firecracker outputs to the terminal where it runs)
   # Inside the VM, configure networking:
   ip addr add 172.16.0.2/24 dev eth0
   ip link set eth0 up
   ip route add default via 172.16.0.1

Cloud Hypervisor
----------------

**Cloud Hypervisor** is an open-source VMM from the Intel/Cloud Native Computing
landscape. Written in Rust, it targets cloud workloads and is the foundation for
projects such as Kata Containers 2.x (which replaced the original QEMU-based runtime).
Cloud Hypervisor supports KVM on x86-64 and AArch64.

Feature highlights:

* Supports **direct device assignment** (VFIO) for high-performance workloads.
* Implements **vhost-user** for efficient data-plane networking and storage.
* Compatible with the Open Virtual Machine Firmware (OVMF) for UEFI boot.
* Exposes a REST API and a command-line interface (``cloud-hypervisor --help``).

**Comparison: Traditional VM vs MicroVM vs Container**

.. list-table::
   :header-rows: 1
   :widths: 15 25 30 30

   * - Property
     - Traditional VM (QEMU)
     - MicroVM (Firecracker)
     - Container (Docker/Podman)
   * - Isolation boundary
     - Hardware virtualisation
     - Hardware virtualisation
     - Kernel namespaces
   * - Boot time
     - 30–90 seconds
     - 100–300 ms
     - < 1 second (process)
   * - Memory overhead
     - 100–500 MB+ (guest kernel)
     - 5–10 MB (guest kernel)
     - 0 (shares host kernel)
   * - Device emulation
     - Hundreds of devices
     - 5–6 virtio devices
     - None
   * - Workload density
     - Low
     - High
     - Very high
   * - Security
     - Strong
     - Strong (reduced TCB)
     - Kernel-shared (weaker)
   * - Use case
     - General purpose VMs
     - FaaS (Lambda), Fargate
     - CI/CD, microservices

.. admonition:: Antipattern: Treating VMs as Pets
   :class: warning

   In the cloud native world, infrastructure is **ephemeral** and **immutable**.
   Avoid the trap of SSH-ing into a VM to tweak configuration files (pet VM
   syndrome). Instead, use tools like ``cloud-init``, Packer, or image pipelines to
   produce golden AMIs that are never modified after boot. This principle applies
   equally to MicroVMs and traditional VMs.

11.1.5 Anatomy: How KVM Handles a Guest Instruction
=====================================================

To truly understand virtualisation, trace the path of a single privileged instruction
executed inside a guest:

1. The guest kernel attempts to execute ``HLT`` (halt the CPU).
2. Because the guest is running in **unprivileged mode** (non-root ring 0; the VMX
   non-root mode on Intel), this instruction triggers a **VM-exit**.
3. The CPU hardware saves the guest state (registers, RIP, RSP) into the **VMCS**
   (Virtual-Machine Control Structure) and jumps to the host-defined exit handler
   in the KVM kernel module.
4. KVM inspects the exit reason (``VM_EXIT_REASON_HLT``), handles it internally
   (e.g., by yielding the host thread), and then re-enters the guest via
   ``VMLAUNCH`` or ``VMRESUME``.
5. The CPU restores guest state from the VMCS and resumes execution in VMX non-root
   mode.

This exit/enter cycle is called the **VM-exit cost**. For most I/O operations
(networking, disk), the cost is microseconds. However, frequent exits (e.g., from
overly aggressive I/O or from programming the programmable interrupt controller in
software) can degrade performance — which is why virtio and paravirtualised drivers
exist: they minimise exits by using shared memory rings between guest and host.

11.1.6 Practical Exercises
==========================

**1. KVM Readiness Check**

.. code-block:: bash

   # Verify your system supports KVM
   grep -E '(vmx|svm)' /proc/cpuinfo
   lsmod | grep kvm
   # If kvm is not loaded:
   sudo modprobe kvm_intel    # or kvm_amd
   # Also check /dev/kvm exists
   ls -l /dev/kvm

**2. libvirt VM Lifecycle**

.. code-block:: bash

   # Install libvirt
   sudo apt update && sudo apt install -y virt-manager libvirt-daemon-system
   sudo systemctl enable --now libvirtd

   # Create a minimal VM
   sudo virt-install \
     --name test-vm \
     --ram 2048 \
     --vcpus 2 \
     --disk size=10 \
     --os-variant ubuntu24.04 \
     --cdrom /dev/null \
     --network network=default \
     --graphics none \
     --print-xml > test-vm.xml

   # Define and start
   virsh define test-vm.xml
   virsh start test-vm

**3. Explore Firecracker (Advanced)**

If you have a Linux machine with KVM and at least 256 MB free RAM, download the
Firecracker binary and hello-rootfs example from the upstream repository, and boot
a MicroVM following the steps in §11.1.4. Measure boot time with ``time``.

