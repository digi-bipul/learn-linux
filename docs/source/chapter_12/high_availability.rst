============================================================
12.2 High Availability (HA) & Load Balancing
============================================================

12.2.1 Defining High Availability
====================================

Availability is expressed as a percentage of uptime over a year:

+-------------------+-------------+------------------+
| Availability      | Downtime/yr | Colloquial Name  |
+===================+=============+==================+
| 99%               | 3.65 days   | "One-nine"       |
+-------------------+-------------+------------------+
| 99.9%             | 8.76 hours  | "Three-nines"    |
+-------------------+-------------+------------------+
| 99.99%            | 52.56 min   | "Four-nines"     |
+-------------------+-------------+------------------+
| 99.999%           | 5.26 min    | "Five-nines"     |
+-------------------+-------------+------------------+

Achieving four-nines or higher requires eliminating **single points of failure (SPOFs)**
at every layer.

12.2.2 Layer 4 vs Layer 7 High Availability
=============================================

Layer 4 (Transport Layer)
-------------------------

Operates on IP addresses and TCP/UDP port numbers. The load balancer does not inspect
the application protocol. Very high speed. Tools: HAProxy (TCP mode), IPVS, Envoy (L4).

Layer 7 (Application Layer)
---------------------------

Operates on HTTP headers, cookies, paths, query parameters, gRPC methods. The LB
terminates TLS and proxies the request. Tools: HAProxy (HTTP mode), Envoy, NGINX.

.. warning::
   Never conflate L4 and L7 health checks. An L4 health check (TCP connect) can report
   a service as healthy even if the application returns HTTP 500s. Use layer-appropriate
   health checks (``option httpchk`` in HAProxy for HTTP services).

12.2.3 VRRP with Keepalived (Floating IPs)
============================================

Virtual Router Redundancy Protocol (VRRP) allows multiple physical servers to share a
single **virtual IP address (VIP)**. If the master fails, the backup takes over.
Keepalived implements VRRP on Linux.

Configuration Example (Master)
-------------------------------

.. code-block:: bash

    # /etc/keepalived/keepalived.conf
    vrrp_instance VI_1 {
        state MASTER
        interface eth0
        virtual_router_id 51
        priority 100
        advert_int 1
        authentication {
            auth_type PASS
            auth_pass SuperSecret42
        }
        virtual_ipaddress {
            192.168.1.100/24 dev eth0
        }
        track_script {
            chk_haproxy
        }
    }
    vrrp_script chk_haproxy {
        script "pidof haproxy"
        interval 2
        fall 2
        rise 2
    }

Configuration Example (Backup)
-------------------------------

Same file, with::

    state BACKUP
    priority 50

.. code-block:: bash

    systemctl enable --now keepalived

12.2.4 HAProxy: The Industry Standard Reverse Proxy
=====================================================

Global and Defaults
--------------------

.. code-block:: haproxy

    global
        log /dev/log local0
        maxconn 100000
        user haproxy
        group haproxy

    defaults
        log global
        mode http
        option httplog
        timeout connect 5s
        timeout client 50s
        timeout server 50s

Frontend and Backend (Layer 7 HTTP)
------------------------------------

.. code-block:: haproxy

    frontend web-frontend
        bind *:443 ssl crt /etc/ssl/haproxy/example.pem
        bind *:80
        redirect scheme https if !{ ssl_fc }
        default_backend web-servers

    backend web-servers
        balance roundrobin
        option httpchk GET /health
        server web01 10.0.1.10:8080 check weight 10
        server web02 10.0.1.11:8080 check weight 10
        server web03 10.0.1.12:8080 check backup

Layer 4 TCP Mode
-----------------

.. code-block:: haproxy

    frontend db-frontend
        bind *:3306
        mode tcp
        option tcplog
        default_backend db-servers

    backend db-servers
        mode tcp
        balance leastconn
        option tcp-check
        server db01 10.0.2.10:3306 check
        server db02 10.0.2.11:3306 check

Modern Alternatives: Envoy Proxy
---------------------------------

`Envoy <https://www.envoyproxy.io/>`_ is a modern, L7 proxy written in C++ that is
the data plane for service meshes like Istio. It offers dynamic configuration via xDS
APIs, making it superior for Kubernetes-native environments.

12.2.5 Cluster Resource Management: Corosync + Pacemaker
==========================================================

The Stack
---------

+---------------------+--------------------------------------------------+
| Component           | Role                                             |
+=====================+==================================================+
| **Corosync**        | Group membership and messaging layer. Maintains  |
|                     | a consistent view of which nodes are alive.      |
+---------------------+--------------------------------------------------+
| **Pacemaker**       | Resource manager. Starts, stops, monitors, and   |
|                     | moves cluster resources based on policy.         |
+---------------------+--------------------------------------------------+
| **pcs**             | Pacemaker/Corosync configuration shell.          |
+---------------------+--------------------------------------------------+

The Quorum Mathematics
----------------------

Corosync uses a **consensus protocol** to agree on membership. A cluster can only make
decisions if it has **quorum**:

.. math::

    quorum_needed = \frac{total\_nodes}{2} + 1

For a 3-node cluster, quorum is 2. For a 2-node cluster, quorum is 2 — meaning one
node going down causes the cluster to lose quorum and shut down resources. This is
why **2-node clusters are discouraged** unless you add a **quorum device** (witness).

.. important::
   Quorum is not optional. A partitioned node running a database primary while the
   majority side also runs one causes **split-brain** — irreparable data corruption.

Installing and Configuring (RHEL 9 / Rocky 9)

.. code-block:: bash

    dnf install -y pacemaker pcs fence-agents-all
    echo 'H@Clust3r!' | passwd --stdin hacluster
    systemctl enable --now pcsd
    pcs host auth node01 node02 node03 -u hacluster -p 'H@Clust3r!'
    pcs cluster setup cluster01 node01 node02 node03
    pcs cluster start --all
    pcs status

12.2.6 STONITH: The Absolute Necessity
========================================

STONITH stands for **Shoot The Other Node In The Head**. It is the mechanism by which
a cluster forcibly removes a misbehaving node (network split, kernel hang) by cutting
its power or pulling its network cables.

Why STONITH is Mandatory
-------------------------

Without STONITH, a failed node might still hold disk locks, IPv4 addresses, or
filesystem leases while the cluster tries to start them elsewhere. This causes
data corruption, IP conflicts, and LVM locking violations.

Pacemaker will refuse to start resources on surviving nodes if a failed node is not
fenced. You will see::

    pcs status
    WARNING: No STONITH device configured.
    Cluster will not recover from node failures.

Configuring fence_ipmilan (BMC)

.. code-block:: bash

    pcs stonith create fence-node01 fence_ipmilan \
        ipaddr=bmc01.example.com \
        login=admin passwd=Secret123 \
        pcmk_host_list=node01 \
        op monitor interval=60s
    pcs stonith create fence-node02 fence_ipmilan \
        ipaddr=bmc02.example.com \
        login=admin passwd=Secret123 \
        pcmk_host_list=node02
    pcs property set stonith-enabled=true
    pcs property set no-quorum-policy=stop

.. warning::
   **Test your STONITH configuration in a maintenance window.** Many operators
   configure fencing incorrectly and discover this only when a real failure occurs.

12.2.7 Cluster Resources in Practice
======================================

Example: PostgreSQL HA with DRBD

.. code-block:: bash

    pcs resource create pgsql-data ocf:linbit:drbd \
        drbd_resource=r0 op monitor interval=30s
    pcs resource master pgsql-data-master pgsql-data \
        master-max=1 master-node-max=1
    pcs resource create pgsql-fs Filesystem \
        device=/dev/drbd0 directory=/var/lib/pgsql fstype=ext4
    pcs resource create pgsql-server systemd:postgresql
    pcs constraint order promote pgsql-data-master then start pgsql-fs
    pcs constraint colocation add pgsql-fs with pgsql-data-master INFINITY

12.2.8 Summary
===============

+---------------------+----------------------------------------------------+
| Tool                | Use Case                                          |
+=====================+====================================================+
| Keepalived (VRRP)   | Active-passive floating IP failover               |
+---------------------+----------------------------------------------------+
| HAProxy             | L4/L7 load balancing, health checks, proxying     |
+---------------------+----------------------------------------------------+
| Envoy               | Modern L7 proxy with dynamic xDS config           |
+---------------------+----------------------------------------------------+
| Corosync+Pacemaker  | Cluster membership, quorum, resource management    |
+---------------------+----------------------------------------------------+
| STONITH / Fencing   | Forcibly remove failed nodes to prevent corruption |
+---------------------+----------------------------------------------------+
