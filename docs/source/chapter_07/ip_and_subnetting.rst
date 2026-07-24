.. _sec-07-02:

=======================================
IP Addressing & Subnetting
=======================================

IP addressing is the postal system of the internet. Every device on a network
must have a unique address, and the structure of that address determines how
routers efficiently deliver data without needing a map of every individual
device. This section covers the two IP protocol versions in use today, the concept of
subnetting that keeps the internet from collapsing under its own size, the
notation you will see in every configuration file, and the critical distinction
between public and private address space.

IPv4: The Workhorse
==========================

IPv4 addresses are 32-bit numbers, conventionally written in **dotted decimal
notation** — four octets separated by dots:

::

    192 . 168 .  1  . 10
    11000000 10101000 00000001 00001010

Each octet ranges from 0 to 255 (28 - 1). The total theoretical address space
is 2^32 = approximately 4.3 billion addresses.

An IPv4 address has two logical components:

+-----------------+-----------------------------------------------------------+
| Component       | Description                                                |
+=================+===========================================================+
| **Network       | The upper bits that identify the network segment. All     |
| portion** | devices on the same subnet share the same network bits.   |
+-----------------+-----------------------------------------------------------+
| **Host          | The remaining bits that identify a specific interface     |
| portion** | within that subnet.                                        |
+-----------------+-----------------------------------------------------------+

Where the boundary between network and host lies is determined by the **subnet
mask** (or, equivalently, the **CIDR prefix length**).

Subnet Masks and CIDR Notation
=====================================

**Subnet Mask**

A subnet mask is a 32-bit number where bits in the network portion are 1 and
bits in the host portion are 0. For example, the mask ``255.255.255.0`` in
binary is:

::

    11111111 . 11111111 . 11111111 . 00000000
    \_______network_______/ \___host___/

This tells us: the first 24 bits are the network; the last 8 bits are the host.
A device with address ``192.168.1.10`` and mask ``255.255.255.0`` is on network
``192.168.1.0``.

**CIDR Notation (Classless Inter-Domain Routing)**

CIDR notation compactly expresses both the address and the mask by appending a
slash and the number of network bits:

::

/24

This reads: "network 192.168.1.0 with a 24-bit mask." It is equivalent to
``192.168.1.0 255.255.255.0``. CIDR superseded the older "classful" system
(Class A /8, Class B /16, Class C /24) in the early 1990s because classful
addressing was too inflexible — it forced everyone into three rigid sizes.

Common CIDR prefixes:

+----------+----------------+----------------------------------------------+
| Prefix   | Mask           | Usable Hosts (2\ :sup:`h` - 2)               |
+==========+================+==============================================+
| /32      | 255.255.255.255| 1 (single host, no network)                  |
+----------+----------------+----------------------------------------------+
| /30      | 255.255.255.252| 2 (typically a point-to-point link)          |
+----------+----------------+----------------------------------------------+
| /28      | 255.255.255.240| 14                                           |
+----------+----------------+----------------------------------------------+
| /24      | 255.255.255.0  | 254 (typical "Class C" size)                 |
+----------+----------------+----------------------------------------------+
| /16      | 255.255.0.0    | 65,534 (typical "Class B" size)              |
+----------+----------------+----------------------------------------------+
| /8       | 255.0.0.0      | 16,777,214 (typical "Class A" size)          |
+----------+----------------+----------------------------------------------+

Note the "- 2": the first address in a subnet is the **network address** (all
host bits 0) and the last address is the **broadcast address** (all host bits
1). Neither can be assigned to an interface.

Subnetting in Practice: A Worked Example
===============================================

Suppose your organisation is assigned the block ``10.0.0.0/24`` (256 addresses)
and you need four subnets: one for servers (50 hosts), one for desktops (100
hosts), one for guest Wi-Fi (20 hosts), and one for management (10 hosts).
Because the required subnet sizes differ, you use **Variable-Length Subnet
Masking (VLSM)** — the practical reality that different subnets within the same
network can have different prefix lengths.

**Step 1 — Sort by size.** The largest need is desktops (100 → need 7 host bits
for 126 usable addresses → /25). We allocate the first /25 subnet:

::

    Subnet A (desktops):   10.0.0.0/25   (usable: 10.0.0.1 – 10.0.0.126)

**Step 2 — Next largest.** Servers need 50 → need 6 host bits (62 usable → /26).
Start where the last subnet ended: 10.0.0.128.

::

    Subnet B (servers):    10.0.0.128/26 (usable: 10.0.0.129 – 10.0.0.190)

**Step 3 — Guest Wi-Fi** needs 20 → 5 host bits (30 usable → /27).

::

    Subnet C (guests):     10.0.0.192/27 (usable: 10.0.0.193 – 10.0.0.222)

**Step 4 — Management** needs 10 → 4 host bits (14 usable → /28).

::

    Subnet D (mgmt):       10.0.0.224/28 (usable: 10.0.0.225 – 10.0.0.238)

We have used 80 of the 256 addresses and still have room to grow.
Key formula: **Required bits for N hosts** = ceil(log2(N+2)). The "+2" accounts
for network and broadcast addresses.

IPv6: The Future (and Present)
=====================================

IPv6 was standardised in 1998 (RFC 2460) to solve IPv4 address exhaustion.
Addresses are 128 bits — 2^128 = 340 undecillion addresses, enough to assign an
IP to every atom on Earth's surface many times over.

**Notation:** Eight groups of four hexadecimal digits, colon-separated:

::

    2001:0db8:85a3:0000:0000:8a2e:0370:7334

Abbreviation rules:

* Leading zeros in a group may be omitted: ``0370`` → ``370``.
* One contiguous run of all-zero groups may be replaced with ``::`` (but only
  once per address): ``2001:db8:85a3::8a2e:370:7334``.

**IPv6 address types:**

+-------------+----------------------------------------------------------+
| Type        | Description                                              |
+=============+==========================================================+
| Global      | Public, routable on the internet. Prefix ``2000::/3``.   |
| Unicast     |                                                          |
+-------------+----------------------------------------------------------+
| Link-Local  | Required on every interface. Used for Neighbor Discovery,|
|             | automatic address configuration. Prefix ``fe80::/10``.   |
|             | Not routable.                                            |
+-------------+----------------------------------------------------------+
| Unique      | Private, routable within an organisation. Prefix         |
| Local       | ``fc00::/7``. Analogous to IPv4 RFC 1918 space.          |
+-------------+----------------------------------------------------------+
| Multicast   | One-to-many. Prefix ``ff00::/8``.                        |
+-------------+----------------------------------------------------------+

**Key differences from IPv4:**

* No NAT is needed (the address space is large enough that every device can
  have a globally unique address).
* ARP is replaced by **Neighbor Discovery Protocol (NDP)**, which uses ICMPv6
  messages.
* Broadcast addresses do not exist. Multicast replaces broadcast.
* IPv6 has mandatory **IPsec** support (though its use is not automatic; it
  must be configured).

**Do you need to be an IPv6 expert today?** Not necessarily for internal
administration, but you must be able to recognise an IPv6 address, understand
that IPv6 stacks are enabled by default on modern Linux, and know that many
public cloud services now require IPv6 readiness.

Public vs. Private IPs (RFC 1918)
========================================

Not every IP address is globally routable. The Internet Assigned Numbers
Authority (IANA) reserved three blocks of IPv4 address space for **private
networks** — networks that are not directly reachable from the internet.
These are defined in **RFC 1918**:

+-------------------+-----------------+------------------------------------------+
| RFC 1918 Block    | CIDR            | Typical Use                              |
+===================+=================+==========================================+
| 10.0.0.0 –        | 10.0.0.0/8      | Large enterprise / cloud VPCs (one /8    |
| 10.255.255.255    |                 | provides 16 million addresses).          |
+-------------------+-----------------+------------------------------------------+
| 172.16.0.0 –      | 172.16.0.0/12   | Medium-sized deployments. Some cloud     |
| 172.31.255.255    |                 | VPCs default to this range.              |
+-------------------+-----------------+------------------------------------------+
| 192.168.0.0 –     | 192.168.0.0/16  | Home / small office networks (65,000     |
| 192.168.255.255   |                 | addresses). Typical home router uses     |
|                   |                 | 192.168.1.0/24 or 192.168.0.0/24.        |
+-------------------+-----------------+------------------------------------------+

Devices with private IP addresses communicate with the internet through
**Network Address Translation (NAT)** — typically performed by your router or
cloud gateway. NAT rewrites the source IP address of outbound packets from the
private address to the router's public address, and maps return traffic back.

For IPv6, the analogous private space is **Unique Local Addresses (ULA)**,
prefix ``fc00::/7``, defined in RFC 4193. However, the conventional IPv6
design philosophy discourages NAT. Most IPv6 deployments give every device a
globally unique address and rely on firewall rules for security rather than
address scarcity.

Special-Purpose Addresses
================================

Be aware of these reserved addresses you will encounter:

+------------------+----------------------------------------------------------+
| Address          | Purpose                                                  |
+==================+==========================================================+
| 127.0.0.0/8      | **Loopback** — traffic to these addresses stays within   |
|                  | the local host. 127.0.0.1 (localhost) is the most        |
|                  | common. IPv6: ``::1``.                                   |
+------------------+----------------------------------------------------------+
| 0.0.0.0/8        | "This network." Used as a source address by a host       |
|                  | before it obtains an IP (e.g., DHCP). Also used to bind  |
|                  | a service to all interfaces (``0.0.0.0:80``).            |
+------------------+----------------------------------------------------------+
| 169.254.0.0/16   | **Link-Local (APIPA)** — automatically assigned when     |
|                  | DHCP fails. An address in this range means the host      |
|                  | could not reach a DHCP server.                           |
+------------------+----------------------------------------------------------+
| 224.0.0.0/4      | **IPv4 multicast** addresses. Used for protocols like    |
|                  | VRRP, mDNS, etc.                                         |
+------------------+----------------------------------------------------------+

Summary
==============

* IPv4 addresses are 32-bit, written in dotted decimal. The boundary between
  network and host is defined by a subnet mask (or CIDR prefix).
* CIDR notation (``/N``) compactly expresses the prefix length. Subnetting
  divides a block into smaller subnets to match sizing requirements.
* IPv6 addresses are 128-bit hex, with abbreviation rules. Every modern Linux
  system supports IPv6 out of the box.
* Private IP ranges (RFC 1918) are for internal use and require NAT for
  internet access.
* Recognizing these concepts in the wild — in configuration files, in the
  output of ``ip addr``, in firewall rules — is an essential skill.
