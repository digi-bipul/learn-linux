.. _section-3-4:

================================================
3.4 Special Permission Bits
================================================

.. rst-class:: lead

   Beyond the standard ``rwx`` trio, Unix defines three **special permission
   bits** that modify how executables run and how directories behave. The
   SetUID (SUID), SetGID (SGID), and Sticky bits are powerful tools—and
   equally powerful vectors for privilege escalation if misapplied.

3.4.1 The Three Special Bits
==============================

The special bits occupy the most significant octal digit, sitting to the
left of the owner triad:

.. code-block:: text

   Special  Owner    Group    Others
   ───────  ──────   ──────   ──────
      ?      r w x    r w x    r w x

They are represented symbolically as:

.. list-table:: Special Bit Notation
   :header-rows: 1
   :widths: 15 15 25 45

   * - Bit
     - Octal
     - Symbolic (``ls``)
     - Meaning
   * - SUID
     - 4000
     - ``s`` in owner execute position
     - ``rwsr-xr-x`` — process runs as file owner.
   * - SGID
     - 2000
     - ``s`` in group execute position
     - ``rwxr-sr-x`` — process runs as file group; directory inheritance.
   * - Sticky
     - 1000
     - ``t`` in others execute position
     - ``rwxrwxrwt`` — restricts file deletion in shared directories.

If the execute bit is **not** set, the special bit is shown in uppercase:

.. code-block:: text

   rwSr-Sr-T    # SUID + SGID + Sticky, but NO execute bits in those positions
   rwsr-xr-T    # SUID (s) with owner execute, Sticky without others execute

(These uppercase forms are rare in practice, as a file with SUID but no
owner execute bit is nearly useless.)

3.4.2 SetUID (SUID) — ``chmod u+s`` (4000)
============================================

**What it does:**

When a file with the SUID bit set is executed, the resulting process runs
with the **effective UID (EUID)** set to the **owner of the file**, rather
than the UID of the user who launched it. If the file is owned by root, the
process runs as root, regardless of who invokes it.

**The classic example — ``passwd``:**

.. code-block:: bash

   $ ls -l /usr/bin/passwd
   -rwsr-xr-x 1 root root 68208 Jul 15 12:00 /usr/bin/passwd

Note the ``s`` in the owner execute position. When a regular user runs
``passwd``, the process runs with EUID=0 (root). This is necessary because
``passwd`` must write to ``/etc/shadow``, which is readable only by root.
Without the SUID bit, ordinary users could never change their own passwords.

**The underlying mechanism — real vs. effective UID:**

When a SUID binary executes:

1. The kernel creates a process with:
   - **Real UID (RUID)**: The user who launched the process.
   - **Effective UID (EUID)**: The owner of the file (e.g., root).
2. The kernel checks permissions against the **EUID**, not the RUID.
3. The process can deliberately swap or set the EUID back to the RUID using
   the ``seteuid(2)`` or ``setreuid(2)`` system calls (a feature called
   "privilege bracketing").

**Security implications:**

The SUID bit is one of the most dangerous permissions in Linux. A
vulnerability in a SUID root binary can give any user on the system full
root access. History is littered with such exploits:

*   **CVE-2010-3847** — SUID ``glibc`` bug allowing arbitrary code execution.
*   **CVE-2021-3156 (Baron Samedit)** — ``sudo`` heap buffer overflow,
    affecting SUID ``sudo`` binary.
*   **CVE-2021-3493** — SUID ``overlayfs`` privilege escalation.
*   ``CVE-2017-1000367`` — ``sudo`` privilege escalation via improper
    environment handling.

**Finding all SUID binaries on your system:**

.. code-block:: bash

   # Find all SUID files (owner-s)
   $ find / -perm -4000 -type f 2>/dev/null

   # A more robust version with details
   $ find / -perm -4000 -type f -exec ls -la {} \; 2>/dev/null

**Creating a SUID binary (for educational purposes only):**

.. code-block:: bash

   # As root, make a custom script SUID
   # chown root:root myhelper
   # chmod u+s myhelper   # Now runs as root
   # ls -l myhelper
   -rwsr-xr-x 1 root root 12345 Jul 15 12:00 myhelper

.. warning::

   SUID on **shell scripts** (``#!/bin/bash``) is **intentionally ignored**
   by most modern systems for security reasons. The kernel (since Linux 2.6
   and ``CONFIG_SECCOMP`` / ``CONFIG_SHELLCODE`` protections) and most shells
   will silently drop the SUID bit on interpreted scripts. This is because
   shell scripts are prone to **race conditions** and **PATH injection**
   attacks (if the script calls ``ls``, which ``ls``? the one in a
   world-writable directory?).

   Only **compiled ELF binaries** reliably honour the SUID bit.

3.4.3 SetGID (SGID) — ``chmod g+s`` (2000)
============================================

SGID has **two distinct behaviours** depending on whether it is applied to a
**file** or a **directory**.

**On an executable file:**

When an SGID executable runs, the process's **effective GID (EGID)** is set
to the file's group owner. This is exactly analogous to SUID but for groups.

Example — ``write(1)`` (the legacy BSD messaging command):

.. code-block:: bash

   $ ls -l /usr/bin/write
   -rwxr-sr-x 1 root tty 18688 Jul 15 12:00 /usr/bin/write

When a user runs ``write``, the process runs with the effective GID ``tty``,
allowing it to write to another user's terminal device (which is
group-owned by ``tty``).

**On a directory (the inheritance behaviour):**

When the SGID bit is set on a **directory**, **newly created files and
subdirectories inside inherit the directory's group**, not the creating
user's primary group. This is one of the most practically useful permission
tricks for collaborative environments.

.. code-block:: bash

   # Without SGID
   $ mkdir project; chmod 770 project; chgrp devteam project
   $ touch project/file1; ls -l project/file1
   -rw-r--r-- 1 alice alice 0 Jul 15 12:00 project/file1
   # file1 is owned by group "alice" (Alice's UPG) — not "devteam"!

   # With SGID
   $ chmod g+s project
   $ ls -ld project
   drwxrws--- 2 root devteam 4096 Jul 15 12:00 project
   $ touch project/file2; ls -l project/file2
   -rw-r--r-- 1 alice devteam 0 Jul 15 12:00 project/file2
   # file2 is owned by group "devteam" — as intended!

Furthermore, subdirectories created inside an SGID directory **automatically
inherit the SGID bit**:

.. code-block:: bash

   $ mkdir project/subdir
   $ ls -ld project/subdir
   drwxrws--- 2 alice devteam 4096 Jul 15 12:00 project/subdir
   # SGID bit (s) propagated automatically!

This inheritance makes SGID directories the standard mechanism for shared
project spaces on Unix systems.

**Combining SGID with ACLs:**

The SGID directory bit works synergistically with **default ACLs** (section
3.5). The SGID bit ensures group ownership inheritance; default ACLs ensure
permission inheritance. Together, they create a fully collaborative
environment where every file is automatically accessible to the team.

3.4.4 The Sticky Bit — ``chmod o+t`` (1000)
=============================================

**On a directory:**

The sticky bit (historically called the "restricted deletion flag") restricts
file deletion within a directory so that **only the file owner, the directory
owner, or root** can delete or rename files. Without the sticky bit, any
user with write permission on a directory can delete any file within it.

**The canonical example — ``/tmp``:**

.. code-block:: bash

   $ ls -ld /tmp
   drwxrwxrwt 1 root root 4096 Jul 15 12:00 /tmp

The ``t`` in the others execute position (``rwt`` instead of ``rwx``)
indicates the sticky bit is set. ``/tmp`` is world-writable (``777``), but
only the owner of a file can delete their own files.

**Demonstration:**

.. code-block:: bash

   # Create a shared directory without sticky bit
   $ mkdir /shared/scratch
   $ chmod 777 /shared/scratch
   $ ls -ld /shared/scratch
   drwxrwxrwx 2 root root 4096 Jul 15 12:00 /shared/scratch

   # Alice creates a file
   $ su alice -c 'touch /shared/scratch/alice.txt'

   # Bob can delete Alice's file
   $ su bob -c 'rm /shared/scratch/alice.txt'
   # succeeds! (Bob has w on the directory, file ownership doesn't matter)

   # Now add the sticky bit
   $ chmod o+t /shared/scratch
   $ ls -ld /shared/scratch
   drwxrwxrwt 2 root root 4096 Jul 15 12:00 /shared/scratch

   # Alice creates another file
   $ su alice -c 'touch /shared/scratch/alice.txt'

   # Bob tries to delete it
   $ su bob -c 'rm /shared/scratch/alice.txt'
   rm: cannot remove '/shared/scratch/alice.txt': Operation not permitted

**On a file (historical):**

The sticky bit on **executable files** was originally used by early Unix
systems to keep the program's text (code) segment in swap space for faster
loading—hence the name "sticky." Modern Linux ignores the sticky bit on
regular files (it has no effect). The kernel's virtual memory subsystem and
disk cache render this historical optimisation obsolete.

**Practical applications:**

- ``/tmp`` and ``/var/tmp`` — the sticky bit is **always** set on these.
- ``/dev/shm`` — shared memory, world-writable with sticky bit.
- Any shared directory for team collaboration (e.g., ``/shared/team``).

3.4.5 Setting Special Bits with ``chmod``
===========================================

**Symbolic syntax:**

.. code-block:: bash

   # SUID
   chmod u+s executable

   # SGID
   chmod g+s executable_or_directory

   # Sticky bit
   chmod o+t shared_directory

   # Multiple
   chmod u+s,g+s,o+t myfile

   # Remove
   chmod u-s g-s o-t myfile

**Octal syntax (four-digit):**

The special bits form the first (most significant) octal digit:

.. code-block:: bash

   # 4755 = SUID + rwxr-xr-x
   chmod 4755 program      # -rwsr-xr-x

   # 2755 = SGID + rwxr-xr-x
   chmod 2755 shared_dir   # drwxr-sr-x  (or -rwxr-sr-x for files)

   # 1755 = Sticky + rwxr-xr-x
   chmod 1755 shared_dir   # drwxr-xr-t

   # 6777 = SUID + SGID + rwxrwxrwx (dangerous!)
   chmod 6777 exploit      # DO NOT USE THIS

   # Remove special bits
   chmod 0755 normal_file  # Leading 0 = no special bits

**Verification:**

.. code-block:: bash

   # Check with stat
   $ stat -c "%a %A %n" /usr/bin/passwd
   4755 -rwsr-xr-x /usr/bin/passwd

   # Or with find
   $ find /usr/bin -perm /6000 -type f 2>/dev/null
   /usr/bin/passwd
   /usr/bin/su
   /usr/bin/sudo
   /usr/bin/pkexec
   /usr/bin/newgrp
   /usr/bin/gpasswd
   /usr/bin/chsh
   /usr/bin/chfn
   /usr/bin/mount
   /usr/bin/umount

(Note: these are the classic SUID/SGID binaries found on most Linux systems.
The exact list varies by distribution.)

3.4.6 Security Implications — A Deeper Look
=============================================

**The principle of least privilege and SUID:**

Every SUID/SGID binary on a system represents a potential privilege
escalation path. The system administrator should:

1. **Audit regularly**:
   .. code-block:: bash

      # Comprehensive SUID/SGID audit
      # find / -type f \( -perm -4000 -o -perm -2000 \) -exec ls -la {} \; \
        2>/dev/null | tee /tmp/privileged-binaries.txt

2. **Remove unnecessary SUID bits**:
   Many distributions ship with SUID binaries that may not be needed.
   For example, if your users don't need to mount devices manually,
   remove SUID from ``mount`` and ``umount``:

   .. code-block:: bash

      # chmod u-s /usr/bin/mount /usr/bin/umount

3. **Use capabilities instead** (modern replacement):
   Linux **capabilities** (``man 7 capabilities``) allow fine-grained
   privileges without full SUID root. For example, ``ping`` traditionally
   needed SUID root to open raw sockets. Modern systems use:

   .. code-block:: bash

      $ getcap /usr/bin/ping
      /usr/bin/ping = cap_net_raw+ep

   This gives ``ping`` only the ``CAP_NET_RAW`` capability—raw socket
   access—and nothing else. Capabilities are the modern, granular
   replacement for the all-or-nothing SUID root model.

4. **Watch for SUID on non-root-owned files**:
   An SUID binary owned by a non-root user is extremely suspicious. Any
   user who can modify that binary gains the owner's privileges.

   .. code-block:: bash

      # Find SUID files not owned by root
      # find / -perm -4000 -type f ! -user root -exec ls -la {} \; 2>/dev/null

**The ``nosuid`` mount option:**

For filesystems that do not need SUID binaries (e.g., ``/tmp``,
``/home`` on some configurations, removable media), mount them with the
``nosuid`` option in ``/etc/fstab``:

.. code-block:: text

   /dev/sda1  /home  ext4  defaults,nosuid,nodev  0  2

This causes the kernel to **ignore** SUID and SGID bits on that filesystem
— a crucial hardening technique.

3.4.7 Summary
==============

*   **SUID (4000)**: Process runs with the file owner's EUID. Dangerous if
    misapplied. Kernel ignores SUID on shell scripts.
*   **SGID (2000)**: On files — process runs with the file group's EGID.
    On directories — new files/subdirs inherit the directory's group.
*   **Sticky bit (1000)**: On directories — only owners (and root) can
    delete/rename files. Essential for ``/tmp`` and shared spaces.
*   Use ``chmod u+s`` / ``chmod g+s`` / ``chmod o+t`` to set these bits.
*   Use four-digit octal (e.g., ``4755``) to set special bits simultaneously.
*   Audit SUID/SGID binaries regularly. Reduce their number where possible.
*   Prefer Linux capabilities (``getcap``/``setcap``) over SUID root for
    fine-grained privilege separation.
*   Mount non-essential filesystems with ``nosuid``.
