.. _sec9_2:

###########################################################
9.2 Pluggable Authentication Modules (PAM)
###########################################################

Authentication on a Linux system is rarely a single operation. When a user
logs in via SSH, authenticates with ``sudo``, unlocks a screen saver, or
switches virtual consoles, every one of these actions passes through the
**Pluggable Authentication Modules (PAM)** framework. PAM decouples
authentication logic from applications, allowing system administrators to
configure password policies, biometric checks, hardware token verification,
and account restrictions in a single, centralized stack.

9.2.1 Architecture: The PAM Stack
==================================

PAM follows a **library-based** architecture. Applications are compiled
against ``libpam.so`` and call PAM functions (``pam_authenticate``,
``pam_acct_mgmt``, ``pam_open_session``, etc.). PAM consults
configuration files in ``/etc/pam.d/`` (or ``/etc/pam.conf`` on older
systems) to determine which **modules** to load and in what **order**.

Each configuration file corresponds to a **service** (e.g., ``sshd``,
``login``, ``sudo``, ``passwd``) and defines a **stack** of rules. A rule
has four fields:

::

    type    control    module_path    arguments

**Types (four management groups):**

1. ``auth`` — Verify identity (password, biometric, token).
2. ``account`` — Check account validity (not expired, allowed hours).
3. ``password`` — Update authentication tokens (password change).
4. ``session`` — Set up / tear down the user's session (mount home, log).

**Control values determine the stack's behaviour:**

+-------------------+----------------------------------------------------+
| Control           | Meaning                                            |
+===================+====================================================+
| ``required``      | Must succeed; if it fails, other modules still     |
|                   | run, but the final result is failure.              |
+-------------------+----------------------------------------------------+
| ``requisite``     | Must succeed; failure immediately returns failure  |
|                   | and skips later modules.                           |
+-------------------+----------------------------------------------------+
| ``sufficient``    | If this module succeeds, skip remaining modules    |
|                   | for this type (unless a prior ``required`` failed).|
+-------------------+----------------------------------------------------+
| ``optional``      | Module result is used only if no other module      |
|                   | determines the outcome.                            |
+-------------------+----------------------------------------------------+
| ``binding``       | (Linux-PAM extension) Like ``sufficient`` but also |
|                   | sets the return status. Rarely used today.         |
+-------------------+----------------------------------------------------+

Modern PAM also supports **control with value comparison**:

::

    auth    [success=ok new_authtok_reqd=ok ignore=ignore default=die] \
            pam_faillock.so

9.2.2 Essential PAM Modules
=============================

``pam_unix.so``
---------------
The traditional Unix password authenticator. It reads ``/etc/shadow``,
hashes the provided password, and compares it to the stored hash.

Common arguments:

- ``nullok`` — Allow blank passwords (highly discouraged; omit in production).
- ``sha512`` — Use SHA-512 hashing (default on modern systems).
- ``shadow`` — Use ``/etc/shadow`` for password storage.
- ``remember=N`` — Remember the last N passwords to prevent reuse.
  Stores history in ``/etc/security/opasswd``.

.. warning::
   ``pam_unix.so`` is the *backstop*. It should typically be the last
   ``auth`` module in the stack, acting as the final verifier when no
   other authentication method is configured.

``pam_cracklib.so`` / ``pam_pwquality.so``
-------------------------------------------
Password quality enforcement. ``pam_cracklib.so`` was the original module;
it has been superseded by ``pam_pwquality.so`` (install the ``libpwquality``
package) which reads ``/etc/security/pwquality.conf``.

Example configuration in ``/etc/security/pwquality.conf``:
::

    minlen = 14
    dcredit = -1       # At least one digit
    ucredit = -1       # At least one uppercase
    lcredit = -1       # At least one lowercase
    ocredit = -1       # At least one special character
    maxrepeat = 3      # No more than 3 identical consecutive characters
    difok = 8          # At least 8 characters must differ from old password
    enforce_for_root   # Apply policy to root as well

``pam_limits.so``
-----------------
Enforces resource limits defined in ``/etc/security/limits.conf`` and
``/etc/security/limits.d/*.conf``. This is the mechanism behind
``ulimit``-based restrictions processed at session start.

Example limits:
::

    @developers    hard    nproc           100
    @developers    hard    nofile          2048
    @web           soft    nofile          65536
    @web           hard    nofile          131072

``pam_faillock.so`` (Replacement for ``pam_tally2.so``)
--------------------------------------------------------
**Critical: ``pam_tally2.so`` is deprecated as of 2024 and removed from**
**shadow-utils 4.14+. Use ``pam_faillock.so``.**

``pam_faillock.so`` tracks failed login attempts and can lock accounts after
a threshold. It stores state in ``/var/run/faillock/`` (non-persistent) or
``/var/log/faillock/`` (persistent via ``dir=/var/log/faillock``).

Typical integration into ``/etc/pam.d/system-auth``:

::

    # Pre-auth: increment fail count
    auth    [default=die]    pam_faillock.so authfail deny=5 unlock_time=900
    auth    sufficient       pam_unix.so
    auth    required         pam_faillock.so authsucc

    # Account: check if account is locked
    account required         pam_faillock.so

    # Password: reset fail count on successful password change
    password required        pam_faillock.so

**Arguments:**
- ``deny=N`` — Lock after N consecutive failures (default: 3).
- ``unlock_time=N`` — Seconds until automatic unlock (0 = manual unlock only).
- ``audit`` — Log all failures to syslog.
- ``even_deny_root`` — Apply locking to root (use with extreme caution).

To manually unlock a user:
::

    faillock --user username --reset

``pam_google_authenticator.so``
-------------------------------
Provides TOTP (Time-based One-Time Password) as a second factor. Configure
in ``/etc/pam.d/sshd`` after the primary auth module:

::

    auth    required    pam_google_authenticator.so nullok

User initializes with:
::

    google-authenticator

This generates a QR code for the authenticator app and writes
``~/.google_authenticator``.

9.2.3 Modern FIDO2 / WebAuthn PAM Integration
==============================================

The passwordless future is here. In 2026, the **FIDO2/WebAuthn** standard
dominates enterprise authentication. Linux integrates FIDO2 through
``pam_u2f.so`` (provided by the ``libpam-u2f`` package or ``pam-fido2``
on Fedora/RHEL).

**Configuration:**

1. Install the package:
   ::

       sudo apt install libpam-u2f         # Debian/Ubuntu
       sudo dnf install pam-fido2           # Fedora/RHEL

2. Associate a FIDO2 token (YubiKey, SoloKey, TouchID) with a user:
   ::

       pamu2fcfg --user=alice > ~/.config/Yubico/u2f_keys

   This stores the key handle and public key for that user.

3. Add to ``/etc/pam.d/sshd`` (or ``/etc/pam.d/sudo``):
   ::

       auth    sufficient   pam_u2f.so
       auth    required     pam_unix.so

   With ``sufficient``, the FIDO2 token alone is enough; falling back to
   password-only if no token is present. For *passwordless* policy, use
   ``required`` and omit ``pam_unix.so``.

**Enterprise deployment in 2026:**

Large organizations manage FIDO2 keys centrally. Rather than per-user
``~/.config/Yubico/u2f_keys``, they use:

::

    auth    required   pam_u2f.so \
        authfile=/etc/ssh/u2f_keys \
        cue        # Show a cue (hint) when token is needed

The centralized ``authfile`` can be managed by Ansible or an Identity
Management system (FreeIPA, Active Directory with ``sssd``).

**Touch ID on Linux (2026):**

On Apple Silicon Macs running Asahi Linux or on Linux laptops with
fingerprint readers, ``pam_fprintd.so`` integrates with ``fprintd`` and
FIDO2 for biometric authentication. The ``libfprint`` project supports
over 100 fingerprint readers.

9.2.4 PAM and Containerized Environments
=========================================

In container environments, PAM can be bypassed because ``systemd-logind``
and the full PAM stack may not be present. For production containers,
consider:

- **``pambox``:** A minimal PAM implementation designed for containers.
- **``sssd`` in containers:** For enterprise IDM integration.
- **Avoiding PAM entirely:** Use ``nsenter`` with host PAM or rely on
  Kubernetes authentication (webhook tokens, OIDC) at the orchestration
  layer instead of container-level PAM.

9.2.5 Debugging PAM
====================

PAM failures manifest as "Authentication failure" with no further detail.
Enable debugging:

::

    # In /etc/pam.d/sshd or the relevant service:
    auth    [success=ok default=bad]    pam_unix.so    debug

    # Or globally via syslog:
    echo "auth.debug    /var/log/pam-debug.log" >> /etc/rsyslog.conf

Modern distributions also support ``pamtester`` for testing PAM stacks
without running the actual service:
::

    pamtester sshd alice authenticate

9.2.6 PAM and Compliance (2026)
================================

Enterprise compliance frameworks (PCI DSS v4.0, SOC 2, FedRAMP) require:

- **Account lockout after N failed attempts:** Use ``pam_faillock.so``.
- **Password complexity:** Use ``pam_pwquality.so``.
- **Password history:** Use ``pam_unix.so remember=24``.
- **Session recording:** Use ``pam_tty_audit.so`` to log all input/output
  on privileged TTY sessions.

**CIS Benchmark alignment:** The CIS Benchmark for Red Hat Enterprise Linux 9
and Ubuntu 22.04/24.04 both mandate specific PAM configurations. We cover
full CIS alignment in :ref:`Section 9.8 <sec9_8>`.
