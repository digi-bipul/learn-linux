.. _app-c-network:

------------------------------------------------------------------------------
Network Diagnostics
------------------------------------------------------------------------------

------------------------------------------------------------------------------
Connectivity Troubleshooting (OSI Layered Approach)
------------------------------------------------------------------------------

.. list-table:: Network Troubleshooting by Layer
   :header-rows: 1
   :widths: 12 18 30 40

   * - Layer
     - Problem
     - Diagnostic Tool(s)
     - Typical Fix
   * - L1 (Physical)
     - Cable unplugged, NIC dead, switch port down
     - ``ip link``, ``ethtool``, ``dmesg | grep -i ethernet``
     - Replace cable, reseat NIC, check switch port LED
   * - L2 (Data Link)
     - MAC filtering, VLAN mismatch, bridge issues
     - ``bridge link``, ``ip neigh``, ``arp -n``, ``tcpdump -e``
     - Check switch port VLAN, verify STP state
   * - L3 (Network)
     - Wrong IP, subnet mask, gateway, no route
     - ``ip addr``, ``ip route``, ``ping``, ``traceroute``, ``mtr``
     - Fix IP config, add default route, check DHCP server
   * - L4 (Transport)
     - Firewall blocking, port not listening, full backlog
     - ``ss -tlnp``, ``nmap``, ``iptables -L``, ``nc -vz``
     - Open firewall port, start service, increase ``somaxconn``
   * - L5-L7 (App)
     - DNS resolution, TLS cert, application error
     - ``dig``, ``nslookup``, ``curl -v``, ``openssl s_client``
     - Fix DNS records, renew cert, check app logs

------------------------------------------------------------------------------
Interface & Link Diagnostics

.. code-block:: bash
   :caption: Checking link state and interface status

   # List all interfaces with state
   ip link show
   # Output: LOOPBACK, UP, DOWN, LOWER_UP (LOWER_UP = cable connected)

   # Check link speed and duplex
   ethtool eth0
   # Look for: Speed, Duplex, Auto-negotiation, Link detected: yes

   # Check interface statistics for errors
   ip -s link show eth0
   # Look for: RX errors, dropped, overrun; TX errors, dropped, carrier

   # Detailed NIC diagnostic
   ethtool -S eth0 | grep -E 'error|fail|drop|crc|miss'

   # Check for interface renaming (predictable names)
   dmesg | grep -i rename
   ls -l /sys/class/net/

------------------------------------------------------------------------------
IP Configuration Checks

.. code-block:: bash
   :caption: Verifying addressing, routing, and neighbours

   # Show all IP addresses
   ip addr show

   # Show routing table
   ip route show
   # Expected: default via <gateway> dev <iface>

   # ARP/neighbour table (L2-to-L3 mappings)
   ip neigh show
   # STALE = normal, REACHABLE = confirmed, FAILED = no response

   # Check what DHCP client is running
   ps aux | grep -E 'dhcp|dhclient|networkd|NetworkManager'

   # Renew DHCP lease
   sudo dhclient -v eth0                  # Debian-style
   sudo dhcpcd -n eth0                    # Arch-style

   # Check DNS configuration
   cat /etc/resolv.conf
   resolvectl status                      # systemd-resolved status
   systemd-resolve --status               # Older syntax

------------------------------------------------------------------------------
Connectivity Testing Tools

.. rubric:: ping — ICMP echo (basic reachability)

.. code-block:: bash

   ping -c 4 8.8.8.8                     # Test Internet connectivity
   ping -c 4 google.com                  # Test DNS + connectivity
   ping -c 4 -I eth0 10.0.0.1            # Ping from specific interface
   ping -s 1472 -M do -c 4 10.0.0.1      # Test MTU (1472 + 28 = 1500)

.. rubric:: traceroute / mtr — path discovery

.. code-block:: bash

   traceroute -n 8.8.8.8                 # Numeric (no DNS lookups)
   traceroute -I 8.8.8.8                 # Use ICMP instead of UDP
   traceroute -T -p 443 8.8.8.8          # Use TCP SYN to port 443

   mtr -n 8.8.8.8                        # Continuous traceroute + ping
   mtr -r -c 10 8.8.8.8                  # Report mode (10 pings per hop)

.. rubric:: nc (netcat) — TCP/UDP port testing

.. code-block:: bash

   nc -vz 10.0.0.5 22                    # Test if port 22 is open (-z = scan)
   nc -vz 10.0.0.5 1-1000               # Port range scan
   nc -vzu 10.0.0.5 53                   # UDP scan (may be unreliable)
   nc -v 10.0.0.5 80 < /dev/null         # Check HTTP banner

.. rubric:: nmap — port scanning

.. code-block:: bash

   nmap -sn 10.0.0.0/24                 # Ping sweep (find live hosts)
   nmap -sT -p 22,80,443 10.0.0.5       # TCP connect scan (common ports)
   nmap -sV 10.0.0.5                    # Service version detection
   nmap -O 10.0.0.5                     # OS fingerprinting
   nmap --script=http-title 10.0.0.5    # NSE script: HTTP title grab

.. rubric:: curl — HTTP/HTTPS debugging

.. code-block:: bash

   curl -v http://example.com            # Verbose (shows request + response headers)
   curl -I https://example.com           # Head request only (check headers)
   curl --resolve example.com:443:10.0.0.5 https://example.com  # Override DNS
   curl -k https://self-signed.local     # Skip TLS verification
   curl --connect-timeout 5 --max-time 10 https://slow.site
   curl -w "Time total: %{time_total}s\n" -o /dev/null -s https://example.com

------------------------------------------------------------------------------
DNS Troubleshooting

.. list-table:: DNS diagnostic commands
   :header-rows: 1
   :widths: 20 35 45

   * - Tool
     - Example
     - Purpose
   * - ``dig``
     - ``dig example.com ANY +short``
     - Full DNS query (ANY, A, AAAA, MX, NS, TXT, etc.)
   * - ``dig +trace``
     - ``dig example.com +trace``
     - Follow delegation chain from root servers
   * - ``nslookup``
     - ``nslookup example.com 1.1.1.1``
     - Query using specific DNS server
   * - ``host``
     - ``host -t MX example.com``
     - Simpler DNS lookup utility
   * - ``resolvectl``
     - ``resolvectl query example.com``
     - Query systemd-resolved's cache
   * - ``delv``
     - ``delv example.com A``
     - DNSSEC validation query
   * - ``getent``
     - ``getent hosts example.com``
     - Query nsswitch (uses /etc/hosts, DNS, LDAP, etc.)

.. code-block:: bash
   :caption: Common DNS scenarios

   # Check which DNS server is being used
   dig +short example.com
   dig example.com | grep SERVER

   # Check if DNSSEC is valid
   dig example.com +dnssec +multiline

   # Reverse DNS lookup
   dig -x 8.8.8.8

   # Query specific record types
   dig example.com MX                  # Mail servers
   dig example.com NS                  # Nameservers
   dig example.com TXT                 # SPF, DKIM, DMARC
   dig example.com CNAME               # Canonical name

   # Check /etc/hosts for overrides
   cat /etc/hosts

   # Check nsswitch order
   cat /etc/nsswitch.conf | grep hosts

   # Flush DNS cache (depends on resolver)
   sudo resolvectl flush-caches        # systemd-resolved
   sudo systemd-resolve --flush-caches # Older syntax
   sudo systemctl restart nscd         # nscd (name service cache daemon)

------------------------------------------------------------------------------
Firewall & Packet Capture

.. code-block:: bash
   :caption: Firewall troubleshooting

   # Check current rules
   sudo iptables -L -n -v              # iptables with counts
   sudo nft list ruleset               # nftables
   sudo firewall-cmd --list-all        # firewalld
   sudo ufw status verbose             # UFW

   # Check packet counts on specific rules
   sudo iptables -L INPUT -n -v | head -20
   # If counters are incrementing when you attempt to connect,
   # the rule is being hit.

   # Temporarily disable firewall for testing
   sudo iptables -P INPUT ACCEPT       # Not persistent
   sudo iptables -F                    # Flush all rules (CAUTION!)
   sudo systemctl stop firewalld
   sudo ufw disable

.. code-block:: bash
   :caption: tcpdump — packet capture essentials

   # Capture on interface, resolve hostnames (or -n to skip DNS)
   sudo tcpdump -i eth0 -n

   # Filter by host
   sudo tcpdump -i eth0 host 10.0.0.5

   # Filter by port
   sudo tcpdump -i eth0 port 80 or port 443

   # Capture HTTP requests (port 80, show payload)
   sudo tcpdump -i eth0 -A port 80

   # Write to file for later analysis
   sudo tcpdump -i eth0 -w capture.pcap

   # Read from file
   tcpdump -r capture.pcap -n

   # Show only SYN packets
   sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack == 0'

   # Filter by TCP flags (SYN-ACK)
   sudo tcpdump -i eth0 'tcp[tcpflags] & tcp-syn != 0 and tcp[tcpflags] & tcp-ack != 0'

   # Count packets per protocol
   sudo tcpdump -i eth0 -n -c 1000 | awk '{print $3}' | sort | uniq -c | sort -rn

.. rubric:: Common network problems quick reference

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - Symptom
     - Likely cause
     - Quick fix
   * - ``ping: Destination Net Unreachable``
     - No route to destination subnet
     - ``ip route`` to check; add route if missing
   * - ``ping: Destination Host Unreachable``
     - No ARP reply (host down or wrong subnet)
     - ``ip neigh``; check if host is on the right VLAN
   * - ``ping: connect: Network is unreachable``
     - Interface down or no IP assigned
     - ``ip link set eth0 up``; check DHCP
   * - ``No route to host``
     - Opposite endpoint is down or firewall drops
     - ``traceroute -n`` to find where it stops
   * - ``Connection refused``
     - Port not listening or service not running
     - ``ss -tlnp`` to check; start service
   * - ``Connection timed out``
     - Firewall dropping SYN packets
     - Check firewall rules; check for IPTABLES DROP in counters
   * - ``Name or service not known``
     - DNS resolution failed
     - ``dig +trace example.com``; check ``/etc/resolv.conf``
   * - ``TLS handshake failed``
     - Certificate expired, wrong SNI, weak cipher
     - ``openssl s_client -connect host:443 -servername host``
   * - Slow transfers
     - MTU mismatch, congestion, buffer bloat
     - ``ping -M do -s 1472`` to test MTU; check for packet loss
   * - Intermittent drops
     - Duplex mismatch, bad cable, switch port errors
     - ``ethtool eth0``; ``ip -s link``; check switch counters
