.. _chapter-11:

============================================================
Chapter 11: Containers, Virtualization & Cloud Native Architecture
============================================================

.. epigraph::

   "Containers are not virtualization — they are encapsulation. The kernel does not
   simulate hardware; it partitions itself."

   — *Adapted from Solomon Hykes, Docker Founder*

The Linux kernel is the single most important piece of infrastructure underpinning the
modern cloud. From the tiniest serverless function executing in an AWS Lambda to the
control plane of a bare-metal Kubernetes cluster spanning thousands of machines, the
operating system you have studied in the preceding ten chapters has evolved into a
**cloud native operating system**. Chapter 11 is the bridge between the classical Linux
system administration you have mastered and the distributed, ephemeral, API-driven world
of cloud native computing.

We begin with the foundation — **virtualization** — because without it, the cloud as we
know it does not exist. You will learn the difference between Type 1 and Type 2
hypervisors, how KVM turns the Linux kernel into a bare-metal hypervisor, and how modern
**MicroVMs** (AWS Firecracker, Cloud Hypervisor) achieve virtual-machine isolation with
container-like boot latencies, enabling the serverless revolution.

From virtual machines we descend into the kernel primitives that power **containers**.
Containers are often mystified as lightweight VMs; they are not. A container is simply a
collection of Linux processes that share a kernel with the host but see a carefully
orchestrated illusion of isolation. We will dissect all **eight Linux namespaces**
(mount, PID, net, IPC, UTS, user, cgroup, and the newer time namespace) and the
**cgroups v2** controller hierarchy that enforces resource boundaries. You will build a
container *by hand* using nothing but shell commands — no Docker required — to
internalise that the emperor indeed has no clothes.

With that foundation, we examine **Docker** as the user-space tooling that popularised
the container abstraction. We analyse its monolithic daemon architecture, layer caching,
multi-stage builds, and the bridge/host/overlay networking models. We then turn to
**Podman**, the daemonless, rootless alternative now preferred by enterprise Linux
distributions, and explore its deep integration with **systemd** via **Quadlets** —
a pattern that transforms container management into native unit-file administration.

No cloud native chapter would be complete without the **Kubernetes ecosystem**. We cover
the control-plane versus worker-node architecture, the atomic unit of the Pod, and the
core API objects (Deployments, Services, ConfigMaps, Secrets). We introduce **Talos
Linux** — an immutable, API-driven OS purpose-built for running Kubernetes — and
**K3s**, the lightweight distribution for edge and resource-constrained environments.

Security receives its own dedicated treatment. You will learn how to drop Linux
capabilities, apply seccomp profiles, and enforce rootless execution. We then examine
the **2026 software supply chain**: scanning container images for Common Vulnerabilities
and Exposures (CVEs) with **Trivy**, generating Software Bills of Materials (SBOMs),
and cryptographically signing artifacts with **Sigstore/cosign**.

Finally, we close with **Infrastructure as Code** and **cloud initialisation**. You will
bootstrap virtual machines with ``cloud-init``, provision cloud resources declaratively
with **OpenTofu** (the open-source successor to Terraform), and interact with cloud APIs
through AWS CLI, ``gcloud``, and ``az``.

By the end of this chapter, you will understand not only how to *use* cloud native tools
but how they *work* — and how the Linux kernel makes them all possible.

.. toctree::
   :maxdepth: 2
   :caption: Subchapters

   01_virtualization_microvms
   02_container_fundamentals
   03_docker_lifecycles
   04_podman_systemd
   05_kubernetes_essentials
   06_container_security
   07_iac_and_cloud
