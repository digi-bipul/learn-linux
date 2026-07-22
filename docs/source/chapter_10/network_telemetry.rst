.. _ch10-network-telemetry:

###########################################################
10.5  Network Telemetry & Control
###########################################################

.. epigraph::

   "The network is the computer."
   — John Gage (Sun Microsystems, 1984)

----------------------------------------------------------------------
10.5.1  Active Testing with ``iperf3``
----------------------------------------------------------------------

**Server (listener):**

.. code-block:: console

   $ iperf3 -s

**Client (throughput test):**

.. code-block:: console

   $ iperf3 -c 10.0.0.1 -t 30 -P 4
   [ ID] Interval           Transfer     Bandwidth       Retr  Cwnd
   [  5]   0.00-30.00  sec  35.9 GBytes  10.3 Gbits/sec  142   1.12 MB

- **Bandwidth:** 10.3 Gbps — acceptable for a 10 G link.
- **Retr (retransmits):** 142 packets / 30 sec. Low (< 0.1%). High = congestion.
- **Cwnd:** TCP congestion window. Small (< 64 KB) = congested path.

**Bidirectional and reverse tests:**

.. code-block:: console

   $ iperf3 -c 10.0.0.1 -R          # Reverse (server → client)
   $ iperf3 -c 10.0.0.1 --bidir     # Both directions

**UDP test (jitter and loss):**

.. code-block:: console

   $ iperf3 -c 10.0.0.1 -u -b 100M -l 1472
   [ ID] Interval           Transfer     Bandwidth       Jitter    Lost/Total Datagrams
   [  5]   0.00-10.00  sec   119 MBytes   100 Mbits/sec  0.023 ms  0/84953 (0%)

----------------------------------------------------------------------
10.5.2  Modern Socket Statistics: ``ss`` and ``nstat`` (Abandoning ``netstat``)
----------------------------------------------------------------------

.. admonition:: R.I.P. ``netstat`` — Why We Abandon It
   :class: important

   ``netstat`` reads ``/proc/net/`` with known race conditions, is slow at
   >100k connections, and has been **deprecated in favour of ``ss`` since
   2009**. It is no longer installed by default (Debian ≥ 12, RHEL ≥ 9).
   **Teaching ``netstat`` in 2026 is irresponsible.**

``ss`` — socket statistics
============================

.. code-block:: console

   $ ss -tlnp
   State    Recv-Q   Send-Q     Local Address:Port     Peer Address:Port   Process
   LISTEN   0        128            0.0.0.0:80            0.0.0.0:*       users:(("nginx",pid=1234))

- **Recv-Q:** Bytes received but not consumed. Growth = application slow to read.
- **Send-Q:** Bytes queued but not acknowledged. Growth = remote slow or congestion.

**Advanced ``ss`` flags:**

.. code-block:: console

   # Show TCP internals (congestion algo, cwnd, rtt)
   $ ss -ti
   ESTAB   0       0        10.0.0.1:443         10.0.0.2:54321
        cubic wscale:7,7 rto:200 rtt:3.5/1.75 ato:40 mss:1448 cwnd:10

   # All sockets with process info, no DNS
   $ ss -tuanp

``nstat`` — kernel SNMP counters
===================================

.. code-block:: console

   $ nstat -az
   #kernel
   TcpRetransSegs                  1234         0.0
   TcpExtTCPLoss                   5            0.0
   TcpExtTCPTimeouts               12           0.0
   TcpExtTCPOFOQueue               0            0.0

**Critical counters:**

- **TcpRetransSegs:** Retransmission count. Rate > 0.1% = investigate.
- **TcpExtTCPLoss:** Segments lost (SACK/RTO detected).
- **TcpExtTCPTimeouts:** Connection timeouts.
- **IpInDiscards, IpOutDiscards:** Kernel-level packet drops.

----------------------------------------------------------------------
10.5.3  Network Interface Tuning with ``ethtool``
----------------------------------------------------------------------

.. code-block:: console

   $ ethtool -i eth0
   driver: mlx5_core
   firmware-version: 26.34.2000

   $ ethtool eth0
   Speed: 100000Mb/s

**Ring buffer tuning:**

.. code-block:: console

   $ ethtool -S eth0 | grep drop
   rx_missed_errors: 14567       # Hardware drops — increase ring buffer

   $ ethtool -G eth0 rx 4096 tx 4096

**Offload features:**

.. code-block:: console

   $ ethtool -k eth0
   tcp-segmentation-offload: on
   generic-segmentation-offload: on
   generic-receive-offload: on

   $ ethtool -K eth0 lro on   # Enable Large Receive Offload

**IRQ affinity:**

.. code-block:: console

   $ ethtool -l eth0        # Show queue count
   $ ethtool -x eth0        # Show RSS indirection table
   $ echo 1 > /proc/irq/123/smp_affinity   # Pin IRQ to CPU 0

----------------------------------------------------------------------
10.5.4  Mitigating Bufferbloat with ``tc`` and Modern AQMs
----------------------------------------------------------------------

**Bufferbloat** is the phenomenon where large buffers cause excessive latency.
AQM algorithms drop/mark packets *before* buffers fill.

``fq_codel`` — the baseline AQM
=================================

.. code-block:: console

   $ tc qdisc replace dev eth0 root fq_codel
   $ tc -s qdisc show dev eth0

``cake`` — the comprehensive AQM
==================================

.. code-block:: console

   # Shape to 100 Mbps down / 10 Mbps up
   $ tc qdisc replace dev eth0 root cake bandwidth 100mbit

   # With per-flow isolation
   $ tc qdisc replace dev eth0 root cake bandwidth 100mbit \
         diffserv4 nat wash

**Measuring the improvement:**

.. code-block:: console

   # Before AQM — RTT under load may spike to 200+ ms
   $ netperf -H 10.0.0.1 -l 10 & ping -c 100 -i 0.01 10.0.0.1

   # After AQM — RTT should stay < 20 ms
   $ tc qdisc replace dev eth0 root cake bandwidth 100mbit
   $ ping -c 100 -i 0.01 10.0.0.1

----------------------------------------------------------------------
10.5.5  Network USE Checklist
----------------------------------------------------------------------

.. code-block:: console

   # 1. Utilisation
   $ sar -n DEV 1
   $ ethtool eth0 | grep Speed

   # 2. Saturation
   $ ethtool -S eth0 | grep -E "miss|drop|error"
   $ ss -ti | grep -E "cwnd|rtt"

   # 3. Errors
   $ nstat -az | grep -E "Retrans|Loss|Drop|Discard|Error"

   # 4. Bandwidth test
   $ iperf3 -c 10.0.0.1 -t 10 -P 4

   # 5. Bufferbloat test
   $ netperf -H 10.0.0.1 -l 10 & ping -c 100 -i 0.01 10.0.0.1

   # 6. AQM applied?
   $ tc qdisc show dev eth0
