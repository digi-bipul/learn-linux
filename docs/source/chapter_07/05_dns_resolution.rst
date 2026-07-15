.. _sec-07-05:

=======================================
7.5 DNS & Resolution
=======================================

The Domain Name System (DNS) is the mechanism that translates human-readable
hostnames (like ``www.example.com``) into IP addresses (like ``93.184.216.34``).
Without DNS, you would need to memorise the IP address of every server you
connect to — a non-starter for a network with millions of hosts. This section covers how Linux resolves hostnames, the configuration files that
govern the process, the increasingly important role of ``systemd-resolved``,
and the diagnostic tools every administrator must know.

7.5.1 The Resolution Order (Name Service Switch)
==================================================

On a Linux system, the order in which different name-resolution sources are
consulted is defined in the **Name Service Switch (NSS)** configuration file:

.. code-block:: bash

    /etc/nsswitch.conf

The relevant line for host resolution looks like this:

::

    hosts: files dns mymachines

This tells the resolver library (``glibc``'s ``gethostbyname()`` and
``getaddrinfo()`` functions):

1. Check ``files`` — i.e., ``/etc/hosts`` — first.
2. If no match is found, consult the ``dns`` provider — which means query the
   DNS server(s) configured in ``/etc/resolv.conf`` (or via ``systemd-resolved``).
3. If still no match, try ``mymachines`` (for local container names managed by
   systemd-machined).

*Why this order matters:* It allows you to override DNS entries locally. If you
add ``127.0.0.1   dev.example.com`` to ``/etc/hosts``, that hostname will
resolve to localhost regardless of what the public DNS says — useful for
development, testing, and blocking unwanted hosts.

7.5.2 /etc/hosts — The Static Host File
========================================

The ``/etc/hosts`` file is a simple text file mapping IP addresses to
hostnames. It predates DNS and is still used daily.

**Format:**

::

    127.0.0.1   localhost localhost.localdomain
    ::1         localhost localhost.localdomain
    192.168.1.100  db-server.internal.example.com  db-server

Each line contains: an IP address, the canonical hostname (FQDN first), and
optional aliases separated by whitespace.

**Common uses:**

* **Loopback mapping:** ``127.0.0.1 localhost`` — every system has this.
* **Development overrides:** Point ``staging.example.com`` to your local
  development server.
* **Blocking domains:** Point ``ads.example.com`` to ``127.0.0.1`` or
  ``0.0.0.0`` to prevent resolution.
* **Private network hosts:** If you have no internal DNS, list your servers
  here so they can resolve each other.

**Caution:** On a network with hundreds or thousands of hosts, managing
``/etc/hosts`` by hand is impractical. DNS (or a local resolver) is the proper
solution at scale.

7.5.3 /etc/resolv.conf — The Resolver Configuration
====================================================

This file tells the system which DNS nameservers to query and which search
domains to append to unqualified hostnames.

**Traditional format:**

::

    nameserver 8.8.8.8
    nameserver 1.1.1.1
    search example.com internal.example.com

* ``nameserver``: Up to three DNS server addresses, queried in order.
* ``search``: A list of domains appended to single-label hostnames. If you
  ``ping db-server`` and the search domain is ``example.com``, the resolver
  will try ``db-server.example.com`` first, then ``db-server`` itself.

**Important caveat:** On modern systems, ``/etc/resolv.conf`` may be a
symlink managed by another service. Do not edit it directly unless you know
which service owns it.

.. code-block:: bash

    # Check if /etc/resolv.conf is a symlink
    ls -l /etc/resolv.conf

    # Typical output on a systemd-resolved system:
    lrwxrwxrwx 1 root root 34 ... /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf

If you need to make persistent DNS changes, use the proper configuration system
(Netplan, NetworkManager, ``systemd-networkd``) rather than editing the
resolv.conf symlink.

7.5.4 systemd-resolved — The Modern Resolver
=============================================

``systemd-resolved`` is systemd's answer to local DNS resolution. It provides:

* **Caching:** Resolved queries are cached, reducing latency and network load.
* **DNS-over-TLS:** Support for encrypted DNS queries.
* **mDNS (Multicast DNS):** Resolve ``.local`` hostnames on the local network
  (e.g., ``my-printer.local``).
* **LLMNR (Link-Local Multicast Name Resolution):** Windows-compatible
  peer-to-peer name resolution.
* **Split DNS:** Different DNS servers for different domains — internal queries
  go to the internal resolver, internet queries go to a public resolver.

**Checking status:**

.. code-block:: bash

    resolvectl status

This shows the current DNS servers for each interface, the domains they are
authoritative for, and which protocols (DNS, LLMNR, mDNS) are enabled.

**Querying with resolvectl:**

.. code-block:: bash

    # Resolve a hostname
    resolvectl query example.com

    # Show DNS statistics
    resolvectl statistics

    # Flush the cache
    resolvectl flush-caches

**How it integrates:**

``systemd-resolved`` listens on a stub resolver at ``127.0.0.53`` (and
``127.0.0.54`` for the "extended" stub). The stub ``/etc/resolv.conf`` points
to this address. All applications send DNS queries to ``127.0.0.53``, and
``systemd-resolved`` handles the actual upstream queries, caching, and
protocol negotiation.

**Potential issue:** Some legacy applications or container runtimes do not
handle ``127.0.0.53`` correctly. If you encounter problems, you can switch
``/etc/resolv.conf`` to point directly to the upstream resolvers, but this
disables ``systemd-resolved`` features.

7.5.5 DNS Query Tools
=======================

Three tools dominate DNS diagnostics. All three should be installed
(``dnsutils`` package on Debian/Ubuntu, ``bind-utils`` on RHEL/Fedora).

**dig (Domain Information Groper)**

``dig`` is the most powerful and flexible DNS query tool. It is the default
choice for any serious DNS investigation.

.. code-block:: bash

    # Basic A record lookup
    dig example.com

    # Query a specific nameserver
    dig @8.8.8.8 example.com

    # Query a specific record type
    dig example.com MX
    dig example.com NS
    dig example.com AAAA

    # Short output (just the answer)
    dig +short example.com

    # Trace the resolution path from root servers
    dig +trace example.com

    # Reverse DNS lookup (PTR record)
    dig -x 93.184.216.34

**Dissecting standard ``dig`` output:**

::

    ; <<>> DiG 9.18.0-1-Debian <<>> example.com
    ;; global options: +cmd
    ;; Got answer:
    ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 12345
    ;; flags: qr rd ra; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1

    ;; OPT PSEUDOSECTION:
    ; EDNS: version: 0, flags:; udp: 1232
    ;; QUESTION SECTION:
    ;example.com.                   IN      A

    ;; ANSWER SECTION:
    example.com.            86400   IN      A       93.184.216.34

    ;; Query time: 23 msec
    ;; SERVER: 127.0.0.53#53(127.0.0.53) (UDP)
    ;; WHEN: Thu Jan 15 12:00:00 EST 2026
    ;; MSG SIZE  rcvd: 56

* ``status: NOERROR`` — The query succeeded. Other statuses: ``NXDOMAIN``
  (domain does not exist), ``SERVFAIL`` (server failure), ``REFUSED``.
* ``flags: qr rd ra`` — ``qr`` (query response), ``rd`` (recursion desired),
  ``ra`` (recursion available).
* ``ANSWER: 1`` — One answer record was returned.
* ``86400`` — The TTL (Time To Live) in seconds.
* ``SERVER: 127.0.0.53#53`` — Which resolver answered the query.

**nslookup (Legacy but Ubiquitous)**

``nslookup`` is older and less feature-rich than ``dig``, but it is installed
on virtually every system, including Windows.

.. code-block:: bash

    # Interactive mode (just type nslookup)
    nslookup
    > server 8.8.8.8
    > set type=MX
    > example.com
    > exit

    # Non-interactive mode
    nslookup example.com
    nslookup -type=MX example.com

**host (Simple and Concise)**

``host`` is the simplest of the three, designed for quick lookups.

.. code-block:: bash

    host example.com
    host -t MX example.com
    host 93.184.216.34

Output is terse and human-readable, making it ideal for scripting quick checks
or for administrators who want minimal verbosity.

7.5.6 DNS Record Types You Must Know
======================================

+----------+----------------------------------------------------------+
| Type     | Purpose                                                  |
+==========+==========================================================+
| A        | Maps a hostname to an IPv4 address.                      |
+----------+----------------------------------------------------------+
| AAAA     | Maps a hostname to an IPv6 address.                      |
+----------+----------------------------------------------------------+
| CNAME    | Canonical name — an alias. ``www.example.com`` →         |
|          | ``example.com``.                                         |
+----------+----------------------------------------------------------+
| MX       | Mail exchange — which SMTP server handles email for the  |
|          | domain.                                                  |
+----------+----------------------------------------------------------+
| NS       | Nameserver — which servers are authoritative for the     |
|          | domain.                                                  |
+----------+----------------------------------------------------------+
| TXT      | Arbitrary text data — used for SPF, DKIM, DMARC (email   |
|          | authentication), and domain ownership verification.      |
+----------+----------------------------------------------------------+
| PTR      | Pointer — reverse DNS, mapping IP → hostname.            |
+----------+----------------------------------------------------------+
| SOA      | Start of Authority — administrative information about    |
|          | the zone (primary NS, admin email, serial number).       |
+----------+----------------------------------------------------------+

7.5.7 Troubleshooting DNS
==========================

When a hostname fails to resolve, follow this diagnostic chain:

1. **Check ``/etc/nsswitch.conf``** — Is ``dns`` in the ``hosts`` line?
2. **Check ``/etc/hosts``** — Is there a manual override that may be blocking
   resolution?
3. **Check the resolver** — ``cat /etc/resolv.conf`` or ``resolvectl status``.
   Are the nameservers correct?
4. **Ping the nameserver IP** — Can you reach the DNS server at all?
5. **Use ``dig +short``** — Does the query succeed when you bypass the local
   resolver (``dig @8.8.8.8 example.com``)?
6. **Check for firewall blocks** — UDP port 53 and TCP port 53 must be open to
   the DNS server.
7. **Check ``systemd-resolved``** — Is it running? Does ``resolvectl query
   example.com`` work?
