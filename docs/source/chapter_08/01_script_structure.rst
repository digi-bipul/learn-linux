.. highlight:: bash

================================
8.1 — Script Structure
================================

A shell script is a plain-text file containing a sequence of commands that the
shell interprets.  It is the simplest possible automation primitive: instead of
typing ten commands one after another, you write them once in a file and run the
file.  This section covers the anatomy of a well-structured script from the
first byte to the final newline.

--------------------------------
8.1.1 The Shebang (``#!``)
--------------------------------

Every script that is meant to be executed directly should begin with a
**shebang** — the two-byte magic number ``#!`` followed by the absolute path to
an interpreter.

.. code-block:: bash

   #!/bin/bash
   echo "Hello, world"

When the kernel executes a file whose first two bytes are ``#!``, it reads the
remainder of the first line, strips any trailing arguments, and invokes that
interpreter with the script's path as an argument.  Conceptually:

.. code-block:: text

   $ ./myscript.sh
   → execve("./myscript.sh", ...)
   → kernel reads shebang → execve("/bin/bash", ["/bin/bash", "./myscript.sh"], ...)

**The shebang is required only for direct execution.** If you run a script with
an explicit interpreter (``bash myscript.sh``), the shebang is treated as a
comment and ignored.  But for standalone use (``./myscript.sh``), it is
mandatory.

**Shebang variants**

=============== ================================================== ==============
Shebang         Interpreter                                         Portable?
=============== ================================================== ==============
``#!/bin/bash`` Bash at the traditional location                    No — FreeBSD,
                                                                    NixOS, etc.
``#!/bin/sh``   POSIX shell (often a symlink to dash or bash)       Yes — expected
                                                                    on every Unix.
``#!/usr/bin/env bash``  Searches ``$PATH`` for the first ``bash``  Yes — works
                                                                    even when bash
                                                                    is not at
                                                                    ``/bin/bash``.
``#!/usr/bin/env python3``  Preferred for Python scripts            Yes
=============== ================================================== ==============

.. _shebang_env_vs_absolute:

``#!/usr/bin/env bash`` vs ``#!/bin/bash``
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

The ``env``-based form is the **modern recommended choice** for portable
scripts.  Here is why:

* On some systems (e.g., NixOS, FreeBSD, or custom Linux installations),
  ``bash`` may reside at ``/usr/bin/bash``, ``/usr/local/bin/bash``, or
  elsewhere.  Hard-coding ``#!/bin/bash`` will fail with a confusing
  ``No such file or directory`` error.
* ``/usr/bin/env bash`` finds ``bash`` wherever it lives in the user's
  ``$PATH``, just as the shell does when you type ``bash``.

**One subtlety:** ``/usr/bin/env`` itself must exist — and it does on every
modern POSIX system.  The only scenario where the absolute form is preferable
is when you need absolute certainty about which interpreter runs (e.g., in a
restricted, controlled environment like an embedded system).

.. note::

   **Best practice:** Use ``#!/usr/bin/env bash`` for scripts that may be
   shared across machines.  Use ``#!/bin/bash`` only when you control every
   target system.

--------------------------------
8.1.2 Comments
--------------------------------

Comments begin with ``#`` and extend to the end of the line.  Use them
liberally to explain *why*, not *what* — the code itself shows the what.

.. code-block:: bash

   #!/usr/bin/env bash
   # Author: Jane Smith
   # License: MIT
   # Purpose: Rotate Nginx access logs safely.
   #
   # Called from cron every hour.  Do NOT run manually while Nginx is serving.

   # --- Configuration ---
   LOG_DIR="/var/log/nginx"

There is no multi-line comment syntax in bash.  For block comments, use
``: '...'`` — the colon is a no-op built-in, and the single-quoted string is
its argument (never evaluated):

.. code-block:: bash

   : '
   This is a block comment.
   Everything between the single quotes is ignored.
   Useful for temporarily disabling large sections.
   '

But prefer a series of ``#`` lines for clarity; the ``: '...'`` trick is
invisible to readers who do not know it.

--------------------------------
8.1.3 Execution Permissions and ``chmod``
--------------------------------

A script is just text.  To make it executable, you must set the **execute bit**:

.. code-block:: bash

   chmod +x myscript.sh    # Add execute for owner, group, others
   chmod 755 myscript.sh   # rwxr-xr-x — classic for scripts
   chmod 700 myscript.sh   # rwx------ — only owner can run

**What the execute bit actually does:** It tells the kernel that the file is a
valid executable candidate.  When you type ``./myscript.sh``, the kernel checks
the execute bit, reads the shebang, and dispatches execution to the specified
interpreter.  Without the execute bit, you get:

.. code-block:: text

   $ ./myscript.sh
   bash: ./myscript.sh: Permission denied

The script's **read bit** is also needed if the interpreter needs to read the
file (which it does).  So effective permissions should be at least ``r-x``.
``755`` is the standard.

--------------------------------
8.1.4 ``$PATH`` Integration
--------------------------------

Typing ``./myscript.sh`` requires the ``./`` prefix — the shell needs an
explicit path.  To run your script like a system command (e.g., just
``myscript``), place it in a directory listed in your ``$PATH`` or add its
directory to ``$PATH``.

**Where to put personal scripts:**

=============== ==================================================
Location        Purpose
=============== ==================================================
``~/bin/``      Personal scripts, added by many distros by default
``~/.local/bin/`` Modern XDG-compliant alternative
``/usr/local/bin/`` System-wide scripts on a machine you control
``/opt/<package>/bin/`` Vendor scripts for third-party packages
=============== ==================================================

**Adding a directory to ``$PATH`` (in ``~/.bashrc`` or ``~/.profile``):**

.. code-block:: bash

   export PATH="$HOME/bin:$PATH"

The prepend ensures your personal scripts override system commands if there is
a name collision (use with care).

.. _antipattern_unsafe_path:

**Antipattern — relative path in PATH:**

.. code-block:: bash

   export PATH=".:$PATH"   # NEVER DO THIS

A ``.`` in ``$PATH`` means the current working directory is searched for
executables.  If you ``cd`` into a directory containing a malicious file named
``ls``, typing ``ls`` will run the malicious file instead of ``/bin/ls``.
Always use absolute paths in ``$PATH``.

--------------------------------
8.1.5 Execution Contexts: Sourcing vs Running
--------------------------------

This is one of the most misunderstood concepts in shell scripting.  There are
**two fundamentally different ways** to run shell code:

**1. Execution (subshell)** — ``./myscript.sh`` or ``bash myscript.sh``

The kernel forks a new child process.  The script runs in a **subshell** — a
separate environment that inherits a copy of the parent's environment.  Any
variables set inside the script **do not** affect the parent shell.

**2. Sourcing (current shell)** — ``source myscript.sh`` or ``. myscript.sh``

The current shell reads the file and executes each line **in the current shell
process** — no fork happens.  Variables set or modified in the sourced script
persist in the calling shell.

**When to use each:**

+------------------------+--------------------------------+------------------------------------+
| Scenario               | Use execution (``./script``)    | Use sourcing (``source script``)   |
+========================+================================+====================================+
| Changing the current   | ❌ No                           | ✅ Yes                             |
| shell's directory      |                                |                                    |
+------------------------+--------------------------------+------------------------------------+
| Setting environment    | ❌ No (unless using ``export``  | ✅ Yes                             |
| variables for the      | in ``~/.profile``)              |                                    |
| interactive session    |                                |                                    |
+------------------------+--------------------------------+------------------------------------+
| Running a one-shot     | ✅ Yes — clean isolation        | ❌ Risk of polluting current       |
| task                   |                                |     shell                           |
+------------------------+--------------------------------+------------------------------------+
| Loading library        | ❌ Functions and aliases not    | ✅ Yes — this is how ``/etc/       |
| functions              | inherited                       | profile`` works                    |
+------------------------+--------------------------------+------------------------------------+

--------------------------------
8.1.6 Script Naming Conventions
--------------------------------

**File extensions are optional on Unix.**  The kernel does not care.  However,
conventions help humans and editors:

* ``.sh`` — traditional for shell scripts.
* ``.bash`` — explicit about the shell dialect.
* No extension — common for system scripts (e.g., ``/usr/bin/ffmpeg``).

**Inside the script** you may see a **docstring** convention using ``#``:

.. code-block:: bash

   #!/usr/bin/env bash
   #
   # backup-database.sh — Dump all MySQL databases to /backup.
   # Usage: ./backup-database.sh [--compress] [--dry-run]
   #

--------------------------------
8.1.7 What NOT to Do — Pitfalls in Script Structure
--------------------------------

**Antipattern 1: Missing shebang with execute bit**
Without a shebang the kernel does not know which interpreter to use.
Always include ``#!/usr/bin/env bash`` as the first line.

**Antipattern 2: DOS line endings (``\r\n``)**
The shebang becomes ``#!/usr/bin/env bash\r`` — the kernel tries to find an
interpreter called ``bash\r`` and fails.  Fix with ``dos2unix``.

**Antipattern 3: Putting ``.`` in ``$PATH``**
A security vulnerability.  Leads to hard-to-debug wrong-command-run errors.

**Antipattern 4: Sourcing a script that should be executed (or vice versa)**

**Antipattern 5: Not making scripts executable and relying on ``bash script``**

**Antipattern 6: Forgetting the trailing newline**

--------------------------------
8.1.8 Summary
--------------------------------

+------------------+-------------------------------------------------------+
| Concept          | Key Takeaway                                          |
+==================+=======================================================+
| Shebang          | ``#!/usr/bin/env bash`` for portability               |
+------------------+-------------------------------------------------------+
| Comments         | ``#`` for single lines                                |
+------------------+-------------------------------------------------------+
| Permissions      | ``chmod +x`` or ``chmod 755``                         |
+------------------+-------------------------------------------------------+
| ``$PATH``        | ``export PATH="$HOME/bin:$PATH"`` in ``~/.bashrc``    |
+------------------+-------------------------------------------------------+
| Sourcing vs Exec | Use ``source`` to modify current environment          |
+------------------+-------------------------------------------------------+
