.. _sec9_1:

#############################################
The Security Mindset & the 2026 Landscape
#############################################

Security is not a checklist; it is a *discipline*—a way of reasoning about
systems under adversarial conditions. Before we configure a single PAM module
or SELinux boolean, we must establish the mental models that separate a
genuinely hardened system from one that merely *appears* hardened.

The Principle of Least Privilege
=======================================

The Principle of Least Privilege (PoLP) states that every entity—user,
process, or network peer—should be granted only the permissions necessary to
perform its function and *no more*. This is the single most impactful
security control in existence.

**In practice on Linux:**

- **Users and groups:** Never run daily operations as ``root``. Use ``sudo``
  with granular ``/etc/sudoers`` rules that limit commands per user.
- **Process capabilities:** Use ``systemd``'s ``CapabilityBoundingSet`` and
  ``AmbientCapabilities`` to drop privileges after binding to a port.
- **Filesystem access:** Set filesystem ACLs with ``setfacl`` rather than
  granting world-read on directories.
- **Network:** Bind services only to required addresses (never ``0.0.0.0``
  unless necessary) and use ``iptables``/``nftables`` default-drop policies.

The 2026 extension of PoLP is **Just-In-Time (JIT) Privilege Elevation**.
Static sudo rules are being replaced by ephemeral credentials issued by
tools such as ``Teleport``, ``Boundary``, and ``OpenBao`` (the community
fork of HashiCorp Vault). A sysadmin authenticates with their hardware
security key, is granted a 15-minute sudo window, and the credential expires
automatically.

Defense in Depth (DiD)
=============================

Defense in Depth acknowledges that any single security layer will eventually
fail. A hardened Linux system therefore stacks multiple independent controls
so that a failure in one layer is caught by another.

**The 2026 Linux DiD Stack (from outer to inner):**

1. **Network edge:** nftables / eBPF-XDP firewall + DDoS scrubbing.
2. **Transport:** TLS 1.3 with certificate pinning or mTLS.
3. **Authentication:** FIDO2/WebAuthn + time-based OTP + PAM.
4. **Authorization:** SELinux or AppArmor mandatory policies.
5. **Process isolation:** ``systemd`` service sandboxing (``ProtectSystem``,
   ``PrivateTmp``, ``NoNewPrivileges``).
6. **Kernel hardening:** ``sysctl`` mitigations (KASLR, ``kernel.kptr_restrict``,
   ``kernel.dmesg_restrict``).
7. **Audit & detection:** ``auditd`` + Falco (eBPF runtime security).
8. **Filesystem integrity:** AIDE / dm-verity.
9. **Backup & recovery:** Immutable snapshots with ``restic`` or ``borg``.

A real-world example: **SWIFT banking transactions** in 2026. The SWIFT
Customer Security Controls Framework (CSCF) mandates DiD with at least three
independent layers. A Linux-based SWIFT interface runs under SELinux (MLS),
with auditd logging every file open, and a dedicated network namespace
isolated by eBPF policies. If an attacker compromises the application, SELinux
prevents reading the transaction database; if they escape SELinux, the audit
trail catches their lateral movement.

Attack Surface Reduction
===============================

Attack surface is the sum of all reachable, exploitable code paths in a
system. Reduction means: **if you don't need it, remove it.**

**Practical steps:**

- Remove unnecessary packages: ``apt purge`` or ``dnf remove`` anything not
  required for the workload.
- Disable unused kernel modules: maintain an ``/etc/modprobe.d/blacklist.conf``
  with modules like ``bluetooth``, ``rfkill``, ``pcspkr``, and ``uvcvideo``
  blacklisted on servers.
- Mask unnecessary ``systemd`` sockets: ``systemctl mask cups.socket`` on a
  headless server.
- Minimize listening ports: ``ss -tlnp`` should show *only* expected services.

**Container-focused attack surface:** In 2026, most new Linux deployments
use containers (Docker, Podman). Use **distroless** base images (Google's
``distroless`` images or ``chainguard`` images) that contain only the
application binary and its runtime dependencies—no shell, no package manager,
no compilers. This reduces the CVE surface by 80-90% compared to a standard
Ubuntu or RHEL base image.

Threat Modeling for Linux Systems
=========================================

A threat model answers four questions:

1. **What are we protecting?** (Data, credentials, infrastructure)
2. **Who are the adversaries?** (Script kiddies, organized crime, nation-states)
3. **What can they do?** (Network access, physical access, insider threat)
4. **What are the consequences of a breach?** (Data exfiltration, ransomware,
   reputational damage)

For a Linux system administrator, the **STRIDE** framework (Spoofing,
Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation
of Privilege) is the most practical tool. Map each STRIDE category to specific
Linux controls:

+-------------------------+--------------------------------------------+
| STRIDE Category         | Linux Mitigation                           |
+=========================+============================================+
| Spoofing                | FIDO2 authentication, SSH host keys        |
+-------------------------+--------------------------------------------+
| Tampering              | dm-verity, AIDE, RPM-GPG package signing   |
+-------------------------+--------------------------------------------+
| Repudiation            | auditd + remote log forwarding (SIEM)      |
+-------------------------+--------------------------------------------+
| Information Disclosure | LUKS2 encryption, SELinux confidentiality  |
+-------------------------+--------------------------------------------+
| Denial of Service       | ``systemd`` resource limits, ``cgroups``   |
+-------------------------+--------------------------------------------+
| Elevation of Privilege  | SELinux/AppArmor, ``NoNewPrivileges``      |
+-------------------------+--------------------------------------------+

Zero Trust Architecture (ZTA) — 2026 Standard
====================================================

The traditional perimeter-based security model ("trust the internal network")
is dead. **Zero Trust** operates on a single axiom: *never trust, always
verify.* Every access request—whether from a laptop in the office or a server
in the same rack—must be authenticated, authorized, and continuously
validated.

**NIST SP 800-207** defines the pillars of Zero Trust:

- **All data sources and computing services are resources.** A Linux server
  is a resource; so is a database, an API endpoint, and a configuration file.
- **Communication is secured regardless of network location.** mTLS is the
  norm, not the exception.
- **Access to resources is granted per-session.** No permanent SSH keys.
- **Access is dynamic and assessed continuously.** eBPF-based tools (Cilium,
  Falco) monitor process behaviour and revoke access if anomalous activity
  is detected.

**Implementation in Linux (2026):**

The gold-standard Zero Trust Linux deployment uses **Tetragon** (Cilium's
runtime security engine) for eBPF-based policy enforcement at the kernel
level, **SPIFFE/SPIRE** for workload identity (X.509 SVIDs), and
**Teleport** for SSH/Kubernetes access with JIT approval. A compromised
workload that attempts to read ``/etc/shadow`` without a valid SPIFFE
identity is immediately blocked by the eBPF policy and flagged to the
Security Operations Center (SOC).

Software Supply Chain Security (SLSA)
============================================

The 2020 SolarWinds breach and the 2024 XZ Utils backdoor (CVE-2024-3094)
demonstrated that the *supply chain* is the most attractive attack vector
for nation-states. In response, the industry has converged on the
**Supply-chain Levels for Software Artifacts (SLSA)** framework.

**SLSA Levels for Linux Administrators:**

- **SLSA 1:** Build scripts are documented (e.g., a Containerfile that uses
  pinned base image digests, not tags).
- **SLSA 2:** Builds are hermetic and run on a trusted build platform (GitHub
  Actions, GitLab CI, or Tekton) with provenance attestation.
- **SLSA 3:** The build platform generates a non-forgeable provenance
  statement (in-toto attestation) that includes all source and dependency
  references.
- **SLSA 4:** Two-person review of all source changes; build platform is
  hardened and isolated.

**In practice on Linux:**

- Use ``cosign`` to sign container images and OCI artifacts.
- Store signatures in a transparency log (Rekor or Sigstore).
- Use ``grype`` or ``trivy`` to scan images for known CVEs before deployment.
- Pin packages to specific versions in ``/etc/apt/sources.list`` or
  ``/etc/yum.repos.d/`` and verify GPG signatures:
  ::

      apt install --allow-unauthenticated  # Never do this

- For RPM-based systems: ``rpm -K package.rpm`` validates the GPG signature
  against the imported RPM-GPG key.

Preparing for Post-Quantum Cryptography (PQC)
=====================================================

By 2026, the U.S. National Institute of Standards and Technology (NIST) has
finalized its post-quantum cryptographic standards (FIPS 203, 204, 205).
The threat is **Harvest Now, Decrypt Later (HNDL)** —adversaries are
collecting encrypted traffic today, knowing that a future quantum computer
will break RSA-2048 and ECDSA-256.

**What Linux administrators must do now:**

- **Hybrid certificates:** Use X.509 certificates that bundle a traditional
  ECDSA key with a CRYSTALS-Kyber (ML-KEM) or CRYSTALS-Dilithium (ML-DSA)
  key. OpenSSL 3.5+ (2025 release) supports hybrid key exchanges.
- **SSH:** Upgrade to OpenSSH 9.9+ which experimental post-quantum key
  exchange (``sntrup761x25519-sha512@openssh.com`` and the newer
  ``mlkem768x25519-sha256`` hybrid).
- **TLS:** Configure TLS 1.3 with hybrid Kyber+ECDHE key exchange:
  ::

      openssl s_server -groups kyber768:prime256v1 -tls1_3

- **DNSSEC:** Post-quantum DNSSEC using CRYSTALS-Dilithium is in
  standardization. Monitor BIND and Unbound release notes.

**Organizations leading the transition:** Google (Chrome supports Kyber since
2023), Cloudflare (Kyber on all edge), Amazon (AWS KMS hybrid PQ), and the
NSA (announced CNSA 2.0 requiring PQ algorithms by 2028).

Real-World Application: Nation-State Threat Profiles
===========================================================

Different adversaries target Linux systems in different ways. Understanding
their methods informs your hardening priorities.

+----------------+--------------------------------------------------+
| Threat Actor   | Linux TTPs (2026)                                |
+================+==================================================+
| China (APT10,  | Supply chain poisoning, VPN/firewall zero-days,  |
| APT41)         | stealthy kernel rootkits, targeting of            |
|                | telecommunications and semiconductor firms.       |
+----------------+--------------------------------------------------+
| Russia (APT29, | Living-off-the-land (LOL) binaries, PowerShell    |
| APT28)         | Core for Linux, ``systemd`` backdoors, targeting  |
|                | government and energy sectors.                    |
+----------------+--------------------------------------------------+
| North Korea    | Cryptocurrency wallet theft, Docker/K8s           |
| (Lazarus)      | container breakout exploits, supply chain         |
|                | attacks on npm/PyPI targeting Linux devs.         |
+----------------+--------------------------------------------------+
| Iran (APT33,   | Destructive wiper malware on Linux (ZeroCleare),  |
| APT39)         | credential harvesting via compromised SSH keys.   |
+----------------+--------------------------------------------------+
| Criminal       | Ransomware (LockBit, BlackCat Linux encryptors),  |
| Ransomware     | mass-scanning for unpatched CVEs (Log4j,          |
| Gangs          | Confluence, Exchange).                            |
+----------------+--------------------------------------------------+

**Conclusion for the Administrator:** If you are a target, implement SLSA 3+
supply chain controls, deploy eBPF-based runtime detection (Falco), enforce
SELinux MLS if handling classified data, and prepare your TLS/SSH
configuration for the post-quantum transition today. Security is not
paranoia—it is informed preparation.
