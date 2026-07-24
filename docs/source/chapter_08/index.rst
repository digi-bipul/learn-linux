.. _chapter-08:

========================================================
Chapter 8 — Shell Scripting & Infrastructure Automation
========================================================

Welcome to the turning point of this book.  In Chapters 1 through 7, you
learned to navigate, administer, network, and secure a Linux system by
typing commands one at a time.  Every file you created, every firewall
rule you added, every package you installed — each required your manual
intervention at the keyboard.  That model does *not* scale.

This chapter transforms you from an interactive operator into an
**automation engineer**.  Shell scripting is the glue that binds the
operating system's primitives into repeatable, auditable, and shareable
routines.  You will learn to write robust scripts that tolerate failure,
parse arguments like professional CLI tools, hook into system events,
and eventually manage entire fleets of machines with
Infrastructure-as-Code (IaC) tooling.

**Chapter Roadmap**

* :doc:`8.1 — Script Structure <01_script_structure>`
* :doc:`8.2 — Variables & Data Types <02_variables_data_types>`
* :doc:`8.3 — Conditionals <03_conditionals>`
* :doc:`8.4 — Loops <04_loops>`
* :doc:`8.5 — Functions & Scope <05_functions_scope>`
* :doc:`8.6 — Error Handling & Robustness <06_error_handling>`
* :doc:`8.7 — CLI Argument Parsing <07_argument_parsing>`
* :doc:`8.8 — Local Automation & Event Hooks <08_local_automation>`
* :doc:`8.9 — Config Management & Modern IaC <09_ansible_and_iac>`

.. toctree::
   :maxdepth: 1
   :titlesonly:

   script_structure
   variables_data_types
   conditionals
   loops
   functions_scope
   error_handling
   argument_parsing
   local_automation
   ansible_and_iac
