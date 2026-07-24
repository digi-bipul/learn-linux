.. _sec-07-03:

=======================================
The ip Command Suite
=======================================

The ``ip`` command from the ``iproute2`` package is the modern, unified tool
for managing virtually every aspect of Linux networking. It replaces a handful
of legacy tools — most notably ``ifconfig`` (interface configuration),
``route`` (routing table), and ``arp`` (address resolution) — all of which are
deprecated and should *never* be used on a modern system.

**Distribution:** ``iproute2`` is installed by default on every major Linux
distribution. If by some chance it is missing, install it with your package
manager; but that scenario is vanishingly rare.

This section is organised by sub-command. Each corresponds to a distinct area
of network management.

ip addr — Interface Address Management
=============================================

The ``ip addr`` (short for ``ip address``) sub-command displays and configures
IP addresses on network interfaces.

**Display all addresses:**

::

    $ ip addr
    1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
        link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
        inet 127.0.0.1/8 scope host lo
           valid_lft forever preferred_lft forever
        inet6 ::1/128 scope host noprefixroute
           valid_lft forever preferred_lft forever
    2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP 
    group default qlen 1000
        link/ether 52:54:00:12:34:56 brd ff:ff:ff:ff:ff:ff
        inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic eth0
           valid_lft 86342sec preferred_lft 86342sec
        inet6 fe80::5054:ff:fe12:3456/64 scope link noprefixroute
           valid_lft forever preferred_lft forever

Let us dissect this output field by field for interface ``eth0``:

+------------------+----------------------------------------------------------+
| Field            | Meaning                                                  |
+==================+==========================================================+
| ``2: eth0:``     | Interface index (``2``) and name (``eth0``).             |
+------------------+----------------------------------------------------------+
| ``<...>``        | **Flags:** ``UP`` = interface is administratively up;    |
|                  | ``LOWER_UP`` = physical link is detected (cable          |
|                  | plugged in); ``BROADCAST`` = supports L2 broadcast;      |
|                  | ``MULTICAST`` = supports multicast transmission.         |
+------------------+----------------------------------------------------------+
| ``mtu 1500``     | Maximum Transmission Unit — the largest L3 packet that   |
|                  | can be sent on this interface (in bytes). Standard       |
|                  | Ethernet = 1500. Jumbo frames = 9000.                    |
+------------------+----------------------------------------------------------+
| ``qdisc fq_codel``| The queuing discipline — controls how packets are       |
|                  | queued for transmission. ``fq_codel`` is a modern        |
|                  | fair-queuing algorithm with controlled delay.            |
+------------------+----------------------------------------------------------+
| ``state UP``     | The operational state of the interface (``UP``,          |
|                  | ``DOWN``, ``UNKNOWN``).                                  |
+------------------+----------------------------------------------------------+
| ``link/ether ...``| The MAC address of the interface.                       |
+------------------+----------------------------------------------------------+
| ``inet 10.0.2.15/24``| The IPv4 address with its CIDR prefix.               |
+------------------+----------------------------------------------------------+
| ``scope global`` | Address scope: ``global`` (routable), ``host``           |
|                  | (loopback only), ``link`` (link-local only).             |
+------------------+----------------------------------------------------------+
| ``dynamic``      | Address was assigned via DHCP. Static addresses lack     |
|                  | this flag.                                               |
+------------------+----------------------------------------------------------+
| ``valid_lft``    | Valid lifetime — how long the address remains            |
|                  | preferred. For DHCP, this is the lease duration.         |
+------------------+----------------------------------------------------------+

**Common operations:**

.. code-block:: bash

    # Add an IP address to an interface
    sudo ip addr add 192.168.1.100/24 dev eth0

    # Remove an IP address
    sudo ip addr del 192.168.1.100/24 dev eth0

    # Show only IPv4 addresses
    ip -4 addr

    # Show only IPv6 addresses
    ip -6 addr

    # Show a specific interface
    ip addr show dev eth0

    # Flush all IP addresses from an interface (useful before 
    reconfiguring)
    sudo ip addr flush dev eth0

**Why ``ifconfig`` is forbidden:** The legacy ``ifconfig`` (from ``net-tools``)
cannot display IPv6 addresses reliably, has no concept of CIDR notation, and
does not support multiple addresses per interface with proper scope labels.
``ip addr`` is superior in every dimension.

ip link — Interface Link-Layer Control
=============================================

While ``ip addr`` manages Layer 3 (IP) configuration, ``ip link`` manages
Layer 2 (link-layer) properties: bring interfaces up or down, change MAC
addresses, set MTU, manage VLANs, and inspect link state.

**Common operations:**

.. code-block:: bash

    # List all links (interfaces)
    ip link show

    # Bring an interface up or down
    sudo ip link set eth0 up
    sudo ip link set eth0 down

    # Set or change the MTU
    sudo ip link set eth0 mtu 9000

    # Change the MAC address (requires interface to be down first)
    sudo ip link set eth0 down
    sudo ip link set eth0 address aa:bb:cc:dd:ee:ff
    sudo ip link set eth0 up

    # Rename an interface (also requires it to be down)
    sudo ip link set eth0 down
    sudo ip link set eth0 name net0
    sudo ip link set net0 up

    # Create a VLAN interface
    sudo ip link add link eth0 name eth0.100 type vlan id 100
    sudo ip link set eth0.100 up

**The ``LOWER_UP`` flag** is especially important for diagnostics. If
``ip link show`` reports ``state DOWN`` but the interface is administratively
up (``UP`` is in the flag list but ``LOWER_UP`` is missing), the physical
cable is disconnected — or the switch port is administratively disabled.

ip route — Routing Table Management
==========================================

The routing table is the kernel's map for where to send packets. When a packet
needs to leave the host, the kernel:

1. Checks if the destination IP is on a directly connected network (a "local"
   or "connected" route).
2. If not, looks for the most specific matching route in the routing table
   (longest prefix match).
3. If no match is found, uses the default route (``0.0.0.0/0``).
4. If no default route exists, the packet is dropped with "Network is
   unreachable."

**Display the routing table:**

::

    $ ip route show
    default via 10.0.2.1 dev eth0 proto dhcp src 10.0.2.15 metric 100
/24 dev eth0 proto dhcp scope link src 10.0.2.15 metric 100

Breaking this down:

+------------------+----------------------------------------------------------+
| Entry            | Meaning                                                  |
+==================+==========================================================+
| ``default``      | The default gateway — catch-all route for off-subnet     |
|                  | traffic.                                                 |
+------------------+----------------------------------------------------------+
| ``via 10.0.2.1`` | The next-hop IP address (the router).                    |
+------------------+----------------------------------------------------------+
| ``dev eth0``     | The interface through which this route is reachable.     |
+------------------+----------------------------------------------------------+
| ``proto dhcp``   | The routing protocol that installed this route (``dhcp``,|
|                  | ``kernel``, ``static``, ``bgp``, etc.).                  |
+------------------+----------------------------------------------------------+
| ``src 10.0.2.15``| The preferred source IP address for packets using this   |
|                  | route.                                                   |
+------------------+----------------------------------------------------------+
| ``metric 100``   | Lower metric = higher priority. If multiple routes match |
|                  | the same destination, the one with the lowest metric is  |
|                  | used.                                                    |
+------------------+----------------------------------------------------------+
| ``10.0.2.0/24``  | A directly connected (local) route — traffic for this    |
|                  | subnet is sent directly without a gateway.               |
+------------------+----------------------------------------------------------+
| ``scope link``   | The route applies only to the local link.                |
+------------------+----------------------------------------------------------+

**Common operations:**

.. code-block:: bash

    # Add a static route
    sudo ip route add 10.10.0.0/16 via 192.168.1.1 dev eth0

    # Add a default gateway
    sudo ip route add default via 192.168.1.1 dev eth0

    # Delete a route
    sudo ip route del 10.10.0.0/16

    # Replace a route (add or update atomically)
    sudo ip route replace 10.10.0.0/16 via 192.168.1.254 dev eth0

    # Show routes for a specific 
    destination
    ip route get 8.8.8.8
    # Output: 8.8.8.8 via 10.0.2.1 dev eth0 src 10.0.2.15 uid 1000

``ip route get`` is an invaluable troubleshooting command. It simulates the
routing decision and shows you exactly which route the kernel would use — and
which source IP it would choose — for a given destination.

ip neigh — The Neighbour (ARP) Cache
============================================

The neighbour table (historically called the ARP cache) maps IP addresses to
MAC addresses on the local network. ``ip neigh`` displays and manages this
table.

::

    $ ip neigh show
dev eth0 lladdr 52:54:00:ab:cd:ef REACHABLE
dev eth0 lladdr 52:54:00:11:22:33 STALE

States you will encounter:

+------------------+----------------------------------------------------------+
| State            | Meaning                                                  |
+==================+==========================================================+
| ``REACHABLE``    | The mapping was recently confirmed; traffic can be sent. |
+------------------+----------------------------------------------------------+
| ``STALE``        | The mapping exists but has not been confirmed recently.  |
|                  | A packet will trigger a new resolution attempt.          |
+------------------+----------------------------------------------------------+
| ``DELAY``        | Waiting for a short confirmation window before           |
|                  | transitioning to ``PROBE`` or back to ``REACHABLE``.     |
+------------------+----------------------------------------------------------+
| ``PROBE``        | A unicast ARP request has been sent; awaiting reply.     |
+------------------+----------------------------------------------------------+
| ``FAILED``       | Resolution failed — the target IP is not reachable at    |
|                  | the link layer.                                          |
+------------------+----------------------------------------------------------+
| ``INCOMPLETE``   | Resolution is in progress (ARP request sent, no reply).  |
+------------------+----------------------------------------------------------+

**Common operations:**

.. code-block:: bash

    # Manually add a neighbour entry (usually not needed)
    sudo ip neigh add 10.0.2.100 lladdr aa:bb:cc:dd:ee:ff dev eth0 nud permanent

    # Delete a neighbour entry
    sudo ip neigh del 10.0.2.100 dev eth0

    # Flush (clear) the neighbour cache for a specific interface
    sudo ip neigh flush dev eth0

    # Flush all entries in a particular state
    sudo ip neigh flush nud stale

You rarely need to manipulate the neighbour table manually, but inspecting 
it
is critical when you suspect Layer 2 issues — e.g., a device has changed its
MAC address, or ARP spoofing is occurring.

ss — The Modern Socket Statistics Tool
=============================================

``ss`` is the modern replacement for the legacy ``netstat``. It reads socket
information directly from the kernel's netlink interface, is faster than
``netstat``, and provides richer detail. **Never use ``netstat`` on a modern
system.**

**Basic usage — show all sockets:**

::

    $ ss -tulpn
    Netid  State   Recv-Q  Send-Q  Local Address:Port   Peer Address:Port   Process
    tcp    LISTEN  0       128     0.0.0.0:22           0.0.0.0:* users:(("sshd",pid=1024,fd=3))
    tcp    LISTEN  0       128  
    [::]:22              [::]:* users:(("sshd",pid=1024,fd=4))
    udp    UNCONN  0       0       127.0.0.53:53        0.0.0.0:* users:(("systemd-resolve",pid=814,fd=12))

Breaking down the flags in ``ss -tulpn``:

+----------+---------------------------------------------------------------+
| Flag     | Meaning                                                       |
+==========+===============================================================+
| ``-t``   | Show **t**CP sockets.                                         |
+----------+---------------------------------------------------------------+
| ``-u``   | Show **u**DP sockets.                                         |
+----------+---------------------------------------------------------------+
| ``-l``   | Show only **l**istening (server) sockets.                     |
+----------+---------------------------------------------------------------+
| ``-p``   | Show the **p**rocess that owns each socket (requires root for |
|          | full visibility).                                             |
+----------+---------------------------------------------------------------+
| ``-n``   | Show **n**umeric addresses and ports (do not resolve DNS or   |
|          | translate port numbers to service names).                     |
+----------+---------------------------------------------------------------+

**Other useful ``ss`` incantations:**

.. code-block:: bash

    # Show all TCP sockets (listening and established)
    ss -t

    # Show all established TCP connections
    ss -t state established

    # Show sockets in TIME_WAIT state
    ss -t state time-wait

    # Show all sockets for a specific destination port
    ss dst :443

    # Show all sockets for a specific source port
    ss src :22

    # Show socket memory usage
    ss -m

The ``Recv-Q`` and ``Send-Q`` columns show the number of bytes queued for
receiving or sending that have not yet been consumed by the application. Persistently non-zero values indicate a slow application or a full socket
buffer.

ip netns — Network Namespaces
=====================================

A brief mention, as this will be explored in later chapters: ``ip netns``
manages **network namespaces**, which create isolated network stacks
(interfaces, routes, firewall rules) within a single kernel. Containers rely on
network namespaces.

.. code-block:: bash

    # Create a namespace
    sudo ip netns add blue

    # Execute a command inside the namespace
    sudo ip netns exec blue ip addr

    # Move an interface into a namespace
    sudo ip link set veth0 netns blue

Network namespaces are fundamental to container networking (Docker, Podman,
Kubernetes) and will be covered in depth in the chapter on virtualization.

The Legacy Tools You Must Never Use
==========================================

.. list-table:: Replacement map
   :header-rows: 1

   * - Legacy Tool (``net-tools``)
     - Modern Replacement (``iproute2``)
   * - ``ifconfig``
     - ``ip addr``, ``ip link``
   * - ``route``
     - ``ip route``
   * - ``arp``
     - ``ip neigh``
   * - ``netstat``
     - ``ss``
   * - ``iptunnel``
     - ``ip tunnel``
   * - ``nameif``
     - ``ip link set name``

If you ever find yourself typing ``ifconfig`` or ``netstat``, stop, apologise
to your terminal, and use the ``iproute2`` equivalent. The legacy tools may not
even be installed in minimal container images or on modern distributions like
Fedora (which dropped ``net-tools`` from the default install in 2018).
