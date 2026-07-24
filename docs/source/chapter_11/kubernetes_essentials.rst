.. _chapter-11-5:

============================================================
Kubernetes Ecosystem Essentials
============================================================

Kubernetes (K8s) is the industry-standard **orchestration platform** for automating the
deployment, scaling, and management of containerised applications. Born from Google's
internal Borg system (the paper "Large-Scale Cluster Management at Google with Borg"
is essential reading) and open-sourced in 2014, Kubernetes is now maintained by the
Cloud Native Computing Foundation (CNCF) and is the most active open-source project
in history. This section provides an architectural overview, introduces the core API
objects, and surveys the landscape of lightweight and immutable Kubernetes
distributions.

Control Plane vs Worker Nodes
======================================

A Kubernetes cluster consists of two logical planes:

.. code-block:: none

   ┌───────────────────────────────────────────────────┐
   │                  Control Plane                     │
   │                                                    │
   │  ┌─────────┐  ┌──────────┐  ┌──────────────────┐  │
   │  │ api-    │  │ etcd     │  │ scheduler        │  │
   │  │ server  │  │ (dist.   │  │ (pod-to-node     │  │
   │  │ (authZ, │  │  key-val │  │  assignment)     │  │
   │  │  valid) │  │  store)  │  └──────────────────┘  │
   │  └────┬────┘  └──────────┘                         │
   │       │                                            │
   │  ┌────┴────┐                                       │
   │  │ c-mgr   │                                       │
   │  │ (ctrl.  │                                       │
   │  │  loops) │                                       │
   │  └─────────┘                                       │
   └──────────────────────┬────────────────────────────┘
                          │ (kube-apiserver — HTTPS)
   ┌──────────────────────┴────────────────────────────┐
   │                  Worker Node                       │
   │                                                    │
   │  ┌──────────┐  ┌────────────┐  ┌───────────────┐  │
   │  │ kubelet  │  │ kube-proxy │  │ Container     │  │
   │  │ (node    │  │ (net rules │  │ Runtime       │  │
   │  │  agent)  │  │  + svc IP) │  │ (containerd)  │  │
   │  └──────────┘  └────────────┘  └───────────────┘  │
   │  ┌────────────────────────────────────────────┐    │
   │  │ Pod (shared netns, cgroups)                │    │
   │  │ ┌──────────┐ ┌──────────┐                  │    │
   │  │ │ container│ │ container│  (sidecar)       │    │
   │  │ └──────────┘ └──────────┘                  │    │
   │  └────────────────────────────────────────────┘    │
   └────────────────────────────────────────────────────┘

**Control plane components:**

* **kube-apiserver:** The front-end to the cluster state. All communication (kubectl,
  kubelet, scheduler, controllers) goes through this HTTPS server. It authenticates,
  authorises, validates, and persists all API objects to etcd.
* **etcd:** A distributed, consistent key-value store (based on the Raft consensus
  algorithm). It is the **source of truth** for the cluster. Only the apiserver
  communicates directly with etcd.
* **kube-scheduler:** Watches for newly created Pods with no node assignment and
  selects the best node based on resource requirements, policies, affinity rules,
  and data locality.
* **kube-controller-manager:** Runs controller loops that reconcile the desired state
  (what you declared) with the actual state (what the cluster is doing). Examples:
  the Node controller (detects dead nodes), the Replication controller (ensures the
  right number of Pod replicas), the Endpoint controller.

**Worker node components:**

* **kubelet:** The primary node agent. It registers the node with the cluster, watches
  for Pod assignments from the apiserver, and ensures the containers in those Pods
  are running and healthy. It communicates with the container runtime via the CRI
  (Container Runtime Interface — gRPC).
* **kube-proxy:** Runs on every node and maintains network rules (iptables, IPVS, or
  eBPF). It enables **Service** abstraction — a stable virtual IP (ClusterIP) that
  load-balances across Pods.
* **Container runtime:** The software that actually runs containers (containerd, CRI-O,
  etc.). Kubernetes uses the CRI abstraction to decouple from any specific runtime.

**Cluster setup (minimal with kind or k3s):**

.. code-block:: bash

   # Option 1: kind (Kubernetes in Docker) — for local development
   kind create cluster --name chapter11
   kubectl cluster-info

   # Option 2: k3s (lightweight single binary)
   curl -sfL https://get.k3s.io | sh -
   kubectl get nodes

   # Check control plane components
   kubectl get componentstatuses
   kubectl -n kube-system get pods

The Core API Objects
============================

Kubernetes is a **declarative API**. You write YAML (or JSON) describing the desired
state, and the controllers work to converge to that state.

**Pod — the smallest deployable unit:**

A Pod is a group of one or more containers that share a network namespace, IPC
namespace, and (optionally) a PID namespace. Containers in a Pod see ``localhost``
as each other and can communicate via shared volumes.

.. code-block:: yaml

   apiVersion: v1
   kind: Pod
   metadata:
     name: nginx-pod
     labels:
       app: nginx
       tier: frontend
   spec:
     containers:
     - name: nginx
       image: nginx:1.27-alpine
       ports:
       - containerPort: 80
       resources:
         requests:
           cpu: 100m        # 0.1 CPU core
           memory: "128Mi"
         limits:
           cpu: 500m
           memory: "256Mi"
       livenessProbe:
         httpGet:
           path: /health
           port: 80
         initialDelaySeconds: 5
         periodSeconds: 10

.. code-block:: bash

   kubectl apply -f nginx-pod.yaml
   kubectl get pods -o wide
   kubectl describe pod nginx-pod
   kubectl logs nginx-pod
   kubectl exec nginx-pod -- nginx -v
   kubectl delete pod nginx-pod

**Deployment — declarative rollout and scaling:**

A Deployment manages a **ReplicaSet**, which in turn manages Pods. When you update the
Pod template (e.g., change the image tag), the Deployment performs a **rolling update**
with configurable surge and unavailable thresholds.

.. code-block:: yaml

   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: api-server
   spec:
     replicas: 3
     revisionHistoryLimit: 5
     strategy:
       type: RollingUpdate
       rollingUpdate:
         maxSurge: 1
         maxUnavailable: 0
     selector:
       matchLabels:
         app: api
     template:
       metadata:
         labels:
           app: api
       spec:
         containers:
         - name: api
           image: myregistry.io/api:v1.2.3
           ports:
           - containerPort: 3000
           env:
           - name: DB_HOST
             valueFrom:
               secretKeyRef:
                 name: db-secret
                 key: host
           resources:
             requests:
               cpu: 250m
               memory: "256Mi"
             limits:
               cpu: 500m
               memory: "512Mi"

.. code-block:: bash

   kubectl apply -f deployment.yaml
   kubectl scale deployment api-server --replicas=5
   kubectl set image deployment/api-server api=myregistry.io/api:v1.3.0
   kubectl rollout status deployment/api-server
   kubectl rollout history deployment/api-server
   kubectl rollout undo deployment/api-server --to-revision=2

**Service — stable network endpoint:**

Pods are ephemeral (they come and go). A Service provides a **stable virtual IP**
(ClusterIP) and DNS name that load-balances across the Pods matching its selector.

.. code-block:: yaml

   apiVersion: v1
   kind: Service
   metadata:
     name: api-service
   spec:
     selector:
       app: api
     ports:
     - port: 80
       targetPort: 3000
       protocol: TCP
     type: ClusterIP       # Exposes only within the cluster

   # For external access:
   # type: NodePort        # Exposes on each node's IP at a high port (30000-32767)
   # type: LoadBalancer    # Creates a cloud load balancer (AWS ELB, etc.)
   # type: ExternalName    # Returns a CNAME record

.. code-block:: bash

   kubectl expose deployment api-server --port=80 --target-port=3000
   kubectl get svc api-service
   # Inside the cluster, other Pods can reach it at: http://api-service:80

**ConfigMap and Secret — configuration injection:**

.. code-block:: yaml

   # ConfigMap (non-sensitive data)
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: app-config
   data:
     APP_ENV: production
     LOG_LEVEL: info
     config.yaml: |
       database:
         host: db.example.com
         port: 5432

   # Secret (base64-encoded, sensitive)
   apiVersion: v1
   kind: Secret
   metadata:
     name: db-secret
   type: Opaque
   stringData:           # stringData is convenience; data expects base64
     username: admin
     password: s3cur3p@ss

.. code-block:: bash

   # Mount as environment variables (bad practice for secrets)
   kubectl create configmap app-config --from-literal=APP_ENV=production
   kubectl create secret generic db-secret --from-literal=password=s3cur3p@ss

   # Better: mount as files
   # (In Pod spec, reference the ConfigMap/Secret in volumes)

.. admonition:: Antipattern: Secrets in Environment Variables
   :class: danger

   As noted in §11.2.5, secrets in env vars leak into logs, ``kubectl describe``,
   and ``/proc``. Prefer **file-based secret mounts**:

   .. code-block:: yaml

      spec:
        containers:
        - name: app
          volumeMounts:
          - name: db-credentials
            mountPath: "/run/secrets/db"
            readOnly: true
        volumes:
        - name: db-credentials
          secret:
            secretName: db-secret

   Then in your app: ``password = readFile("/run/secrets/db/password")``

Immutable Node OSes: Talos Linux
========================================

Traditional Kubernetes worker nodes run a full Linux distribution (Ubuntu, RHEL,
Flatcar) with SSH access, a package manager, and mutable filesystems. This creates
configuration drift, security surface, and operational overhead.

**Talos Linux** is an **immutable, API-driven Kubernetes OS**:

* No shell, no SSH, no package manager.
* All node management occurs through the **Talos API** (gRPC over mutual TLS).
* The OS boots from a squashfs image (read-only root) and runs entirely in memory.
* Configuration is applied as a single ``talosconfig`` YAML file.
* System components (etcd, kubelet, kube-apiserver) run as containerised processes
  managed by Talos's own init (``machined``).

.. code-block:: bash

   # Install Talos on a node (one-shot ISO or network boot)
   talosctl apply-config \
     --insecure \
     --nodes 192.168.1.100 \
     --file talosconfig.yaml

   # Interact with the cluster
   talosctl --talosconfig=./talosconfig kubeconfig .
   kubectl get nodes

   # Upgrade the OS (one command, no SSH)
   talosctl upgrade \
     --image ghcr.io/siderolabs/installer:v1.8.0 \
     --preserve=true

   # Debug without SSH (limited introspection)
   talosctl logs kubelet
   talosctl containers
   talosctl processes

Benefits of Talos:

* **Immutable infrastructure:** The OS is never patched in-place; upgrades are atomic
  image swaps.
* **Reduced attack surface:** No SSH, no shell, no package manager, no compilers.
* **API-driven:** Full automation without SSH key management.
* **minimal:** Approximately 50 MB footprint.

Lightweight Distributions: K3s
======================================

**K3s** (pronounced "k-ees") is a CNCF-certified Kubernetes distribution optimised for
resource-constrained environments: edge devices, Raspberry Pi, IoT, and CI runners.
Created by Rancher (now part of SUSE), K3s packages the entire control plane into a
single binary (~60 MB) and replaces etcd with an embedded SQLite backend (optional:
external etcd or embedded dqlite for HA).

Key simplifications:

* Removes alpha, beta, and deprecated feature gates.
* Replaces ``kube-proxy`` with a simple iptables-based proxy or ``linkerd``
  integration.
* Uses ``containerd`` as the default container runtime.
* Bundles essential addons: CoreDNS, Traefik ingress controller (optional),
  local-path-provisioner for dynamic volumes.
* Integrates a simple load balancer for HA (embedded etcd or dqlite).

.. code-block:: bash

   # Single-node K3s (one command)
   curl -sfL https://get.k3s.io | sh -
   kubectl get nodes
   kubectl get pods -A

   # Multi-node (server + agents)
   # On server:
   curl -sfL https://get.k3s.io | sh -
   K3S_TOKEN=$(sudo cat /var/lib/rancher/k3s/server/node-token)

   # On agent:
   curl -sfL https://get.k3s.io | K3S_URL=https://server-ip:6443 K3S_TOKEN=$K3S_TOKEN sh -

   # HA with embedded etcd
   curl -sfL https://get.k3s.io | sh -s - server \
     --cluster-init \
     --token my-shared-secret

   # Then on other servers:
   curl -sfL https://get.k3s.io | sh -s - server \
     --server https://first-server:6443 \
     --token my-shared-secret

**When to choose K3s vs Talos vs full K8s:**

.. list-table::
   :header-rows: 1
   :widths: 20 25 25 30

   * - Criterion
     - Full Kubernetes (kubeadm)
     - K3s
     - Talos Linux
   * - Node OS management
     - Manual (SSH, apt)
     - Manual (SSH, apt)
     - API-driven (no SSH)
   * - Control plane size
     - Multiple components
     - Single binary
     - Containerised
   * - Database
     - etcd (3+ nodes)
     - SQLite / embedded etcd
     - etcd (containerised)
   * - Minimum RAM per node
     - 2 GB
     - 512 MB
     - 1 GB
   * - Use case
     - Production data centre
     - Edge, IoT, CI, lab
     - Security-sensitive production

The Kubernetes Networking Model
=======================================

Kubernetes imposes a flat network model with three fundamental requirements:

1. All Pods can communicate with all other Pods without NAT, regardless of node.
2. All Nodes can communicate with all Pods without NAT.
3. The IP that a Pod sees for itself is the same IP that others see.

This model **delegates implementation** to Container Network Interface (CNI) plugins:

* **Calico:** Uses BGP for routing (no overlay). High performance, supports network
  policies.
* **Flannel:** Simple overlay (VXLAN). Easy to set up, no network policies.
* **Cilium:** Uses **eBPF** for networking, observability, and security. Replaces
  kube-proxy entirely. Modern choice for 2026.
* **Weave:** Mesh-based overlay with built-in DNS.

.. code-block:: bash

   # Install Cilium in an existing cluster
   cilium install --version 1.16.0
   cilium status

   # Verify connectivity
   kubectl run test-pod --image=busybox --rm -it -- wget -O- http://cilium.io

.. note::
   In 2026, **Cilium** is the dominant CNI choice for new clusters due to its
   eBPF foundation, which provides superior performance, deep observability
   (Hubble), and identity-based security (CiliumNetworkPolicy).

Practical Exercises
==========================

**1. Deploy a Full Application**

.. code-block:: bash

   # Create a deployment
   kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:2.0
   kubectl expose deployment hello-world --port=8080

   # Scale it
   kubectl scale deployment hello-world --replicas=5

   # Port-forward to access locally
   kubectl port-forward service/hello-world 8080:8080 &
   curl http://localhost:8080

   # Rolling update
   kubectl set image deployment/hello-world hello-world=gcr.io/google-samples/hello-app:1.0
   kubectl rollout status deployment/hello-world

   # Rollback
   kubectl rollout undo deployment/hello-world

**2. ConfigMap and Secret Injection**

.. code-block:: bash

   kubectl create configmap app-config --from-literal=greeting="Hello, Kubernetes!"
   kubectl create secret generic api-key --from-literal=key=sk-12345

   cat << 'EOF' | kubectl apply -f -
   apiVersion: v1
   kind: Pod
   metadata:
     name: config-demo
   spec:
     containers:
     - name: demo
       image: busybox
       command: ["sh", "-c", "cat /etc/config/greeting && echo ' - key: ' && cat /etc/secret/key && sleep 3600"]
       volumeMounts:
       - name: config-vol
         mountPath: /etc/config
       - name: secret-vol
         mountPath: /etc/secret
     volumes:
     - name: config-vol
       configMap:
         name: app-config
     - name: secret-vol
       secret:
         secretName: api-key
   EOF

   kubectl logs config-demo
   # Output: Hello, Kubernetes! - key: sk-12345

**3. Explore K3s or kind**

.. code-block:: bash

   # If you have Docker, try kind
   kind create cluster
   kubectl cluster-info --context kind-kind

   # Or if you have a spare machine/VPS, install K3s
   curl -sfL https://get.k3s.io | sh -
   kubectl get pods -A
