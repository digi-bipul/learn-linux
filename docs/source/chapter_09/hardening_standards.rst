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
