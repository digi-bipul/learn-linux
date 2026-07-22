.. _sec9_6:

###########################################################
9.6 Cryptography & Encryption
###########################################################

Cryptography is the bedrock of data protection. On a Linux system, it
protects data at rest (full-disk encryption), data in transit (TLS/SSH),
and data in use (memory encryption via AMD SME/Intel SGX, though that is
outside our scope). This section covers the practical administration of
Linux cryptographic tools with an emphasis on **2026 best practices**:
LUKS2 with Argon2, TLS 1.3 with hybrid post-quantum key exchange, and
the imminent migration to NIST-approved post-quantum cryptographic
algorithms.

9.6.1 LUKS2 Full-Disk Encryption
=================================

**LUKS (Linux Unified Key Setup)** is the standard for Linux full-disk
encryption. **LUKS2** (introduced in cryptsetup 2.0.0, 2018) is the current
standard, superseding LUKS1. All new deployments in 2026 must use LUKS2.

**Why LUKS2 over LUKS1:**

+-------------------------+-----------------------------+-----------------------------+
| Feature                 | LUKS1                       | LUKS2                       |
+=========================+=============================+=============================+
| Key derivation
+-------------------------+-----------------------------+-----------------------------+
| Feature                 | LUKS1                       | LUKS2                       |
+=========================+=============================+=============================+
| Key derivation function | PBKDF2 (iterations)         | Argon2 (memory-hard,        |
|                         |                             | resistant to ASIC/GPU       |
|                         |                             | attacks)                    |
+-------------------------+-----------------------------+-----------------------------+
| Integrity protection    | None (plaintext/ciphertext) | AEAD modes (``--integrity`` |
|                         |                             | with dm-crypt)              |
+-------------------------+-----------------------------+-----------------------------+
| Backup headers          | Single header (fragile)     | Multiple header slots +     |
|                         |                             | JSON metadata area for      |
|                         |                             | resilience                  |
+-------------------------+-----------------------------+-----------------------------+
| Token-based unlocking   | Limited (``--key-slot``)    | Native token support        |
|                         |                             | (``systemd-tpm2``, PKCS#11) |
+-------------------------+-----------------------------+-----------------------------+
| Re-encryption           | Not supported offline       | ``cryptsetup reencrypt``    |
|                         |                             | (online re-encryption)      |
+-------------------------+-----------------------------+-----------------------------+

**Creating a LUKS2 encrypted volume:**

::

    # 1. Partition the disk (assuming /dev/sdb)
    sudo parted /dev/sdb mklabel gpt
    sudo parted /dev/sdb mkpart primary 0% 100%
    sudo parted /dev/sdb set 1 crypt LUKS

    # 2. Create LUKS2 container with Argon2
    sudo cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 \
        --key-size 512 --pbkdf argon2id --iter-time 5000 /dev/sdb1

    # 3. Open the container
    sudo cryptsetup open /dev/sdb1 secret

    # 4. Create a filesystem
    sudo mkfs.ext4 /dev/mapper/secret

    # 5. Mount
    sudo mount /dev/mapper/secret /mnt/secret

    # 6. Automate unlock at boot via /etc/crypttab and initramfs
    echo "secret UUID=$(sudo blkid -s UUID -o value /dev/sdb1) none luks" \
        | sudo tee -a /etc/crypttab
    sudo update-initramfs -u

**TPM2-based automatic unlocking (2026 standard):**

On systems with a TPM 2.0 chip (virtually every server and laptop since
2020), you can bind LUKS2 to the TPM so the disk unlocks automatically
at boot—but *only* if the boot chain is unmodified (measured boot via
TPM PCRs).

::

    # Add a LUKS2 token bound to TPM PCRs 0, 2, 7
    sudo systemd-cryptenroll --tpm2-device=auto \
        --tpm2-pcrs=0+2+7 /dev/sdb1

Now the disk unlocks automatically on that specific machine. If someone
removes the drive and attaches it to a different system, the TPM will not
release the key—the PCR values will not match.

**FIDO2-based unlocking:**

YubiKeys and other FIDO2 tokens can serve as LUKS2 unlock keys:

::

    sudo systemd-cryptenroll --fido2-device=auto /dev/sdb1

At boot, ``systemd-cryptsetup`` prompts the user to touch the FIDO2 token.

9.6.2 GPG (GNU Privacy Guard)
==============================

GPG implements the OpenPGP standard (RFC 4880) for encryption, signing, and
key management. In 2026, it remains the tool of choice for file-level
encryption, email security, and package signing verification (e.g., Debian's
``apt-key``, though ``apt-key`` is deprecated in favour of signed-by).

**Key generation (2026 best practice — ECC, not RSA):**

::

    gpg --full-generate-key
    # Choose: (9) ECC (sign and encrypt) -> Curve 25519
    # Expiry: 2 years (rotate keys regularly)
    # Real name, email, passphrase (use a strong passphrase)

**ECC is mandatory in 2026.** RSA-4096 is still secure but less efficient.
Ed25519 for signing and Curve25519 for encryption are the default choices
and are FIPS 186-5 approved.

**Encrypting a file for a recipient:**

::

    gpg --encrypt --recipient alice@example.com document.pdf
    # Produces document.pdf.gpg

**Signing a file:**

::

    gpg --detach-sign --armor document.pdf
    # Produces document.pdf.asc (detached ASCII-armored signature)

**Verifying a package (Debian repository style):**

::

    # The repository Release file is signed by the Debian GPG key
    gpg --verify Release.gpg Release

**Key Servers and Web of Trust:**

In 2026, the traditional SKS keyserver pool has been mostly replaced by
**keys.openpgp.org**, which acts as a verified key directory. The Web of
Trust (WoT) model is still used by Debian developers and the Fedora
project, but most enterprises use centralized key management via
**OpenPGP CA** or an internal key server.

9.6.3 OpenSSL: TLS, Certificate Management, and Hybrid PQ
==========================================================

OpenSSL is the library that powers TLS on virtually every Linux server.
In 2026, OpenSSL 3.5+ is the standard, with support for TLS 1.3 (mandatory),
the Provider API (for pluggable cryptographic backends), and experimental
post-quantum key exchange.

**Generating a modern TLS certificate (EC P-384):**

::

    # Generate private key (ECDSA P-384)
    openssl ecparam -name secp384r1 -genkey -out server.key

    # Generate CSR
    openssl req -new -key server.key -out server.csr \
        -subj "/C=US/ST=Virginia/L=Reston/O=Acme Corp/CN=api.acme.com"

    # Self-sign (for internal/testing; production uses a CA)
    openssl x509 -req -days 365 -in server.csr \
        -signkey server.key -out server.crt

**Modern TLS 1.3 configuration for NGINX:**

::

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256;
    ssl_prefer_server_ciphers off;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 8.8.8.8 valid=300s;
    resolver_timeout 5s;

    # Modern curves (include X25519 for forward secrecy)
    ssl_ecdh_curve X25519:secp384r1:secp521r1;

**Post-quantum hybrid TLS (OpenSSL 3.5+, 2026):**

NIST has standardized ML-KEM (FIPS 203, formerly Kyber) and ML-DSA
(FIPS 204, formerly Dilithium). OpenSSL 3.5 supports hybrid key exchange
using the ``groups`` option:

::

    # Server-side: enable Kyber + ECDHE hybrid
    ssl_groups mlkem768x25519:kyber768:prime256v1

    # The server and client negotiate the strongest mutually supported group.
    # A client with PQ support gets hybrid Kyber+X25519;
    # a legacy client falls back to X25519 or P-256.

To generate a hybrid X.509 certificate with both an ECDSA and a Dilithium
key, you need OpenSSL 3.5 compiled with the ``oqs-provider`` (OpenQuantumSafe):

::

    # Hybrid certificate request (ECDSA + ML-DSA)
    openssl req -newkey p384 -newkey dilithium3 \
        -nodes -keyout server.pem -out server.csr

You can verify the post-quantum signature algorithm in the certificate:
::

    openssl x509 -in server.crt -text -noout | grep "Signature Algorithm"
    # Output: ecdsa-with-SHA384 + dilithium3

**Real-world status in 2026:**

- **Google:** Chrome and Google Cloud support X25519Kyber768 since 2023.
- **Cloudflare:** All edge servers offer Kyber+ECDHE hybrid.
- **Amazon:** AWS Certificate Manager supports hybrid PQ certificates.
- **NSA:** CNSA 2.0 mandates ML-KEM and ML-DSA by 2028 for National
  Security Systems.
- **CISA:** Urges all federal agencies to inventory and begin migration.

9.6.4 Let's Encrypt and certbot
================================

Let's Encrypt is the world's largest certificate authority, providing free,
automated TLS certificates via the ACME protocol. In 2026, it has issued
over 3 billion certificates.

**Automated certificate issuance with certbot:**

::

    # Install certbot with the nginx plugin
    sudo apt install certbot python3-certbot-nginx

    # Obtain and install certificate
    sudo certbot --nginx -d api.acme.com -d www.acme.com

    # Verify auto-renewal (systemd timer)
    sudo systemctl status certbot.timer

**ACME DNS-01 challenge (for wildcard certificates):**

::

    # Requires a DNS API plugin for your provider (Cloudflare, AWS Route 53, etc.)
    sudo certbot certonly --dns-cloudflare \
        --dns-cloudflare-credentials /etc/cloudflare.ini \
        -d '*.acme.com'

**Post-quantum ACME (2026):**

Let's Encrypt announced in 2025 that all new certificates use hybrid
ML-DSA + ECDSA signatures by default. Your certbot client must be version
2.12+ to support PQ ACME:

::

    certbot --preferred-chain "ISRG Root PQ X1" -d example.com

9.6.5 SSH Key Management and Hardening
=======================================

**Generating modern SSH keys (2026):**

The days of RSA-2048 are ending. Use Ed25519:

::

    ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519

The ``-a 100`` sets 100 KDF rounds (default is 16) for brute-force
resistance if the private key is stolen.

**Post-quantum SSH:**

OpenSSH 9.9+ (released 2025) includes the hybrid key exchange
``mlkem768x25519-sha256``:

::

    # In ~/.ssh/config or /etc/ssh/sshd_config:
    Host *
        HostKeyAlgorithms +ssh-ed25519
        KexAlgorithms +mlkem768x25519-sha256
        PubkeyAcceptedAlgorithms +ssh-ed25519

**SSH CA (Certificate Authority) authentication:**

Instead of distributing hundreds of public keys to servers, use an SSH CA:

::

    # On the CA server:
    ssh-keygen -t ed25519 -f /etc/ssh/user_ca_key

    # Sign the user's public key:
    ssh-keygen -s /etc/ssh/user_ca_key -I alice@acme.com \
        -n alice -V +52w ~alice/.ssh/id_ed25519.pub

    # On the SSH server, in /etc/ssh/sshd_config:
    TrustedUserCAKeys /etc/ssh/user_ca_key.pub

Now any server with that CA public key trusts all certificates signed by
the CA. Revocation is handled by a ``revoked_keys`` file or CRL.

9.6.6 Hardware Security Modules (HSM) and PKCS#11
==================================================

In enterprise environments, private keys should never reside in filesystem
files. **Hardware Security Modules (HSMs)** —including TPMs, YubiKeys with
PIV, and dedicated network HSMs—protect keys against extraction.

**Using a YubiKey PIV for SSH/TLS:**

::

    # Generate key on the YubiKey (never leaves hardware)
    ykman piv generate-key --algorithm ECCP384 9a pubkey.pem

    # Generate CSR
    openssl req -new -key pkcs11:token=YubiKey -subj "/CN=example.com"

    # SSH via PKCS#11 provider
    ssh -I /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so server.example.com

9.6.7 Cryptographic Erasure
============================

When decommissioning a LUKS2-encrypted drive, simply destroying the LUKS
header renders all data permanently inaccessible—no need for multi-pass
overwrites:

::

    # Remove LUKS2 header (irreversible)
    sudo cryptsetup erase /dev/sdb1

    # Or wipe the header area explicitly
    sudo dd if=/dev/urandom of=/dev/sdb1 bs=1M count=16

This is the fastest and most secure method of data sanitization for
encrypted drives. For SSDs, also issue the ATA SANITIZE command:
::

    sudo hdparm --user-master u --security-set-pass p /dev/sdb
    sudo hdparm --user-master u --security-erase-enhanced p /dev/sdb
EOF

# ──────────────────────────────────────────────────────────────
# File: 07_audit_intrusion.rst
# ──────────────────────────────────────────────────────────────

cat << 'EOF' > ~/learn-linux/docs/source/chapter_09/07_audit_intrusion.rst
.. _sec9_7:

###########################################################
9.7 Audit, EDR, & Intrusion Detection
###########################################################

Detection is the complement to prevention. Even the most hardened system will
eventually face a compromise. The question is: *will you know about it?*
This section covers the Linux audit subsystem, file integrity monitoring,
rootkit detection, and the modern Endpoint Detection and Response (EDR)
tools that define security operations in 2026.

9.7.1 auditd: The Linux Audit Framework
========================================

The Linux Audit Daemon (``auditd``) is the kernel's event-logging subsystem
for security-relevant activity. It captures system calls, file accesses,
process executions, and configuration changes—all at the kernel level,
making it extremely difficult for an attacker to evade.

**Architecture:**

1. The **kernel audit subsystem** (``CONFIG_AUDIT=y``) generates events.
2. **``auditd``** (userspace daemon) reads events from ``netlink`` socket
   and writes them to ``/var/log/audit/audit.log``.
3. **``audispd``** (audit dispatcher) can forward events to remote syslog,
   SIEM (Splunk, Elastic, Wazuh), or custom plugins.

**Essential rules (``/etc/audit/rules.d/audit.rules``):**

::

    # Remove any existing rules
    -D

    # Buffer size (increase for busy systems)
    -b 8192

    # Failure mode: 0=silent, 1=printk, 2=panic (high-security)
    -f 1

    # Log all system calls by privileged users (uid < 1000)
    -a always,exit -F arch=b64 -S execve -F uid=0 -k privileged-exec

    # Monitor password files
    -w /etc/passwd -p wa -k passwd-changes
    -w /etc/shadow -p wa -k shadow-changes
    -w /etc/sudoers -p wa -k sudoers-changes

    # Monitor SSH configuration and keys
    -w /etc/ssh/sshd_config -p wa -k sshd-config
    -w /etc/ssh/ -p wa -k sshd-config
    -w ~/.ssh/ -p wa -k user-ssh

    # Monitor sensitive binaries
    -w /usr/bin/su -p x -k su-exec
    -w /usr/bin/sudo -p x -k sudo-exec

    # Monitor kernel module loading
    -w /sbin/insmod -p x -k kernel-modules
    -w /sbin/modprobe -p x -k kernel-modules

    # Monitor time changes
    -a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change

    # Monitor user/group management
    -w /usr/sbin/useradd -p x -k user-mgmt
    -w /usr/sbin/userdel -p x -k user-mgmt
    -w /usr/sbin/usermod -p x -k user-mgmt
    -w /usr/sbin/groupadd -p x -k group-mgmt

    # Monitor mount operations
    -a always,exit -F arch=b64 -S mount -S umount2 -k mount

    # Make the configuration immutable (prevents tampering with audit rules)
    -e 2

.. warning::
   The ``-e 2`` flag makes the audit rules immutable until the next reboot.
   Test new rules thoroughly before enabling this.

**Querying the audit log:**

::

    # All events in the last hour
    ausearch -ts today -i

    # Events for a specific key
    ausearch -k passwd-changes -i

    # Login events
    ausearch -m USER_LOGIN -i

    # Failed file access attempts
    ausearch -m PATH -i --success no

    # Real-time monitoring
    tail -f /var/log/audit/audit.log | audit2why

**Remote log forwarding (SIEM integration):**

::

    # /etc/audit/audispd-plugins/au-remote.conf
    active = yes
    direction = out
    path = /sbin/audisp-remote
    args = tcp://10.0.0.100:60
    format = rich

For high-security environments, configure TLS-encrypted audit transport
using ``audisp-remote`` with TLS or forward via syslog-ng/rsyslog with
TLS to an Elastic SIEM or Splunk Heavy Forwarder.

9.7.2 File Integrity Monitoring: AIDE
======================================

**AIDE (Advanced Intrusion Detection Environment)** creates a cryptographic
database of file metadata and content hashes, then periodically compares the
live filesystem against that database to detect unauthorized changes.

**Initialization:**

::

    # Install
    sudo apt install aide

    # Configure /etc/aide/aide.conf (or /etc/aide.conf)
    # Define rules for what to monitor
    #
    # Example rules:
    #   p: permissions, i: inode, n: number of links
    #   u: user, g: group, s: size, b: block count
    #   m: mtime, a: atime, c: ctime, S: SHA-256 hash

    # Monitor critical system binaries with SHA-256
    /bin    NORMAL
    /sbin   NORMAL
    /usr/bin NORMAL
    /usr/sbin NORMAL

    # Monitor configuration files
    /etc    NORMAL

    # Exclude volatile directories
    !/var/log
    !/var/spool
    !/tmp
    !/proc
    !/sys

    # Initialize the database
    sudo aide --init

    # Rename the database
    sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

**Periodic checks:**

::

    # Run a check
    sudo aide --check

    # Report differences
    # Output includes: "added", "removed", "changed" files with before/after hashes

**Automation with systemd:**

::

    # /etc/systemd/system/aide-check.service
    [Unit]
    Description=AIDE integrity check

    [Service]
    Type=oneshot
    ExecStart=/usr/bin/aide --check
    ExecStartPost=/usr/bin/systemd-cat -t aide /usr/bin/logger -p authpriv.notice "AIDE check complete"

    [Install]
    WantedBy=multi-user.target

    # Timer: run daily
    # /etc/systemd/system/aide-check.timer
    [Unit]
    Description=Daily AIDE integrity check

    [Timer]
    OnCalendar=daily
    Persistent=true

    [Install]
    WantedBy=timers.target

**Tripwire (alternative to AIDE):**

Tripwire is the predecessor to AIDE and follows the same concept. AIDE is
more widely used today due to its simpler configuration and better
performance. However, Tripwire's commercial version (Tripwire Enterprise)
is still deployed in large financial institutions where centralized policy
management and compliance reporting are required.

**dm-verity / Integrity Measurement Architecture (IMA):**

For the highest-security deployments (e.g., Android Verified Boot,
ChromeOS, and certain DoD systems), **dm-verity** provides block-level
integrity verification using a Merkle hash tree stored in a separate
partition. **IMA** (Integrity Measurement Architecture) extends this to
measure and attest the integrity of every executed file. These are
beyond the scope of typical Linux administration but are essential in
**Trusted Computing** environments with TPM-based remote attestation.

9.7.3 Rootkit Detection: rkhunter and chkrootkit
=================================================

**Rootkits** are stealth malware that modify the kernel or system binaries
to hide the attacker's presence. Detection requires specialised tools.

**rkhunter (Rootkit Hunter):**

::

    sudo apt install rkhunter

    # Update signatures
    sudo rkhunter --update

    # Run a check
    sudo rkhunter --check --skip-keypress

    # Check specific categories
    sudo rkhunter --check --scan-knownbad-files --skip-keypress

rkhunter checks for:

- Known rootkit signatures (by name and hash).
- Suspicious kernel module loading.
- Hidden processes and open ports.
- Binary signature mismatches (compares against distribution database).
- Root-owned SUID/SGID files.
- SSH and LD_PRELOAD vulnerabilities.

**chkrootkit:**

::

    sudo apt install chkrootkit
    sudo chkrootkit

chkrootkit is more primitive and signature-based than rkhunter. It checks
for specific strings in memory, hidden file descriptors, and known rootkit
commands.

**2026 status of rootkit detection:**

Traditional signature-based rootkit detection (rkhunter, chkrootkit) is
increasingly obsolete. Modern kernel rootkits (e.g., Syslogk, Reptile,
Diamorphine) are easily modified to evade signatures. The 2026 standard for
rootkit detection is **eBPF-based runtime monitoring** (Falco, Tetragon)
which detects the *behaviour* of a rootkit (e.g., hiding processes via
hook modification) rather than its static signature.

Nevertheless, rkhunter and chkrootkit remain useful as a *complementary*
layer—particularly in legacy environments where eBPF is not available.

9.7.4 lynis: Security Auditing
===============================

**Lynis** is an open-source security auditing tool that scans a Linux system
for compliance with security best practices. It is the most comprehensive
automated auditing tool available for Linux.

::

    sudo apt install lynis
    sudo lynis audit system

Lynis checks:

- System boot and kernel configuration.
- User accounts, groups, and sudo settings.
- File system and disk encryption.
- Firewall and network configuration.
- Services and daemons.
- Authentication (PAM, SSH, NSS).
- Software updates and package management.
- Logging and auditing.
- Custom compliance profiles (CIS, PCI DSS, HIPAA).

**Example output:**

::

    [+] Firewall
      ----------------------------------------
      - iptables is active
      - nftables is active (not used, iptables is used)
      - Found 2 rules
      - Firewall rules loaded
      - Complete profile (not configured)

    [+] Hardening
      ----------------------------------------
      - 15 of 70 tests passed
      - 3 of 70 tests failed (see below)
      - 52 of 70 tests are suggestions

    Suggestions (3):
      * Install a PAM module for password strength testing
        https://cisofy.com/lynis/controls/ACCT-0037/
      * Install a file integrity tool like AIDE or Tripwire
        https://cisofy.com/lynis/controls/FINT-4350/

Lynis **hardening index** ranges from 0 (worst) to 100 (best). A freshly
installed Ubuntu 24.04 LTS typically scores around 65. After applying the
guidance in this chapter, a properly hardened system should score 85+.

**Automation in CI/CD:**

::

    # Run lynis in non-interactive mode and output JSON for dashboards
    sudo lynis audit system --quiet --report-file /tmp/lynis-report.json
    sudo lynis show details --json > /tmp/lynis-full.json

**Warning:** Lynis is an *advisory* tool. It generates suggestions, not
absolute requirements. Evaluate each suggestion against your specific threat
model and operational requirements.

9.7.5 Modern EDR: osquery and Falco
====================================

**osquery: SQL-based OS instrumentation**

Osquery exposes the operating system as a relational database that can be
queried with SQL. It is developed by Facebook/Meta and used by thousands of
organizations for security monitoring and incident response.

::

    sudo apt install osquery

    # Interactive query mode
    osqueryi

    # Query running processes
    osquery> SELECT pid, name, path, cmdline FROM processes WHERE name = 'sshd';

    # Query listening ports
    osquery> SELECT pid, port, protocol, address FROM listening_ports;

    # Query recently modified files (last 24 hours)
    osquery> SELECT path, mtime, size FROM file WHERE path LIKE '/etc/%'
             AND mtime > (SELECT unix_time - 86400 FROM time);

    # Query ARP cache (lateral movement detection)
    osquery> SELECT address, mac, interface FROM arp_cache;

**Osquery fleet management (2026):**

For enterprise deployment, **Fleet** (formerly Kolide) or
**osctrl** manages osquery agents across thousands of endpoints. Queries are
scheduled centrally, and results are streamed to a SIEM. Osquery is the
standard EDR data source for **CISA's Continuous Diagnostics and Mitigation
(CDM)** program in the US federal government.

**Falco: eBPF-based runtime security**

Falco (introduced in :ref:`Section 9.5 <sec9_5>`) monitors system calls via
eBPF and alerts on suspicious behaviour. It is the de-facto standard for
container runtime security in 2026.

**Key Falco rules for Linux hosts (not just containers):**

::

    # /etc/falco/falco_rules.local.yaml
    - rule: Unauthorized process execution in /tmp
      desc: A binary was executed from /tmp (potential malware staging)
      condition: >
        spawned_process and
        proc.exe startswith "/tmp"
      priority: CRITICAL
      output: >
        Executable in /tmp (user=%user.name command=%proc.cmdline
        pid=%proc.pid parent=%proc.pname)

    - rule: Sensitive file read by non-authorized process
      desc: Non-SSH process reading SSH private keys
      condition: >
        open_read and
        fd.name startswith "/root/.ssh/" and
        not proc.name in (sshd, ssh, tmux)
      priority: WARNING
      output: >
        SSH key read alert (user=%user.name command=%proc.cmdline
        file=%fd.name)

    - rule: Kernel module insertion
      desc: A kernel module was loaded (potential rootkit)
      condition: >
        evt.type=init_module
      priority: CRITICAL
      output: >
        Kernel module loaded (module=%evt.arg.name
        user=%user.name command=%proc.cmdline)

- **Alert outputs:** Falco can send alerts to syslog, stdout, Slack, PagerDuty,
  AWS SNS, GCP Pub/Sub, or any HTTP endpoint via webhook.
- **Falco Talons:** The open-source Falco Talon engine enables *automated
  response* — when a critical alert fires, Talon can kill the process,
  pause the container, or trigger a network block via CiliumNetworkPolicy.

9.7.6 Real-World EDR Stack (2026)
==================================

A production EDR stack deployed by a Fortune 500 company in 2026:

+------------------+---------------------------------------------------+
| Component        | Role                                              |
+==================+===================================================+
| Osquery (Fleet)  | Baseline visibility: processes, network           |
|                  | connections, file changes, logged in users.       |
+------------------+---------------------------------------------------+
| Falco (eBPF)     | Real-time syscall-level threat detection and      |
|                  | blocking (kernel mode rootkits, container         |
|                  | breakouts, crypto miners).                        |
+------------------+---------------------------------------------------+
| auditd           | User activity logging (who ran what command,      |
|                  | when, with what UID). Logs forwarded to SIEM.     |
+------------------+---------------------------------------------------+
| AIDE             | Hourly filesystem integrity check. Alerts on      |
|                  | changed binaries or unexpected new SUID files.    |
+------------------+---------------------------------------------------+
| Wazuh (SIEM/XDR) | Open-source SIEM that ingests osquery, Falco,     |
|                  | auditd, and AIDE data; correlates alerts and      |
|                  | generates incidents with MITRE ATT&CK mapping.    |
+------------------+---------------------------------------------------+
| SOAR (Shuffle    | Automated incident response: isolate compromised  |
| or Tines)        | host via nftables block, trigger PagerDuty, open  |
|                  | Jira ticket.                                      |
+------------------+---------------------------------------------------+

This stack detects:

- **Supply chain attack (e.g., tampered package):** AIDE detects the
  changed binary hash; Falco detects the anomalous behaviour; Wazuh
  correlates and alerts.
- **Lateral movement (SSH key theft):** Falco detection of SSH key read
  by non-SSH process; osquery cross-references failed SSH logins across
  the fleet.
- **Rootkit installation:** auditd captures ``insmod`` syscall; Falco
  detects hidden process via eBPF; the host is isolated by SOAR
  within 30 seconds.
EOF

# ──────────────────────────────────────────────────────────────
# File: 08_hardening_standards.rst
# ──────────────────────────────────────────────────────────────

cat << 'EOF' > ~/learn-linux/docs/source/chapter_09/08_hardening_standards.rst
.. _sec9_8:

###########################################################
9.8 Enterprise Hardening Standards
###########################################################

The difference between a hobbyist's hardened system and an enterprise
production system is **standards**. Enterprises must demonstrate compliance
to auditors, regulators, and customers. This section covers the three
pillars of Linux security standards in 2026: the **CIS Benchmarks**,
the **DISA STIGs**, and practical **systemd service sandboxing** that
implements many of these controls by default.

9.8.1 CIS Benchmarks — The Industry Baseline
=============================================

The **Center for Internet Security (CIS)** publishes benchmark documents
for every major operating system, cloud platform, and application. The CIS
Benchmark for Linux (specifically RHEL 9, Ubuntu 24.04 LTS, and SUSE Linux
Enterprise Server 15) is the most widely adopted security baseline in the
private sector.

**CIS Levels:**

- **Level 1:** Core practical security controls that do not significantly
  impact functionality. Suitable for all systems.
- **Level 2:** More restrictive controls suitable for high-security
  environments. May impact operational convenience.

**Key CIS controls for Linux (2026):**

We present the salient CIS recommendations organized by category. Each
item includes the CIS rule identifier.

**1. Filesystem Configuration (CIS 1.1)**

::

    # CIS 1.1.1.1: Separate /tmp partition (noexec, nosuid, nodev)
    # In /etc/fstab:
    UUID=... /tmp ext4 defaults,noexec,nosuid,nodev 0 2

    # CIS 1.1.4: Separate /var partition
    # CIS 1.1.5: Separate /var/log partition
    # CIS 1.1.11: Separate /home partition with nodev

    # CIS 1.1.2: Sticky bit on world-writable directories
    df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' \
        find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null
    # Fix: chmod +t on each listed directory

    # CIS 1.1.20: Disable unused filesystems (cramfs, freevxfs, jffs2, hfs, squashfs, udf)
    # /etc/modprobe.d/disable-filesystems.conf:
    install cramfs /bin/true
    install freevxfs /bin/true
    install jffs2 /bin/true
    install hfs /bin/true
    install hfsplus /bin/true
    install squashfs /bin/true
    install udf /bin/true

**2. SSH Configuration (CIS 5.2)**

::

    # /etc/ssh/sshd_config — CIS Level 1 & 2
    Protocol 2
    Port 22                  # Change to non-standard port for Level 2
    AddressFamily inet       # Level 2: IPv4 only
    PermitRootLogin no
    MaxAuthTries 3
    MaxSessions 10
    PubkeyAuthentication yes
    PasswordAuthentication no   # Level 2: key-only
    PermitEmptyPasswords no
    ChallengeResponseAuthentication no
    UsePAM yes
    X11Forwarding no
    PrintMotd no
    Banner /etc/issue.net
    AcceptEnv LANG LC_*
    Subsystem sftp /usr/lib/openssh/sftp-server -f AUTHPRIV -l INFO
    ClientAliveInterval 300
    ClientAliveCountMax 0
    LoginGraceTime 60
    LogLevel VERBOSE
    Macs hmac-sha2-512,hmac-sha2-256
    KexAlgorithms curve25519-sha256,diffie-hellman-group16-sha512
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com

**3. PAM and Password Policies (CIS 5.3)**

::

    # /etc/security/pwquality.conf
    minlen = 14
    minclass = 4
    maxrepeat = 3
    difok = 8
    enforce_for_root

    # /etc/login.defs
    PASS_MAX_DAYS   90
    PASS_MIN_DAYS   7
    PASS_WARN_AGE   7
    UMASK           027
    USERGROUPS_ENAB no

**4. Audit and Logging (CIS 4)**

::

    # Ensure auditd is installed and running
    systemctl enable --now auditd

    # CIS 4.1.1.1: Audit log storage size
    # /etc/audit/auditd.conf
    max_log_file = 100
    max_log_file_action = rotate
    num_logs = 5
    space_left_action = email
    action_mail_acct = root
    admin_space_left_action = halt

**5. Kernel Hardening via sysctl (CIS 3)**

::

    # /etc/sysctl.d/99-cis-hardening.conf

    # IPv4 hardening
    net.ipv4.ip_forward = 0
    net.ipv4.conf.all.send_redirects = 0
    net.ipv4.conf.default.send_redirects = 0
    net.ipv4.conf.all.accept_redirects = 0
    net.ipv4.conf.default.accept_redirects = 0
    net.ipv4.conf.all.secure_redirects = 0
    net.ipv4.conf.default.secure_redirects = 0
    net.ipv4.conf.all.rp_filter = 1
    net.ipv4.conf.default.rp_filter = 1
    net.ipv4.tcp_syncookies = 1

    # IPv6 hardening
    net.ipv6.conf.all.accept_redirects = 0
    net.ipv6.conf.default.accept_redirects = 0

    # Kernel hardening
    kernel.randomize_va_space = 2                     # ASLR (full)
    kernel.kptr_restrict = 2                          # Restrict /proc/kallsyms
    kernel.dmesg_restrict = 1                         # Restrict dmesg to root
    kernel.unprivileged_bpf_disabled = 1              # Block unpriv eBPF
    net.core.bpf_jit_harden = 2                       # Hardened eBPF JIT
    kernel.yama.ptrace_scope = 2                      # Only root can ptrace
    fs.protected_hardlinks = 1                        # Hardlink restrictions
    fs.protected_symlinks = 1                         # Symlink restrictions
    fs.suid_dumpable = 0                              # No suid core dumps

**Automated CIS assessment:**

The industry-standard tool for CIS assessment is **OpenSCAP**:

::

    # Install
    sudo apt install libopenscap8 scap-security-guide
    # or: sudo dnf install openscap-scanner scap-security-guide

    # Scan against CIS benchmark for RHEL 9
    sudo oscap xccdf eval \
        --profile cis \
        --results /tmp/oscap-results.xml \
        --report /tmp/oscap-report.html \
        /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

    # View the HTML report in a browser
    firefox /tmp/oscap-report.html

OpenSCAP generates a detailed pass/fail report with remediation scripts.
It is the standard tool for DoD STIG validation (discussed next).

9.8.2 DISA STIGs — US Military & Government Standard
=====================================================

The **Defense Information Systems Agency (DISA)** publishes **Security
Technical Implementation Guides (STIGs)** —the mandatory configuration
standards for all US Department of Defense (DoD) information systems.
STIGs are significantly more restrictive than CIS Level 2.

**Key differences between CIS and STIGs:**

+----------------------+--------------------------------+--------------------------------+
| Criterion            | CIS Benchmark                  | DISA STIG                      |
+======================+================================+================================+
| Authority            | Industry consensus (voluntary) | DoD directive (mandatory)      |
+----------------------+--------------------------------+--------------------------------+
| Scope                | General-purpose                | US military, federal agencies  |
+----------------------+--------------------------------+--------------------------------+
| Enforcement          | Recommended (auditable)        | Required (enforced by          |
|                      |                                | vulnerability scans)           |
+----------------------+--------------------------------+--------------------------------+
| MAC requirement      | Recommended                    | **Required** (SELinux          |
|                      |                                | enforcing, per STIG ID         |
|                      |                                | RHEL-09-210020)                |
+----------------------+--------------------------------+--------------------------------+
| Multi-factor auth    | Level 2 recommends             | **Required** (for privileged   |
|                      |                                | accounts, per STIG ID          |
|                      |                                | RHEL-09-610010)                |
+----------------------+--------------------------------+--------------------------------+
| Audit retention      | 6 months (recommended)         | 1 year (minimum, per DoD       |
|                      |                                | Instruction 8500.01)           |
+----------------------+--------------------------------+--------------------------------+
| Updates/patching     | Latest stable                  | Within 24 hours for critical   |
|                      |                                | (per CTO/CISO directive)       |
+----------------------+--------------------------------+--------------------------------+

**Applying a STIG to RHEL 9:**

::

    # Install the DISA STIG content for RHEL 9
    sudo dnf install scap-security-guide openscap-scanner

    # List available STIG profiles
    sudo oscap info /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml \
        | grep stig

    # Apply the STIG profile (automatic remediation)
    sudo oscap xccdf eval --remediate \
        --profile stig \
        --results /tmp/stig-results.xml \
        /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

    # The --remediate flag applies all automated fixes.
    # Manually review items that could not be auto-remediated.

**Critical STIG rules for RHEL 9:**

+----------------------+---------------------------------------------------+
| STIG ID              | Requirement                                       |
+======================+===================================================+
| RHEL-09-210020       | SELinux must be in enforcing mode.                |
+----------------------+---------------------------------------------------+
| RHEL-09-210040       | The system must use a Linux Security Module       |
|                      | (SELinux or AppArmor).                            |
+----------------------+---------------------------------------------------+
| RHEL-09-231010       | A file integrity tool (AIDE) must be installed.   |
+----------------------+---------------------------------------------------+
| RHEL-09-251010       | The system must be configured with a host-based   |
|                      | firewall (nftables).                              |
+----------------------+---------------------------------------------------+
| RHEL-09-252010       | The system must use FIPS 140-3 validated          |
|                      | cryptographic modules.                            |
+----------------------+---------------------------------------------------+
| RHEL-09-255020       | SSH must implement FIPS 140-3 compliant ciphers.  |
+----------------------+---------------------------------------------------+
| RHEL-09-271015       | The audit system must alert on disk space         |
|                      | thresholds.                                       |
+----------------------+---------------------------------------------------+
| RHEL-09-411030       | Duplicate user IDs (UIDs) must not exist.         |
+----------------------+---------------------------------------------------+
| RHEL-09-411035       | The root account must be the only account with    |
|                      | UID 0.                                            |
+----------------------+---------------------------------------------------+
| RHEL-09-611090       | System accounts must not be mapped to /bin/bash   |
|                      | shell.                                            |
+----------------------+---------------------------------------------------+

**STIG Viewer:**

DISA provides the **STIG Viewer** application for browsing and tracking
STIG compliance. In 2026, the web-based eMASS (Enterprise Mission Assurance
Support Service) is the authoritative platform for waivers and POA&Ms
(Plans of Action and Milestones). Every federal contractor with Linux
systems must upload STIG check results to eMASS.

**FBI and Law Enforcement:**

The FBI's **CJIS (Criminal Justice Information Services)** Security Policy
references DISA STIGs for any Linux system handling criminal justice data.
Similarly, the **Drug Enforcement Administration (DEA)** and
**Transportation Security Administration (TSA)** require STIG compliance
for Linux servers in regulated environments.

9.8.3 systemd Service Sandboxing
=================================

In 2026, the most practical and enforceable hardening technique for Linux
services is **systemd unit sandboxing**. Rather than relying solely on
AppArmor or SELinux (which many organizations struggle to maintain),
``systemd`` provides built-in security directives that restrict what a
service can see, write to, and execute — regardless of the LSM in use.

**Essential sandboxing directives for a production service:**

::

    [Service]
    # Process isolation
    ProtectSystem=strict
    ProtectHome=yes
    ProtectKernelTunables=yes
    ProtectControlGroups=yes
    ProtectKernelModules=yes
    ProtectKernelLogs=yes
    ProtectHostname=yes
    ProtectClock=yes
    ProtectProc=invisible

    # Filesystem restrictions
    ReadWritePaths=/var/lib/myapp /var/log/myapp
    ReadOnlyPaths=/usr /etc
    InaccessiblePaths=/home /root /media

    # Network restrictions
    PrivateNetwork=no       # Set to yes for services that don't need network

    # Capability dropping
    CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_SETUID CAP_SETGIP

    # System call filtering
    SystemCallFilter=@system-service
    SystemCallArchitectures=native

    # Memory and other restrictions
    MemoryDenyWriteExecute=yes
    NoNewPrivileges=yes
    RestrictRealtime=yes
    RestrictSUIDSGID=yes
    RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK

    # Namespace isolation
    PrivateTmp=yes
    PrivateDevices=yes
    MountFlags=private

**Directive reference:**

+---------------------------+---------------------------------------------------+
| Directive                 | Effect                                            |
+===========================+===================================================+
| ``ProtectSystem=strict``  | Makes ``/usr`` and ``/etc`` read-only; only       |
|                           | ``/var``, ``/run``, ``/tmp``, and paths in        |
|                           | ``ReadWritePaths`` are writable.                  |
+---------------------------+---------------------------------------------------+
| ``ProtectHome=yes``       | Makes ``/home``, ``/root``, and ``/run/user``     |
|                           | inaccessible to the service.                      |
+---------------------------+---------------------------------------------------+
| ``PrivateTmp=yes``        | Sets up a private ``/tmp`` and ``/var/tmp`` with  |
|                           | a mount namespace — prevents other processes      |
|                           | from seeing the service's temporary files.        |
+---------------------------+---------------------------------------------------+
| ``ProtectKernelModules=yes`` | Blocks ``insmod``, ``modprobe``, and related   |
|                           | syscalls — prevents kernel rootkit installation.  |
+---------------------------+---------------------------------------------------+
| ``NoNewPrivileges=yes``   | Prevents the process and its children from        |
|                           | gaining new privileges via ``setuid``, ``setcap``,|
|                           | or ``ptrace``.                                   |
+---------------------------+---------------------------------------------------+
| ``MemoryDenyWriteExecute=yes`` | Prevents ``mmap()`` with both ``PROT_WRITE`` |
|                           | and ``PROT_EXEC`` — mitigates code injection.    |
+---------------------------+---------------------------------------------------+
| ``SystemCallFilter=@system-service`` | Only allows a pre-approved set of       |
|                           | system calls (the ``@system-service`` group).     |
+---------------------------+---------------------------------------------------+
| ``RestrictAddressFamilies=`` | Limits which socket address families the      |
|                           | service can use. Block ``AF_PACKET`` to prevent   |
|                           | raw packet injection.                             |
+---------------------------+---------------------------------------------------+

**Example: A hardened PostgreSQL service unit**

::

    # /etc/systemd/system/postgresql.service.d/hardening.conf
    [Service]
    ProtectSystem=full
    ProtectHome=yes
    PrivateTmp=yes
    NoNewPrivileges=yes
    MemoryDenyWriteExecute=yes
    RestrictRealtime=yes
    RestrictSUIDSGID=yes
    SystemCallFilter=@system-service
    CapabilityBoundingSet=
    PrivateDevices=yes
    ProtectKernelModules=yes
    ProtectKernelTunables=yes
    ProtectControlGroups=yes

After adding the drop-in, reload and verify:

::

    sudo systemctl daemon-reload
    sudo systemctl restart postgresql
    sudo systemctl show postgresql -p ProtectSystem -p NoNewPrivileges

**Auditing sandbox effectiveness:**

Use ``systemd-analyze security`` to get a numeric score (0 = exposed,
10 = fully hardened) for each service:

::

    sudo systemd-analyze security postgresql.service
    # Output example:
    # → Overall exposure level for postgresql.service: 3.1 OUTSTANDING :)

The tool assigns an exposure score based on which security directives are
set. A score below 5 is considered good; below 3 is excellent.

9.8.4 Container Hardening Standards
====================================

Containers share the host kernel, making isolation paramount. In 2026, the
**CIS Docker Benchmark** and **NSA/CISA Kubernetes Hardening Guide** are
the authoritative standards.

**Key container hardening controls:**

::

    # Docker daemon configuration (/etc/docker/daemon.json):
    {
      "icc": false,
      "iptables": true,
      "log-driver": "json-file",
      "log-opts": {"max-size": "10m", "max-file": "3"},
      "no-new-privileges": true,
      "userns-remap": "default",
      "live-restore": true,
      "userland-proxy": false,
      "seccomp-profile": "/etc/docker/seccomp-default.json",
      "selinux-enabled": true
    }

**Podman (default for RHEL 9+):**

Podman runs rootless by default and supports SELinux labels natively.
Key security features:

::

    # Run a container rootless (no root in container, no root on host)
    podman run --userns=keep-id --user=1000:1000 nginx

    # Drop all capabilities
    podman run --cap-drop=ALL nginx

    # Read-only root filesystem
    podman run --read-only --tmpfs /tmp nginx

**Kubernetes Pod Security Standards (PSS):**

In Kubernetes 1.30+, the **Pod Security Admission** controller enforces
three levels:

+---------------------------+--------------------------------------------+
| PSS Level                 | Restrictions                               |
+===========================+============================================+
| **Privileged**            | No restrictions (e.g., infrastructure      |
|                           | pods).                                     |
+---------------------------+--------------------------------------------+
| **Baseline**              | Prevents known privilege escalations.      |
|                           | Disallows ``hostPID``, ``hostNetwork``,    |
|                           | ``privileged`` containers.                 |
+---------------------------+--------------------------------------------+
| **Restricted**            | Strongest: drops all capabilities,         |
|                           | requires read-only root filesystem,        |
|                           | ``seccomp=RuntimeDefault``, no             |
|                           | ``allowPrivilegeEscalation``.              |
+---------------------------+--------------------------------------------+

**Applying Restricted PSS in a namespace:**

::

    kubectl label namespace production \
        pod-security.kubernetes.io/enforce=restricted

9.8.5 Bringing It All Together: A Hardened Baseline
====================================================

The following checklist represents a **CIS Level 2 + DISA STIG-aligned**
hardened Linux system in 2026:

.. list-table:: Enterprise Hardening Checklist
   :header-rows: 1

   * - Category
     - Control
     - Tool / Configuration
   * - **Authentication**
     - FIDO2 + TOTP MFA for privileged access
     - ``pam_u2f.so`` + ``pam_google_authenticator.so``
   * - **Access Control**
     - SELinux enforcing (targeted or MLS)
     - ``/etc/selinux/config``: ``SELINUX=enforcing``
   * - **Firewall**
     - Default-drop nftables, eBPF/XDP for DDoS
     - ``nftables`` + Cilium/Tetragon
   * - **Encryption**
     - LUKS2 with Argon2, TLS 1.3 with PQC hybrid
     - ``cryptsetup``, OpenSSL 3.5+
   * - **Audit**
     - Full system call audit, remote forwarding
     - ``auditd`` + Wazuh/Elastic SIEM
   * - **Integrity**
     - AIDE daily checks, RPM package verification
     - ``aide``, ``rpm -Va``
   * - **Runtime Detection**
     - eBPF-based syscall monitoring
     - Falco / Tetragon
   * - **Service Isolation**
     - systemd sandboxing directives
     - ``ProtectSystem=strict``, ``NoNewPrivileges=yes``
   * - **Kernel Hardening**
     - 40+ sysctl mitigations
     - ``/etc/sysctl.d/99-hardening.conf``
   * - **Patch Management**
     - Automatic security updates
     - ``unattended-upgrades`` (Debian) /
       ``dnf-automatic`` (RHEL)
   * - **Log Retention**
     - 1 year minimum, TLS-encrypted transport
     - ``rsyslog`` with TLS to central log server
   * - **Supply Chain**
     - Image signing, provenance attestation
     - ``cosign``, ``in-toto``, ``trivy`` scanning

9.8.6 The Path Forward: Continuous Compliance
==============================================

Hardening is not a one-time configuration. In 2026, leading organizations
implement **Continuous Compliance** — automated, policy-as-code enforcement
of security baselines.

- **Tool:** ``Chef InSpec`` or ``OpenSCAP`` running in CI/CD.
- **Platform:** ``StackRox`` (now part of Red Hat Advanced Cluster Security)
  for Kubernetes.
- **Framework:** ``NIST SP 800-53`` controls mapped to CIS/STIG via
  ``OSCAL`` (Open Security Controls Assessment Language).

**Example: InSpec profile snippet**

::

    # Verify SELinux is enforcing
    control 'selinux-01' do
      impact 1.0
      title 'SELinux must be in enforcing mode'
      desc 'The system must use SELinux in enforcing mode per DISA STIG RHEL-09-210020'
      describe command('getenforce') do
        its('stdout.strip') { should eq 'Enforcing' }
      end
    end

    # Verify SSH protocol version
    control 'ssh-01' do
      impact 0.7
      title 'SSH Protocol must be version 2'
      describe sshd_config do
        its('Protocol') { should cmp 2 }
      end
    end

This profile can be executed against every server in a fleet via
``inspec exec``, automated in Ansible or Terraform pipelines, and reported
to a compliance dashboard.

---

**Closing Remark for Chapter 9:**

Security is a journey, not a destination. The tools and techniques in this
chapter represent the consensus of the global security community in 2026.
But the adversary evolves constantly. Today's best practice is tomorrow's
legacy vulnerability. The mindset you have developed here—questioning
assumptions, layering defenses, measuring and auditing continuously—is
the skill that will serve you long after specific tools are superseded.

In Chapter 10, we will apply everything you have learned to real-world
deployment scenarios: building a production-ready Linux web infrastructure
from the ground up, with every layer hardened according to these principles.
EOF

echo "---"
echo "Chapter 9 generation complete."
echo "Files created:"
ls -la ~/learn-linux/docs/source/chapter_09/
+-------------------------+-----------------------------+-----------------------------+
| Feature                 | LUKS1                       | LUKS2                       |
+=========================+=============================+=============================+
| Key derivation function | PBKDF2 (iterations)         | Argon2 (memory-hard,        |
|                         |                             | resistant to ASIC/GPU       |
|                         |                             | attacks)                    |
+-------------------------+-----------------------------+-----------------------------+
| Integrity protection    | None (plaintext/ciphertext) | AEAD modes (``--integrity`` |
|                         |                             | with dm-crypt)              |
+-------------------------+-----------------------------+-----------------------------+
| Backup headers          | Single header (fragile)     | Multiple header slots +     |
|                         |                             | JSON metadata area for      |
|                         |                             | resilience                  |
+-------------------------+-----------------------------+-----------------------------+
| Token-based unlocking   | Limited (``--key-slot``)    | Native token support        |
|                         |                             | (``systemd-tpm2``, PKCS#11) |
+-------------------------+-----------------------------+-----------------------------+
| Re-encryption           | Not supported offline       | ``cryptsetup reencrypt``    |
|                         |                             | (online re-encryption)      |
+-------------------------+-----------------------------+-----------------------------+

**Creating a LUKS2 encrypted volume:**

::

    # 1. Partition the disk (assuming /dev/sdb)
    sudo parted /dev/sdb mklabel gpt
    sudo parted /dev/sdb mkpart primary 0% 100%
    sudo parted /dev/sdb set 1 crypt LUKS

    # 2. Create LUKS2 container with Argon2
    sudo cryptsetup luksFormat --type luks2 --cipher aes-xts-plain64 \
        --key-size 512 --pbkdf argon2id --iter-time 5000 /dev/sdb1

    # 3. Open the container
    sudo cryptsetup open /dev/sdb1 secret

    # 4. Create a filesystem
    sudo mkfs.ext4 /dev/mapper/secret

    # 5. Mount
    sudo mount /dev/mapper/secret /mnt/secret

    # 6. Automate unlock at boot via /etc/crypttab and initramfs
    echo "secret UUID=$(sudo blkid -s UUID -o value /dev/sdb1) none luks" \
        | sudo tee -a /etc/crypttab
    sudo update-initramfs -u

**TPM2-based automatic unlocking (2026 standard):**

On systems with a TPM 2.0 chip (virtually every server and laptop since
2020), you can bind LUKS2 to the TPM so the disk unlocks automatically
at boot—but *only* if the boot chain is unmodified (measured boot via
TPM PCRs).

::

    # Add a LUKS2 token bound to TPM PCRs 0, 2, 7
    sudo systemd-cryptenroll --tpm2-device=auto \
        --tpm2-pcrs=0+2+7 /dev/sdb1

Now the disk unlocks automatically on that specific machine. If someone
removes the drive and attaches it to a different system, the TPM will not
release the key—the PCR values will not match.

**FIDO2-based unlocking:**

YubiKeys and other FIDO2 tokens can serve as LUKS2 unlock keys:

::

    sudo systemd-cryptenroll --fido2-device=auto /dev/sdb1

At boot, ``systemd-cryptsetup`` prompts the user to touch the FIDO2 token.

9.6.2 GPG (GNU Privacy Guard)
==============================

GPG implements the OpenPGP standard (RFC 4880) for encryption, signing, and
key management. In 2026, it remains the tool of choice for file-level
encryption, email security, and package signing verification (e.g., Debian's
``apt-key``, though ``apt-key`` is deprecated in favour of signed-by).

**Key generation (2026 best practice — ECC, not RSA):**

::

    gpg --full-generate-key
    # Choose: (9) ECC (sign and encrypt) -> Curve 25519
    # Expiry: 2 years (rotate keys regularly)
    # Real name, email, passphrase (use a strong passphrase)

**ECC is mandatory in 2026.** RSA-4096 is still secure but less efficient.
Ed25519 for signing and Curve25519 for encryption are the default choices
and are FIPS 186-5 approved.

**Encrypting a file for a recipient:**

::

    gpg --encrypt --recipient alice@example.com document.pdf
    # Produces document.pdf.gpg

**Signing a file:**

::

    gpg --detach-sign --armor document.pdf
    # Produces document.pdf.asc (detached ASCII-armored signature)

**Verifying a package (Debian repository style):**

::

    # The repository Release file is signed by the Debian GPG key
    gpg --verify Release.gpg Release

**Key Servers and Web of Trust:**

In 2026, the traditional SKS keyserver pool has been mostly replaced by
**keys.openpgp.org**, which acts as a verified key directory. The Web of
Trust (WoT) model is still used by Debian developers and the Fedora
project, but most enterprises use centralized key management via
**OpenPGP CA** or an internal key server.

9.6.3 OpenSSL: TLS, Certificate Management, and Hybrid PQ
==========================================================

OpenSSL is the library that powers TLS on virtually every Linux server.
In 2026, OpenSSL 3.5+ is the standard, with support for TLS 1.3 (mandatory),
the Provider API (for pluggable cryptographic backends), and experimental
post-quantum key exchange.

**Generating a modern TLS certificate (EC P-384):**

::

    # Generate private key (ECDSA P-384)
    openssl ecparam -name secp384r1 -genkey -out server.key

    # Generate CSR
    openssl req -new -key server.key -out server.csr \
        -subj "/C=US/ST=Virginia/L=Reston/O=Acme Corp/CN=api.acme.com"

    # Self-sign (for internal/testing; production uses a CA)
    openssl x509 -req -days 365 -in server.csr \
        -signkey server.key -out server.crt

**Modern TLS 1.3 configuration for NGINX:**

::

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256;
    ssl_prefer_server_ciphers off;

    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;

    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 1.1.1.1 8.8.8.8 valid=300s;
    resolver_timeout 5s;

    # Modern curves (include X25519 for forward secrecy)
    ssl_ecdh_curve X25519:secp384r1:secp521r1;

**Post-quantum hybrid TLS (OpenSSL 3.5+, 2026):**

NIST has standardized ML-KEM (FIPS 203, formerly Kyber) and ML-DSA
(FIPS 204, formerly Dilithium). OpenSSL 3.5 supports hybrid key exchange
using the ``groups`` option:

::

    # Server-side: enable Kyber + ECDHE hybrid
    ssl_groups mlkem768x25519:kyber768:prime256v1

    # The server and client negotiate the strongest mutually supported group.
    # A client with PQ support gets hybrid Kyber+X25519;
    # a legacy client falls back to X25519 or P-256.

To generate a hybrid X.509 certificate with both an ECDSA and a Dilithium
key, you need OpenSSL 3.5 compiled with the ``oqs-provider`` (OpenQuantumSafe):

::

    # Hybrid certificate request (ECDSA + ML-DSA)
    openssl req -newkey p384 -newkey dilithium3 \
        -nodes -keyout server.pem -out server.csr

You can verify the post-quantum signature algorithm in the certificate:
::

    openssl x509 -in server.crt -text -noout | grep "Signature Algorithm"
    # Output: ecdsa-with-SHA384 + dilithium3

**Real-world status in 2026:**

- **Google:** Chrome and Google Cloud support X25519Kyber768 since 2023.
- **Cloudflare:** All edge servers offer Kyber+ECDHE hybrid.
- **Amazon:** AWS Certificate Manager supports hybrid PQ certificates.
- **NSA:** CNSA 2.0 mandates ML-KEM and ML-DSA by 2028 for National
  Security Systems.
- **CISA:** Urges all federal agencies to inventory and begin migration.

9.6.4 Let's Encrypt and certbot
================================

Let's Encrypt is the world's largest certificate authority, providing free,
automated TLS certificates via the ACME protocol. In 2026, it has issued
over 3 billion certificates.

**Automated certificate issuance with certbot:**

::

    # Install certbot with the nginx plugin
    sudo apt install certbot python3-certbot-nginx

    # Obtain and install certificate
    sudo certbot --nginx -d api.acme.com -d www.acme.com

    # Verify auto-renewal (systemd timer)
    sudo systemctl status certbot.timer

**ACME DNS-01 challenge (for wildcard certificates):**

::

    # Requires a DNS API plugin for your provider (Cloudflare, AWS Route 53, etc.)
    sudo certbot certonly --dns-cloudflare \
        --dns-cloudflare-credentials /etc/cloudflare.ini \
        -d '*.acme.com'

**Post-quantum ACME (2026):**

Let's Encrypt announced in 2025 that all new certificates use hybrid
ML-DSA + ECDSA signatures by default. Your certbot client must be version
2.12+ to support PQ ACME:

::

    certbot --preferred-chain "ISRG Root PQ X1" -d example.com

9.6.5 SSH Key Management and Hardening
=======================================

**Generating modern SSH keys (2026):**

The days of RSA-2048 are ending. Use Ed25519:

::

    ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519

The ``-a 100`` sets 100 KDF rounds (default is 16) for brute-force
resistance if the private key is stolen.

**Post-quantum SSH:**

OpenSSH 9.9+ (released 2025) includes the hybrid key exchange
``mlkem768x25519-sha256``:

::

    # In ~/.ssh/config or /etc/ssh/sshd_config:
    Host *
        HostKeyAlgorithms +ssh-ed25519
        KexAlgorithms +mlkem768x25519-sha256
        PubkeyAcceptedAlgorithms +ssh-ed25519

**SSH CA (Certificate Authority) authentication:**

Instead of distributing hundreds of public keys to servers, use an SSH CA:

::

    # On the CA server:
    ssh-keygen -t ed25519 -f /etc/ssh/user_ca_key

    # Sign the user's public key:
    ssh-keygen -s /etc/ssh/user_ca_key -I alice@acme.com \
        -n alice -V +52w ~alice/.ssh/id_ed25519.pub

    # On the SSH server, in /etc/ssh/sshd_config:
    TrustedUserCAKeys /etc/ssh/user_ca_key.pub

Now any server with that CA public key trusts all certificates signed by
the CA. Revocation is handled by a ``revoked_keys`` file or CRL.

9.6.6 Hardware Security Modules (HSM) and PKCS#11
==================================================

In enterprise environments, private keys should never reside in filesystem
files. **Hardware Security Modules (HSMs)** —including TPMs, YubiKeys with
PIV, and dedicated network HSMs—protect keys against extraction.

**Using a YubiKey PIV for SSH/TLS:**

::

    # Generate key on the YubiKey (never leaves hardware)
    ykman piv generate-key --algorithm ECCP384 9a pubkey.pem

    # Generate CSR
    openssl req -new -key pkcs11:token=YubiKey -subj "/CN=example.com"

    # SSH via PKCS#11 provider
    ssh -I /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so server.example.com

9.6.7 Cryptographic Erasure
============================

When decommissioning a LUKS2-encrypted drive, simply destroying the LUKS
header renders all data permanently inaccessible—no need for multi-pass
overwrites:

::

    # Remove LUKS2 header (irreversible)
    sudo cryptsetup erase /dev/sdb1

    # Or wipe the header area explicitly
    sudo dd if=/dev/urandom of=/dev/sdb1 bs=1M count=16

This is the fastest and most secure method of data sanitization for
encrypted drives. For SSDs, also issue the ATA SANITIZE command:
::

    sudo hdparm --user-master u --security-set-pass p /dev/sdb
    sudo hdparm --user-master u --security-erase-enhanced p /dev/sdb
