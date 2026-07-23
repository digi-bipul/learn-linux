============================================================
Chapter 10: Performance Engineering & Modern Observability
============================================================

.. toctree::
   :maxdepth: 1
   :titlesonly:

   performance_methodology
   cpu_analysis
   memory_dynamics
   storage_io
   network_telemetry
   cgroups_v2
   tracing_ebpf
   observability_stack

---

**Chapter Overview**

Performance engineering is the discipline of measuring, analysing, and
optimising the behaviour of computer systems under load. In the early 2000s,
this meant SSHing into a box, running ``top``, and hoping nothing caught fire.
The modern landscape is radically different. With the adoption of containerised
microservices, multi-core NUMA architectures, NVMe storage, and 100 Gbps
networking, the margin for error has vanished — and so have the old tools.

This chapter bridges classical systems performance analysis (the kind Brendan
Gregg codified at Netflix) with the modern observability ecosystem that has
coalesced around Prometheus, OpenTelemetry, and eBPF. By the end of this
chapter, you will be able to:

- Diagnose a misbehaving system using the USE and RED methodologies.
- Profile CPU, memory, storage, and network subsystems with modern tooling.
- Understand and control resource isolation via **cgroups v2** (the 2026
  standard).
- Write one-liner eBPF programs with ``bpftrace`` to trace kernel and
  application behaviour with near-zero overhead.
- Architect a production-grade observability stack using Prometheus,
  OpenTelemetry, and Grafana.

**Prerequisites.** This chapter assumes you have mastered Chapters 1–9:
basic shell literacy, system administration, networking, security, and
automation. We will not revisit package management, user administration, or
init systems. We assume a Linux kernel ≥ 6.x and a recent (2024+) distribution.

**A Note on Tooling.** Many tools taught in legacy Linux textbooks — ``netstat``,
``vmstat``, ``strace`` without eBPF, ``cgroups v1`` — are either deprecated or
dangerous in production. This chapter explicitly explains *why* they have been
superseded and what to use instead. Where possible, we teach both the
mathematical foundation and the practical invocation.
