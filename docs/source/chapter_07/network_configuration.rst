.. _sec-07-04:

=======================================
7.4 Network Configuration Ecosystems
=======================================

Commands like ``ip addr add`` and ``ip route add`` change the kernel's
network state *immediately*, but those changes are **transient** — they vanish
on reboot. To make network configuration persistent across restarts, Linux
distributions use configuration systems that re-apply the desired state at
boot time. The landscape is fragmented. Different distributions (and even different
versions of the same distribution) use different tools. This section covers the
four major systems you will encounter in production, with guidance on which to
use and when.

7.4.1 Netplan (Ubuntu 17.10+)
==============================

**Netplan** is a YAML-based network configuration abstraction layer developed
by Canonical for Ubuntu. It does not configure the network itself; instead, it
reads a set of YAML files at boot time and generates back-end configuration for
either **NetworkManager** (for desktop) or **systemd-networkd** (for
server/cloud). You never edit the back-end files directly.

**Configuration location:** ``/etc/netplan/*.yaml``

**Basic structure:**

.. code-block:: yaml
   :caption: /etc/netplan/01-netcfg.yaml

   network:
     version: 2
     renderer: networkd
     ethernets:
       eth0:
         dhcp4: true
       eth1:
         addresses:
           - 10.0.100.10/24
         routes:
           - to: 10.20.0.0/16
             via: 10.0.100.1
         nameservers:
           addresses:
             - 8.8.8.8
             - 8.8.4.4
         dhcp4: false

**Applying changes:**

.. code-block:: bash

    # Validate the configuration syntax
    sudo netplan try

    # If validation passes, 
    apply permanently
    sudo netplan apply

    # Generate back-end config without applying (for inspection)
    sudo netplan generate

``netplan try`` is a safety net: it applies the configuration for a short
timeout (default 120 seconds) and rolls back if you do not confirm. If you
accidentally cut off your network access, wait for the timeout, and the
previous configuration is restored.

**Key points:**

* Netplan prioritises files alphabetically. Later files override earlier ones.
* The ``renderer`` key chooses the back-end: ``networkd`` (default for
  server) or ``NetworkManager`` (default for desktop).
* Netplan supports bonds, bridges, VLANs, and Wi-Fi networks.
* You can use ``sudo netplan set`` to modify settings from the command line
  (e.g., ``sudo netplan set ethernets.eth0.dhcp4=false``).

7.4.2 NetworkManager (Desktop / RHEL / Fedora)
===============================================

**NetworkManager** is the de-facto standard for desktop Linux networking and is
also the default on RHEL, Fedora, CentOS, and many derivatives. It provides a
D-Bus API, a GUI applet, ``nmcli`` (command-line client), and ``nmtui``
(textual user interface).

NetworkManager manages connections as *profiles*. Each profile can be
associated with a device and contains all the settings (IP, DNS, routes, VPN,
etc.).

**Command-line usage (``nmcli``):**

.. code-block:: bash

    # Show all connections (profiles)
    nmcli connection show

    # Show active devices and their state
    nmcli device status

    # Show detailed device info
    nmcli device show eth0

    # Create a new static connection profile
    nmcli connection add type ethernet con-name my-server ifname eth0 \
        ipv4.method manual ipv4.addresses 192.168.1.100/24 \
        ipv4.gateway 192.168.1.1 ipv4.dns 8.8.8.8

    # Modify an existing connection
    nmcli connection modify my-server ipv4.dns "1.1.1.1 8.8.8.8"

    # Activate a connection
    nmcli connection up my-server

    # Deactivate and bring down
    nmcli connection down my-server

    # Delete a connection
    nmcli connection delete my-server

    # Re-scan Wi-Fi networks
    nmcli device wifi rescan

    # Connect to a Wi-Fi network
    nmcli device wifi connect "MyWiFi" password "secret"

**Key files:** Connection profiles are stored in ``/etc/NetworkManager/system-connections/`` as ``.nmconnection`` files (keyfile format).

**When to use NetworkManager:** On any desktop or laptop, and on RHEL/Fedora
server installations where it is the default. It is well-integrated with
``firewalld``, VPN plugins, and the desktop environment. On lightweight
servers or containers, you may prefer ``systemd-networkd``.

7.4.3 systemd-networkd (Modern Server Standard)
=================================================

``systemd-networkd`` is a part of the systemd ecosystem and is rapidly becoming
the standard for server and cloud networking. It is lightweight, fast, and
configured with simple ``.network`` files.

**Configuration location:** ``/etc/systemd/network/`` (or ``/run/systemd/network/``
for runtime configuration).

**File types:**

* ``.link`` files — low-level interface properties (MAC, MTU, rename policy).
* ``.netdev`` files — virtual devices (bonds, bridges, VLANs, VXLANs).
* ``.network`` files — IP addresses, routes, DNS, DHCP.

**Example — Static configuration:**

.. code-block:: ini
   :caption: /etc/systemd/network/10-eth0.network

   [Match]
   Name=eth0

   [Network]
   Address=192.168.1.100/24
   Gateway=192.168.1.1
   DNS=8.8.8.8
   DNS=1.1.1.1

   [DHCPv4]
   UseDNS=false

**Example — DHCP configuration:**

.. code-block:: ini
   :caption: /etc/systemd/network/10-eth0.network

   [Match]
   Name=eth0

   [Network]
   DHCP=ipv4

   [DHCPv4]
   UseDNS=true
   UseDomains=true

**Managing the service:**

.. code-block:: bash

    # Enable and start the daemon
    sudo systemctl enable --now systemd-networkd

    # Restart to re-read configuration files
    sudo systemctl restart systemd-networkd

    # Check status
    systemctl status systemd-networkd

    # Query current state
    networkctl status
    networkctl list

``networkctl`` is the companion command-line tool. ``networkctl status eth0``
shows you exactly which ``.network`` file is currently applied to the
interface, along with link state, speed, and DHCP lease details.

**Interoperability note:** NetworkManager and ``systemd-networkd`` cannot both
manage the same interface simultaneously. If you switch a server from
NetworkManager to ``systemd-networkd``, you must either uninstall
NetworkManager or configure it to ignore the interfaces that
``systemd-networkd`` controls (``nmcli device set eth0 managed no``).

7.4.4 Legacy ifupdown (Older Debian / Ubuntu)
==============================================

Before Netplan, Debian and Ubuntu used the ``ifupdown`` package, configured
via ``/etc/network/interfaces``. This system is still present on many older
systems and is the default for Debian if Netplan is not installed.

**Configuration file:** ``/etc/network/interfaces`` (and
``/etc/network/interfaces.d/`` for snippets).

**Example — static configuration:**

::

    # The loopback interface
    auto lo
    iface lo inet loopback

    # Static configuration for eth0
    auto eth0
    iface eth0 inet static
        address 192.168.1.100/24
        gateway 192.168.1.1
        dns-nameservers 8.8.8.8 1.1.1.1

**Example — DHCP:**

::

    auto eth0
    iface eth0 inet dhcp

**Managing interfaces:**

.. code-block:: bash

    # Bring an interface up
    sudo ifup eth0

    # Bring an interface down
    sudo ifdown eth0

    # Reload all interfaces defined in /etc/network/interfaces
    sudo ifup -a

**Why this is legacy:** The ``ifupdown`` system is simple but inflexible. It
does not handle dynamic configurations (like Wi-Fi roaming) gracefully, has
limited support for complex setups (bonds, bridges, VLANs), and has no
integration with modern init systems or D-Bus. If you encounter it, migrate to
``systemd-networkd`` or Netplan at your earliest convenience.

7.4.5 Choosing the Right System
================================

+---------------------+------------------------+-------------------------------+
| Scenario            | Recommended System     | Reason                        |
+=====================+========================+===============================+
| Ubuntu Desktop      | Netplan (renderer:     | Canonical's default; GUI      |
|                     | NetworkManager)        | integration.                  |
+---------------------+------------------------+-------------------------------+
| Ubuntu Server       | Netplan (renderer:     | Canonical's default for       |
|                     | networkd)              | server; clean YAML syntax.    |
+---------------------+------------------------+-------------------------------+
| Fedora / RHEL       | NetworkManager +       | Red Hat's default; firewalld  |
|                     | nmcli                  | integration.                  |
+---------------------+------------------------+-------------------------------+
| Arch / minimal      | systemd-networkd       | Lightweight, no dependencies  |
| server              |                        | beyond systemd.               |
+---------------------+------------------------+-------------------------------+
| Debian (old)        | ifupdown (migrate)     | Still works but deprecated.   |
+---------------------+------------------------+-------------------------------+
| Containers / VMs    | systemd-networkd       | Minimal, predictable, no      |
|                     |                        | desktop dependencies.         |
+---------------------+------------------------+-------------------------------+

**Golden rule:** Know which system your distribution uses before you start
editing files. Running ``systemctl status systemd-networkd`` and checking
whether NetworkManager is active will tell you instantly what you are dealing
with.

7.4.6 Practical Workflow: Configuring a New Interface
======================================================

Regardless of the system, the workflow is the same:

1. **Identify the interface name:** ``ip link show`` or ``ip addr``.
2. **Decide on addressing:** Static or DHCP? If static, what IP, subnet,
   gateway, DNS?
3. **Write the config file** in the appropriate format for your system.
4. **Apply the config** (``netplan apply``, ``nmcli connection up``,
   ``systemctl restart systemd-networkd``, or ``ifup``).
5. **Verify:** ``ip addr``, ``ip route show``, ``ping`` the gateway.
6. **Persist:** The configuration is now persistent across reboots. Confirm
   with a reboot test if possible.
