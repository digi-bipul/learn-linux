.. _chapter-11-4:

============================================================
11.4 Podman & Systemd Integration
============================================================

Podman (Pod Manager) emerged as a response to the architectural limitations of Docker's
monolithic daemon. Developed by Red Hat (now part of IBM) and first released in 2018,
Podman is now the default container tool on Red Hat Enterprise Linux (RHEL) 9+,
Fedora, CentOS Stream, and many other enterprise Linux distributions. This section
explains the daemonless architecture, rootless execution, and the powerful **Quadlet**
system for integrating containers with systemd.

11.4.1 Daemonless and Rootless Architecture
============================================

Unlike Docker, Podman has **no central daemon**. Every ``podman`` command forks a new
child process that directly interacts with the kernel, the OCI runtime (``crun`` or
``runc``), and the container storage. This design has profound implications:

.. list-table:: Docker vs Podman Architecture
   :header-rows: 1
   :widths: 20 40 40

   * - Property
     - Docker
     - Podman
   * - Daemon
     - ``dockerd`` (long-running root process)
     - None (fork-exec model)
   * - User namespace
     - Requires explicit ``--userns=`` flag
     - Default on for rootless mode
   * - Rootless mode
     - Added in 19.03, requires ``dockerd-rootless-setuptool.sh``
     - Native from day one, no extra setup
   * - OCI runtime
     - ``runc`` (controlled by containerd)
     - ``crun`` (default, faster, C-based)
   * - Socket
     - ``/var/run/docker.sock`` (root-owned)
     - No socket by default; ``podman system service`` for API
   * - Systemd integration
     - Manual unit files or ``docker-compose``
     - **Quadlets** — native `.container` files
   * - Pod concept
     - No native pods (Kubernetes-style sidecars via compose)
     - Native pods via ``podman pod``
   * - Image pull policy
     - Always pulls latest tag by default
     - ``localhost`` images are never re-pulled unless forced

**How rootless containers work in Podman:**

1. **User namespace mapping:** Podman automatically creates a new user namespace.
   UID 0 inside the container is mapped to the invoking user's UID (e.g., 1001) on
   the host. This is done via ``/etc/subuid`` and ``/etc/subgid`` files:

   .. code-block:: bash

      # These files define subordinate UID/GID ranges for user namespaces
      cat /etc/subuid
      # alice:100000:65536
      # bob:165536:65536

   This means user ``alice`` can map up to 65,536 UIDs, starting at 100000, into
   a container's user namespace.

2. **Network namespace:** Rootless containers use **slirp4netns** or **pasta** for
   networking — a user-space NAT that does not require root privileges. This means
   rootless containers cannot create raw sockets or ICMP echo requests (``ping``)
   by default.

3. **Storage:** Container images and layers are stored under ``~/.local/share/containers/``
   for rootless Podman, not under ``/var/lib/docker/``.

**Validating the daemonless nature:**

.. code-block:: bash

   # No podman daemon is running
   ps aux | grep podman
   # (Only grep itself — no daemon)

   # Run a container — podman forks a child
   podman run -d --name test alpine sleep 3600
   ps aux | grep -E "(podman|sleep)"
   # The sleep process is a direct child of the shell, not a daemon

11.4.2 Podman's Native Pod Support
===================================

Podman introduced the concept of **pods** — groups of containers that share the same
network namespace, IPC namespace, and (optionally) PID namespace. This is directly
modelled after Kubernetes pods.

.. code-block:: bash

   # Create a pod
   podman pod create \
     --name web-pod \
     --publish 8080:80 \
     --network bridge

   # Add containers to the pod (they share 127.0.0.1)
   podman run -d --pod web-pod --name nginx nginx:alpine
   podman run -d --pod web-pod --name sidecar alpine sleep 3600

   # Verify they share a network namespace
   podman exec nginx ip addr
   podman exec sidecar ip addr   # Same IP address!

   # Inspect the pod
   podman pod inspect web-pod
   podman pod stats web-pod

   # Stop and remove the pod (removes all containers)
   podman pod stop web-pod
   podman pod rm web-pod

.. note::
   Pods are not a Kubernetes abstraction — they are a Podman-native feature. However,
   the pod concept means you can develop and test multi-container Kubernetes workloads
   locally without a cluster.

11.4.3 Podman Quadlets: Containers as Systemd Units
====================================================

**Quadlets** are the killer feature that makes Podman the preferred choice for
enterprise Linux. A Quadlet allows you to define a container with a simple
``.container`` file placed in ``/etc/containers/systemd/`` (or
``~/.config/containers/systemd/`` for user services). Podman's quadlet generator
translates these into native systemd ``.service`` units.

**Why Quadlets matter:**

Without Quadlets, running a container under systemd requires writing a hand-crafted
``.service`` unit file, managing ``ExecStartPre`` commands to pull images, handling
restart policies, and integrating with journald. With Quadlets, this is automatic.

**The translation pipeline:**

.. code-block:: none

   /etc/containers/systemd/
   └── my-app.container        # User writes this (20 lines)
        │
        ▼
   /run/systemd/generator/
   ├── my-app.service          # systemd unit (generated by quadlet)
   ├── my-app.volume           # Volume lifecycle
   └── my-app.network          # Network lifecycle
        │
        ▼
   systemctl start my-app.service  # Managed like any other service

**Anatomy of a .container file:**

.. code-block:: ini

   # my-app.container
   [Unit]
   Description=My Application Container
   After=network-online.target
   Wants=network-online.target

   [Container]
   Image=docker.io/nginx:1.27-alpine
   ContainerName=my-app
   PublishPort=8080:80
   Volume=my-app-data:/usr/share/nginx/html:Z
   Environment=NGINX_HOST=example.com
   Secret=my-tls-cert,type=mount
   Network=my-app-net
   Label=app=my-app
   Label=environment=production
   HealthCmd=curl -f http://localhost/health
   HealthInterval=30s
   Retries=3
   User=1000:1000

   # Resource limits via cgroups v2
   CPUQuota=50%
   MemoryMax=256M

   [Service]
   Restart=always
   RestartSec=5
   TimeoutStartSec=300

   [Install]
   WantedBy=multi-user.target

**Additional Quadlet types:**

.. list-table:: Quadlet File Types
   :header-rows: 1
   :widths: 15 35 50

   * - Extension
     - Purpose
     - Example
   * - ``.container``
     - Define a container (creates a ``.service`` unit)
     - ``web-app.container``
   * - ``.pod``
     - Define a pod (containers within share network)
     - ``backend.pod``
   * - ``.volume``
     - Define a named volume lifecycle
     - ``my-data.volume``
   * - ``.network``
     - Define a container network (bridge)
     - ``app-net.network``
   * - ``.kube``
     - Run a Kubernetes YAML as a systemd service
     - ``deployment.kube``

**Deploying with Quadlets:**

.. code-block:: bash

   # 1. Create the systemd quadlet directory
   sudo mkdir -p /etc/containers/systemd/

   # 2. Write your .container file
   sudo tee /etc/containers/systemd/nginx.container << 'EOF'
   [Unit]
   Description=NGINX Container
   After=network-online.target

   [Container]
   Image=docker.io/nginx:alpine
   PublishPort=8080:80
   Volume=nginx-html:/usr/share/nginx/html:Z

   [Service]
   Restart=always

   [Install]
   WantedBy=multi-user.target
   EOF

   # 3. Reload systemd (quadlet generator runs automatically)
   sudo systemctl daemon-reload

   # 4. Start and enable
   sudo systemctl start nginx.service
   sudo systemctl enable nginx.service

   # 5. Check logs
   journalctl -u nginx.service -f

   # 6. Update the container (change image tag, then restart)
   sudo systemctl restart nginx.service

**User-level Quadlets (no root required):**

.. code-block:: bash

   # Create user systemd directory
   mkdir -p ~/.config/containers/systemd/

   # Write a user container
   cat > ~/.config/containers/systemd/user-app.container << 'EOF'
   [Unit]
   Description=User Application Container

   [Container]
   Image=docker.io/alpine:latest
   ContainerName=user-app
   Exec=sleep infinity

   [Install]
   WantedBy=default.target
   EOF

   # Reload user daemon
   systemctl --user daemon-reload

   # Start
   systemctl --user start user-app.service

   # Enable on login
   systemctl --user enable user-app.service

11.4.4 Podman Secret Management
================================

Podman has a built-in secret store (unlike Docker, which relies on external solutions).
Secrets are stored in a memory-backed tmpfs and are never written to disk.

.. code-block:: bash

   # Create a secret from a file
   echo "s3cr3t!" > db_password.txt
   podman secret create db-password db_password.txt
   rm db_password.txt  # Source file can now be deleted

   # Create a secret from stdin
   echo "apikey123" | podman secret create api-key -

   # List secrets
   podman secret ls

   # Use a secret in a container
   podman run -d \
     --secret db-password,type=mount,target=/run/secrets/db_password \
     --secret api-key,type=env,target=API_KEY \
     --name my-app \
     my-app-image

   # Inside the container
   cat /run/secrets/db_password
   echo $API_KEY

   # Remove a secret
   podman secret rm db-password

.. warning::
   Secrets are only available to containers on the same host. For multi-host
   secrets, use an external vault (HashiCorp Vault, AWS Secrets Manager, etc.)
   and mount them at container start.

11.4.5 Podman Machine (macOS/Windows)
======================================

On non-Linux platforms, Podman runs inside a lightweight VM called ``podman machine``.
This is Podman's equivalent to Docker Desktop but open-source and without a GUI.

.. code-block:: bash

   # Create a default machine
   podman machine init

   # Start it
   podman machine start

   # Connect to the machine
   podman machine ssh

   # Set resources
   podman machine init --cpus 4 --memory 4096 --disk-size 50

   # Stop
   podman machine stop

11.4.6 Podman vs Docker: CLI Compatibility
===========================================

Podman is a **drop-in replacement** for Docker in almost all cases:

.. code-block:: bash

   # Alias docker to podman (many distros do this by default)
   alias docker=podman

   # All these work identically:
   podman pull nginx
   podman run -d -p 8080:80 nginx
   podman ps
   podman images
   podman exec -it <container> sh
   podman logs <container>
   podman compose up   # Podman also supports Compose!

   # Docker socket emulation (for tools that require /var/run/docker.sock):
   podman system service --time=0 unix:///tmp/podman.sock &
   DOCKER_HOST=unix:///tmp/podman.sock docker ps   # Works!

11.4.7 Why Enterprise Linux Prefers Podman
===========================================

Red Hat's strategic decision to make Podman the default container tool in RHEL 9+
is rooted in several architectural advantages:

1. **No daemon attack surface:** The absence of a root-owned daemon means there is
   no single process to compromise.
2. **Rootless by default:** In the zero-trust enterprise, containers should never run
   with elevated privileges. Podman's rootless mode is the default, not an opt-in.
3. **systemd native:** RHEL is systemd-centric. Quadlets integrate containers into
   the same management plane as every other service — no separate Docker Compose
   or Swarm infrastructure.
4. **CVE compliance:** Rootless execution significantly reduces the blast radius
   of container breakout CVEs.
5. **Kubernetes alignment:** Podman's pod abstraction and ``podman play kube``
   (which converts Kubernetes YAML to local containers) allow developers to test
   workloads locally before deploying to OpenShift or Kubernetes.

**Generating Kubernetes YAML from a running pod:**

.. code-block:: bash

   podman generate kube web-pod > web-pod.yaml
   # This creates a Pod spec that can be deployed on a Kubernetes cluster

11.4.8 Antipatterns
===================

.. admonition:: Antipattern: Ignoring Subordinate ID Ranges
   :class: warning

   Rootless Podman depends on ``/etc/subuid`` and ``/etc/subgid`` being configured
   correctly. If these files are missing or incomplete, rootless containers will
   fail with "could not find enough UIDs/GIDs" errors. Administrators migrating
   users from Docker to Podman must ensure these are set.

.. admonition:: Antipattern: Treating Quadlet .container Files Like Docker Compose
   :class: warning

   Quadlets are **systemd units**, not Compose files. They are designed for
   single-container services or simple pods. For complex multi-service
   applications, use ``podman-compose`` or Kubernetes.

11.4.9 Practical Exercises
==========================

**1. Rootless Container**

.. code-block:: bash

   # As a non-root user
   podman run -d --name rootless-test alpine sleep 3600

   # Verify no root processes
   ps aux | grep sleep
   # The sleep runs under your UID, not root

   # Check the user namespace mapping
   podman unshare cat /proc/self/uid_map

**2. Quadlet Deployment**

.. code-block:: bash

   # Create a simple HTTP server quadlet
   mkdir -p ~/.config/containers/systemd/
   cat > ~/.config/containers/systemd/httpserver.container << 'EOF'
   [Unit]
   Description=HTTP Test Server

   [Container]
   Image=docker.io/python:3.12-alpine
   PublishPort=8000:8000
   Exec=python3 -m http.server 8000
   WorkingDir=/data
   Volume=web-data:/data:Z

   [Service]
   Restart=on-failure

   [Install]
   WantedBy=default.target
   EOF

   systemctl --user daemon-reload
   systemctl --user start httpserver.service
   curl http://localhost:8000/

**3. Play Kubernetes YAML**

.. code-block:: bash

   # Create a simple pod spec
   cat > ~/test-pod.yaml << 'EOF'
   apiVersion: v1
   kind: Pod
   metadata:
     name: test-pod
   spec:
     containers:
     - name: nginx
       image: nginx:alpine
       ports:
       - containerPort: 80
   EOF

   # Run it locally with Podman
   podman play kube ~/test-pod.yaml
   podman pod ps
   podman play kube --down ~/test-pod.yaml
