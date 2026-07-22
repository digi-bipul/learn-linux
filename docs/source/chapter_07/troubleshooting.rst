.. _sec-07-09:

=======================================
7.9 Network Troubleshooting
=======================================

No matter how carefully you configure a network, things will break. A cable
will be unplugged, a firewall rule will be too strict, a DNS server will
stumble, or a router will drop packets. The difference between a novice and an
expert is not the absence of problems — it is the ability to diagnose and
resolve them methodically.

This section presents the administrator's diagnostic toolkit. We cover each
tool in depth: what it measures, how to interpret its output, and how to apply
it in a real troubleshooting workflow.

7.9.1 The Troubleshooting Methodology
======================================

Before reaching for any tool, have a mental framework:

1. **Define the problem precisely.** "The website is down" is vague. "I cannot
   connect to 203.0.113.10 on port 443 from this client" is actionable.
2. **Check yourself.** Can you reach any other hosts? Is the problem specific to
   one destination, one service, or one client?
3. **Isolate the layer.** Start at the bottom and work up:
   * Layer 1: Is the cable plugged in? Is the link light on?
   * Layer 2: Can you ARP the gateway?
   * Layer 3: Can you ping the gateway? Can you traceroute to the destination?
   * Layer 4: Is the remote port open? (``ss -tulpn``, ``nmap``)
   * Layer 7: Is the application responding? (``curl``, ``wget``)
4. **Form a hypothesis and test it.** "The firewall is blocking port 443" →
   check the firewall rules.
5. **Fix, verify, document.**

7.9.2 ping — The Layer 3 Reachability Test
===========================================

``ping`` sends ICMP Echo Request packets to a target host and waits for Echo
Reply packets. It is the most basic test of whether a remote host is reachable
at the network layer.

.. code-block:: bash

    # Basic ping
    ping 8.8.8.8

    # Ping with a specific count (Linux stops automatically)
    ping -c 5 8.8.8.8

    # Ping with a specific interval (default 1 second)
    ping -i 0.5 8.8.8.8

    # Ping with a specific packet size
    ping -s 1472 8.8.8.8

**Interpreting output:**

::

    PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
    64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=12.3 ms
    64 bytes from 8.8.8.8: icmp_seq=2 ttl=117 time=12.1 ms
    64 bytes from 8.8.8.8: icmp_seq=3 ttl=117 time=12.5 ms

    --- 8.8.8.8 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2000ms
    rtt min/avg/max/mdev = 12.091/12.333/12.587/0.221 ms

* **``ttl=117``** — Time To Live. Each router hop decrements this by 1. The
  starting TTL (typically 64, 128, or 255) minus the received TTL gives the
  number of hops. Here ``255 - 117 = 138`` hops would be impossible for the
  internet; this indicates the starting TTL was 128, so ``128 - 117 = 11`` hops.
* **``time=12.3 ms``** — Round-trip latency. Consistent values indicate a stable
  path. Jitter (varying times) may indicate congestion or a failing link.
* **``0% packet loss``** — If non-zero, packets are being dropped somewhere
  along the path.

**Important caveat:** Many networks block ICMP traffic entirely. A failed ping
does *not* necessarily mean the host is unreachable on other protocols (TCP,
UDP). Always try a TCP-based test (like ``curl``) when ping fails.

7.9.3 traceroute / mtr — Path Discovery
========================================

When you can reach a host but the connection is slow, or when you cannot reach
a host but ping to the gateway works, you need to know the **path** packets
take.

**traceroute — Classic Path Discovery**

``traceroute`` works by sending packets with incrementing TTL values. The
first packet has TTL=1; the first router decrements it to 0 and returns an
ICMP Time Exceeded message. Traceroute records the router's IP. Then TTL=2,
and so on.

.. code-block:: bash

    # Basic traceroute
    traceroute 8.8.8.8

    # Use TCP packets (bypass ICMP blocks)
    traceroute -T -p 80 8.8.8.8

    # Use UDP packets (traditional method)
    traceroute -U 8.8.8.8

    # Don't resolve IPs to names (faster)
    traceroute -n 8.8.8.8

    # Set a specific interface
    traceroute -i eth0 8.8.8.8

**Troubleshooting interpretation:**

.. code-block:: text

    traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
    1  192.168.1.1  1.2 ms  1.1 ms  1.3 ms
    2  10.0.0.1    2.5 ms  2.3 ms  2.6 ms
    3  * * *
    4  203.0.113.1  15.2 ms  15.5 ms  15.1 ms
    5  72.14.222.1  18.2 ms  18.5 ms  18.3 ms
    6  8.8.8.8     12.1 ms  12.3 ms  12.5 ms

* Hop 3 shows ``* * *`` — the router did not respond (common; many routers are
  configured not to send ICMP Time Exceeded).
* The latency jump from hop 2 to hop 4 (2.5 ms → 15.2 ms) may indicate a
  geographic distance or a congested link.
* The final hop shows a lower latency (12 ms from hop 6) because that is the
  final destination responding, not an intermediate router.

**mtr — The Best of ping and traceroute**

``mtr`` (My Traceroute) continuously probes each hop and provides real-time
statistics on packet loss and latency. It is arguably the most valuable single
troubleshooting tool.

.. code-block:: bash

    # Install
    sudo apt install mtr        # Debian/Ubuntu
    sudo dnf install mtr        # Fedora/RHEL

    # Run (text-based UI)
    mtr 8.8.8.8

    # Run in report mode (non-interactive, for scripts)
    mtr -r -c 10 8.8.8.8

    # Run without DNS lookups
    mtr -n 8.8.8.8

    # Use TCP instead of ICMP
    mtr -T -P 443 example.com

**Output interpretation:**

::

                                          Loss%   Snt   Last   Avg  Best  Wrst StDev
    1. 192.168.1.1                         0.0%    10   1.1   1.2   1.0   1.5   0.2
    2. 10.0.0.1                            0.0%    10   2.2   2.4   2.0   3.0   0.3
    3. 203.0.113.1                        50.0%    10  15.1  15.3  15.0  16.0   0.4
    4. 72.14.222.1                         0.0%    10  18.0  18.2  17.9  19.0   0.3
    5. 8.8.8.8                             0.0%    10  12.0  12.3  12.0  13.0   0.3

**Critical insight:** The packet loss at hop 3 is *not* damaging traffic to
hop 5 (0% loss). This means hop 3 is deprioritising ICMP responses but is
correctly forwarding the actual packets. If hop 3 showed 50% loss *and* hop 5
showed the same, the link at hop 3 would be the problem.

**Rule of thumb for mtr:** The last hop with high loss is the problem node.
If a middle hop shows loss but subsequent hops do not, ignore it — some
routers rate-limit ICMP responses.

7.9.4 tcpdump — Packet Sniffing
=================================

``tcpdump`` captures raw packets from a network interface and displays them in
human-readable form. It is the ultimate tool for diagnosing what is *actually*
on the wire, not what you think should be there.

.. code-block:: bash

    # Capture all packets on eth0
    sudo tcpdump -i eth0

    # Capture only 10 packets, then stop
    sudo tcpdump -i eth0 -c 10

    # Don't resolve hostnames (faster, cleaner)
    sudo tcpdump -i eth0 -n

    # Show packets in hex and ASCII (for protocol debugging)
    sudo tcpdump -i eth0 -X

    # Write to a file for later analysis
    sudo tcpdump -i eth0 -w capture.pcap

    # Read from a capture file
    tcpdump -r capture.pcap

    # Increase buffer size (prevents packet drops under load)
    sudo tcpdump -i eth0 -B 4096

**Filter expressions (BPF — Berkeley Packet Filter):**

.. code-block:: bash

    # Filter by host
    sudo tcpdump -i eth0 host 8.8.8.8

    # Filter by source or destination
    sudo tcpdump -i eth0 src 192.168.1.100
    sudo tcpdump -i eth0 dst 192.168.1.100

    # Filter by port
    sudo tcpdump -i eth0 port 22
    sudo tcpdump -i eth0 port 53

    # Filter by protocol
    sudo tcpdump -i eth0 icmp
    sudo tcpdump -i eth0 tcp
    sudo tcpdump -i eth0 udp

    # Complex filters
    sudo tcpdump -i eth0 'tcp port 80 and (src host 192.168.1.100 or src host 10.0.0.1)'

    # Capture TCP SYN packets only
    sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0'

    # Capture DNS queries and responses
    sudo tcpdump -i eth0 -n port 53

**Practical troubleshooting example — Watching an SSH connection:**

.. code-block:: bash

    # Terminal 1: Start capture on port 22
    sudo tcpdump -i eth0 -n port 22

    # Terminal 2: Initiate an SSH connection
    ssh user@server

    # tcpdump output:
    12:00:00.123456 IP 192.168.1.100.45000 > 203.0.113.10.22: Flags [S], seq 12345, ...
    12:00:00.123789 IP 203.0.113.10.22 > 192.168.1.100.45000: Flags [S.], seq 67890, ...
    12:00:00.123912 IP 192.168.1.100.45000 > 203.0.113.10.22: Flags [.], ack 67891, ...

The three-way TCP handshake: SYN, SYN-ACK, ACK. If you see SYN sent but no
SYN-ACK returned, the remote host is not listening or a firewall is dropping
the SYN packet.

7.9.5 nmap — Port Scanning and Host Discovery
===============================================

``nmap`` (Network Mapper) scans hosts and networks to discover open ports,
running services, operating systems, and more. It is an essential tool for
both security auditing and troubleshooting.

**Installation:**

.. code-block:: bash

    sudo apt install nmap        # Debian/Ubuntu
    sudo dnf install nmap        # Fedora/RHEL

**Basic scans:**

.. code-block:: bash

    # Scan a single host for the 1000 most common ports
    nmap 192.168.1.100

    # Scan all 65535 ports (slow)
    nmap -p- 192.168.1.100

    # Scan specific ports
    nmap -p 22,80,443 192.168.1.100

    # Scan a subnet
    nmap 192.168.1.0/24

    # Detect service versions
    nmap -sV 192.168.1.100

    # Detect OS
    nmap -O 192.168.1.100

    # Aggressive scan (OS, services, scripts, traceroute)
    nmap -A 192.168.1.100

**Port states:**

+----------------+----------------------------------------------------------+
| State          | Meaning                                                  |
+================+==========================================================+
| ``open``       | An application is actively accepting connections on this |
|                | port.                                                    |
+----------------+----------------------------------------------------------+
| ``filtered``   | The port is blocked by a firewall; nmap cannot determine |
|                | whether it is open or closed.                            |
+----------------+----------------------------------------------------------+
| ``closed``     | No application is listening; the host responded with a   |
|                | RST packet.                                              |
+----------------+----------------------------------------------------------+
| ``unfiltered`` | The port is accessible but nmap cannot determine its     |
|                | state. Rare.                                             |
+----------------+----------------------------------------------------------+

**Practical use case — Verify a firewall change:**

.. code-block:: bash

    # Before adding a firewall rule, check which ports are open
    nmap -p 22,80,443 localhost

    # After adding a rule, scan from outside the host to confirm
    nmap -p 22,80,443 target.example.com

**Caution:** Scanning hosts without permission is illegal in many
jurisdictions. Only scan hosts you own or have explicit written permission to
test.

7.9.6 iperf3 — Bandwidth Testing
==================================

``iperf3`` measures the maximum achievable bandwidth between two hosts. It is
invaluable for validating network throughput and identifying bottlenecks.

**Setup:**

.. code-block:: bash

    # Install on both client and server
    sudo apt install iperf3
    sudo dnf install iperf3

**Server side:**

.. code-block:: bash

    # Start iperf3 in server mode
    iperf3 -s

    # Listen on a specific port
    iperf3 -s -p 5201

**Client side:**

.. code-block:: bash

    # Default test (TCP upload from client to server)
    iperf3 -c server.example.com

    # Test for 30 seconds instead of default 10
    iperf3 -c server.example.com -t 30

    # Reverse test (server → client, measures download)
    iperf3 -c server.example.com -R

    # UDP test (measure jitter and packet loss)
    iperf3 -c server.example.com -u -b 100M

    # Use multiple parallel streams
    iperf3 -c server.example.com -P 4

**Interpreting output:**

::

    [ ID] Interval           Transfer     Bitrate         Retr  Cwnd
    [  5]   0.00-10.00  sec  1.10 GBytes  945 Mbits/sec    0    1.56 MBytes
    [  5]  10.00-10.04  sec  4.00 MBytes  944 Mbits/sec    0    1.56 MBytes
    - - - - - - - - - - - - - - - - - - - - - - - - -
    [ ID] Interval           Transfer     Bitrate         Retr
    [  5]   0.00-10.04  sec  1.10 GBytes  940 Mbits/sec    0             sender
    [  5]   0.00-10.04  sec  1.10 GBytes  940 Mbits/sec               receiver

* **Bitrate:** 940 Mbits/sec on a 1 Gbps link — excellent, the 60 Mbps
  overhead is expected (TCP/IP headers, Ethernet framing).
* **Retr:** 0 — no TCP retransmissions, indicating a clean, uncongested link.
* **Cwnd:** 1.56 MBytes — the TCP congestion window, a measure of how much
  data is in flight.

If you see a bitrate far below link capacity (e.g., 50 Mbps on a 1 Gbps link)
and many retransmissions, the link likely has packet loss, a faulty cable, or
network congestion.

7.9.7 curl / wget — HTTP Diagnostics
======================================

Both ``curl`` and ``wget`` download files via HTTP, HTTPS, and other
protocols. ``curl`` is the more versatile tool for diagnostics because it
exposes headers and connection details.

**curl — The Diagnostic Swiss Army Knife**

.. code-block:: bash

    # Basic request
    curl https://example.com

    # Show response headers and connection details (verbose)
    curl -v https://example.com

    # Show only response headers
    curl -I https://example.com

    # Follow redirects and show the final URL
    curl -L https://example.com

    # Use a specific protocol version
    curl --http1.1 https://example.com
    curl --http2 https://example.com

    # Specify a custom port
    curl http://example.com:8080

    # Set a custom User-Agent
    curl -A "Mozilla/5.0" https://example.com

    # Timeout after a specified duration
    curl --connect-timeout 5 --max-time 10 https://example.com

    # Resolve a hostname to a specific IP (bypass DNS)
    curl --resolve example.com:443:93.184.216.34 https://example.com

    # Measure timing breakdown
    curl -w "\nTime: %{time_total}s\n" https://example.com

**Interpreting curl -v output:**

::

    * Trying 93.184.216.34:443...
    * Connected to example.com (93.184.216.34) port 443 (#0)
    * ALPN: offers h2,http/1.1
    * SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
    * Server certificate: example.com
    * Server certificate expiration: 2027-01-15
    > GET / HTTP/2
    > Host: example.com
    > User-Agent: curl/8.0.0
    >
    < HTTP/2 200
    < content-type: text/html; charset=UTF-8
    < date: Mon, 15 Jan 2026 12:00:00 GMT
    < server: ECS (dcb/7F5A)
    <

* ``Trying ...:443...`` — DNS resolution succeeded and a TCP connection is
  being established.
* ``Connected to ... port 443`` — TCP handshake complete.
* ``SSL connection using TLSv1.3`` — TLS handshake successful.
* ``> GET / HTTP/2`` — The request being sent.
* ``< HTTP/2 200`` — The server's response status line.

**wget — Simpler Download Tool**

.. code-block:: bash

    # Basic download
    wget https://example.com/file.iso

    # Resume an interrupted download
    wget -c https://example.com/file.iso

    # Set a timeout
    wget --timeout=10 https://example.com

    # Mirror a website (careful with this)
    wget -r -l 2 --no-parent https://example.com

``wget`` is less diagnostic-oriented than ``curl`` but excels at recursive
downloads and resumption of interrupted transfers.

7.9.8 End-to-End Troubleshooting Scenario
==========================================

Let us walk through a realistic problem: "Users cannot connect to the web
server at ``www.example.com``."

**Step 1 — Check client-side DNS:**

.. code-block:: bash

    $ dig +short www.example.com
    203.0.113.10

DNS resolves. Good.

**Step 2 — Check connectivity (Layer 3):**

.. code-block:: bash

    $ ping -c 3 203.0.113.10
    PING 203.0.113.10 (203.0.113.10) 56(84) bytes of data.
    --- 203.0.113.10 ping statistics ---
    3 packets transmitted, 0 received, 100% packet loss

Ping fails. But ICMP may be blocked.

**Step 3 — Check the port (Layer 4):**

.. code-block:: bash

    $ nmap -p 80,443 203.0.113.10
    Starting Nmap ...
    PORT    STATE    SERVICE
    80/tcp  filtered http
    443/tcp filtered https

"Filtered" suggests a firewall is blocking the ports.

**Step 4 — Check the path with mtr:**

.. code-block:: bash

    $ mtr -n 203.0.113.10
    ...
    4. 198.51.100.1     0.0%    10    5ms
    5. 203.0.113.1      0.0%    10    8ms
    6. 203.0.113.10     0.0%    10    8ms

The path is clear; the server itself is reachable.

**Step 5 — Check the server's firewall:**

.. code-block:: bash

    $ ssh admin@203.0.113.10
    $ sudo nft list ruleset
    table inet filter {
        chain input {
            type filter hook input priority filter; policy drop;
            ct state established,related accept
            tcp dport 22 accept
            # Missing: tcp dport 80, 443
        }
    }

The firewall has no rules allowing HTTP/HTTPS. The solution:

.. code-block:: bash

    sudo nft add rule inet filter input tcp dport 80 accept
    sudo nft add rule inet filter input tcp dport 443 accept
    sudo nft list ruleset > /etc/nftables.conf

**Step 6 — Verify the fix:**

.. code-block:: bash

    $ curl -I https://www.example.com
    HTTP/2 200

Problem solved.

7.9.9 Quick Reference: Diagnostic Flow
=======================================

::

    Can you reach the gateway?
    ├── No  → Check physical link (ip link), cable, switch port
    │         Check IP configuration (ip addr, ip route)
    │
    └── Yes → Can you reach the remote host?
        ├── No  → Check firewall on local host (nftables / ufw / firewalld)
        │         Run mtr to see where packets stop
        │         Check remote host firewall (if you have access)
        │
        └── Yes → Can you reach the specific port?
            ├── No  → Check that the service is running (systemctl status)
            │         Check firewall on the remote host
            │         (Common: service bound to 127.0.0.1 instead of 0.0.0.0)
            │
            └── Yes → Application issue (check logs, application config)

This structured approach turns a panic into a process. Learn it, internalise
it, and your troubleshooting time will shrink dramatically.

7.9.10 Summary of Tools
=========================

+------------+----------------------------------------------------------+
| Tool       | When to Use                                              |
+============+============================================================+
| ``ping``   | Quick Layer 3 reachability test (ICMP).                  |
+------------+----------------------------------------------------------+
| ``mtr``    | Path discovery with real-time loss and latency stats.    |
+------------+----------------------------------------------------------+
| ``tcpdump``| Inspect raw packets; diagnose protocol-level issues.     |
+------------+----------------------------------------------------------+
| ``nmap``   | Port scan; discover services and open ports.             |
+------------+----------------------------------------------------------+
| ``iperf3`` | Measure bandwidth and identify throughput bottlenecks.   |
+------------+----------------------------------------------------------+
| ``curl``   | HTTP/S diagnostics; inspect headers and TLS details.     |
+------------+----------------------------------------------------------+
| ``wget``   | Download files; recursive or resumable transfers.        |
+------------+----------------------------------------------------------+
| ``ss``     | Inspect local sockets (listening and established).       |
+------------+----------------------------------------------------------+
| ``ip``     | Inspect and manipulate addresses, routes, links.         |
+------------+----------------------------------------------------------+
| ``dig``    | DNS querying — the most authoritative DNS tool.          |
+------------+----------------------------------------------------------+
