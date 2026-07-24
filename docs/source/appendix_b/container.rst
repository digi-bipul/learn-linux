.. _app-b-container:

------------------------------------------------------------------------------
Containers (Docker, Podman, LXC)
------------------------------------------------------------------------------

------------------------------------------------------------------------------
Docker
------------------------------------------------------------------------------

.. rubric:: Image Management

.. list-table:: Docker image commands
   :header-rows: 1
   :widths: 25 35 40

   * - Command
     - Example
     - Description
   * - ``docker pull``
     - ``docker pull nginx:alpine``
     - Download an image from registry
   * - ``docker images``
     - ``docker images``
     - List local images
   * - ``docker rmi``
     - ``docker rmi nginx:alpine``
     - Remove an image
   * - ``docker build``
     - ``docker build -t myapp:v1 .``
     - Build image from Dockerfile
   * - ``docker tag``
     - ``docker tag myapp:v1 myrepo/myapp:v1``
     - Tag an image
   * - ``docker push``
     - ``docker push myrepo/myapp:v1``
     - Push image to registry
   * - ``docker save``
     - ``docker save -o myapp.tar myapp:v1``
     - Save image to tar archive
   * - ``docker load``
     - ``docker load -i myapp.tar``
     - Load image from tar archive
   * - ``docker history``
     - ``docker history myapp:v1``
     - Show image layer history
   * - ``docker inspect``
     - ``docker inspect myapp:v1``
     - Show detailed image metadata

.. rubric:: Container Lifecycle

.. list-table:: Docker container commands
   :header-rows: 1
   :widths: 25 35 40

   * - Command
     - Example
     - Description
   * - ``docker run``
     - ``docker run -d --name web -p 80:80 nginx``
     - Create and start a container
   * - ``docker start``
     - ``docker start web``
     - Start a stopped container
   * - ``docker stop``
     - ``docker stop web``
     - Stop a container (SIGTERM + SIGKILL after timeout)
   * - ``docker kill``
     - ``docker kill web``
     - Force-stop (SIGKILL)
   * - ``docker restart``
     - ``docker restart web``
     - Restart a container
   * - ``docker rm``
     - ``docker rm web``
     - Remove a stopped container (``-f`` for running)
   * - ``docker ps``
     - ``docker ps -a``
     - List containers (``-a`` includes stopped)
   * - ``docker exec``
     - ``docker exec -it web bash``
     - Run command in running container (interactive)
   * - ``docker logs``
     - ``docker logs -f web``
     - View container logs (``-f`` = follow)
   * - ``docker cp``
     - ``docker cp web:/etc/nginx/nginx.conf ./``
     - Copy files between container and host
   * - ``docker export``
     - ``docker export -o web.tar web``
     - Export container filesystem as tar
   * - ``docker import``
     - ``docker import web.tar newimage:latest``
     - Import tar as an image

.. rubric:: Docker Networking

.. list-table:: Docker network commands
   :header-rows: 1
   :widths: 25 35 40

   * - Command
     - Example
     - Description
   * - ``docker network ls``
     - ``docker network ls``
     - List networks
   * - ``docker network create``
     - ``docker network create --driver bridge mynet``
     - Create a network
   * - ``docker network connect``
     - ``docker network connect mynet web``
     - Connect container to network
   * - ``docker network disconnect``
     - ``docker network disconnect mynet web``
     - Disconnect container
   * - ``docker network inspect``
     - ``docker network inspect mynet``
     - Show network details

.. rubric:: Docker Compose (``docker-compose.yml``)

.. code-block:: yaml

   version: '3.8'
   services:
     web:
       image: nginx:alpine
       ports:
         - "80:80"
       volumes:
         - ./html:/usr/share/nginx/html:ro
       depends_on:
         - db
     db:
       image: postgres:15
       environment:
         POSTGRES_PASSWORD: changeme
       volumes:
         - pgdata:/var/lib/postgresql/data
   volumes:
     pgdata:

.. code-block:: bash

   docker compose up -d       # Start all services
   docker compose down        # Stop and remove
   docker compose logs -f     # Follow all logs
   docker compose ps          # List container status
   docker compose exec web bash  # Shell into service

------------------------------------------------------------------------------
Podman
------------------------------------------------------------------------------

Podman is a daemonless container engine, largely Docker-compatible. Commands
are intentionally similar: ``podman`` can often replace ``docker`` with the
same CLI syntax.

.. list-table:: Docker vs. Podman differences
   :header-rows: 1
   :widths: 25 35 40

   * - Feature
     - Docker
     - Podman
   * - Architecture
     - Client + daemon (dockerd)
     - Daemonless (fork/exec)
   * - Rootless mode
     - Supported (since 19.03)
     - **Native** — no daemon needed for rootless
   * - Kubernetes YAML
     - Not natively
     - Can generate and run ``podman kube play``
   * - Pods
     - Docker Compose for multi-container
     - Built-in ``podman pod`` (Kubernetes-like)
   * - Systemd integration
     - Manual
     - ``podman generate systemd`` auto-generates service files
   * - Security
     - Runs as root by default
     - Rootless by design; no daemon means smaller attack surface

.. code-block:: bash
   :caption: Podman-specific features

   # Pod (group of containers sharing network namespace)
   podman pod create --name mypod -p 80:80
   podman run -d --pod mypod --name app nginx:alpine
   podman pod list

   # Generate systemd unit for container auto-start
   podman generate systemd --name mycontainer > /etc/systemd/system/mycontainer.service
   systemctl daemon-reload
   systemctl enable --now mycontainer.service

   # Rootless alias
   alias docker=podman

------------------------------------------------------------------------------
LXC / LXD
------------------------------------------------------------------------------

LXC (Linux Containers) provides system containers that behave like lightweight
VMs (init system, network stack, separate kernel namespace). **LXD** is the
management daemon built on top of LXC.

.. list-table:: LXD Command Reference
   :header-rows: 1
   :widths: 25 35 40

   * - Command
     - Example
     - Description
   * - ``lxc launch``
     - ``lxc launch ubuntu:22.04 mycontainer``
     - Create and start a container from an image
   * - ``lxc list``
     - ``lxc list``
     - List all containers
   * - ``lxc exec``
     - ``lxc exec mycontainer -- bash``
     - Execute command in container
   * - ``lxc file pull``
     - ``lxc file pull mycontainer/etc/hosts ./``
     - Pull file from container
   * - ``lxc file push``
     - ``lxc file push ./config mycontainer/etc/``
     - Push file to container
   * - ``lxc snapshot``
     - ``lxc snapshot mycontainer snap1``
     - Create a container snapshot
   * - ``lxc restore``
     - ``lxc restore mycontainer snap1``
     - Restore container from snapshot
   * - ``lxc delete``
     - ``lxc delete mycontainer``
     - Delete container (must be stopped)
   * - ``lxc config set``
     - ``lxc config set mycontainer limits.memory 512MB``
     - Set resource limits
   * - ``lxc info``
     - ``lxc info mycontainer``
     - Show container details
   * - ``lxc remote``
     - ``lxc remote add my-pc https://10.0.0.5:8443``
     - Add remote LXD host

.. rubric:: Docker vs. LXC comparison

.. list-table:: Docker vs. LXC
   :header-rows: 1
   :widths: 15 35 50

   * - Aspect
     - Docker
     - LXC / LXD
   * - Container type
     - Application containers (one process)
     - System containers (full OS with init)
   * - Init system
     - None (process runs directly)
     - systemd, SysV init — full boot sequence
   * - Isolation
     - Namespaces + cgroups
     - Namespaces + cgroups (stronger by default)
   * - Image size
     - Small (MBs — stripped OS layers)
     - Larger (100MB+ — full rootfs)
   * - Use case
     - Microservices, CI/CD, stateless apps
     - VM replacement, legacy apps, full OS environments
   * - State management
     - Ephemeral (volumes for persistence)
     - Persistent by default (like a VM)
   * - Networking
     - Bridge, overlay, host, macvlan
     - Bridge, NAT, routed, physical (more flexible)
