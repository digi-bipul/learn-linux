Chapter 2: File Management, Text Viewing, and Permissions
=========================================================

In Chapter 1, you learned to move around the Linux filesystem with ``cd``,
``pwd``, and ``ls``.  Now it is time to *do* things — to create, copy, move,
inspect, and protect your data.  This chapter covers the fundamental operations
that turn the filesystem from a passive map into an active workspace.

We begin with the core file‑management commands (``mkdir``, ``touch``, ``cp``,
``mv``, ``rm``) and then turn to the tools you use to peek inside files
(``cat``, ``less``, ``head``, ``tail``) and a brief introduction to terminal‑based
editors.  The second half of the chapter introduces the Linux security model:
users, groups, file ownership, and the permission bits that govern who may read,
write, or execute every file on the system.

By the end of this chapter you will be able to:

* Create, copy, move, rename, and safely delete files and directories.
* View file contents in whole, in part, or interactively.
* Understand the multi‑user architecture of a Linux system.
* Read and set file permissions using both symbolic and octal notation.
* Recognise and apply special permission bits (SUID, SGID, and the sticky bit).

.. toctree::
   :maxdepth: 2
   :caption: Contents:

   01_working_with_files
   02_viewing_text
   03_users_and_groups
   04_file_permissions
   05_special_permissions
