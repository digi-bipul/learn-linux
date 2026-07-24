.. _sec-07-07:

=======================================
Firewall Frontends
=======================================

While nftables gives you direct, low-level control over the kernel's packet
filter, writing raw nftables rulesets can be verbose and error-prone for
everyday tasks. **Firewall frontends** provide higher-level abstractions —
services, zones, profiles, and simplified commands — while delegating the
heavy lifting to nftables (or, on older systems, iptables) underneath.

This section covers the two dominant frontends in the Linux ecosystem:
``ufw`` (the default for Debian and Ubuntu) and ``firewalld`` (the default for
RHEL, Fedora, and CentOS). We also discuss the security technique of *port
knocking*.

ufw — Uncomplicated Firewall (Debian/Ubuntu)
===================================================

**ufw** (Uncomplicated Firewall) lives up to its name. It provides a
minimal, human-friendly interface to nftables or iptables. It is the default
firewall management tool on Ubuntu and is widely used on Debian.

**Under the hood:** ufw generates nftables (or legacy iptables) rules from
simple commands. You can inspect the generated rules with ``ufw show raw``.

**Basic usage:**

.. code-block:: bash

    # Enable/disable
    sudo ufw enable
    sudo ufw disable

    # Check status and rules
    sudo ufw status verbose

    # Default policies
    sudo ufw default deny incoming
    sudo ufw default allow outgoing

    # Allow a service by name (from /etc/services)
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https

    # Allow a specific port
    sudo ufw allow 8080/tcp

    # Allow from a specific IP
    sudo ufw allow from 192.168.1.0/24 to any port 22

    # Deny a port
    sudo ufw deny 23/tcp

    # Delete a rule
    sudo ufw delete allow 8080/tcp

    # Reset to factory defaults
    sudo ufw reset

**Application profiles:**

ufw ships with application profiles that define standard port sets. You can
list and manage them:

.. code-block:: bash

    # List all application profiles
    sudo ufw app list

    # Show the details of a profile
    sudo ufw app info 'OpenSSH'

    # Allow a profile
    sudo ufw allow 'OpenSSH'

    # Allow a custom profile (edited in /etc/ufw/applications.d/)
    # Profiles are simple INI-like files

**Logging:**

.. code-block:: bash

    # Enable logging
    sudo ufw logging on

    # Set log level (low, medium, high)
    sudo ufw logging medium

**Configuration files:**

* ``/etc/default/ufw`` — Global UFW settings (default policies, IPv6 toggle,
  etc.).
* ``/etc/ufw/before.rules`` — Rules applied before user-defined rules (used
  for NAT, rate limiting, etc.).
* ``/etc/ufw/after.rules`` — Rules applied after user-defined rules.
* ``/etc/ufw/user.rules`` — User-defined rules (do not edit manually; use
  ``ufw`` commands).
* ``/etc/ufw/applications.d/`` — Application profile definitions.

**Stateful behaviour:** By default, ufw is stateful — it allows established
and related connections automatically. The ``before.rules`` file contains the
``ct state`` rules that enable this.

**NAT with ufw:**

To enable NAT (e.g., for a router), edit ``/etc/ufw/before.rules`` and add
nftables (or iptables) NAT rules before the ``*filter`` section:

.. code-block:: bash

    # /etc/ufw/before.rules — add before the *filter section
    *nat
    :POSTROUTING ACCEPT [0:0]
    -A POSTROUTING -o eth0 -j MASQUERADE
    COMMIT

Then edit ``/etc/default/ufw`` and set ``DEFAULT_FORWARD_POLICY="ACCEPT"``, and
enable IP forwarding in ``/etc/sysctl.conf`` (``net.ipv4.ip_forward=1``).

**Limitations:**

* Not designed for complex, enterprise-scale rule sets with hundreds of
  exceptions.
* No built-in support for zones or rich rule abstractions (use firewalld for
  that).
* Rule ordering can be tricky — ufw inserts rules at the end of the chain, so
  interactions with ``before.rules`` and ``after.rules`` require care.

firewalld — Firewall Zones and Services (RHEL/Fedora)
=============================================================

**firewalld** is the default firewall management tool on RHEL, Fedora,
CentOS, and their derivatives. It introduces the concept of **zones** — named
collections of rules that can be assigned to interfaces based on their trust
level.

**Core concepts:**

* **Zone:** A security profile (e.g., ``public``, ``internal``, ``trusted``,
  ``dmz``). Each zone defines which ports/services are open and which are
  blocked.
* **Service:** A named shortcut for one or more ports/protocols (e.g., the
  ``ssh`` service opens port 22/tcp).
* **Rich Rule:** An advanced, expressive rule syntax for fine-grained control
  (e.g., rate limiting, source IP filtering).
* **Runtime vs. Permanent:** Changes can be applied immediately (runtime) or
  made persistent across reboots.

**Default zones (from least to most trusted):**

+-----------------+----------------------------------------------------------+
| Zone            | Default Policy                                           |
+=================+==========================================================+
| ``drop``        | All incoming packets dropped; no ICMP replies.           |
|                 | Outgoing allowed.                                        |
+-----------------+----------------------------------------------------------+
| ``block``       | All incoming rejected with ICMP ``host-prohibited``.     |
+-----------------+----------------------------------------------------------+
| ``public``      | Default for new interfaces. Only selected services       |
|                 | allowed (typically SSH).                                 |
+-----------------+----------------------------------------------------------+
| ``external``    | For external-facing interfaces (with masquerading).      |
+-----------------+----------------------------------------------------------+
| ``internal``    | For internal networks (moderate trust).                  |
+-----------------+----------------------------------------------------------+
| ``dmz``         | For DMZ hosts — limited access to specific services.     |
+-----------------+----------------------------------------------------------+
| ``work``        | For work networks.                                       |
+-----------------+----------------------------------------------------------+
| ``home``        | For home networks — higher trust.                        |
+-----------------+----------------------------------------------------------+
| ``trusted``     | All traffic accepted. Use with caution.                  |
+-----------------+----------------------------------------------------------+

**Command-line usage (``firewall-cmd``):**

.. code-block:: bash

    # Show the default zone
    firewall-cmd --get-default-zone

    # List all zones
    firewall-cmd --get-zones

    # Show active zones (zones with assigned interfaces)
    firewall-cmd --get-active-zones

    # Show zone details
    firewall-cmd --zone=public --list-all

    # Add a service to a zone (runtime only)
    sudo firewall-cmd --zone=public --add-service=http

    # Add a service permanently
    sudo firewall-cmd --zone=public --add-service=http --permanent

    # Add a port
    sudo firewall-cmd --zone=public --add-port=8080/tcp --permanent

    # Remove a service
    sudo firewall-cmd --zone=public --remove-service=http --permanent

    # Reload to apply permanent changes to runtime
    sudo firewall-cmd --reload

    # Completely reload (loses runtime changes)
    sudo firewall-cmd --complete-reload

    # Assign an interface to a zone
    sudo firewall-cmd --zone=internal --change-interface=eth1 --permanent

    # Enable masquerade (NAT for gateway)
    sudo firewall-cmd --zone=external --add-masquerade --permanent

    # Port forwarding
    sudo firewall-cmd --zone=public \
        --add-forward-port=port=8080:proto=tcp:toport=80:toaddr=10.0.0.10 \
        --permanent

**Rich rules:**

For rules beyond simple service/port declarations:

.. code-block:: bash

    # Allow SSH only from a specific source IP
    sudo firewall-cmd --permanent \
        --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" \
        service name="ssh" accept'

    # Rate-limit incoming connections
    sudo firewall-cmd --permanent \
        --add-rich-rule='rule service name="http" \
        accept limit value="30/minute"'

**Runtime vs. Permanent explained:**

firewalld maintains two separate rule sets:

* **Runtime:** The rules currently active in the kernel. Changed with commands
  *without* ``--permanent``. These are lost on reboot.
* **Permanent:** Rules saved to XML files in ``/etc/firewalld/zones/``. Changed
  with ``--permanent``. Applied on reboot or after ``firewall-cmd --reload``.

Always use ``--permanent`` when you want a change to survive a reboot, and
then run ``--reload`` to apply the permanent rules to runtime.

**Configuration files:**

* ``/etc/firewalld/firewalld.conf`` — Global daemon configuration.
* ``/etc/firewalld/zones/`` — Per-zone XML configuration files.
* ``/etc/firewalld/services/`` — Service definitions (port-to-service mappings).
* ``/usr/lib/firewalld/`` — Default (distribution-provided) zones and services.
  Custom overrides go in ``/etc/firewalld/``.

**Direct mode (escape hatch):**

If you need to insert raw nftables rules that firewalld cannot express:

.. code-block:: bash

    sudo firewall-cmd --direct --add-rule ipv4 filter INPUT 0 -p tcp --dport 9999 -j ACCEPT

Direct mode is a last resort — it bypasses firewalld's zone and service
abstractions and should be used sparingly.

Port Knocking
=====================

**Port knocking** is a security technique that hides a service (typically SSH)
behind a closed firewall. The port remains closed until a specific sequence of
connection attempts (knocks) is received from the same source IP. Upon
detecting the correct sequence, the firewall temporarily opens the port.

**How it works:**

1. The firewall (via a daemon like ``knockd``) monitors connection attempts to
   closed ports.
2. A client sends SYN packets to a predefined sequence of ports (e.g., 7000,
   8000, 9000) — in that order.
3. The daemon logs these attempts, matches the sequence, and adds a temporary
   firewall rule allowing the client's IP to connect to the target port (e.g.,
   SSH on port 22).
4. After a timeout, the rule is removed.

**Installation and basic configuration:**

.. code-block:: bash

    # Install knockd
    sudo apt install knockd          # Debian/Ubuntu
    sudo dnf install knockd          # Fedora/RHEL

**Example knockd configuration:**

.. code-block:: ini
   :caption: /etc/knockd.conf

    [options]
            logfile = /var/log/knockd.log

    [openSSH]
            sequence    = 7000,8000,9000
            seq_timeout = 5
            command     = /usr/sbin/nft add rule inet filter input \
                          ip saddr %IP% tcp dport 22 accept
            tcpflags    = syn

    [closeSSH]
            sequence    = 9000,8000,7000
            seq_timeout = 5
            command     = /usr/sbin/nft delete rule inet filter input \
                          ip saddr %IP% tcp dport 22 accept
            tcpflags    = syn

**Client side (from another machine):**

.. code-block:: bash

    # Use nmap or a simple one-liner to knock
    for port in 7000 8000 9000; do nmap -p $port --scanflags SYN target.example.com; done

    # Or using knock (client tool)
    knock target.example.com 7000 8000 9000

    # Now connect to SSH (the port is open for your IP)
    ssh user@target.example.com

    # Close the port after use
    knock target.example.com 9000 8000 7000

**Security considerations:**

* Port knocking is security by obscurity — it does *not* replace strong
  authentication, but it does eliminate automated SSH brute-force scans.
* Knock sequences travel in plaintext; anyone who can sniff the traffic can
  replay the sequence.
* For stronger protection, use **Single Packet Authorization (SPA)** with tools
  like ``fwknop``, which encrypts the authorization packet.
* Combine port knocking with SSH key authentication for defence in depth.

When to Use Each Tool
============================

+------------------------+-----------------------------------+-----------------------------------+
| Scenario               | Recommended Tool                  | Rationale                         |
+========================+===================================+===================================+
| Single Ubuntu/Debian   | ufw                               | Simple, maintainable, default     |
| server                 |                                   | on the platform.                  |
+------------------------+-----------------------------------+-----------------------------------+
| RHEL/Fedora server     | firewalld                         | Default, integrated with the      |
|                        |                                   | distribution's security model.    |
+------------------------+-----------------------------------+-----------------------------------+
| Enterprise / multi-    | firewalld with zones              | Zone-based policy separates       |
| homed server           |                                   | internal from external traffic.   |
+------------------------+-----------------------------------+-----------------------------------+
| Cloud / container      | nftables directly                 | Minimal dependencies; no daemon   |
| host                   |                                   | overhead; fully scriptable.       |
+------------------------+-----------------------------------+-----------------------------------+
| Hiding a service       | Port knocking (knockd) or         | Reduces attack surface from       |
| from scanners          | fwknop (SPA)                      | automated scans.                  |
+------------------------+-----------------------------------+-----------------------------------+
| Migrating from         | Use the native nftables syntax    | The compatibility layer works,    |
| iptables to nftables   | for new rules; migrate old rules  | but native is cleaner and         |
|                        | incrementally.                    | more maintainable long-term.      |
+------------------------+-----------------------------------+-----------------------------------+

Both ufw and firewalld are **frontends**. Be aware that if you use ufw (which
writes nftables rules) and then directly manipulate nftables, the two may
conflict. Stick to one management approach per host.
