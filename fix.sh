#!/usr/bin/env bash
# =============================================================================
# Chapter 12: Enterprise Administration, SRE Practices & Capstone Project
# Generate all Sphinx .rst source files for Chapter 12.
#
# IMPORTANT FIXES from the previous version:
#   1. chapter_12/index.rst now includes a proper .. toctree:: directive
#      listing all 7 subchapters. Without this, subchapters do NOT appear
#      in the left navigation pane and there are NO "Next"/"Previous" buttons.
#   2. A top-level docs/source/index.rst is also created (if absent) so that
#      Chapter 12 appears in the book's global table of contents.
#   3. A docs/source/conf.py is created (if absent) with proper html_sidebars.
#
# Usage: bash generate_chapter12.sh
# Then:  cd ~/learn-linux/docs && sphinx-build -b html source _build
# =============================================================================

set -euo pipefail

BASE=~/learn-linux/docs/source/chapter_12
mkdir -p "$BASE"

# =============================================================================
# FILE 1: index.rst
# =============================================================================
cat > "$BASE/index.rst" << 'EOF'
.. _chapter-12:

============================================================
Chapter 12: Enterprise Administration, SRE Practices & Capstone Project
============================================================

.. epigraph::

    "Hope is not a strategy. A backup is not a strategy. A runbook is a strategy."

    — Adapted from Site Reliability Engineering, Google

Welcome to the final chapter of *Linux from Scratch to Advanced Professional*. By this
point you have mastered the terminal, secured systems, containerised applications,
orchestrated clusters, and peered into the kernel with eBPF. You are ready to think
like a **Principal Infrastructure Architect** and a **Site Reliability Engineer (SRE)**.

This chapter bridges the gap between managing a single server and governing a fleet
of thousands. It fuses traditional enterprise administration—centralised identity,
high-availability clustering, disaster recovery—with the modern Site Reliability
Engineering paradigm that treats operations as a software engineering discipline.

.. toctree::
   :maxdepth: 2
   :caption: Subchapters

   01_centralized_iam
   02_high_availability
   03_disaster_recovery
   04_log_management
   05_gitops_and_cm
   06_sre_practices
   07_capstone_project
EOF

# =============================================================================
# FILE 2: 01_centralized_iam.rst
# =============================================================================
cat > "$BASE/01_centralized_iam.rst" << 'EOF'
.. _sec-12-1:

============================================================
12.1 Centralised Identity & Access (IAM)
============================================================

12.1.1 Why Centralised Identity Matters
=========================================

In a fleet of one server, local ``/etc/passwd`` and ``/etc/shadow`` are sufficient.
When your organisation grows to ten, a hundred, or ten thousand Linux nodes, managing
users locally becomes both a security liability and an operational impossibility.
Centralised Identity and Access Management (IAM) provides a **single source of truth**
for who can do what, on which machine, at what time.

In 2026, two parallel identity worlds coexist:

1. **Legacy POSIX Identity** — LDAP, Kerberos, FreeIPA. The Unix user model (UID, GID,
   home directory, shell) extended over the network.
2. **Cloud-Native Identity** — OIDC, SAML, SCIM. Token-based, federated, and often
   bound to a SaaS identity provider (Okta, Azure AD, Google Workspace).

The modern enterprise bridges both. A Linux server must authenticate an engineer using
their corporate SSO (OIDC) and then map that identity to a local POSIX user with specific
filesystem permissions and an SELinux context.

12.1.2 Lightweight Directory Access Protocol (LDAP)
=====================================================

LDAP is the backbone of almost every enterprise directory, including Microsoft Active
Directory (which uses LDAP as its wire protocol). We will use **OpenLDAP**, the open-source
reference implementation.

Anatomy of an LDAP Tree
------------------------

An LDAP directory is a hierarchical tree (DIT — Directory Information Tree)::

    dc=example,dc=com
    ├── ou=People
    │   ├── uid=alice
    │   ├── uid=bob
    │   └── uid=carol
    ├── ou=Groups
    │   ├── cn=developers
    │   └── cn=admins
    └── ou=Hosts
        └── cn=web-01

Every entry has a **Distinguished Name (DN)** (e.g., ``uid=alice,ou=People,dc=example,dc=com``)
and a set of attribute-value pairs defined by a **schema**.

Installing OpenLDAP (Debian 12)
-------------------------------

.. code-block:: bash

    apt-get update && apt-get install -y slapd ldap-utils
    dpkg-reconfigure slapd
    slapcat

Installing OpenLDAP (RHEL 9)
----------------------------

.. code-block:: bash

    dnf install -y openldap-servers openldap-clients
    slappasswd
    cp /usr/share/openldap-servers/DB_CONFIG.example /var/lib/ldap/DB_CONFIG
    systemctl enable --now slapd
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif
    ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif

Adding a User (LDIF format)
---------------------------

.. code-block:: ldif

    dn: uid=jdoe,ou=People,dc=example,dc=com
    objectClass: top
    objectClass: posixAccount
    objectClass: inetOrgPerson
    cn: John Doe
    sn: Doe
    uid: jdoe
    uidNumber: 10001
    gidNumber: 1001
    homeDirectory: /home/jdoe
    loginShell: /bin/bash
    userPassword: {SSHA}encryptedhashhere

Load with:

.. code-block:: bash

    ldapadd -x -D "cn=admin,dc=example,dc=com" -W -f add_user.ldif

12.1.3 Kerberos: Trusted Authentication
=========================================

LDAP stores *who you are* and *what groups you belong to*, but it transmits passwords
(in LDAP bind operations) unless wrapped in TLS. **Kerberos** solves authentication
without sending passwords over the wire using symmetric-key cryptography and a trusted
third party called the **Key Distribution Center (KDC)**.

Kerberos Flow
--------------

1. User requests a **Ticket-Granting Ticket (TGT)** from the KDC by encrypting a
   timestamp with their password-derived key.
2. KDC decrypts the timestamp (proving the user knows the password) and returns a TGT
   encrypted with the KDC's secret key.
3. To access a service (e.g., SSH, NFS), the user presents the TGT to request a
   **Service Ticket**.
4. The service ticket is presented to the target server, which trusts the KDC to have
   verified the user's identity.

This means **no password ever traverses the network**. Only encrypted timestamps and
tickets.

Installing a KDC

.. code-block:: bash

    # RHEL 9
    dnf install -y krb5-server krb5-workstation
    # Debian 12
    apt-get install -y krb5-kdc krb5-admin-server
    krb5_newrealm
    systemctl enable --now krb5kdc kadmin

Add a principal (user):

.. code-block:: bash

    kadmin.local -q "addprinc alice"

12.1.4 FreeIPA: The Integrated Identity Platform
==================================================

FreeIPA (Free Identity, Policy, and Audit) bundles:

* 389 Directory Server (LDAP)
* MIT Kerberos (KDC)
* DNS with automatic service records
* Certificate Authority (DogTag)
* SSSD configuration ready out of the box
* Web UI for management

Deploying FreeIPA Server

.. code-block:: bash

    # RHEL 9 / Rocky 9
    dnf install -y ipa-server
    ipa-server-install --realm=EXAMPLE.COM --domain=example.com \
        --ds-password=Secret123 --admin-password=Secret123 \
        --setup-dns --auto-forwarders
    kinit admin
    ipa user-add alice --first=Alice --last=Smith --password
    ipa host-add web01.example.com

12.1.5 SSSD: Client-Side Identity Caching
==========================================

**System Security Services Daemon (SSSD)** is the modern bridge between a Linux machine
and remote identity sources.

Why SSSD?
---------

* **Caching**: If the network or remote server goes down, users can still log in.
* **Multiple backends**: LDAP, FreeIPA, Active Directory, Kerberos.
* **Offline authentication**: After first successful login, SSSD caches credentials.

Configuring SSSD for FreeIPA

.. code-block:: ini

    [sssd]
    services = nss, pam
    domains = example.com

    [domain/example.com]
    id_provider = ipa
    auth_provider = ipa
    ipa_hostname = client01.example.com
    ipa_server = ipa.example.com
    ipa_domain = example.com
    cache_credentials = True
    enumerate = False

.. code-block:: bash

    dnf install -y sssd sssd-tools realmd
    realm join --user=admin example.com
    getent passwd alice
    ssh alice@localhost

.. warning::
   Never set ``enumerate = True`` on a domain with more than 1,000 users. Enumeration
   causes every client to download the entire user list, flooding the LDAP server.

12.1.6 Modern IAM Bridging: PAM + OIDC with Keycloak and Dex
==============================================================

The **key problem**: Linux PAM understands POSIX identities and passwords, not OIDC tokens.
The solution is an **IAM bridge** that sits between PAM and the OIDC identity provider.

Keycloak
--------

`Keycloak <https://www.keycloak.org/>`_ is an open-source identity and access management
server that speaks OIDC, SAML, and LDAP.

Dex
---

`Dex <https://dexidp.io/>`_ is a lightweight OIDC identity provider that connects
to other identity sources. It is commonly deployed inside Kubernetes as the bridge
to corporate SSO.

Bridging PAM with OIDC: The Flow
---------------------------------

::

    User   ──→  SSH / sudo prompt
                   │
                   ▼
              PAM Module (pam_oidc)
                   │
                   ▼
          Browser opens → Authenticate at Keycloak / Okta
                   │
                   ▼
          OIDC Authorization Code → Token exchanged
                   │
                   ▼
          PAM module creates ephemeral local user (UID)
          with SSH certificate (valid for 8 hours)
                   │
                   ▼
              Grant Access

Practical Deployment: PAM OIDC with Keycloak
---------------------------------------------

.. code-block:: bash

    dnf install -y pam_oauth2_device
    cat >> /etc/pam.d/sshd << 'PAMEOF'
    auth sufficient pam_oauth2_device.so \
        client_id=linux-ssh \
        client_secret=***** \
        issuer=https://keycloak.example.com/realms/linux-prod \
        scope=openid,profile,groups
    PAMEOF

Dex Configuration

.. code-block:: yaml

    # /etc/dex/config.yaml
    issuer: https://dex.example.com:5556
    storage:
      type: kubernetes
      config:
        inCluster: true
    web:
      http: 0.0.0.0:5556
    connectors:
    - type: oidc
      id: okta
      name: Okta
      config:
        issuer: https://okta.example.com
        clientID: $DEX_CLIENT_ID
        clientSecret: $DEX_CLIENT_SECRET
        redirectURI: https://dex.example.com:5556/callback
    staticClients:
    - id: linux-ssh
      redirectURIs:
      - 'http://localhost:8000'
      name: 'Linux SSH Bridge'
      secret: $SSH_BRIDGE_SECRET

12.1.7 Summary
===============

+-------------------+--------------------------------------------------+
| Technology        | Use Case                                         |
+===================+==================================================+
| OpenLDAP          | POSIX identity store (UID/GID, home directory)   |
+-------------------+--------------------------------------------------+
| Kerberos KDC      | Passwordless, encrypted authentication           |
+-------------------+--------------------------------------------------+
| FreeIPA           | All-in-one: LDAP + Kerberos + CA + DNS + Web UI  |
+-------------------+--------------------------------------------------+
| SSSD              | Client-side caching for remote identity sources  |
+-------------------+--------------------------------------------------+
| Keycloak / Dex    | Bridge between Linux PAM and cloud-native OIDC   |
+-------------------+--------------------------------------------------+
EOF

# =============================================================================
# FILE 3: 02_high_availability.rst
# =============================================================================
cat > "$BASE/02_high_availability.rst" << 'EOF'
.. _sec-12-2:

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
EOF

# =============================================================================
# FILE 4: 03_disaster_recovery.rst
# =============================================================================
cat > "$BASE/03_disaster_recovery.rst" << 'EOF'
.. _sec-12-3:

============================================================
12.3 Disaster Recovery & Ransomware Defences
============================================================

12.3.1 The Threat Landscape in 2026
=====================================

Ransomware operators now exfiltrate data before encrypting (double extortion), delete
backup catalogs, and linger inside networks for months. A disaster recovery plan that
assumes "we will restore from tape" is obsolete.

12.3.2 The 3-2-1-1 Rule
==========================

* **3** copies of your data.
* **2** different storage media types.
* **1** copy off-site.
* **1** copy **immutable** (cannot be modified or deleted, even by root).

+----------+----------------------------+-----------------------------------+
| Copy #   | Location                   | Characteristics                  |
+==========+============================+===================================+
| 1        | Production server (local)  | Hot, online, fast restore         |
+----------+----------------------------+-----------------------------------+
| 2        | Local backup server        | Different machine, deduplicated   |
+----------+----------------------------+-----------------------------------+
| 3        | Remote (cloud/colocation)  | Encrypted in transit and at rest  |
+----------+----------------------------+-----------------------------------+
| 1 (Imm)  | Object lock / WORM media   | Append-only, non-erasable         |
+----------+----------------------------+-----------------------------------+

.. note::
   True immutability requires hardware WORM media, S3 Object Lock with retention
   policies, or a physically air-gapped system. Read-only permissions are insufficient
   against a compromised root account.

12.3.3 BorgBackup: Deduplicating, Encrypted Backups
=====================================================

`BorgBackup <https://www.borgbackup.org/>`_ splits data into chunks, hashes them, and
stores unique chunks only once. Supports authenticated encryption (chacha20-poly1305).

Installation
------------

.. code-block:: bash

    # RHEL 9 (EPEL)
    dnf install -y epel-release dnf install -y borgbackup
    # Debian 12
    apt-get install -y borgbackup

Creating a Repository
---------------------

.. code-block:: bash

    borg init --encryption=keyfile /mnt/backup/borg-repo
    borg key export /mnt/backup/borg-repo /root/borg-repo.key

Automated Backup Script
-----------------------

.. code-block:: bash

    #!/bin/bash
    export BORG_REPO="/mnt/backup/borg-repo"
    export BORG_PASSPHRASE="$(cat /root/borg-passphrase)"
    BACKUP_NAME="$(hostname)-$(date +%Y-%m-%d_%H%M%S)"
    borg create --verbose --stats --compression zstd,6 \
        --exclude '/dev' --exclude '/proc' --exclude '/sys' \
        --exclude '/tmp' --exclude '/run' --exclude '/mnt' \
        --exclude '/var/cache' --exclude '/var/tmp' \
        "::{BACKUP_NAME}" /etc /var /home /root /srv
    borg prune --verbose --list --keep-daily=7 --keep-weekly=4 --keep-monthly=6
    borg check --verbose

Restoring from Borg
-------------------

.. code-block:: bash

    borg list /mnt/backup/borg-repo
    borg extract /mnt/backup/borg-repo::myhost-2026-07-18_020000

12.3.4 Restic: Backups to Cloud and Object Storage
=====================================================

`Restic <https://restic.net/>`_ natively supports S3, GCS, Azure Blob, B2, and SFTP.

.. code-block:: bash

    export AWS_ACCESS_KEY_ID="minioadmin"
    export AWS_SECRET_ACCESS_KEY="minioadmin"
    restic init --repo s3:https://s3.example.com/restic-repo
    restic backup /etc /home --exclude="*.cache" --tag production
    restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
    restic restore latest --target /tmp/restore

.. important::
   Enable **S3 Object Lock** to enforce immutability:

   .. code-block:: bash

        aws s3api put-object-lock-configuration \
            --bucket my-backup-bucket \
            --object-lock-configuration '{"ObjectLockEnabled": "Enabled",
              "Rule": {"DefaultRetention": {"Mode": "GOVERNANCE", "Days": 30}}}'

12.3.5 Database Backup Strategies
====================================

Logical Backups (pg_dump / mysqldump)
--------------------------------------

Portable across versions, can restore single table. Slow for large databases.

.. code-block:: bash

    pg_dump -Fc -h localhost -U postgres mydb > /backup/mydb.dump
    pg_restore -d mydb /backup/mydb.dump
    mysqldump --single-transaction -h localhost -u root mydb > /backup/mydb.sql

Physical Backups (pg_basebackup / XtraBackup)
-----------------------------------------------

Fast, consistent point-in-time recovery. Binary format, version-specific.

.. code-block:: bash

    pg_basebackup -h localhost -D /backup/pg_phys -X stream -P
    # Point-in-Time Recovery via WAL archives
    # archive_command = 'cp %p /backup/wal/%f'
    # recovery_target_time = '2026-07-19 12:00:00'

    xtrabackup --backup --target-dir=/backup/mysql_phys
    xtrabackup --prepare --target-dir=/backup/mysql_phys

12.3.6 Filesystem Snapshots: ZFS and Btrfs Send/Recv
=======================================================

ZFS Send/Recv
-------------

.. code-block:: bash

    zfs snapshot -r tank/data@weekly-2026-07-19
    zfs send -R -i tank/data@weekly-2026-07-12 \
        tank/data@weekly-2026-07-19 \
        | ssh backup-host "zfs receive -F tank/backups/data"

Btrfs Send/Recv
---------------

.. code-block:: bash

    btrfs subvolume snapshot -r /mnt/data /mnt/data/.snapshots/weekly-2026-07-19
    btrfs send /mnt/data/.snapshots/weekly-2026-07-19 \
        | ssh backup-host "btrfs receive /mnt/backups/data"

.. caution::
   Use ``zfs hold`` to prevent snapshot deletion. Send snapshots to a separate
   air-gapped backup server with no interactive login.

12.3.7 Testing Your Disaster Recovery
========================================

An untested backup is not a backup. Schedule quarterly DR drills and measure:

+-----------------+------------------------------------+
| Metric          | Definition                         |
+=================+====================================+
| **RTO**         | Time to restore service.           |
|                 | Target: hours, not days.           |
+-----------------+------------------------------------+
| **RPO**         | Maximum acceptable data loss.      |
|                 | Target: minutes, not hours.        |
+-----------------+------------------------------------+

12.3.8 Summary
===============

1. **3-2-1-1** is non-negotiable. One copy must be immutable/air-gapped.
2. **Borg** for local, deduplicated, encrypted backups.
3. **Restic** for cloud-native backups with S3 Object Lock.
4. Database backups need **logical** AND **physical** strategies with WAL archiving.
5. **ZFS/Btrfs send/recv** for instant, incremental filesystem replication.
6. **Test everything** quarterly.
EOF

# =============================================================================
# FILE 5: 04_log_management.rst
# =============================================================================
cat > "$BASE/04_log_management.rst" << 'EOF'
.. _sec-12-4:

============================================================
12.4 Modern Log Management
============================================================

12.4.1 The 2026 Logging Landscape
=====================================

By 2026, the industry has moved away from the JVM-heavy ELK stack (Elasticsearch,
Logstash, Kibana) due to cost and complexity. The modern stack is:

+---------------------+---------------------------------------------+
| Component           | Role                                        |
+=====================+=============================================+
| **Vector**          | Log collection, transformation, routing     |
|                     | (replaces Logstash, Filebeat, Fluentd)      |
+---------------------+---------------------------------------------+
| **Grafana Loki**    | Horizontally scalable log aggregation       |
|                     | (replaces Elasticsearch for logs)           |
+---------------------+---------------------------------------------+
| **OpenTelemetry**   | Unified telemetry: logs, metrics, traces    |
+---------------------+---------------------------------------------+

12.4.2 Local Logging: rsyslog and logrotate
=============================================

rsyslog
--------

.. code-block:: bash

    # /etc/rsyslog.conf
    module(load="imudp")
    input(type="imudp" port="514")
    module(load="imtcp")
    input(type="imtcp" port="514")

    template(name="json-template" type="list") {
        constant(value="{")
        constant(value="\"timestamp\":\"") property(name="timereported" dateformat="rfc3339")
        constant(value="\",\"host\":\"")     property(name="hostname")
        constant(value="\",\"message\":\"")  property(name="msg" format="json")
        constant(value="\"}")
    }

    *.* action(type="omfwd" target="127.0.0.1" port="601" protocol="tcp"
               template="json-template")

logrotate
----------

.. code-block:: bash

    # /etc/logrotate.d/custom
    /var/log/myapp/*.log {
        daily
        rotate 30
        compress
        delaycompress
        missingok
        notifempty
        create 0640 root adm
        sharedscripts
        postrotate
            systemctl reload myapp > /dev/null 2>&1 || true
        endscript
    }

12.4.3 Vector: The Universal Log Router
=========================================

`Vector <https://vector.dev/>`_ is written in Rust (~10 MB binary, < 50 MB RAM).

File → Parse → Loki Pipeline
-----------------------------

.. code-block:: toml

    # /etc/vector/vector.toml
    [sources.app_logs]
    type = "file"
    include = ["/var/log/myapp/*.log"]
    ignore_older_secs = 600

    [transforms.parse_json]
    type = "remap"
    inputs = ["app_logs"]
    source = '''
    . = parse_json!(.message)
    .timestamp = now()
    .service = "myapp"
    '''

    [sinks.loki]
    type = "loki"
    inputs = ["parse_json"]
    endpoint = "http://loki.example.com:3100"
    encoding.codec = "json"
    labels.service = "{{ service }}"

    [sinks.loki.buffer]
    type = "disk"
    max_size = 1049000000
    when_full = "block"

12.4.4 Grafana Loki: Log Aggregation for the Modern Era
=========================================================

Loki does not index log content — only labels. This reduces storage 5-10x vs ELK.

.. code-block:: yaml

    # loki-config.yaml
    auth_enabled: false
    server:
      http_listen_port: 3100
    schema_config:
      configs:
        - from: 2024-01-01
          store: tsdb
          object_store: filesystem
          schema: v13
    storage_config:
      filesystem:
        directory: /loki

Querying with LogQL
--------------------

.. code-block:: text

    # Error count per service in last hour
    sum by (service) (count_over_time({job="myapp"} |= "error" [1h]))
    # Show logs for a specific request
    {job="nginx"} |= "req_abc123"
    # Rate of log lines
    rate({job="postgresql"}[5m])

12.4.5 OpenTelemetry: The Unified Standard
=============================================

`OpenTelemetry <https://opentelemetry.io/>`_ is the industry standard for telemetry.

.. code-block:: yaml

    # /etc/otel/config.yaml
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: "0.0.0.0:4317"
    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
    exporters:
      loki:
        endpoint: "http://loki.example.com:3100/loki/api/v1/push"
    service:
      pipelines:
        logs:
          receivers: [otlp]
          processors: [batch]
          exporters: [loki]

.. important::
   OTel is a **standard**. Instrument once with the OTel SDK, ship anywhere.

12.4.6 Summary
===============

* **rsyslog** and **logrotate** remain essential for local log management.
* **Vector** replaces the ELK pipeline with a single efficient Rust binary.
* **Grafana Loki** replaces Elasticsearch, reducing cost 5-10x.
* **OpenTelemetry** is the universal standard — instrument once, ship anywhere.
EOF

# =============================================================================
# FILE 6: 05_gitops_and_cm.rst
# =============================================================================
cat > "$BASE/05_gitops_and_cm.rst" << 'EOF'
.. _sec-12-5:

============================================================
12.5 Configuration Management at Scale & GitOps
============================================================

12.5.1 The Evolution of Configuration Management
===================================================

+----------------+-----------------------------------+---------------------------+
| Era            | Tools                             | Paradigm                  |
+================+===================================+===========================+
| **1.0**        | Shell scripts, scp + ssh          | Ad-hoc, mutable, manual   |
+----------------+-----------------------------------+---------------------------+
| **2.0**        | Puppet, Chef, SaltStack           | Push/pull, declarative    |
+----------------+-----------------------------------+---------------------------+
| **3.0**        | Ansible + GitOps (ArgoCD/Flux)    | Pull-based, declarative,  |
|                |                                   | continuous reconciliation  |
+----------------+-----------------------------------+---------------------------+

By 2026, Era 2.0 tools are in terminal decline. The industry standard is **GitOps**.

12.5.2 Ansible at Scale: AWX
================================

AWX is the open-source upstream of Red Hat Ansible Automation Platform.

.. code-block:: bash

    kubectl create namespace awx
    kubectl apply -f https://raw.githubusercontent.com/ansible/awx-operator/devel/config/crd/bases/awx.ansible.com_awxs.yaml

    cat << 'AWXEOF' | kubectl apply -f -
    apiVersion: awx.ansible.com/v1beta1
    kind: AWX
    metadata:
      name: awx-demo
      namespace: awx
    spec:
      service_type: ClusterIP
      admin_password_secret: awx-admin-password
      projects_persistence: true
      projects_storage_size: 10Gi
    AWXEOF

Ansible Semaphore (Lightweight)
--------------------------------

`Semaphore <https://www.ansible-semaphore.com/>`_ is a lightweight alternative.

.. code-block:: bash

    cat > semaphore-compose.yaml << 'SEMEOF'
    services:
      semaphore:
        image: semaphoreui/semaphore:latest
        ports:
          - "3000:3000"
        environment:
          SEMAPHORE_DB_DIALECT: bolt
          SEMAPHORE_ADMIN_PASSWORD: changeme
          SEMAPHORE_GIT_URL: https://github.com/yourorg/ansible-prod.git
    SEMEOF

12.5.3 The Decline of Legacy CM Tools
========================================

+----------------+---------------------------------------+----------------------------------+
| Limitation     | Puppet / Chef                        | Ansible / GitOps                 |
+================+=======================================+==================================+
| Architecture   | Agent (Ruby/JRuby) on every node     | Agentless (SSH) or pull-based    |
+----------------+---------------------------------------+----------------------------------+
| State handling | Convergence model (re-runs every 30m) | Idempotent / continuous reconcile |
+----------------+---------------------------------------+----------------------------------+
| Immutability   | Mutates state in place               | Promotes immutable images        |
+----------------+---------------------------------------+----------------------------------+

12.5.4 GitOps: The Industry Standard
========================================

Principles: declarative state, Git as single source of truth, pull-based
reconciliation, self-healing.

ArgoCD
------

.. code-block:: bash

    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    cat << 'ARGOCDEOF' | kubectl apply -f -
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: production-webapp
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/example/production-deployments.git
        targetRevision: main
        path: webapp/overlays/production
      destination:
        server: https://kubernetes.default.svc
        namespace: webapp-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
    ARGOCDEOF

Flux CD
-------

.. code-block:: bash

    flux bootstrap github \
        --owner=example \
        --repository=fleet-infra \
        --path=./clusters/production
    cat << 'FLUXEOF' | kubectl apply -f -
    apiVersion: helm.toolkit.fluxcd.io/v2
    kind: HelmRelease
    metadata:
      name: nginx
      namespace: production
    spec:
      chart:
        spec:
          chart: nginx
          sourceRef:
            kind: HelmRepository
            name: bitnami
      interval: 5m
      values:
        replicaCount: 3
    FLUXEOF

12.5.5 Summary
===============

The 2026 verdict: **If it is not in Git, it does not exist.** GitOps eliminates drift
by continuously reconciling live state against the canonical state in version control.
EOF

# =============================================================================
# FILE 7: 06_sre_practices.rst
# =============================================================================
cat > "$BASE/06_sre_practices.rst" << 'EOF'
.. _sec-12-6:

============================================================
12.6 SRE Practices & Change Management
============================================================

12.6.1 What is Site Reliability Engineering?
==============================================

SRE applies software engineering to operations. Core principles: treat operations as
an engineering problem, use error budgets, reduce toil, conduct blameless post-mortems,
and treat everything as code.

12.6.2 Version-Controlling /etc with etckeeper
=================================================

`etckeeper <https://etckeeper.branchable.com/>`_ turns ``/etc`` into a Git repository.

.. code-block:: bash

    # Install
    dnf install -y etckeeper   # EPEL
    apt-get install -y etckeeper  # Debian

    # Initialise
    cd /etc && etckeeper init
    etckeeper commit "Initial commit of /etc"
    git config user.email "admin@example.com"
    git config user.name "Root Admin"

    # View history
    cd /etc && git log --oneline

    # Push to remote (audit trail)
    git remote add origin git@git.example.com:etc-backups/corp-webserver.git
    git push --all origin

.. important::
   Use a **private** repository or ``git-crypt`` to protect secrets in /etc.

12.6.3 Executable Runbooks
=============================

Static runbook documents are outdated under pressure. Use executable runbooks instead.

Jupyter Notebook Runbooks
--------------------------

.. code-block:: python

    # rebuild_postgres_primary.ipynb
    CLUSTER_NAME = "prod-db-cluster"
    NEW_PRIMARY = "db03.example.com"

    # Verify cluster state
    import subprocess
    result = subprocess.run(["pcs", "status"], capture_output=True, text=True)
    assert "FAILED" not in result.stdout

    # Promote new primary
    subprocess.run(["pcs", "resource", "promote", "pgsql-data-master",
                    f"node={NEW_PRIMARY}"], check=True)
    print("Runbook complete.")

Markdown + Ansible Playbooks
-------------------------------

.. code-block:: markdown

    # Runbook: Reboot a Production Node Safely
    ## Pre-Checks
    - [ ] Verify cluster health: `pcs status`
    ## Drain Node
    ```bash
    pcs node standby $HOSTNAME
    ```
    ## Reboot
    ```bash
    shutdown -r now
    ```
    ## Post-Checks
    ```bash
    pcs node unstandby $HOSTNAME
    pcs status
    ```

12.6.4 Toil Reduction: The 50% Rule
======================================

Toil is manual, repetitive, automatable, tactical work with no enduring value.
Every SRE should spend no more than 50% of their time on toil.

12.6.5 Blameless Post-Mortems
=================================

A post-mortem identifies system weaknesses, not individual mistakes.

.. code-block:: markdown

    # Post-Mortem: Outage-2026-07-19
    **Duration:** 47 minutes
    **Severity:** SEV-1
    **Root Cause:** HAProxy backend misconfiguration (single active server)

    ## Action Items
    | Action | Owner | Ticket |
    |--------|-------|--------|
    | Add haproxy -c to CI/CD | @ops-eng | #4213 |
    | Create "Less than 2 backends" alert | @monitoring | #4215 |

    ## Blameless Statement
    The engineer followed the existing process. The failure is in the process.

12.6.6 Change Management: The SRE Way
========================================

Replace process gatekeeping with engineering gates: automated testing, progressive
delivery, observability, and automatic rollback.

.. code-block:: bash

    # Pre-deployment validation
    haproxy -c -f /etc/haproxy/haproxy.cfg
    ansible-playbook --syntax-check deploy-webapp.yml
    echo "=== Validation passed ==="

12.6.7 Summary
===============

* **etckeeper** versions /etc automatically.
* **Executable runbooks** replace static documents with actionable procedures.
* **Toil reduction** is an explicit engineering goal — measure and automate.
* **Blameless post-mortems** focus on system weaknesses, not people.
* **Change management** is automated, progressive, and observable.
EOF

# =============================================================================
# FILE 8: 07_capstone_project.rst
# =============================================================================
cat > "$BASE/07_capstone_project.rst" << 'EOF'
.. _sec-12-7:

============================================================
12.7 Capstone Project: Production-Ready 3-Tier Architecture
============================================================

12.7.1 Project Overview
=========================

Design and deploy a production-ready, resilient 3-tier architecture from scratch.

::

    Internet → HAProxy (Keepalived VIP) → Web Tier (K8s) → PostgreSQL → MinIO

Technology Stack
----------------

+--------------------+---------------------------------------------------+
| Layer              | Technology                                        |
+====================+===================================================+
| IaC (Provision)    | OpenTofu                                         |
+--------------------+---------------------------------------------------+
| Config Mgmt        | Ansible (AWX / Semaphore)                         |
+--------------------+---------------------------------------------------+
| Load Balancing     | HAProxy + Keepalived (VRRP)                       |
+--------------------+---------------------------------------------------+
| Compute            | Podman or Kubernetes (kind/k3s)                   |
+--------------------+---------------------------------------------------+
| Security           | SELinux (enforcing) + FirewallD                   |
+--------------------+---------------------------------------------------+
| Database           | PostgreSQL 16 with streaming replication          |
+--------------------+---------------------------------------------------+
| Observability      | Prometheus + Loki + Grafana                       |
+--------------------+---------------------------------------------------+
| Backups            | Borg/Restic to MinIO (Object Lock)                |
+--------------------+---------------------------------------------------+

12.7.2 Phase 1: Infrastructure with OpenTofu
===============================================

.. code-block:: hcl

    # tofu/main.tf
    provider "libvirt" {
      uri = "qemu+ssh://user@hypervisor.example.com/system"
    }
    module "compute" {
      source = "./modules/compute"
      servers = {
        lb01  = { cpu = 2, ram = 4096, ip = "10.100.1.10" }
        lb02  = { cpu = 2, ram = 4096, ip = "10.100.1.11" }
        web01 = { cpu = 4, ram = 8192, ip = "10.100.1.20" }
        web02 = { cpu = 4, ram = 8192, ip = "10.100.1.21" }
        web03 = { cpu = 4, ram = 8192, ip = "10.100.1.22" }
        db01  = { cpu = 4, ram = 16384, ip = "10.100.2.10" }
        db02  = { cpu = 4, ram = 16384, ip = "10.100.2.11" }
        monitor = { cpu = 2, ram = 4096, ip = "10.100.1.100" }
        backup  = { cpu = 4, ram = 8192, ip = "10.100.1.200" }
      }
      image = "rocky-9-generic"
    }

.. code-block:: bash

    cd tofu && tofu init && tofu apply

12.7.3 Phase 2: Configuration with Ansible
=============================================

.. code-block:: yaml

    # playbooks/site.yml
    - name: Apply base hardening
      hosts: all
      roles: [common, selinux, firewalld]
    - name: Configure load balancers
      hosts: loadbalancers
      roles: [haproxy, keepalived]
    - name: Deploy web applications
      hosts: webservers
      roles: [podman, webapp]
    - name: Configure PostgreSQL cluster
      hosts: databases
      roles: [postgresql, corosync-pacemaker]
    - name: Set up monitoring
      hosts: monitoring
      roles: [prometheus, loki, grafana]
    - name: Configure backup server
      hosts: backup
      roles: [restic]

.. code-block:: bash

    ansible-playbook -i inventory/production/hosts.ini playbooks/site.yml

12.7.4 Phase 3: SELinux Hardening
====================================

.. code-block:: bash

    getenforce  # Must return "Enforcing"
    cat > webapp.te << 'SEEOF'
    module webapp 1.0;
    require {
        type http_port_t; type etc_t; type var_log_t; type initrc_t;
        class tcp_socket { name_bind create connect };
        class file { read write open };
    }
    allow initrc_t http_port_t:tcp_socket name_bind;
    allow initrc_t var_log_t:file { write append };
    SEEOF
    checkmodule -M -m -o webapp.mod webapp.te
    semodule_package -o webapp.pp -m webapp.mod
    semodule -i webapp.pp

12.7.5 Phase 4: Kubernetes Deployment
========================================

.. code-block:: yaml

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
      namespace: capstone-prod
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: webapp
      template:
        metadata:
          labels:
            app: webapp
        spec:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          containers:
          - name: webapp
            image: registry.example.com/webapp:latest
            ports:
            - containerPort: 8080
            env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: url
            livenessProbe:
              httpGet:
                path: /health
                port: 8080
            readinessProbe:
              httpGet:
                path: /ready
                port: 8080

.. code-block:: bash

    kubectl apply -f k8s/

12.7.6 Phase 5: Observability Stack
========================================

.. code-block:: yaml

    # prometheus.yml
    scrape_configs:
    - job_name: 'kubernetes'
      kubernetes_sd_configs:
      - role: pod
    - job_name: 'haproxy'
      static_configs:
      - targets: ['lb01:9101', 'lb02:9101']
    - job_name: 'postgresql'
      static_configs:
      - targets: ['db01:9187', 'db02:9187']

Alert Rules
------------

.. code-block:: yaml

    groups:
    - name: capstone
      rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 2m
      - alert: DatabaseReplicationLag
        expr: pg_replication_lag_seconds > 300
        for: 1m

12.7.7 Phase 6: Automated Backups & DR
=========================================

.. code-block:: bash

    # /usr/local/bin/backup-all.sh
    set -euo pipefail
    pg_dump -Fc -h localhost -U postgres capstone_prod > /tmp/db_dump.sql
    restic backup /tmp/db_dump.sql --tag db-cron
    restic backup /etc --tag config
    restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
    restic check

12.7.8 Phase 7: GitOps Reconciliation
========================================

.. code-block:: yaml

    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: capstone-prod
      namespace: argocd
    spec:
      source:
        repoURL: https://github.com/yourorg/capstone-infra.git
        path: k8s
      destination:
        server: https://kubernetes.default.svc
        namespace: capstone-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true

12.7.9 Validation Checklist
=============================

.. list-table::
   :header-rows: 1

   * - #
     - Requirement
     - Verification Command
   * - 1
     - SELinux enforcing on all nodes
     - :command:`ansible all -m command -a getenforce`
   * - 2
     - HAProxy responds on VIP
     - :command:`curl -I https://203.0.113.100/`
   * - 3
     - Web app returns 200
     - :command:`curl -f http://localhost:8080/health`
   * - 4
     - DB replication active
     - :command:`psql -c "SELECT pg_is_in_recovery();"`
   * - 5
     - Prometheus scrapes targets
     - :command:`curl http://monitor:9090/api/v1/targets`
   * - 6
     - Loki receives logs
     - :command:`curl http://monitor:3100/loki/api/v1/labels`
   * - 7
     - Restic backup succeeds
     - :command:`restic check`
   * - 8
     - ArgoCD shows Synced
     - :command:`argocd app get capstone-prod`
   * - 9
     - STONITH armed
     - :command:`pcs stonith show --full`
   * - 10
     - /etc git-tracked
     - :command:`cd /etc && git log --oneline`

12.7.10 Graduation
====================

You have earned the title: **Senior Linux Infrastructure Engineer**.

* **Provision infrastructure** with OpenTofu
* **Configure at scale** with Ansible
* **Run containers securely** with K8s + SELinux
* **Balance traffic** with HAProxy + Keepalived
* **Centralise identity** with FreeIPA + SSSD
* **Observe every layer** with Prometheus + Loki + Grafana
* **Recover from disaster** with encrypted immutable backups
* **Automate change** with GitOps and blameless incident response

.. rubric:: What's Next?

* `Kernel Newbies <https://kernelnewbies.org/>`_
* `SRE Weekly <https://sreweekly.com/>`_
* `CNCF Landscape <https://landscape.cncf.io/>`_

Keep learning. Keep building. Keep making systems that survive.
EOF

# =============================================================================
# DONE
# =============================================================================
echo "=============================================="
echo "Chapter 12 generation complete."
echo "Files created in: $BASE"
ls -la "$BASE"
echo ""
echo "Build with:"
echo "  cd ~/learn-linux/docs && sphinx-build -b html source _build"
echo "  cd _build && python3 -m http.server 8000"
echo "=============================================="
