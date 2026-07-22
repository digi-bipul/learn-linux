.. _sec-07-01:

=======================================
7.1 Foundational CS Networking Theory
=======================================

Before we configure a single interface, we must establish a mental model of how
computers communicate. This section provides the conceptual foundation a Linux
professional needs in order to diagnose problems, interpret tool output, and
understand what the kernel is actually doing when it sends or receives data.
We deliberately avoid the depths of physical-layer engineering (modulation,
signal encoding, cable impedance). Our focus is the abstraction layers from the
link layer upward — the layers a system administrator touches every day.

7.1.1 Why Layering? The Sandwich Metaphor
==========================================

Networking protocols are organised into *layers*. Each layer provides a service
to the layer above it and consumes a service from the layer below. Think of a
sandwich shop:

* The **customer** (application) orders a turkey sandwich.
* The **cashier** (transport layer) writes the order on a ticket — "turkey on
  rye, no mustard" — and hands it to the kitchen.
* The **kitchen** (network layer) decides which chef should make it, routes the
  ticket.
* The **chef** (data-link layer) wraps the finished sandwich in paper, labels
  it.
* The **delivery driver** (physical layer) carries the wrapped sandwich to the
  customer.

Each layer is self-contained. The cashier does not need to know how the
kitchen assigns work; the chef does not need to know how the customer placed
the order. This *separation of concerns* allows technology at one layer to be
replaced entirely without disturbing the others. You can swap out your physical
cabling from copper to fibre without rewriting your web server.

7.1.2 The OSI Model (The Full Seven Layers)
============================================

The **Open Systems Interconnection (OSI) model**, standardised by ISO in 1984,
defines seven layers. Memorising all seven is less important than understanding
the *principle* of layering, but the OSI model remains the lingua franca for
discussing networking architecture. From bottom to top:

+----------+---------------------+----------------------------------------------+
| Layer    | Name                | What happens at this layer                   |
+==========+=====================+==============================================+
| 7        | Application         | HTTP, SMTP, SSH, DNS — protocols the user    |
|          |                     | directly interacts with.                     |
+----------+---------------------+----------------------------------------------+
| 6        | Presentation        | Encoding, encryption, compression. TLS/SSL   |
|          |                     | technically lives here (and partly at L5).   |
+----------+---------------------+----------------------------------------------+
| 5        | Session             | Establishing, managing, terminating          |
|          |                     | conversations between applications.          |
+----------+---------------------+----------------------------------------------+
| 4        | Transport           | TCP (reliable, ordered) or UDP (fast,        |
|          |                     | connectionless). Port numbers live here.     |
+----------+---------------------+----------------------------------------------+
| 3        | Network             | IP addressing, routing. Packets and routers. |
+----------+---------------------+----------------------------------------------+
| 2        | Data Link           | MAC addressing, switching. Frames and        |
|          |                     | switches.                                    |
+----------+---------------------+----------------------------------------------+
| 1        | Physical            | Electrical signals, light pulses, radio      |
|          |                     | waves. Cables, transceivers, antennas.       |
+----------+---------------------+----------------------------------------------+

*Key insight for administrators:* You almost never deal with Layer 1 directly
(except when a cable is unplugged). Layers 2 and 3 are where you diagnose
connectivity. Layer 4 is where you control access (firewalls, port filtering).
Layers 5–7 are the purview of application configuration.

7.1.3 The TCP/IP Stack (The Four-Layer Model)
==============================================

The OSI model is a *conceptual* framework. The *practical* model used by the
internet is the **TCP/IP stack** (also called the Internet Protocol Suite),
which collapses seven layers into four:

+------------------+-----------------------------------------------------------+
| TCP/IP Layer     | OSI Equivalents                                           |
+==================+===========================================================+
| Application      | Layers 5–7 (Session, Presentation, Application)           |
+------------------+-----------------------------------------------------------+
| Transport        | Layer 4 (Transport) — TCP or UDP                          |
+------------------+-----------------------------------------------------------+
| Internet         | Layer 3 (Network) — IP                                    |
+------------------+-----------------------------------------------------------+
| Link             | Layers 1–2 (Physical, Data Link)                          |
+------------------+-----------------------------------------------------------+

When you hear someone say "Layer 3 switch" or "Layer 4 load balancer", they are
referring to the OSI layer number. When you hear "TCP/IP", they mean the
practical four-layer stack. Both are valid; use whichever is more precise for
the context.

7.1.4 Packets vs. Frames: The Encapsulation Dance
==================================================

The single most important concept for a Linux administrator to internalise is
*encapsulation*. Imagine a Russian nesting doll (matryoshka). Data starts at the application
layer and gets wrapped (encapsulated) inside headers from each lower layer:

1. An application (e.g., a web browser) produces a **message** (an HTTP GET
   request).
2. The transport layer (TCP) wraps that message inside a **segment**, adding a
   TCP header with a source port and a destination port, plus sequence numbers
   for reliability.
3. The network layer (IP) wraps the segment inside a **packet**, adding an IP
   header with a source IP address and a destination IP address.
4. The data-link layer wraps the packet inside a **frame**, adding a MAC header
   with source and destination MAC addresses, plus a trailer (FCS — Frame Check
   Sequence) for error detection.

The receiver performs the reverse process: strip the frame, inspect the packet,
reassemble the segments, deliver the message to the application.

::

    [ Frame Header | IP Header | TCP Header | HTTP Data | Frame Trailer ]
        ^              ^            ^            ^
        |              |            |            |
      MAC addrs     IP addrs     Ports      Payload

**The critical distinction:**

* A **frame** (Layer 2) moves data between *directly connected devices on the
  same network segment* — between your laptop and your Wi-Fi access point, or
  between a server and its upstream switch.
* A **packet** (Layer 3) moves data across *multiple network segments* — from
  your laptop to a web server on another continent. The packet is carried inside
  a series of frames, each hop re-encapsulating the same packet into a new frame
  with new MAC addresses.

This is why a router strips the incoming frame, inspects the packet's
destination IP, consults its routing table, then wraps the same packet into a
*new* frame for the next hop. The packet lives across the entire path; frames
live only for a single hop.

7.1.5 MAC Addresses vs. IP Addresses
=====================================

| **MAC address** (Media Access Control) — 48 bits, usually written as six
  hexadecimal octets (e.g., ``a4:5e:60:de:ad:be``). Every network interface
  card (NIC) is factory-assigned a globally unique MAC address. It is an
  *identifier*, not a *locator*. It tells you *who* a device is, not *where*
  it is.
| **IP address** (Internet Protocol) — 32 bits (IPv4) or 128 bits (IPv6). An IP
  address is a *locator*. It tells the network *where* a device lives. The
  network prefix identifies the subnet; the host portion identifies the specific
  interface on that subnet.

If MAC addresses are like a person's name (persistent, unique to the device),
IP addresses are like a mailing address (hierarchical, changes when you move to
a new network).

The **Address Resolution Protocol (ARP)** for IPv4 (and **Neighbor Discovery
Protocol** for IPv6) bridges the gap: when a host knows an IP address but needs
the corresponding MAC address to build a frame, it broadcasts an ARP request:
"Who has IP 192.168.1.10? Tell me your MAC address."

7.1.6 Switching vs. Routing
============================

**Switching (Layer 2)**

A *switch* forwards frames based on destination MAC addresses. When a frame
arrives on a switch port, the switch reads the destination MAC, looks it up in
its CAM (Content-Addressable Memory) table, and forwards the frame out of the
appropriate port — *without* modifying the frame. Switching is fast and
hardware-accelerated.

Switches create a single *broadcast domain*: a frame sent to the broadcast MAC
address (``ff:ff:ff:ff:ff:ff``) reaches every device on the switched network.

**Routing (Layer 3)**

A *router* forwards packets based on destination IP addresses. When a packet
arrives, the router:

1. Strips the incoming frame.
2. Decrements the IP Time-to-Live (TTL) field.
3. Looks up the destination IP in its routing table.
4. Finds the best matching route (or drops the packet if none matches).
5. Wraps the packet in a new frame addressed to the next-hop MAC.
6. Sends the new frame out of the appropriate interface.

Routers separate broadcast domains. A broadcast on one side of a router does
not reach the other side.

**Practical relevance:** When your Linux server cannot reach the internet, the
first question is whether the destination is on your *local subnet* (switching)
or beyond your gateway (routing). If your default gateway is unreachable, no
off-subnet traffic will flow.

7.1.7 Ports and Sockets
========================

The **port** is a 16-bit number (0–65535) that identifies a specific process or
service on a host. Ports are the mechanism that allows a single IP address to
host multiple simultaneous connections — SSH on port 22, HTTP on port 80, HTTPS
on port 443, all on the same machine.

A **socket** is the combination of:

::

    (Protocol, Source IP, Source Port, Destination IP, Destination Port)

For TCP, this 5-tuple uniquely identifies a connection. For example:

::

    TCP 192.168.1.100:45000 → 93.184.216.34:80

This socket says: "There is a TCP connection from my ephemeral port 45000 to
the web server at 93.184.216.34 on port 80." A different process on the same
machine using a different ephemeral port would be a different socket.

Port ranges:

+-------------+----------------------------------------------------------+
| Range       | Classification                                           |
+=============+==========================================================+
| 0–1023      | **Well-known ports** — reserved for system services.     |
|             | Only root can bind to these. Examples: 22 (SSH),         |
|             | 80 (HTTP), 443 (HTTPS), 53 (DNS).                        |
+-------------+----------------------------------------------------------+
| 1024–49151  | **Registered ports** — assigned by IANA to specific      |
|             | applications but can be used by any user. Example:       |
|             | 3306 (MySQL), 5432 (PostgreSQL), 8080 (HTTP-alt).        |
+-------------+----------------------------------------------------------+
| 49152–65535 | **Dynamic / ephemeral ports** — used temporarily by      |
|             | clients when initiating outbound connections.            |
+-------------+----------------------------------------------------------+

7.1.8 TCP vs. UDP: A Quick Comparison
======================================

Enough theory for a conceptual foundation. Two transport protocols dominate:

+----------------+----------------------------------------+--------------------------------------+
| Property       | TCP (Transmission Control Protocol)    | UDP (User Datagram Protocol)         |
+================+========================================+======================================+
| Connection     | Connection-oriented — three-way        | Connectionless — no handshake        |
|                | handshake (SYN, SYN-ACK, ACK)          |                                      |
+----------------+----------------------------------------+--------------------------------------+
| Reliability    | Guaranteed delivery via ACKs and       | No guarantee — "fire and forget"     |
|                | retransmission                         |                                      |
+----------------+----------------------------------------+--------------------------------------+
| Ordering       | Data arrives in the order sent         | Packets may arrive out of order      |
+----------------+----------------------------------------+--------------------------------------+
| Flow control   | Yes — sliding window algorithm         | No                                   |
+----------------+----------------------------------------+--------------------------------------+
| Use cases      | Web, email, file transfer, SSH         | DNS, VoIP, streaming video, DHCP     |
+----------------+----------------------------------------+--------------------------------------+

As a systems administrator, you will write firewall rules that distinguish TCP
from UDP because different services use different protocols. DNS, for example,
uses UDP for queries (port 53) but may fall back to TCP for large responses.

7.1.9 Summary: The Administrator's Mental Map
==============================================

When you type a URL into a browser or ``ssh`` into a remote server, this chain
of events occurs, and each link in the chain is a potential failure point:

1. **DNS resolution** — the hostname is translated to an IP address (Layer 7).
2. **Routing decision** — the kernel checks whether the destination is local or
   remote (Layer 3). For a remote destination, it finds the default gateway.
3. **ARP / NDP** — the kernel resolves the next-hop IP to a MAC address to
   build a frame (Layer 2 ↔ Layer 3 bridge).
4. **Framing** — the packet is wrapped in an Ethernet (or Wi-Fi) frame and
   transmitted onto the wire (Layer 2).
5. **Switching** — hops through local switches reach the gateway (Layer 2).
6. **Routing** — the gateway (router) forwards the packet toward the
   destination (Layer 3), repeating steps 3–6 at each hop.
7. **Arrival** — the destination host strips frames, reassembles segments, and
   delivers data to the listening application (Layers 2→3→4→7).

This section has given you the vocabulary and mental model. The rest of the
chapter fills in the practical details — how Linux implements each of these
steps, and how you control and observe that implementation.
