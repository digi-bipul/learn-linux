##########################################
Chapter 7: Linux Networking & Core Network Fundamentals
##########################################

Computer networking is the connective tissue of modern systems. Without it, our
servers are isolated islands—powerful, but alone. This chapter bridges the gap
between a single-user Linux machine and the global internet. We will start with
the fundamental computer science theory of how data moves across wires and
through the air, then descend into the practical toolkit every Linux
administrator must wield to configure, secure, and troubleshoot networked
systems.

By the end of this chapter, you will not merely be able to follow a recipe to
set up a network interface—you will understand *why* packets are structured the
way they are, *how* the kernel decides where to send them, and *what* tools to
reach for when the connection breaks.

Prior Knowledge Assumption
==========================

Chapters 1 through 6 have equipped you with terminal fluency, shell
proficiency, user and permission management, process supervision, package
administration, and storage/filesystem mastery. This chapter assumes you are
comfortable editing files with a terminal text editor, running commands as root
via ``sudo``, and navigating the Linux filesystem. No prior networking
experience is required.

Chapter Roadmap
===============

.. toctree::
   :titlesonly:
   :numbered:

   01_networking_theory
   02_ip_and_subnetting
   03_ip_command_suite
   04_network_configuration
   05_dns_resolution
   06_nftables_core
   07_firewall_frontends
   08_ssh_mastery
   09_troubleshooting

Learning Objectives
===================

After completing this chapter, you will be able to:

* Explain how data is encapsulated into frames, packets, and segments, and map
  these concepts to the OSI and TCP/IP models.
* Distinguish between MAC addresses and IP addresses, and describe the
  respective roles of switches and routers.
* Compute subnet ranges using CIDR notation and identify public vs. private
  address space.
* Administer network interfaces, addresses, routes, and neighbor caches
  exclusively with the modern ``ip`` command suite.
* Configure persistent networking on major Linux distributions using Netplan,
  NetworkManager, ``systemd-networkd``, and ``ifupdown``.
* Diagnose and configure DNS resolution, including local overrides via
  ``/etc/hosts`` and the role of ``systemd-resolved``.
* Write and manage packet-filtering rules with ``nftables`` including NAT and
  stateful firewalls.
* Operate higher-level firewall frontends like ``ufw`` and ``firewalld``, and
  understand their relationship to the kernel's netfilter framework.
* Deploy SSH with Ed25519 keys, configure agent forwarding, set up tunnels, and
  harden an SSH server.
* Troubleshoot network issues methodically using ``ping``, ``traceroute`` /
  ``mtr``, ``tcpdump``, ``nmap``, ``iperf3``, ``curl``, and ``wget``.

Estimated Time to Completion
=============================

Reading and comprehension: approximately 6–8 hours. Hands-on lab exercises:
4–6 hours. Expect to spend a full weekend with this chapter if you work through
every example at the terminal.
