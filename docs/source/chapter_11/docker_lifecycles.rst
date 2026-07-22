.. _chapter-11-3:

============================================================
11.3 Docker & Image Lifecycles
============================================================

Docker popularised containers by packaging the kernel primitives from §11.2 into a
coherent developer experience. While the underlying technology (namespaces, cgroups,
``pivot_root``) existed in Linux long before Docker's 2013 debut, Docker provided the
missing pieces: a portable image format, a build system, a registry protocol, and a
user-friendly CLI. This section examines the Docker architecture, image layering,
efficient build practices, networking abstractions, and declarative orchestration with
Docker Compose.

11.3.1 The Docker Daemon Architecture
======================================

Docker uses a **client-server (C/S) architecture** with a monolithic daemon:

.. code-block:: none

   ┌──────────────┐        HTTP/REST       ┌───────────────────────────┐
   │  docker CLI  │ ──────────────────────>│  dockerd (daemon)         │
   │  (client)    │<────────────────────── │  - Image management      │
   └──────────────┘     JSON response       │  - Container lifecycle   │
                                            │  - Volume management     │
                                            │  - Network management    │
                                            └───────┬───────────────────┘
                                                    │ gRPC
                                           ┌────────┴────────┐
                                           │  containerd     │
                                           │  (container     │
                                           │   supervisor)   │
                                           └────────┬────────┘
                                                    │
                                           ┌────────┴────────┐
                                           │  runc (OCI)     │
                                           │  (namespaces,   │
                                           │   cgroups, etc) │
                                           └─────────────────┘

Key components:

* **dockerd:** The background daemon. It listens on a Unix socket (``/var/run/docker.sock``)
  by default and optionally on TCP (not recommended without TLS). It manages images,
  containers, volumes, and networks.
* **containerd:** The industry-standard container supervisor (donated by Docker to CNCF).
  It handles image transfer, storage, and the execution lifecycle via the CRI API.
  Docker speaks to containerd via gRPC.
* **runc:** The OCI low-level runtime that actually creates the container.
* **docker-init (tini):** A minimal init process that runs as PID 1 inside the container
  to handle signal forwarding and zombie reaping.

.. warning::
   **Monolithic daemon antipattern:** Because ``dockerd`` is a single, long-running,
   root-owned process, it has been a high-value attack vector. A compromise of the
   Docker daemon gives an attacker root on the host. This architectural concern drove
   the industry towards daemonless alternatives like Podman (§11.4).

**The Docker socket problem:**

.. code-block:: bash

   ls -l /var/run/docker.sock
   # srw-rw---- 1 root docker 0 Mar 10 10:00 /var/run/docker.sock

Any user in the ``docker`` group has effective root access on the host — they can
mount the host filesystem, escape containers, and install kernel modules:

.. code-block:: bash

   docker run -v /:/hostroot -it ubuntu bash
   # Now inside the container:
   chroot /hostroot
   # You are root on the host.

.. admonition:: Security best practice
   :class: important

   Never add users to the ``docker`` group unless you fully trust them with root
   access. Use **rootless Docker** (available since Docker 19.03) or, preferably,
   switch to **Podman** (§11.4).

11.3.2 Container Images and Layers
===================================

A Docker image is a **stack of read-only layers** built using a union filesystem
(overlay2, aufs, or devicemapper). Each layer corresponds to an instruction in the
Dockerfile. The layers are shared and cached across images, making pulls and builds
efficient.

**The overlay2 filesystem:**

.. code-block:: none

   Container's view (merged):
   / → overlay mount
      ├── bin/     (from layer 5: RUN apt install)
      ├── etc/     (from layer 3: RUN apt update)
      ├── lib/     (from layer 2: RUN apt update)
      ├── usr/     (from base image: ubuntu:24.04)
      └── app/     (from layer 4: COPY app)
      └── /tmp     (read-write layer — container's changes)

   Lower layers (image layers):
   /var/lib/docker/overlay2/
   ├── <hash1>/diff/   ← ubuntu:24.04 base
   ├── <hash2>/diff/   ← RUN apt update
   ├── <hash3>/diff/   ← RUN apt install -y nginx
   ├── <hash4>/diff/   ← COPY index.html /usr/share/nginx/html
   └── <hash5>/diff/   ← RUN echo "done"

   Upper layer (container layer):
   /var/lib/docker/overlay2/<hash6>/diff/  ← writable

The **Copy-on-Write (CoW)** principle means that when a container modifies a file from
a lower layer, the file is copied up to the writable layer and then modified. The
original layer is untouched.

**Inspecting image layers:**

.. code-block:: bash

   docker history nginx:latest
   # IMAGE          CREATED       CREATED BY                                      SIZE
   # 2b7d6430f78d   2 weeks ago   /bin/sh -c #(nop)  CMD ["nginx" "-g" "daemon…  0B
   # <missing>      2 weeks ago   /bin/sh -c #(nop)  STOPSIGNAL SIGQUIT           0B
   # ...

   docker image inspect nginx:latest | jq '.[].RootFS'
   # {
   #   "Type": "layers",
   #   "Layers": [
   #     "sha256:...",
   #     "sha256:...",
   #   ]
   # }

11.3.3 Building Efficient Images
=================================

**Multi-stage builds** are the single most important technique for minimising image
size. The principle: use one stage to compile/build your application, then copy only
the runtime artifacts into a clean, minimal final stage.

**Before (bad — 1.2 GB image):**

.. code-block:: dockerfile

   # ❌ Antipattern: Build tools and runtime in the same image
   FROM ubuntu:24.04
   RUN apt update && apt install -y golang-go git make
   COPY . /src
   RUN cd /src && go build -o /app
   CMD ["/app"]

**After (good — 15 MB image):**

.. code-block:: dockerfile

   # Stage 1: Build
   FROM golang:1.23 AS builder
   WORKDIR /src
   COPY go.mod go.sum ./
   RUN go mod download
   COPY . .
   RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app .

   # Stage 2: Runtime
   FROM gcr.io/distroless/static-debian12:nonroot
   COPY --from=builder /app /app
   USER nonroot:nonroot
   CMD ["/app"]

Key optimisations:

* ``--ldflags="-s -w"``: Strip debug symbols and DWARF tables.
* ``CGO_ENABLED=0``: Produce a statically linked binary (no libc dependency).
* Distroless base images: No shell, no package manager, no utilities — only the
  application and its runtime libraries.
* ``COPY --from=builder``: Only the binary crosses stages.

**Layer ordering and cache busting:**

Docker caches each layer. If a layer changes, all subsequent layers are rebuilt.
Optimise by ordering instructions from least-to-most frequently changing:

.. code-block:: dockerfile

   FROM node:22-alpine AS builder

   # 1. Install system dependencies (rarely changes)
   RUN apk add --no-cache python3 make g++

   # 2. Copy dependency manifests (changes only on dependency update)
   COPY package.json package-lock.json ./
   RUN npm ci

   # 3. Copy source code (changes on every commit)
   COPY . .

   # 4. Build
   RUN npm run build

This way, a source-code change does not trigger a reinstall of dependencies.

**Other optimisation tips:**

* Use ``.dockerignore`` to exclude ``node_modules``, ``__pycache__``, ``.git``, etc.
* Use ``--no-install-recommends`` on apt-get to avoid pulling unnecessary packages.
* Combine ``RUN`` commands with ``&&`` to reduce layers (but balance with cache
  efficiency).
* Use ``DOCKER_BUILDKIT=1`` (enabled by default in Docker 24+) for parallel builds
  and secret mounting.

11.3.4 Docker Networking Abstractions
======================================

Docker provides five built-in network drivers:

.. list-table:: Docker Network Drivers
   :header-rows: 1
   :widths: 15 35 50

   * - Driver
     - Behaviour
     - Use Case
   * - ``bridge``
     - Default. Containers on the same bridge can communicate; NAT to host
       for external access.
     - Single-host container networking.
   * - ``host``
     - Container shares the host's network stack (no isolation).
     - Performance-sensitive apps (e.g., DPDK, low-latency).
   * - ``overlay``
     - Multi-host networking via VXLAN. Requires a key-value store (consul, etcd).
     - Docker Swarm or Kubernetes-like multi-host topologies.
   * - ``macvlan``
     - Assigns real MAC addresses to containers, making them directly reachable on
       the physical network.
     - Legacy apps that expect direct L2 access.
   * - ``none``
     - No networking. ``lo`` only.
     - Security sandboxes, offline processing.

**Bridge network deep dive:**

When you run a container without specifying ``--network``, Docker creates:

1. A **Linux bridge** (``docker0``, 172.17.0.0/16 by default) on the host.
2. A **veth pair** for each container — one end in the container's netns (``eth0``),
   the other plugged into ``docker0``.
3. **iptables NAT rules** (MASQUERADE) so that outbound traffic from the container
   appears to come from the host's IP.
4. **iptables DNAT rules** for published ports (``-p 8080:80``) to forward host
   traffic to the container.

.. code-block:: none

   Host Network Namespace
   ┌──────────────────────────────────────────────┐
   │  eth0 (physical: 192.168.1.10)               │
   │                                              │
   │  docker0 (bridge: 172.17.0.1/16)             │
   │    ├── veth-abc123 ──┐    ┌── veth-def456    │
   │    └─────────────────┤    ├──────────────────┘
   └──────────────────────┼────┼──────────────────┘
                          │    │
               Container A│    │Container B
               netns      │    │netns
               ┌──────────┘    └──────────┐
               │ eth0 (172.17.0.2/16)     │ eth0 (172.17.0.3/16)
               │                          │
               │ (container process)      │ (container process)
               └──────────────────────────┘

**Inspecting docker networking:**

.. code-block:: bash

   # List networks
   docker network ls

   # Inspect a bridge
   docker network inspect bridge

   # Create a custom bridge with user-defined subnet
   docker network create --subnet 10.10.0.0/16 my-net
   docker run --net my-net --ip 10.10.0.42 -d nginx

   # Connect a running container to a network
   docker network connect my-net my-container

   # Disconnect
   docker network disconnect my-net my-container

11.3.5 Docker Compose: Declarative State
=========================================

Docker Compose allows you to define multi-container applications in a YAML file and
manage them as a single unit. It is not an orchestrator (that is Kubernetes/Docker
Swarm) but a local development and single-host tool.

**Example ``compose.yml``:**

.. code-block:: yaml

   services:
     web:
       image: nginx:alpine
       ports:
         - "8080:80"
       volumes:
         - ./html:/usr/share/nginx/html:ro
       networks:
         - frontend
       depends_on:
         - api

     api:
       build:
         context: ./api
         dockerfile: Dockerfile
       environment:
         - DB_HOST=db
         - DB_NAME=appdb
       secrets:
         - db-password
       networks:
         - frontend
         - backend
       healthcheck:
         test: ["CMD", "curl", "-f", "http://localhost/health"]
         interval: 30s
         retries: 3

     db:
       image: postgres:17
       volumes:
         - pgdata:/var/lib/postgresql/data
       secrets:
         - db-password
       environment:
         POSTGRES_PASSWORD_FILE: /run/secrets/db-password
       networks:
         - backend

   networks:
     frontend:
     backend:

   volumes:
     pgdata:

   secrets:
     db-password:
       file: ./secrets/db_password.txt

**Key Compose lifecycle commands:**

.. code-block:: bash

   docker compose up -d           # Start all services in daemon mode
   docker compose down            # Stop and remove containers, networks
   docker compose logs -f         # Tail logs from all services
   docker compose ps              # List container status
   docker compose exec api bash   # Exec into a running service
   docker compose build           # Build images (if build: is specified)
   docker compose pull            # Pull images from registry
   docker compose config          # Validate and view the resolved config

.. note::
   Docker Compose v2 is integrated into the ``docker`` CLI (``docker compose``, not
   ``docker-compose``). As of 2026, the standalone ``docker-compose`` Python tool is
   fully deprecated.

**Health checks and dependencies:**

Compose does **not** wait for a service to be healthy before starting its dependents;
it only waits for the container to be running. For strict ordering, add:

.. code-block:: yaml

   services:
     api:
       depends_on:
         db:
           condition: service_healthy

This tells Compose: wait until the ``db`` service passes its health check before
starting ``api``.

11.3.6 The Docker Registry Protocol
====================================

Docker images are distributed via registries — the default being **Docker Hub**
(``docker.io``). The protocol (Docker Registry HTTP API V2) works as follows:

1. **Authentication:** ``docker login`` stores credentials in ``~/.docker/config.json``.
   For cloud registries (AWS ECR, GCR, Azure ACR), the credential helper is preferred.
2. **Push:** Image layers are uploaded as compressed blobs (gzip or zstd). Manifests
   (JSON that describes the layers and configuration) are uploaded last.
3. **Pull:** The manifest is fetched first, then each layer is pulled and verified
   against its digest (SHA256 hash).
4. **Content-addressable storage:** Every blob is stored by its digest. This enables
   deduplication — if two images share a layer, it is stored only once.

**Working with multiple registries:**

.. code-block:: bash

   # Tag for a specific registry
   docker tag my-app:latest ghcr.io/myorg/my-app:v1.0.0
   docker push ghcr.io/myorg/my-app:v1.0.0

   # Use a credential helper for AWS ECR
   # Install amazon-ecr-credential-helper, then configure:
   cat ~/.docker/config.json
   # {
   #   "credHelpers": {
   #     "123456789.dkr.ecr.us-east-1.amazonaws.com": "ecr-login"
   #   }
   # }

11.3.7 Antipatterns
===================

.. admonition:: Antipattern: The "Fat Image" Anti-Pattern
   :class: danger

   Pulling a 1.5 GB ``node:latest`` image just to serve a 5 MB static file is a
   waste of bandwidth, disk, and security surface. Use distroless or Alpine-based
   images. Every unnecessary package is a potential CVE.

   .. code-block:: bash

      # Size comparison
      docker images node
      # node:latest             1.1 GB
      # node:22-alpine          130 MB
      # node:22-slim            250 MB
      # gcr.io/distroless/nodejs:22  85 MB

.. admonition:: Antipattern: Building Secrets Into Images
   :class: danger

   Never bake API keys, certificates, or passwords into an image layer. They persist
   in the history and can be extracted by anyone who can pull the image.

   .. code-block:: dockerfile

      # ❌ Bad
      RUN echo "ghp_mysecrettoken" > /etc/git-token

      # ✅ Good (BuildKit secret mount)
      RUN --mount=type=secret,id=git-token \
          cat /run/secrets/git-token > /etc/git-token

   Build with: ``DOCKER_BUILDKIT=1 docker build --secret id=git-token,src=./token .``

.. admonition:: Antipattern: Running ``:latest`` in Production
   :class: warning

   ``:latest`` is a mutable tag. It can be overwritten, meaning your production
   deployment gets a different image tomorrow than it does today. Always pin to a
   **specific digest** or a **semantic version tag**.

   .. code-block:: bash

      # Bad
      image: nginx:latest
      # Good
      image: nginx:1.27.2
      # Best (immutable)
      image: nginx@sha256:a1b2c3d4e5f6...

11.3.8 Practical Exercises
==========================

**1. Layer Inspection**

.. code-block:: bash

   docker pull alpine:latest
   docker history alpine:latest
   docker image inspect alpine:latest | jq '.[].RootFS.Layers | length'

   # View the contents of a layer
   LAYER_DIR=$(docker info | grep "Docker Root Dir" | awk '{print $NF}')
   ls "$LAYER_DIR/overlay2"

**2. Multi-stage Build**

.. code-block:: bash

   mkdir -p /tmp/gomulti && cd /tmp/gomulti
   cat > main.go << 'EOF'
   package main
   import "fmt"
   func main() { fmt.Println("Hello from distroless!") }
   EOF

   cat > Dockerfile << 'EOF'
   FROM golang:1.23 AS builder
   WORKDIR /src
   COPY main.go .
   RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app .

   FROM gcr.io/distroless/static-debian12:nonroot
   COPY --from=builder /app /app
   USER nonroot:nonroot
   CMD ["/app"]
   EOF

   docker build -t hello-distroless .
   docker images hello-distroless
   docker run hello-distroless

**3. Custom Bridge Networking**

.. code-block:: bash

   docker network create --driver bridge --subnet 10.99.0.0/24 test-net
   docker run -d --name c1 --net test-net --ip 10.99.0.10 alpine sleep 3600
   docker run -it --name c2 --net test-net alpine ping 10.99.0.10
   docker network rm test-net
