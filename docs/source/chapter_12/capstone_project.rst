.. _capstone-project:

============================================================
Capstone Project: Production-Ready 3-Tier Architecture
============================================================

Project Overview
=========================

Design and deploy a production-ready, resilient 3-tier architecture from scratch.

::

    Internet → HAProxy (Keepalived VIP) → Web Tier (K8s) → PostgreSQL → MinIO

Technology Stack
----------------

+--------------------+---------------------------------------------------+
| Layer              | Technology                                        |
+====================+===================================================+
| IaC (Provision)    | OpenTofu                                         |
+--------------------+---------------------------------------------------+
| Config Mgmt        | Ansible (AWX / Semaphore)                         |
+--------------------+---------------------------------------------------+
| Load Balancing     | HAProxy + Keepalived (VRRP)                       |
+--------------------+---------------------------------------------------+
| Compute            | Podman or Kubernetes (kind/k3s)                   |
+--------------------+---------------------------------------------------+
| Security           | SELinux (enforcing) + FirewallD                   |
+--------------------+---------------------------------------------------+
| Database           | PostgreSQL 16 with streaming replication          |
+--------------------+---------------------------------------------------+
| Observability      | Prometheus + Loki + Grafana                       |
+--------------------+---------------------------------------------------+
| Backups            | Borg/Restic to MinIO (Object Lock)                |
+--------------------+---------------------------------------------------+

Phase 1: Infrastructure with OpenTofu
===============================================

.. code-block:: hcl

    # tofu/main.tf
    provider "libvirt" {
      uri = "qemu+ssh://user@hypervisor.example.com/system"
    }
    module "compute" {
      source = "./modules/compute"
      servers = {
        lb01  = { cpu = 2, ram = 4096, ip = "10.100.1.10" }
        lb02  = { cpu = 2, ram = 4096, ip = "10.100.1.11" }
        web01 = { cpu = 4, ram = 8192, ip = "10.100.1.20" }
        web02 = { cpu = 4, ram = 8192, ip = "10.100.1.21" }
        web03 = { cpu = 4, ram = 8192, ip = "10.100.1.22" }
        db01  = { cpu = 4, ram = 16384, ip = "10.100.2.10" }
        db02  = { cpu = 4, ram = 16384, ip = "10.100.2.11" }
        monitor = { cpu = 2, ram = 4096, ip = "10.100.1.100" }
        backup  = { cpu = 4, ram = 8192, ip = "10.100.1.200" }
      }
      image = "rocky-9-generic"
    }

.. code-block:: bash

    cd tofu && tofu init && tofu apply

Phase 2: Configuration with Ansible
=============================================

.. code-block:: yaml

    # playbooks/site.yml
    - name: Apply base hardening
      hosts: all
      roles: [common, selinux, firewalld]
    - name: Configure load balancers
      hosts: loadbalancers
      roles: [haproxy, keepalived]
    - name: Deploy web applications
      hosts: webservers
      roles: [podman, webapp]
    - name: Configure PostgreSQL cluster
      hosts: databases
      roles: [postgresql, corosync-pacemaker]
    - name: Set up monitoring
      hosts: monitoring
      roles: [prometheus, loki, grafana]
    - name: Configure backup server
      hosts: backup
      roles: [restic]

.. code-block:: bash

    ansible-playbook -i inventory/production/hosts.ini playbooks/site.yml

Phase 3: SELinux Hardening
====================================

.. code-block:: bash

    getenforce  # Must return "Enforcing"
    cat > webapp.te << 'SEEOF'
    module webapp 1.0;
    require {
        type http_port_t; type etc_t; type var_log_t; type initrc_t;
        class tcp_socket { name_bind create connect };
        class file { read write open };
    }
    allow initrc_t http_port_t:tcp_socket name_bind;
    allow initrc_t var_log_t:file { write append };
    SEEOF
    checkmodule -M -m -o webapp.mod webapp.te
    semodule_package -o webapp.pp -m webapp.mod
    semodule -i webapp.pp

Phase 4: Kubernetes Deployment
========================================

.. code-block:: yaml

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: webapp
      namespace: capstone-prod
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: webapp
      template:
        metadata:
          labels:
            app: webapp
        spec:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          containers:
          - name: webapp
            image: registry.example.com/webapp:latest
            ports:
            - containerPort: 8080
            env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: db-credentials
                  key: url
            livenessProbe:
              httpGet:
                path: /health
                port: 8080
            readinessProbe:
              httpGet:
                path: /ready
                port: 8080

.. code-block:: bash

    kubectl apply -f k8s/

Phase 5: Observability Stack
========================================

.. code-block:: yaml

    # prometheus.yml
    scrape_configs:
    - job_name: 'kubernetes'
      kubernetes_sd_configs:
      - role: pod
    - job_name: 'haproxy'
      static_configs:
      - targets: ['lb01:9101', 'lb02:9101']
    - job_name: 'postgresql'
      static_configs:
      - targets: ['db01:9187', 'db02:9187']

Alert Rules
------------

.. code-block:: yaml

    groups:
    - name: capstone
      rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.01
        for: 2m
      - alert: DatabaseReplicationLag
        expr: pg_replication_lag_seconds > 300
        for: 1m

Phase 6: Automated Backups & DR
=========================================

.. code-block:: bash

    # /usr/local/bin/backup-all.sh
    set -euo pipefail
    pg_dump -Fc -h localhost -U postgres capstone_prod > /tmp/db_dump.sql
    restic backup /tmp/db_dump.sql --tag db-cron
    restic backup /etc --tag config
    restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune
    restic check

Phase 7: GitOps Reconciliation
========================================

.. code-block:: yaml

    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: capstone-prod
      namespace: argocd
    spec:
      source:
        repoURL: https://github.com/yourorg/capstone-infra.git
        path: k8s
      destination:
        server: https://kubernetes.default.svc
        namespace: capstone-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true

Validation Checklist
=============================

.. list-table::
   :header-rows: 1

   * - #
     - Requirement
     - Verification Command
   * - 1
     - SELinux enforcing on all nodes
     - :command:`ansible all -m command -a getenforce`
   * - 2
     - HAProxy responds on VIP
     - :command:`curl -I https://203.0.113.100/`
   * - 3
     - Web app returns 200
     - :command:`curl -f http://localhost:8080/health`
   * - 4
     - DB replication active
     - :command:`psql -c "SELECT pg_is_in_recovery();"`
   * - 5
     - Prometheus scrapes targets
     - :command:`curl http://monitor:9090/api/v1/targets`
   * - 6
     - Loki receives logs
     - :command:`curl http://monitor:3100/loki/api/v1/labels`
   * - 7
     - Restic backup succeeds
     - :command:`restic check`
   * - 8
     - ArgoCD shows Synced
     - :command:`argocd app get capstone-prod`
   * - 9
     - STONITH armed
     - :command:`pcs stonith show --full`
   * - 10
     - /etc git-tracked
     - :command:`cd /etc && git log --oneline`

Graduation
====================

You have earned the title: **Senior Linux Infrastructure Engineer**.

* **Provision infrastructure** with OpenTofu
* **Configure at scale** with Ansible
* **Run containers securely** with K8s + SELinux
* **Balance traffic** with HAProxy + Keepalived
* **Centralise identity** with FreeIPA + SSSD
* **Observe every layer** with Prometheus + Loki + Grafana
* **Recover from disaster** with encrypted immutable backups
* **Automate change** with GitOps and blameless incident response

.. rubric:: What's Next?

* `Kernel Newbies <https://kernelnewbies.org/>`_
* `SRE Weekly <https://sreweekly.com/>`_
* `CNCF Landscape <https://landscape.cncf.io/>`_

Keep learning. Keep building. Keep making systems that survive.
