.. _app-b-encryption:

------------------------------------------------------------------------------
Encryption (GPG, LUKS, OpenSSL, SSH)
------------------------------------------------------------------------------

------------------------------------------------------------------------------
GPG (GNU Privacy Guard)
------------------------------------------------------------------------------

GPG implements the OpenPGP standard (RFC 4880) for encryption and signing.

.. rubric:: Key Management

.. list-table:: GPG Key Management Commands
   :header-rows: 1
   :widths: 30 35 35

   * - Command
     - Example
     - Description
   * - ``--gen-key``
     - ``gpg --gen-key``
     - Interactive key generation (RSA 3072 default)
   * - ``--full-generate-key``
     - ``gpg --full-generate-key``
     - Full control over key type, size, expiry
   * - ``--list-keys``
     - ``gpg --list-keys``
     - List all public keys in the keyring
   * - ``--list-secret-keys``
     - ``gpg --list-secret-keys``
     - List private keys
   * - ``-k``
     - ``gpg -k alice@example.com``
     - Search/display specific public key
   * - ``--export``
     - ``gpg --export -a alice@example.com > pubkey.asc``
     - Export public key (``-a`` = ASCII-armored)
   * - ``--export-secret-keys``
     - ``gpg --export-secret-keys -a alice > privkey.asc``
     - Export private key (**backup securely**)
   * - ``--import``
     - ``gpg --import pubkey.asc``
     - Import a key
   * - ``--keyserver``
     - ``gpg --keyserver keyserver.ubuntu.com --recv-keys KEYID``
     - Receive key from keyserver
   * - ``--send-keys``
     - ``gpg --keyserver keyserver.ubuntu.com --send-keys KEYID``
     - Upload public key to keyserver
   * - ``--delete-key``
     - ``gpg --delete-key alice@example.com``
     - Delete public key
   * - ``--delete-secret-keys``
     - ``gpg --delete-secret-keys alice``
     - Delete private key
   * - ``--edit-key``
     - ``gpg --edit-key alice@example.com``
     - Interactive key editing (add UID, set expiry, sign keys)
   * - ``--fingerprint``
     - ``gpg --fingerprint KEYID``
     - Display key fingerprint (for verification)

.. rubric:: Encryption & Decryption

.. list-table:: GPG Encrypt/Decrypt/Sign
   :header-rows: 1
   :widths: 30 35 35

   * - Command
     - Example
     - Description
   * - ``-e`` / ``--encrypt``
     - ``gpg -e -r alice@example.com file.txt``
     - Encrypt file for recipient
   * - ``-d`` / ``--decrypt``
     - ``gpg -d file.txt.gpg``
     - Decrypt file (output to stdout)
   * - ``-o`` / ``--output``
     - ``gpg -o plain.txt -d file.txt.gpg``
     - Decrypt with explicit output file
   * - ``-s`` / ``--sign``
     - ``gpg -s file.txt``
     - Sign file (produces ``file.txt.gpg``)
   * - ``--clearsign``
     - ``gpg --clearsign file.txt``
     - Clearsign (ASCII-armored, original text readable)
   * - ``-b`` / ``--detach-sign``
     - ``gpg -b file.txt``
     - Detached signature (``file.txt.sig``)
   * - ``--verify``
     - ``gpg --verify file.txt.sig file.txt``
     - Verify detached signature
   * - ``-c`` / ``--symmetric``
     - ``gpg -c file.txt``
     - Symmetric encryption (password-based, no key needed)

.. rubric:: GPG Agent & Caching

.. code-block:: bash

   # GPG agent caches passphrase; configure in ~/.gnupg/gpg-agent.conf:
   # default-cache-ttl 3600
   # max-cache-ttl 86400

   # Reload agent after config change
   gpg-connect-agent reloadagent /bye

   # Kill agent (forgets cached passphrases)
   gpgconf --kill gpg-agent

------------------------------------------------------------------------------
LUKS (Linux Unified Key Setup)
------------------------------------------------------------------------------

LUKS is the standard for full-disk encryption on Linux.

.. rubric:: Creating and opening a LUKS volume

.. code-block:: bash

   # 1. Partition or create a file to use as the volume
   dd if=/dev/zero of=luks_volume.img bs=1M count=512  # 512 MB test volume
   # Or use a real partition: /dev/sdb1

   # 2. Format with LUKS
   sudo cryptsetup luksFormat /dev/sdb1
   # WARNING: This ERASES all data on the device

   # 3. Open (map) the LUKS container
   sudo cryptsetup open /dev/sdb1 my_encrypted_volume

   # 4. Create a filesystem
   sudo mkfs.ext4 /dev/mapper/my_encrypted_volume

   # 5. Mount
   sudo mount /dev/mapper/my_encrypted_volume /mnt/secure

   # 6. Close
   sudo umount /mnt/secure
   sudo cryptsetup close my_encrypted_volume

.. rubric:: Key management

.. list-table:: LUKS Key Management
   :header-rows: 1
   :widths: 30 35 35

   * - Command
     - Example
     - Description
   * - ``luksAddKey``
     - ``sudo cryptsetup luksAddKey /dev/sdb1``
     - Add a new passphrase (up to 8 slots)
   * - ``luksRemoveKey``
     - ``sudo cryptsetup luksRemoveKey /dev/sdb1``
     - Remove a passphrase
   * - ``luksChangeKey``
     - ``sudo cryptsetup luksChangeKey /dev/sdb1 -S 1``
     - Change passphrase in slot 1
   * - ``luksKillSlot``
     - ``sudo cryptsetup luksKillSlot /dev/sdb1 2``
     - Wipe slot 2 (even without knowing its passphrase — if you have another)
   * - ``luksDump``
     - ``sudo cryptsetup luksDump /dev/sdb1``
     - Show LUKS header info (cipher, hash, slots used)
   * - ``luksHeaderBackup``
     - ``sudo cryptsetup luksHeaderBackup /dev/sdb1 --header-backup-file backup.img``
     - Backup LUKS header (critical for recovery)
   * - ``luksHeaderRestore``
     - ``sudo cryptsetup luksHeaderRestore /dev/sdb1 --header-backup-file backup.img``
     - Restore LUKS header from backup
   * - ``isLuks``
     - ``sudo cryptsetup isLuks /dev/sdb1 && echo "Is LUKS"``
     - Check if a device is LUKS-encrypted
   * - ``luksUUID``
     - ``sudo cryptsetup luksUUID /dev/sdb1``
     - Show/set UUID of LUKS device

.. rubric:: Auto-mounting LUKS at boot (``/etc/crypttab``)

.. code-block:: text

   # /etc/crypttab syntax:
   # <target_name>  <source_device>  <key_file>  <options>

   my_secure  /dev/sdb1  /root/luks-keyfile  luks,discard
   # Or with password prompt:
   my_secure  /dev/sdb1  none                luks

.. code-block:: bash

   # Generate a key file (128 random bytes)
   sudo dd if=/dev/urandom of=/root/luks-keyfile bs=1024 count=4
   sudo chmod 0400 /root/luks-keyfile

   # Add keyfile as an additional passphrase
   sudo cryptsetup luksAddKey /dev/sdb1 /root/luks-keyfile

.. rubric:: LUKS performance

.. list-table:: Common cipher/hash combinations
   :header-rows: 1
   :widths: 20 30 30 20

   * - Cipher
     - Mode
     - Hash
     - Speed
   * - ``aes-xts-plain64``
     - XTS
     - sha256
     - Fast (hardware AES on most CPUs)
   * - ``aes-cbc-essiv:sha256``
     - CBC + ESSIV
     - sha256
     - Slower, older default
   * - ``twofish-xts-plain64``
     - XTS
     - sha512
     - Slower but no hardware acceleration; high security margin

   # Check current cipher:
   sudo cryptsetup luksDump /dev/sdb1 | grep Cipher

   # Benchmark ciphers:
   cryptsetup benchmark

------------------------------------------------------------------------------
OpenSSL Quick Reference
------------------------------------------------------------------------------

.. list-table:: OpenSSL command categories
   :header-rows: 1
   :widths: 25 75

   * - Sub-command
     - Purpose
   * - ``openssl genrsa``
     - Generate RSA private key
   * - ``openssl rsa``
     - RSA key management (view, convert, extract public)
   * - ``openssl req``
     - Certificate Signing Request (CSR) generation
   * - ``openssl x509``
     - X.509 certificate management (view, sign, convert)
   * - ``openssl s_client``
     - SSL/TLS test client (connect to HTTPS server)
   * - ``openssl s_server``
     - SSL/TLS test server
   * - ``openssl enc``
     - Symmetric encryption (AES, ChaCha20, etc.)
   * - ``openssl dgst``
     - Calculate/verify digests (md5, sha256, sha512)
   * - ``openssl speed``
     - Benchmark crypto operations

.. rubric:: Essential one-liners

.. code-block:: bash

   # Generate RSA private key (2048-bit)
   openssl genrsa -out key.pem 2048

   # Extract public key
   openssl rsa -in key.pem -pubout -out pubkey.pem

   # Generate a CSR (requires key first)
   openssl req -new -key key.pem -out csr.pem

   # Generate a self-signed certificate (10 years)
   openssl req -x509 -sha256 -nodes -days 3650 -key key.pem -out cert.pem

   # View certificate details
   openssl x509 -in cert.pem -text -noout

   # Connect to an HTTPS server and show certificate
   openssl s_client -connect example.com:443 -showcerts

   # Check expiration dates on remote server
   openssl s_client -connect example.com:443 -servername example.com 2>/dev/null | \
     openssl x509 -noout -dates

   # Symmetric encrypt a file (AES-256-CBC)
   openssl enc -aes-256-cbc -salt -in plain.txt -out encrypted.enc

   # Decrypt
   openssl enc -d -aes-256-cbc -in encrypted.enc -out plain.txt

   # Compute SHA256 hash
   openssl dgst -sha256 file.txt

   # Base64 encode/decode
   echo -n "hello" | openssl base64
   echo "aGVsbG8=" | openssl base64 -d

------------------------------------------------------------------------------
SSH Key Management
------------------------------------------------------------------------------

.. list-table:: SSH Key Commands
   :header-rows: 1
   :widths: 30 35 35

   * - Command
     - Example
     - Description
   * - ``ssh-keygen``
     - ``ssh-keygen -t ed25519 -C "my_key"``
     - Generate SSH key pair (ED25519 recommended over RSA)
   * - ``ssh-keygen -p``
     - ``ssh-keygen -p -f ~/.ssh/id_ed25519``
     - Change passphrase on existing key
   * - ``ssh-copy-id``
     - ``ssh-copy-id user@server``
     - Copy public key to server's ``~/.ssh/authorized_keys``
   * - ``ssh-add``
     - ``ssh-add ~/.ssh/id_ed25519``
     - Add key to SSH agent (``-l`` to list, ``-D`` to clear all)
   * - ``ssh-keyscan``
     - ``ssh-keyscan -t ed25519 server.example.com``
     - Fetch server's public host key
   * - ``ssh-keygen -R``
     - ``ssh-keygen -R server.example.com``
     - Remove host key from ``known_hosts``
   * - ``ssh-keygen -F``
     - ``ssh-keygen -F server.example.com``
     - Find host key in ``known_hosts``

.. rubric:: Key types and strengths

.. list-table:: SSH Key Types
   :header-rows: 1
   :widths: 15 20 25 40

   * - Type
     - Default bits
     - Security level
     - Recommendation
   * - RSA
     - 3072 (``ssh-keygen -t rsa -b 4096``)
     - Strong (factoring)
     - Legacy compatibility; use ED25519 for new keys
   * - ECDSA
     - 256, 384, 521
     - Strong (elliptic curve)
     - Acceptable; NIST curves, some controversy
   * - ED25519
     - 256 (fixed)
     - Very strong
     - **Recommended** — fast, small, modern, secure
   * - DSA
     - 1024 (fixed)
     - Weak
     - **Deprecated** — do not use

.. rubric:: SSH Agent forwarding

.. code-block:: bash

   # In ~/.ssh/config:
   Host *.example.com
       ForwardAgent yes

   # At runtime:
   ssh -A user@jumphost

   # WARNING: Agent forwarding allows the remote server to use your local keys.
   # Only use with trusted hosts.

.. rubric:: SSH config file cheat sheet (``~/.ssh/config``)

.. code-block:: text

   # Host-specific settings
   Host bastion
       HostName bastion.example.com
       User alice
       Port 2222
       IdentityFile ~/.ssh/bastion_key
       ForwardAgent no

   Host webserver
       HostName 10.0.0.5
       User deploy
       ProxyJump bastion

   Host *.internal
       User admin
       ProxyJump bastion
       ServerAliveInterval 60
       ServerAliveCountMax 3

   # Defaults for all hosts
   Host *
       UseKeychain yes
       AddKeysToAgent yes
       IdentityFile ~/.ssh/id_ed25519
       IdentityFile ~/.ssh/id_rsa
