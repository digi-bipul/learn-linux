################################################
Chapter 3: Users, Groups & Permissions
################################################

.. rst-class:: lead

   *"The unix system is simple and coherent, but it takes a genius (or a
   programmer) to understand and appreciate the simplicity."* — Dennis Ritchie

Linux is, at its core, a **multi-user operating system**. Unlike single-user
systems (e.g., a typical desktop Windows 9x installation or a standalone gaming
console), Linux was designed from the ground up to allow many users—possibly
hundreds or thousands—to share a single machine simultaneously, each with their
own identity, resources, and restrictions.

This chapter explores the three pillars of Linux security and identity:

1. **Users & Groups** — Who you are and what teams you belong to.
2. **Permissions** — What you can read, write, or execute.
3. **Privilege Escalation** — How to temporarily become someone more powerful.

By the end of this chapter, you will understand not only *how* to manage users
and permissions, but *why* the system is designed the way it is—the principle
of least privilege, the separation of data and metadata, and the Unix philosophy
of "everything is a file."

.. toctree::
   :titlesonly:

   01_multi_user_model
   02_user_group_management
   03_file_permissions
   04_special_permission_bits
   05_acls
   06_advanced_attributes
   07_privilege_escalation
