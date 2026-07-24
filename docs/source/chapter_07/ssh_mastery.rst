.. _sec-07-08:

=======================================
SSH Mastery
=======================================

The Secure Shell (SSH) protocol is the Swiss Army knife of remote
administration. It provides encrypted remote login, secure file transfer (via
SFTP and SCP), port forwarding (tunnelling), X11 forwarding, and more. For a
Linux administrator, SSH is not merely a tool — it is an extension of your
presence.

This section covers SSH from the ground up: key-based authentication (with
modern cryptographic recommendations), agent forwarding, the three types of
tunnels, server hardening, and the lesser-known DNS-based SSH fingerprint
verification (SSHFP).

SSH Architecture Overview
================================

SSH follows a client-server model:

* **SSH server (sshd):** Listens on TCP port 22 by default. Accepts incoming
  connections, authenticates clients, and provides the requested services
  (shell, file transfer, port forwarding).
* **SSH client (ssh):** Initiates connections to the server, handles
  authentication on the user's behalf, and provides the user interface.

The protocol has three layers:

1. **Transport Layer:** Negotiates encryption algorithms, key exchange, and
   integrity checking. Establishes an encrypted channel.
2. **Authentication Layer:** Authenticates the user to the server (password,
   public key, or other methods).
3. **Connection Layer:** Multiplexes multiple logical channels (shell sessions,
   file transfers, forwarded ports) over the single encrypted connection.

Key-Based Authentication
===============================

Password authentication over SSH is vulnerable to brute-force attacks and is
generally considered a security anti-pattern. **Public key authentication** is
the standard — it uses asymmetric cryptography: a private key (kept secret on
the client) and a public key (deployed to servers).

**Generating a key pair (modern, recommended approach):**

.. code-block:: bash

    ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519 -C "my-email@example.com"

Flag breakdown:

* ``-t ed25519`` — The key type. **Ed25519** is a modern elliptic-curve
  algorithm. It produces small keys (256 bits), is fast to generate and verify,
  and is resistant to side-channel attacks. **Always prefer Ed25519.**
* ``-a 100`` — The number of KDF (key derivation function) rounds applied to
  the passphrase. Higher = more resistant to brute-force cracking. The default
  is 16; 100–200 is recommended.
* ``-f ~/.ssh/id_ed25519`` — Output file path.
* ``-C "..."`` — A comment (typically your email or hostname) embedded in the
  public key for identification.

**Why not RSA?**

RSA keys are still widely deployed and perfectly functional. However:

* RSA keys must be at least 3072 bits to match the security of Ed25519's 256
  bits. Larger keys mean slower generation and larger authentication packets.
* Ed25519 is faster, smaller, and considered more cryptographically robust
  (it uses the twisted Edwards curve, proven secure in the cryptographic
  literature).

If you must use RSA for compatibility with legacy systems:

.. code-block:: bash

    ssh-keygen -t rsa -b 4096 -a 100 -f ~/.ssh/id_rsa

**Deploying the public key to a server:**

.. code-block:: bash

    # The simplest method
    ssh-copy-id -i ~/.ssh/id_ed25519.pub user@server.example.com

    # What ssh-copy-id does:
    # 1. Connects to the server (using password for the last time)
    # 2. Appends your public key to ~/.ssh/authorized_keys on the server
    # 3. Sets proper permissions (600 on authorized_keys, 700 on ~/.ssh)
    # 4. Disconnects

    # Manual alternative
    cat ~/.ssh/id_ed25519.pub | ssh user@server.example.com \
        "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"

**The authorized_keys file:**

On the server, each line in ``~/.ssh/authorized_keys`` (or
``/etc/ssh/authorized_keys/%u`` if using the ``AuthorizedKeysFile`` directive)
contains one public key. Key options can be prepended:

.. code-block:: text
    :caption: ~/.ssh/authorized_keys

    # Restrict this key to specific commands and source IPs
    command="/usr/local/bin/backup.sh",from="10.0.0.0/24",no-agent-forwarding,no-port-forwarding ssh-ed25519 AAAAC3... comment

Common key options:

+----------------------+------------------------------------------------------+
| Option               | Effect                                               |
+======================+======================================================+
| ``from="pattern"``   | Only allow connections from matching source IPs.     |
+----------------------+------------------------------------------------------+
| ``command="cmd"``    | Force a specific command (key is only valid for that |
|                      | command).                                            |
+----------------------+------------------------------------------------------+
| ``no-agent-forwarding``| Disable agent forwarding for this key.             |
+----------------------+------------------------------------------------------+
| ``no-port-forwarding`` | Disable port forwarding for this key.              |
+----------------------+------------------------------------------------------+
| ``no-pty``           | Disable interactive shell allocation.                |
+----------------------+------------------------------------------------------+
| ``restrict``         | Enable all restrictions at once (OpenSSH 6.2+).      |
+----------------------+------------------------------------------------------+

SSH Agent and Agent Forwarding
=====================================

The **SSH agent** is a background process that holds your decrypted private
keys in memory. When the agent is running, SSH client tools (``ssh``, ``scp``,
``git``) can authenticate using the agent rather than requiring you to enter
your passphrase repeatedly.

**Starting the agent:**

.. code-block:: bash

    # Start the agent and set environment variables
    eval "$(ssh-agent -s)"

    # Add your key to the agent
    ssh-add ~/.ssh/id_ed25519

    # List keys currently loaded in the agent
    ssh-add -l

    # Remove all keys from the agent
    ssh-add -D

**Agent Forwarding:**

Agent forwarding allows your local SSH agent to be used on a remote server,
so that from that server you can authenticate to a third host without storing
any private key on the intermediate server.

::

    Laptop ──ssh──→ Server A ──ssh──→ Server B
      │                                        │
      └────────── agent forwarded ─────────────┘
                (keys never leave laptop)

**How to use:**

.. code-block:: bash

    # Connect with agent forwarding enabled
    ssh -A user@server-a.example.com

    # From Server A, this now works without any key on Server A:
    ssh user@server-b.example.com

**Security warning:** Agent forwarding is extremely powerful but also
dangerous. A malicious user with root access on Server A can use your forwarded
agent socket to authenticate to any host your keys grant access to —
*without* knowing your passphrase.

**Best practices:**

* Use ``ssh -A`` only when necessary. The default is ``-a`` (agent forwarding
  disabled).
* Use the ``ForwardAgent`` directive in your ``~/.ssh/config`` for specific
  hosts rather than globally.
* Consider using **SSH proxy jump** (``-J``) instead of forwarding when
  possible (see Section 7.8.5).

SSH Tunnels (Port Forwarding)
=====================================

SSH tunnels allow you to route TCP traffic through an encrypted SSH
connection. There are three types, each serving a different purpose.

**Local Port Forwarding (-L)**

Forward a local port to a remote destination through the SSH server.

::

    # Syntax: ssh -L local_port:destination_host:destination_port ssh_server

    # Example: Make a database on a private server accessible locally
    ssh -L 5432:db-internal.example.com:5432 bastion.example.com

After running this, connecting to ``localhost:5432`` on your machine will be
tunnelled through the bastion to the internal database server.

**Use case:** Access a service on a private network behind a bastion host.

**Remote Port Forwarding (-R)**

Forward a remote port (on the SSH server) to a local destination.

::

    # Syntax: ssh -R remote_port:local_host:local_port ssh_server

    # Example: Expose a local development server to the internet via a public VPS
    ssh -R 8080:localhost:3000 user@public-vps.example.com

After running this, anyone connecting to ``public-vps.example.com:8080`` will
be tunnelled back to your local machine's port 3000.

**Use case:** Show a local web app to a colleague without deploying it. Also
used for bypassing NAT.

**Dynamic Port Forwarding (-D) — SOCKS Proxy**

Create a SOCKS5 proxy that dynamically routes traffic through the SSH server.

::

    # Syntax: ssh -D local_socks_port ssh_server

    # Example: Create a SOCKS proxy on localhost:1080
    ssh -D 1080 user@gateway.example.com

Configure your browser (or system) to use ``SOCKS5 localhost 1080``. All web
traffic will be encrypted and routed through the SSH server.

**Use case:** Secure browsing on public Wi-Fi, bypassing regional restrictions,
or routing traffic through a corporate network.

**SSH ProxyJump (-J)**

Not technically a tunnel, but a clean alternative to agent forwarding for
multi-hop scenarios:

.. code-block:: bash

    # Jump through a bastion to reach a target host
    ssh -J bastion.example.com internal-server.example.com

    # Can chain multiple jumps
    ssh -J jump1, jump2 target.example.com

    # Config file equivalent (~/.ssh/config)
    Host internal-server
        HostName internal-server.example.com
        ProxyJump bastion.example.com

ProxyJump establishes a separate SSH connection to each hop, forwarding the
final SSH connection through them. Unlike agent forwarding, it does not expose
your agent to intermediate hosts.

Hardening sshd_config
============================

The SSH server's configuration file is ``/etc/ssh/sshd_config``. The
following hardening measures represent current best practice; apply them on any
server exposed to the internet.

.. code-block:: text
    :caption: /etc/ssh/sshd_config (hardened)

    # --- Authentication ---
    # Disable password authentication (key-based only)
    PasswordAuthentication no

    # Disable empty passwords
    PermitEmptyPasswords no

    # Disable root login entirely (use sudo)
    PermitRootLogin no

    # Limit authentication attempts to prevent brute force
    MaxAuthTries 3
    MaxSessions 10

    # --- Key Management ---
    # Use only modern key types
    PubkeyAuthentication yes
    AuthorizedKeysFile .ssh/authorized_keys

    # --- Networking ---
    # Change default port (optional, reduces log noise)
    Port 22

    # Only use modern protocol; SSHv1 is long dead
    Protocol 2

    # Bind to specific interfaces if possible
    # ListenAddress 192.168.1.10

    # --- Cryptographic Hardening ---
    # Use only modern key exchange algorithms
    KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512

    # Use only modern ciphers
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com

    # Use only modern MACs
    MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

    # Disable host-based authentication and .rhosts
    IgnoreRhosts yes
    HostbasedAuthentication no

    # --- Logging ---
    # Verbose logging (helps with forensics)
    LogLevel VERBOSE

    # --- Session ---
    # Close idle sessions after 10 minutes
    ClientAliveInterval 300
    ClientAliveCountMax 0

    # Allow only specific users or groups
    AllowUsers alice bob
    # AllowGroups ssh-users

    # --- Forwarding ---
    # Disable agent forwarding by default (enable per-user)
    AllowAgentForwarding no

    # Disable TCP forwarding if not needed
    # AllowTcpForwarding no

    # Disable X11 forwarding if not needed
    X11Forwarding no

**After each change:**

.. code-block:: bash

    # Validate the configuration (syntax check)
    sudo sshd -t

    # Reload the daemon gracefully (does not disconnect existing sessions)
    sudo systemctl reload sshd

**Note on the port change:** Changing SSH from port 22 to a non-standard port
(e.g., 2222) is debated. It reduces log noise from automated scanners but
provides no real security — any targeted attacker will find your SSH port with
a simple port scan. It is acceptable as a minor inconvenience to attackers, but
never rely on it as a security measure.

SSHFP Records — SSH Fingerprint Verification via DNS
===========================================================

**SSHFP (SSH Fingerprint)** resource records allow a DNS zone to publish the
public host key fingerprints of SSH servers. This enables clients to
automatically verify the server's host key without manual fingerprint
distribution.

**The problem it solves:** When you connect to an SSH server for the first
time, OpenSSH asks you to verify the host key fingerprint. Most users blindly
accept it, opening the door to man-in-the-middle attacks. SSHFP records
automate this verification — if your DNSSEC-secured DNS zone publishes the
correct fingerprint, the client can verify the server's identity
cryptographically.

**Setting up SSHFP records:**

.. code-block:: bash

    # On the SSH server, generate the SSHFP records
    ssh-keygen -r server.example.com

    # Output:
    # server.example.com IN SSHFP 1 1 ... (RSA SHA1)
    # server.example.com IN SSHFP 1 2 ... (RSA SHA256)
    # server.example.com IN SSHFP 4 1 ... (ECDSA SHA1)
    # server.example.com IN SSHFP 4 2 ... (ECDSA SHA256)

    # Add these records to your DNS zone file.
    # For DNSSEC verification to work, the zone must be signed.

**Client-side verification:**

Add this to your ``~/.ssh/config`` to use SSHFP verification:

::

    Host *
        VerifyHostKeyDNS yes

With ``VerifyHostKeyDNS yes``, the client will fetch SSHFP records from DNS
and, if they match and are validated by DNSSEC, automatically accept the host
key. If no SSHFP record exists, it falls back to the manual prompt.

With ``VerifyHostKeyDNS confirm``, the client will accept if DNSSEC-validated;
otherwise it prompts you to confirm.

Practical SSH Config File
================================

The ``~/.ssh/config`` file can save enormous time and avoid repetitive typing. Here is a practical example:

::

    # Global defaults
    Host *
        ServerAliveInterval 60
        ServerAliveCountMax 3
        AddKeysToAgent yes
        IdentityFile ~/.ssh/id_ed25519

    # Bastion host
    Host bastion
        HostName bastion.example.com
        User admin
        Port 22

    # Internal server accessed via bastion
    Host internal-db
        HostName 10.0.0.50
        User dbadmin
        ProxyJump bastion
        LocalForward 5432 localhost:5432

    # GitHub
    Host github.com
        HostName github.com
        User git
        IdentityFile ~/.ssh/github_ed25519

Now you can type ``ssh bastion`` instead of ``ssh admin@bastion.example.com``,
and ``ssh internal-db`` automatically tunnels through the bastion and forwards
the database port.

Common SSH Troubleshooting
=================================

.. list-table::
   :header-rows: 1

   * - Problem
     - Likely Cause
     - Solution
   * - ``Permission denied (publickey)``
     - Key not in ``authorized_keys``, or wrong permissions on
       ``~/.ssh`` or ``authorized_keys``.
     - Check server-side permissions
       (``~/.ssh`` must be ``700``,
       ``authorized_keys`` must be ``600``).
       Use ``ssh -vvv`` for verbose debug.
   * - ``Connection refused``
     - SSH server not running, or firewall blocking port 22.
     - ``systemctl status sshd``, check firewall rules
       (``ufw status``, ``firewall-cmd --list-all``).
   * - ``Connection timed out``
     - Network unreachable or intermediate firewall dropping
       packets.
     - ``ping`` the server, ``traceroute`` the path,
       check routing.
   * - ``Host key verification failed``
     - Server host key has changed (reinstall, MiTM attack).
     - Verify with server admin. If legitimate, remove old
       key: ``ssh-keygen -R hostname``.
   * - Agent forwarding not working
     - ``ForwardAgent no`` in server's ``sshd_config`` or
       client config.
     - Verify ``AllowAgentForwarding yes`` on server.
       Use ``-A`` flag explicitly.
