.. _app-b-firewall:

------------------------------------------------------------------------------
B.4  Firewalls
------------------------------------------------------------------------------

Three major firewall frameworks coexist on modern Linux: the low-level
``iptables``/``nftables``, the service-level ``firewalld`` (RHEL/Fedora), and
the simplified ``ufw`` (Ubuntu).

------------------------------------------------------------------------------
B.4.1  iptables / nftables
------------------------------------------------------------------------------

**nftables** is the successor to iptables (available since kernel 3.13).
RHEL 9, Debian 11+, Ubuntu 22.04+ ship with nftables as the default
backend. iptables still works via a compatibility layer (``iptables-legacy``
or ``iptables-nft``).

.. rubric:: iptables quick reference

.. list-table:: iptables command structure
   :header-rows: 1
   :widths: 15 25 60

   * - Component
     - Options
     - Notes
   * - Table
     - ``-t filter`` (default), ``-t nat``, ``-t mangle``, ``-t raw``, ``-t security``
     - Most rules are in ``filter``
   * - Chain
     - ``INPUT``, ``OUTPUT``, ``FORWARD`` (filter); ``PREROUTING``, ``POSTROUTING`` (nat)
     - Built-in chains; custom chains also possible
   * - Match
     - ``-s`` (source), ``-d`` (dest), ``-p`` (proto), ``--dport``, ``-m state``, ``-j`` (target)
     - ``-m conntrack --ctstate NEW,ESTABLISHED`` for stateful
   * - Target
     - ``ACCEPT``, ``DROP``, ``REJECT``, ``LOG``, ``MASQUERADE``, ``DNAT``, ``SNAT``
     - ``DROP`` silently discards; ``REJECT`` sends ICMP error

.. code-block:: bash
   :caption: Essential iptables one-liners

   # Default policies
   iptables -P INPUT DROP
   iptables -P FORWARD DROP
   iptables -P OUTPUT ACCEPT

   # Allow loopback
   iptables -A INPUT -i lo -j ACCEPT

   # Allow established connections
   iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

   # Allow SSH (port 22)
   iptables -A INPUT -p tcp --dport 22 -j ACCEPT

   # Allow HTTP/HTTPS
   iptables -A INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT

   # Allow ping (ICMP echo-request)
   iptables -A INPUT -p icmp --icmp-type echo-request -j ACCEPT

   # Log dropped packets (rate-limited to prevent log flood)
   iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "iptables drop: "

   # Port forwarding (DNAT)
   iptables -t nat -A PREROUTING -p tcp --dport 8080 -j DNAT --to-destination 10.0.0.5:80

   # MASQUERADE (NAT for outbound traffic)
   iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

.. rubric:: Saving and restoring iptables rules

.. code-block:: bash

   # Save
   sudo iptables-save > /etc/iptables/rules.v4
   sudo ip6tables-save > /etc/iptables/rules.v6

   # Restore
   sudo iptables-restore < /etc/iptables/rules.v4

.. rubric:: nftables equivalent

.. code-block:: text

   # /etc/nftables.conf (example)
   table inet filter {
     chain input {
       type filter hook input priority 0; policy drop;
       iif "lo" accept
       ct state established,related accept
       tcp dport { 22, 80, 443 } accept
       ip protocol icmp icmp type echo-request accept
       log prefix "nftables drop: " limit rate 5/minute
     }
     chain forward {
       type filter hook forward priority 0; policy drop;
     }
     chain output {
       type filter hook output priority 0; policy accept;
     }
   }

.. code-block:: bash
   :caption: nftables commands

   nft list ruleset           # Show all rules
   nft flush ruleset          # Delete all rules
   nft -f /etc/nftables.conf  # Load rules from file
   systemctl enable --now nftables

------------------------------------------------------------------------------
B.4.2  firewalld
------------------------------------------------------------------------------

firewalld (default on RHEL/CentOS/Fedora) manages nftables through
**zones** and **services**.

.. list-table:: firewalld Zones (common)
   :header-rows: 1
   :widths: 20 40 40

   * - Zone
     - Default trust level
     - Use case
   * - ``drop``
     - Lowest — all incoming dropped except loopback
     - Public-facing, hostile network
   * - ``block``
     - All incoming rejected with ICMP
     - Slightly friendlier than drop
   * - ``public``
     - Untrusted — allow selected services
     - Default zone for external interfaces
   * - ``external``
     - NAT/Masquerade enabled for IPv4
     - Internet-facing router/gateway
   * - ``internal``
     - Private network — moderate trust
     - Internal LAN
   * - ``trusted``
     - All traffic accepted
     - Management or dedicated backend network

.. code-block:: bash
   :caption: firewalld essential commands

   firewall-cmd --list-all                    # Current zone config
   firewall-cmd --get-active-zones            # Which zones are active
   firewall-cmd --zone=public --add-service=http --permanent
   firewall-cmd --zone=public --add-port=8080/tcp --permanent
   firewall-cmd --zone=public --remove-service=ssh --permanent
   firewall-cmd --reload                      # Reload permanent config
   firewall-cmd --runtime-to-permanent        # Save running config
   firewall-cmd --add-masquerade              # Enable NAT

   # Rich rules (fine-grained)
   firewall-cmd --add-rich-rule='rule family="ipv4" source address="10.0.0.0/24" accept'
   firewall-cmd --add-rich-rule='rule family="ipv4" port port="3306" protocol="tcp" drop'

------------------------------------------------------------------------------
B.4.3  ufw (Uncomplicated Firewall)
------------------------------------------------------------------------------

ufw (default on Ubuntu) is a front-end to iptables/nftables.

.. code-block:: bash
   :caption: UFW quick reference

   ufw enable                      # Enable firewall (CAUTION: locks out SSH if not allowed)
   ufw disable                     # Disable
   ufw status verbose              # Show rules and default policy
   ufw allow ssh                   # Allow SSH (from /etc/services)
   ufw allow 80/tcp                # Allow HTTP
   ufw allow 443/tcp               # Allow HTTPS
   ufw allow from 10.0.0.0/24 to any port 3306  # MySQL from subnet
   ufw deny 23/tcp                 # Block telnet
   ufw delete deny 23/tcp          # Remove rule
   ufw default deny incoming       # Set default policy
   ufw default allow outgoing
   ufw app list                    # List application profiles
   ufw app info 'Nginx Full'       # Show app profile details

.. rubric:: UFW application profiles (``/etc/ufw/applications.d/``)

.. code-block:: text

   [Nginx Full]
   title=Nginx (HTTP + HTTPS)
   description=Web server with both HTTP and HTTPS
   ports=80,443/tcp
