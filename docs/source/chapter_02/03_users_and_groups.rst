Understanding Users and Groups
===============================

Linux is a multiuser operating system from the ground up.  Its security
model — the rules that determine who can read, write, or execute any file
on the system — rests on the twin concepts of *users* and *groups*.  Before
you can understand file permissions, you must understand how Linux identifies
the person (or process) making a request.

.. contents:: :local:
   :depth: 2


The Multi‑User Design of Linux
------------------------------

When Thompson and Ritchie designed Unix at Bell Labs in the early 1970s, they
built it for a department‑sized PDP‑11 minicomputer shared by multiple
researchers via serial terminals.  The system had to isolate one user's files
from another's and prevent a buggy (or malicious) program from corrupting the
entire machine.  The solution — user accounts, groups, and permission bits —
was so elegant that it remains essentially unchanged in modern Linux.

Every process that runs on a Linux system runs *as* a particular user and
*belongs to* a set of groups.  The kernel enforces access control based on
these identities.  Even system services like ``sshd`` or ``nginx`` run as
dedicated, unprivileged users (often named after the service) so that a
compromise of the service does not hand over full control of the machine.


The ``/etc/passwd`` File
------------------------

The primary database of user accounts is the plain‑text file
``/etc/passwd``.  Despite its name, it does not (on modern systems) contain
passwords — those migrated to ``/etc/shadow`` long ago.  Each line in
``/etc/passwd`` represents one user and has seven colon‑separated fields:

::

   username:password:UID:GID:GECOS:home_directory:shell

Let us dissect a typical line:

.. code-block:: text

   alice:x:1001:1001:Alice Example,,,:/home/alice:/bin/bash

=============  ============================================================
Field          Meaning
=============  ============================================================
``alice``      Login name.  Case‑sensitive; conventionally all lowercase.
``x``          Placeholder for the password hash.  ``x`` means the actual
               hash is in ``/etc/shadow``.  An empty field (``::``) would
               mean no password is required — a serious security risk.
``1001``       User ID (UID).  0 is reserved for ``root``.  1–999 (on most
               modern distributions) are system accounts.  1000 and above
               are regular ("human") users.
``1001``       Primary Group ID (GID).  The group whose permissions apply
               when the user creates a file.
``Alice Example,,,``  GECOS field.  A legacy name (General Electric
               Comprehensive Operating Supervisor) that now stores the
               user's full name and optionally room number, work phone,
               and home phone, separated by commas.
``/home/alice``  Home directory.  The user's personal directory, set at
               login time.
``/bin/bash``  Login shell.  The program launched when the user logs in.
               ``/sbin/nologin`` or ``/bin/false`` are used for service
               accounts that should never have interactive shell access.
=============  ============================================================

You can safely view ``/etc/passwd`` with ``cat`` or ``less`` — it is
world‑readable, as many programs need to map UIDs to usernames and look up
home directories:

.. code-block:: bash

   cat /etc/passwd
   less /etc/passwd

To see your own entry:

.. code-block:: bash

   grep "^$(whoami):" /etc/passwd


The ``/etc/shadow`` File
------------------------

Password hashes were once stored directly in ``/etc/passwd``, but because the
file must be world‑readable, this made it trivially easy for any user to
extract hashes and run a password cracker against them.  Modern systems store
hashes in ``/etc/shadow``, which is readable only by root and the ``shadow``
group:

.. code-block:: bash

   $ ls -l /etc/shadow
   -rw-r----- 1 root shadow 1234 Jan 1 12:00 /etc/shadow

Each line has nine colon‑separated fields:

.. code-block:: text

   alice:$6$s4lt...$h4sh...:19500:0:99999:7:::

=======  ====================================================================
Field    Meaning
=======  ====================================================================
1        Login name
2        Encrypted password hash (``$6$`` = SHA‑512 on modern systems; ``!``
         or ``*`` means the account is locked)
3        Date of last password change (days since 1970‑01‑01)
4        Minimum days before password may be changed
5        Maximum days before password must be changed
6        Days before expiry to warn the user
7        Days after expiry before the account is disabled
8        Account expiration date (days since epoch)
9        Reserved field
=======  ====================================================================

You should never edit ``/etc/shadow`` by hand.  Use ``passwd`` to change
passwords, ``chage`` to manage aging, and ``usermod`` / ``useradd`` for
account management (covered in a later chapter on user administration).


The ``/etc/group`` File
-----------------------

Groups allow you to grant permissions to multiple users at once.  Each line
in ``/etc/group`` defines a group:

.. code-block:: text

   developers:x:1002:alice,bob,charlie

=============  ============================================================
Field          Meaning
=============  ============================================================
``developers``  Group name
``x``          Placeholder for group password (rarely used; group passwords
               are stored in ``/etc/gshadow``)
``1002``       Group ID (GID)
``alice,bob,charlie``  Comma‑separated list of supplementary members
=============  ============================================================

A user has a *primary group* (the GID in ``/etc/passwd``) and zero or more
*supplementary groups* (the comma‑separated list in ``/etc/group``).  When a
user creates a file, it is owned by that user and the user's *primary group*.
Permissions for "group" refer to the file's owning group, not necessarily all
the groups the user belongs to.

System‑reserved GIDs follow the same convention as UIDs: groups below 1000
are typically system groups, and regular groups start at 1000 (though some
distributions use thresholds of 500 or 999 — check ``/etc/login.defs`` for
the exact values on your system).


Discovering Your Identity
--------------------------

Several lightweight commands tell you who you are and what groups you belong
to:

``whoami``
   Prints your current effective username:

   .. code-block:: bash

      $ whoami
      alice

``id``
   Prints your UID, GID, and all group memberships in detail:

   .. code-block:: bash

      $ id
      uid=1001(alice) gid=1001(alice) groups=1001(alice),27(sudo),1002(developers)

   ``id`` can also query another user (if you have permission):

   .. code-block:: bash

      $ id bob
      uid=1002(bob) gid=1002(bob) groups=1002(bob),1002(developers)

``groups``
   Prints just the group names:

   .. code-block:: bash

      $ groups
      alice sudo developers

``who`` and ``w``
   Show who is currently logged in and what they are doing:

   .. code-block:: bash

      $ who
      alice   tty1         2025-07-11 09:15
      bob     pts/0        2025-07-11 09:30 (192.168.1.50)

   ``w`` gives the same information plus the current process each user is
   running and the system load average.


Switching Users with ``su``
----------------------------

The ``su`` (substitute user / switch user) command starts a shell as another
user.  Without arguments, it defaults to ``root``:

.. code-block:: bash

   su              # Start a root shell (asks for root's password)
   su -            # Start a root *login* shell
   su - alice      # Start a login shell as alice

The hyphen (``-``) is critically important:

* ``su`` without ``-`` changes the effective user ID but keeps the original
  user's environment: ``$HOME``, ``$PATH``, and the current working directory
  remain unchanged.  This can lead to subtle problems — for example, running
  root commands with a user's ``$PATH`` that does not include ``/sbin``.
* ``su -`` (or ``su -l``) simulates a full login: it changes to the target
  user's home directory, resets environment variables, and sources the
  target's login scripts (``.profile``, ``.bashrc``, etc.).

.. tip::

   Unless you have a specific reason not to, **always use** ``su -`` when
   switching to root.  The clean environment avoids many hard‑to‑debug
   issues.

You may also run a single command as another user with ``-c``:

.. code-block:: bash

   su -c 'whoami' alice       # Run 'whoami' as alice
   su -c 'apt update'         # Run 'apt update' as root (prompts for root password)


Privilege Escalation with ``sudo``
-----------------------------------

``sudo`` (superuser do) is the modern alternative to ``su``.  Instead of
requiring the target user's password, ``sudo`` asks for *your own* password
and then checks whether you are authorised — via ``/etc/sudoers`` — to run
the requested command.

Basic usage:

.. code-block:: bash

   sudo command

``sudo`` runs ``command`` as ``root`` by default.  To run as a different
user, use ``-u``:

.. code-block:: bash

   sudo -u www-data touch /var/www/cache/refresh

Key options:

``-i``
   Start an interactive login shell as the target user (equivalent to
   ``su -`` but via ``sudo``):

   .. code-block:: bash

      sudo -i

``-s``
   Start a shell as the target user but keep the current environment
   (equivalent to ``su`` without the hyphen).

``-l``, ``--list``
   List the commands your current ``sudo`` configuration allows:

   .. code-block:: bash

      sudo -l

``-v``
   Extend the ``sudo`` timeout (refresh the cached credentials) without
   running a command.  By default, ``sudo`` caches your authentication for a
   few minutes.

``-k``
   Invalidate the cached credentials, forcing ``sudo`` to ask for your
   password on the next use.

The ``/etc/sudoers`` file controls ``sudo`` access.  **Never edit it
directly** — always use ``visudo``, which validates the syntax before saving
and prevents lock‑outs caused by a malformed file:

.. code-block:: bash

   sudo visudo

A typical ``sudoers`` entry looks like:

.. code-block:: text

   alice   ALL=(ALL:ALL) ALL

This grants ``alice`` the ability to run any command, as any user, on any
host.  The ``sudo`` group (on Debian/Ubuntu) or ``wheel`` group (on
RHEL/Fedora) is commonly used to grant admin access:

.. code-block:: text

   # Debian/Ubuntu style
   %sudo   ALL=(ALL:ALL) ALL

   # RHEL/Fedora style
   %wheel  ALL=(ALL:ALL) ALL

A user in the relevant group can then use ``sudo`` without an individual
``sudoers`` entry.  Add a user to the ``sudo`` group with:

.. code-block:: bash

   sudo usermod -aG sudo alice     # Debian/Ubuntu
   sudo usermod -aG wheel alice    # RHEL/Fedora


Distribution Differences: Debian vs. RHEL
------------------------------------------

The two largest Linux families handle the root account differently, and it is
worth understanding the rationale behind each approach.

**Debian / Ubuntu:**

* During installation, if you set a root password, the root account is
  enabled with that password and ``sudo`` is not automatically configured.
* If you leave the root password blank, the root account is *locked*
  (``/etc/shadow`` contains a ``!`` for root) and the first user created is
  added to the ``sudo`` group.  All administrative tasks must use ``sudo``.
* This is the default on Ubuntu desktop and most Debian derivatives.  The
  reasoning: forcing the use of ``sudo`` creates an audit trail (commands
  are logged) and reduces the risk of accidentally running a destructive
  command in a root shell.

**RHEL / Fedora / CentOS:**

* The root account is always enabled (you set a root password during
  installation).
* A user created during installation is offered membership in the ``wheel``
  group, which grants ``sudo`` access if the ``wheel`` line in
  ``/etc/sudoers`` is uncommented.
* Administrators may choose to use ``su -`` to become root or ``sudo`` —
  both are available.

.. note::

   Both approaches are valid.  The Debian model is arguably more secure for
   newcomers; the RHEL model gives experienced administrators more
   flexibility.  When writing scripts or documentation intended for both
   families, use ``sudo`` — it works everywhere that ``sudo`` is installed
   and configured.


Practical Exercises
-------------------

#. Run ``cat /etc/passwd`` and find your own entry.  Identify each of the
   seven fields.  What is your UID?  What is your login shell?

#. Run ``id`` and ``groups``.  Are there any supplementary groups you did not
   know you belonged to?

#. Use ``sudo -l`` to see what commands your account is authorised to run as
   root.

#. Become root with ``sudo -i``.  What changed in your prompt?  Run ``pwd``
   — where are you now?  Run ``echo $HOME``.  Exit the root shell with
   ``exit`` or :kbd:`Ctrl-d`.

#. Compare ``sudo -i`` and ``sudo -s``.  What differences do you notice in
   the environment?  (Use ``pwd``, ``echo $HOME``, and ``env | sort`` in
   each shell to compare.)

#. Examine ``/etc/group``.  Find the entry for the ``sudo`` or ``wheel``
   group.  Is your username listed?
