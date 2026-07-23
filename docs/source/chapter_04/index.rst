==================================================
Chapter 4: Processes, Services & Initialization
==================================================

.. rst-class:: lead

   *"A process is a program in execution. It is not the same as a program,
   which is a passive collection of instructions. A process is the active
   state of that program, complete with memory, file descriptors, and
   an identity."* — Adapted from Tanenbaum, *Modern Operating Systems*

The first three chapters of this book were about **static** resources: files,
users, permissions. This chapter turns to the **dynamic** heart of a running
Linux system: **processes** — the units of execution that bring the machine
to life.

Processes are the atoms of the operating system. They are created, they run,
they communicate, they die. The kernel's **scheduler** decides which process
runs on which CPU core at which instant. The **init system** (PID 1) is the
ancestor of every process and the orchestrator of system services.

This chapter explores the complete lifecycle:

1. **Process Lifecycle** — How processes are born (``fork``/``exec``),
   their states, their identities, and the ``/proc`` filesystem.
2. **Process Monitoring** — The tools to see what is running: ``ps``,
   ``top``, ``htop``, ``atop``, ``pstree``.
3. **Signals** — Inter-process communication through kernel-delivered
   notifications: ``kill``, ``killall``, ``pkill``, and shell traps.
4. **Initialization Archetypes & systemd** — The design of PID 1,
   contrasting sequential init with systemd's event-driven, parallel model.
5. **Writing systemd Unit Files** — Creating services, dependencies, and
   modern security hardening.
6. **Alternative Init Systems** — OpenRC (Alpine) and Runit (Void).
7. **Service Logging** — The systemd journal (``journalctl``) vs.
   traditional syslog.
8. **Scheduling** — Cron, crontab, anacron, at, batch, and systemd timers.

.. toctree::
   :maxdepth: 1
   :titlesonly:

   process_lifecycle
   process_monitoring
   signals
   init_and_systemd
   writing_unit_files
   alternative_inits
   service_logging
   scheduling
