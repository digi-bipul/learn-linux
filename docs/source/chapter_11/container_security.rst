.. _chapter-11-6:

============================================================
11.6 Container Security & Compliance
============================================================

Containers introduce a unique security challenge: they share a kernel with the host and
each other. A vulnerability in the container runtime, a misconfigured namespace, or an
excessive capability can lead to **container breakout** — where a process inside a
container gains access to the host kernel or host filesystem. This section covers the
defence-in-depth strategies for securing containers at every layer: dropping
capabilities, applying seccomp and AppArmor profiles, enforcing rootless execution,
and implementing a modern **software supply chain** security pipeline with CVE
scanning, SBOMs, and cryptographic signing.

11.6.1 Linux Capabilities: The Principle of Least Privilege
============================================================

Linux capabilities break the binary root/non-root model into fine-grained privileges.
A process can have a specific capability (e.g., ``CAP_NET_BIND_SERVICE`` to bind to a
privileged port) without being fully root.

**Default capabilities in Docker/Podman:**

When you run a container, the runtime grants a default set of capabilities. As of
Docker 25+, the default set is conservative:

.. code-block:: bash

   # Check capabilities granted to a running container
   docker run -d --name caps-demo nginx:alpine
   docker exec caps-demo cat /proc/1/status | grep -i cap
   # CapInh: 00000000a80425fb
   # CapPrm: 00000000a80425fb
   # CapEff: 00000000a80425fb
   # CapBnd: 00000000a80425fb

   # Decode with capsh
   docker run --rm --cap-add ALL nginx:alpine capsh --decode=00000000a80425fb
   # 0x00000000a80425fb = CAP_CHOWN, CAP_DAC_OVERRIDE, CAP_FOWNER, CAP_FSETID,
   #                      CAP_KILL, CAP_SETGID, CAP_SETUID, CAP_SETPCAP,
   #                      CAP_NET_BIND_SERVICE, CAP_NET_RAW, CAP_SYS_CHROOT,
   #                      CAP_MKNOD, CAP_AUDIT_WRITE, CAP_SETFCAP

**Dropping unnecessary capabilities:**

The rule: **drop all capabilities, then add back only what is needed.**

.. code-block:: bash

   # Run with NO capabilities
   docker run --rm --cap-drop ALL alpine ping -c 1 8.8.8.8
   # ping: socket: Operation not permitted (because CAP_NET_RAW is missing)

   # Run with only the capabilities needed
   docker run --rm --cap-drop ALL --cap-add NET_RAW alpine ping -c 1 8.8.8.8
   # PING 8.8.8.8 (8.8.8.8): 56 data bytes

   # In Podman (rootless):
   podman run --rm --cap-drop ALL alpine id
   # uid=0(root) gid=0(root) groups=0(root)
   # Even though uid=0, without CAP_CHOWN and CAP_DAC_OVERRIDE, the process
   # cannot change ownership or bypass permission checks.

**Kubernetes: securityContext**

In Kubernetes, you specify capabilities via ``securityContext``:

.. code-block:: yaml

   apiVersion: v1
   kind: Pod
   metadata:
     name: secure-pod
   spec:
     containers:
     - name: app
       image: my-app:latest
       securityContext:
         capabilities:
           drop: ["ALL"]
           add: ["NET_BIND_SERVICE"]   # For binding to port 80
         runAsNonRoot: true
         runAsUser: 1000
         readOnlyRootFilesystem: true
         allowPrivilegeEscalation: false

.. note::
   ``allowPrivilegeEscalation: false`` is critical. It ensures that even if the
   container process gains a new binary (e.g., via ``sudo`` or a ``setuid`` binary),
   it cannot escalate privileges inside the container. This is always the safe
   default.

11.6.2 Seccomp Profiles
========================

**Seccomp** (Secure Computing Mode) is a Linux kernel feature that allows a process to
specify a filter for the system calls it is allowed to make. Seccomp-bpf extends this
with BPF (Berkeley Packet Filter) programs that can inspect syscall arguments.

**The default Docker/Podman seccomp profile:**

Docker ships a default seccomp profile that blocks approximately 44 of the ~300 Linux
syscalls. Blocked syscalls include:

* ``keyctl`` (key management operations)
* ``bpf`` (loading BPF programs)
* ``acct`` (process accounting)
* ``uselib`` (obsolete)
* ``ptrace`` (tracing other processes)
* ``kexec_file_load`` (loading a new kernel)

**Applying a custom seccomp profile:**

.. code-block:: json

   {
     "defaultAction": "SCMP_ACT_ERRNO",
     "architectures": [
       "SCMP_ARCH_X86_64",
       "SCMP_ARCH_AARCH64"
     ],
     "syscalls": [
       {
         "names": [
           "accept", "bind", "close", "connect", "dup",
           "epoll_create", "epoll_wait", "fcntl", "fstat",
           "getdents64", "getpid", "listen", "lseek",
           "mmap", "mprotect", "munmap", "openat", "read",
           "recvfrom", "sendto", "socket", "write"
         ],
         "action": "SCMP_ACT_ALLOW",
         "args": [],
         "comment": "Minimal syscall set for a static web server"
       }
     ]
   }

.. code-block:: bash

   # Run a container with the custom profile
   docker run --rm \
     --security-opt seccomp=./minimal-profile.json \
     nginx:alpine

   # In Podman (rootless, seccomp is enabled by default):
   podman run --rm \
     --security-opt seccomp=./minimal-profile.json \
     nginx:alpine

   # In Kubernetes:
   securityContext:
     seccompProfile:
       type: Localhost
       localhostProfile: profiles/minimal.json

.. warning::
   Writing a seccomp profile manually is error-prone. Use tools like ``inspektor-gadget``
   or ``strace`` to record the syscalls an application actually makes, then generate a
   profile from the trace:

   .. code-block:: bash

      strace -c -f -o /tmp/syscalls.log nginx -g 'daemon off;'
      # Then cat /tmp/syscalls.log to see the syscall names and counts

11.6.3 AppArmor and SELinux
============================

Beyond capabilities and seccomp, Mandatory Access Control (MAC) systems provide
additional confinement:

* **AppArmor** (default on Ubuntu/Debian): Path-based MAC. You define profiles that
  restrict a program's access to files, network, and capabilities.
* **SELinux** (default on RHEL/CentOS/Fedora): Label-based MAC. Every process and file
  has a security context (user:role:type). Labels are checked before any DAC check.

**AppArmor example:**

.. code-block:: bash

   # Install apparmor-utils
   sudo apt install apparmor-utils

   # View currently loaded profiles
   sudo aa-status

   # Create a profile for nginx
   cat > /etc/apparmor.d/docker-nginx << 'EOF'
   #include <tunables/global>

   profile docker-nginx flags=(attach_disconnected,mediate_deleted) {
     #include <abstractions/base>
     #include <abstractions/lxc/container-base>

     /etc/nginx/** r,
     /var/log/nginx/* w,
     /usr/sbin/nginx ix,
     /run/nginx.pid rw,
     network tcp,
     network inet tcp,
   }
   EOF

   sudo apparmor_parser /etc/apparmor.d/docker-nginx

   # Run container with the profile
   docker run --rm --security-opt apparmor=docker-nginx nginx

11.6.4 Rootless Execution: The Zero-Trust Baseline
====================================================

As explained in §11.4, running containers **rootless** means the container process has
no more privileges on the host than the unprivileged user who launched it. Even if a
container breakout occurs, the attacker gets a non-root UID on the host.

**In Kubernetes, achieve rootless with the following Pod Security Context:**

.. code-block:: yaml

   spec:
     securityContext:
       runAsNonRoot: true
       runAsUser: 1001
       runAsGroup: 1001
       fsGroup: 1001
       seccompProfile:
         type: RuntimeDefault
     containers:
     - name: app
       securityContext:
         allowPrivilegeEscalation: false
         capabilities:
           drop: ["ALL"]
         readOnlyRootFilesystem: true

**Pod Security Standards (PSS):**

Kubernetes defines three built-in security policy levels, enforced via admission
controllers (as of v1.30+, PodSecurity admission is built-in):

.. list-table:: Pod Security Standards
   :header-rows: 1
   :widths: 15 30 55

   * - Level
     - `pod-security.kubernetes.io/enforce`
     - Restrictions
   * - **Privileged**
     - ``privileged``
     - Unrestricted. For system-level components (kube-proxy, CNI daemonsets).
   * - **Baseline**
     - ``baseline``
     - Prevents known privilege escalations (no hostPID, no hostNetwork, no privileged
       containers, no ``CAP_SYS_ADMIN``).
   * - **Restricted**
     - ``restricted``
     - Follows all pod hardening best practices. Requires ``runAsNonRoot: true``,
       ``seccomp: RuntimeDefault``, ``capabilities.drop: ["ALL"]``.

.. code-block:: bash

   # Apply a Pod Security Standard to a namespace
   kubectl create namespace production
   kubectl label namespace production \
     pod-security.kubernetes.io/enforce=restricted \
     pod-security.kubernetes.io/warn=restricted

   # Try to create a privileged pod — it will be denied
   kubectl -n production run bad-pod --image=nginx --privileged
   # Error: admission webhook "pod-security" denied the request

11.6.5 The 2026 Software Supply Chain Pipeline
================================================

The 2021 SolarWinds and Log4j attacks taught the industry that you cannot trust third-
party dependencies without verification. A modern supply chain pipeline has three
phases: **Scan → SBOM → Sign**.

**Phase 1: CVE Scanning with Trivy**

**Trivy** (by Aqua Security) is the de-facto standard vulnerability scanner for
container images, filesystems, and Git repositories. It detects vulnerabilities in
OS packages (Alpine, Debian, RHEL) and language-specific dependencies (npm, PyPI,
Go modules, Maven).

.. code-block:: bash

   # Install Trivy
   curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh

   # Scan an image
   trivy image nginx:1.27-alpine

   # Scan with severity filter and output as JSON
   trivy image --severity CRITICAL,HIGH --format json nginx:alpine > scan.json

   # Scan a filesystem (useful before building)
   trivy filesystem --severity CRITICAL .

   # Scan a Git repository
   trivy repo https://github.com/org/my-app.git

   # Fail the CI pipeline if critical CVEs are found
   trivy image --exit-code 1 --severity CRITICAL my-app:latest

**Phase 2: Software Bill of Materials (SBOM)**

An **SBOM** is a machine-readable inventory of all components in a software artifact.
The standard format is **SPDX** (ISO/IEC 5962:2021) or **CycloneDX**.

.. code-block:: bash

   # Generate an SBOM for an image (Syft is the standard tool)
   syft nginx:alpine -o spdx-json > nginx.sbom.json

   # Generate in CycloneDX format
   syft nginx:alpine -o cyclonedx-json > nginx.cdx.json

   # Generate during CI (attach SBOM to the release)
   syft my-app:latest -o spdx-json > sbom.spdx.json

   # View dependencies
   cat nginx.sbom.json | jq '.packages[].name'

**SBOM use cases:**

* **Vulnerability correlation:** When a new CVE is announced (e.g., Log4Shell),
  query your SBOM database to find exactly which releases are affected.
* **License compliance:** Verify that all dependencies use compatible licenses.
* **Supply chain transparency:** Prove to auditors that you know what is in your
  software.

**Phase 3: Cryptographic Signing with Sigstore/cosign**

**Sigstore** is a Linux Foundation project that provides a public, non-profit signing
infrastructure. **cosign** is the CLI tool for signing and verifying container images.

.. code-block:: bash

   # Generate a key pair (can also use OIDC — no key management!)
   cosign generate-key-pair

   # Sign an image with a key
   cosign sign --key cosign.key ghcr.io/myorg/my-app:v1.0.0

   # Verify the signature
   cosign verify --key cosign.pub ghcr.io/myorg/my-app:v1.0.0

   # Keyless signing (using OIDC — recommended for 2026)
   # Sign with your GitHub/GitLab/Google identity — no key to manage
   cosign sign ghcr.io/myorg/my-app:v1.0.0

   # Verify keyless
   cosign verify \
     --certificate-identity-regexp ".*@myorg\.com$" \
     --certificate-oidc-issuer https://github.com/login/oauth \
     ghcr.io/myorg/my-app:v1.0.0

**How keyless signing works:**

1. ``cosign sign`` contacts the Sigstore **Fulcio** certificate authority.
2. Fulcio issues a short-lived code-signing certificate after verifying the
   user's OIDC identity (via Google, GitHub, Microsoft).
3. The image is signed with an ephemeral key pair (generated locally, discarded after
   signing).
4. The certificate and signature are uploaded to the **Rekor** transparency log,
   providing an immutable audit trail.
5. Anyone can verify the signature by checking the certificate chain against Fulcio
   and the Rekor log.

**End-to-end CI/CD security pipeline:**

.. code-block:: yaml

   # (GitHub Actions example)
   jobs:
     build-and-sign:
       runs-on: ubuntu-latest
       permissions:
         id-token: write   # For OIDC keyless signing
         contents: read
       steps:
         - uses: actions/checkout@v4

         - name: Build image
           run: docker build -t my-app:${{ github.sha }} .

         - name: Scan for CVEs
           run: trivy image --exit-code 1 --severity CRITICAL my-app:${{ github.sha }}

         - name: Generate SBOM
           run: syft my-app:${{ github.sha }} -o spdx-json > sbom.spdx.json

         - name: Sign image (keyless)
           uses: sigstore/cosign-installer@v3
           run: cosign sign ghcr.io/myorg/my-app:${{ github.sha }}

         - name: Attach SBOM
           run: cosign attach sbom --sbom sbom.spdx.json ghcr.io/myorg/my-app:${{ github.sha }}

         - name: Push
           run: docker push ghcr.io/myorg/my-app:${{ github.sha }}

11.6.6 Runtime Security with Falco
====================================

**Falco** (by Sysdig, CNCF graduated) is a runtime security monitor for containers and
Kubernetes. It uses eBPF or kernel modules to intercept system calls and raises alerts
when behaviour deviates from defined rules.

.. code-block:: bash

   # Install Falco
   curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco.gpg
   sudo apt install -y falco

   # Run Falco (eBPF probe)
   sudo falco \
     --modern-bpf \
     -r /etc/falco/falco_rules.yaml

   # Example alert: "Shell opened inside a container"
   # Falco Rule: "Sensitive file opened for writing by non-trusted program"
   # 06:30:15.000000000: Warning Shell opened inside container (user=root container=my-app shell=sh)

   # Custom rule: Alert when curl/wget are run inside a container
   # (indicates potential malware download)
   # /etc/falco/falco_rules.local.yaml:
   # - rule: Unauthorized Process Download
   #   desc: Detect curl/wget in containers
   #   condition: container and proc.name in (curl, wget)
   #   output: "Download tool used (user=%user.name container=%container.name process=%proc.name)"
   #   priority: WARNING

11.6.7 Antipatterns
===================

.. admonition:: Antipattern: Running a Privileged Container
   :class: danger

   ``--privileged`` gives a container **all** capabilities, disables seccomp, and
   grants access to all host devices (including ``/dev/sda``). This is almost never
   necessary. If a container needs a specific device (e.g., a GPU), use
   ``--device /dev/dri`` instead.

.. admonition:: Antipattern: Ignoring Base Image CVEs
   :class: danger

   Many teams build custom images on top of ``ubuntu:latest`` without ever scanning
   them. A 2024 study found that **60% of critical container CVEs** reside in the
   base image, not the application code. Scan your base images before building.

.. admonition:: Antipattern: Using ``:latest`` in Production
   :class: warning

   As mentioned in §11.3, ``:latest`` is a mutable tag. An image pinned by digest
   (``image@sha256:...``) is immutable and guarantees that what you scanned and
   tested is exactly what is deployed.

11.6.8 Practical Exercises
==========================

**1. Capability Exploration**

.. code-block:: bash

   # Run a container with all capabilities dropped
   docker run --rm --cap-drop ALL alpine whoami
   # (it works — whoami does not need capabilities)

   # Try to change the hostname (requires CAP_SYS_ADMIN)
   docker run --rm --cap-drop ALL alpine hostname newname
   # hostname: sethostname: Operation not permitted

   # Add back CAP_SYS_ADMIN
   docker run --rm --cap-drop ALL --cap-add SYS_ADMIN alpine hostname newname
   # (succeeds)

**2. Trivy + SBOM + cosign Pipeline**

.. code-block:: bash

   # Prerequisites: trivy, syft, cosign installed

   # 1. Pull an image
   docker pull alpine:latest

   # 2. Scan it
   trivy image --severity CRITICAL alpine:latest

   # 3. Generate SBOM
   syft alpine:latest -o spdx-json > alpine.sbom.json

   # 4. Sign (keyless — requires OIDC login first)
   cosign login ghcr.io -u <your-username>
   cosign sign ghcr.io/<your-username>/alpine:test

   # 5. Verify
   cosign verify ghcr.io/<your-username>/alpine:test

**3. Pod Security Standard Enforcement**

.. code-block:: bash

   kind create cluster
   kubectl create namespace secure-ns
   kubectl label namespace secure-ns \
     pod-security.kubernetes.io/enforce=restricted

   # This will be rejected:
   kubectl -n secure-ns run nginx --image=nginx
   # Error: admission webhook "pod-security" denied the request

   # To fix: add the required securityContext in a YAML file:
   cat << 'EOF' | kubectl -n secure-ns apply -f -
   apiVersion: v1
   kind: Pod
   metadata:
     name: nginx
   spec:
     securityContext:
       runAsNonRoot: true
       runAsUser: 1001
       seccompProfile:
         type: RuntimeDefault
     containers:
     - name: nginx
       image: nginx
       securityContext:
         allowPrivilegeEscalation: false
         capabilities:
           drop: ["ALL"]
         readOnlyRootFilesystem: true
   EOF
