.. _centralized-iam:

============================================================
Centralised Identity & Access (IAM)
============================================================

Why Centralised Identity Matters
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

Lightweight Directory Access Protocol (LDAP)
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

Kerberos: Trusted Authentication
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

FreeIPA: The Integrated Identity Platform
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

SSSD: Client-Side Identity Caching
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

Modern IAM Bridging: PAM + OIDC with Keycloak and Dex
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

Summary
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
