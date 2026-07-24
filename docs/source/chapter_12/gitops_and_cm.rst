.. _gitops-and-cm:

============================================================
Configuration Management at Scale & GitOps
============================================================

The Evolution of Configuration Management
===================================================

+----------------+-----------------------------------+---------------------------+
| Era            | Tools                             | Paradigm                  |
+================+===================================+===========================+
| **1.0**        | Shell scripts, scp + ssh          | Ad-hoc, mutable, manual   |
+----------------+-----------------------------------+---------------------------+
| **2.0**        | Puppet, Chef, SaltStack           | Push/pull, declarative    |
+----------------+-----------------------------------+---------------------------+
| **3.0**        | Ansible + GitOps (ArgoCD/Flux)    | Pull-based, declarative,  |
|                |                                   | continuous reconciliation  |
+----------------+-----------------------------------+---------------------------+

By 2026, Era 2.0 tools are in terminal decline. The industry standard is **GitOps**.

Ansible at Scale: AWX
================================

AWX is the open-source upstream of Red Hat Ansible Automation Platform.

.. code-block:: bash

    kubectl create namespace awx
    kubectl apply -f https://raw.githubusercontent.com/ansible/awx-operator/devel/config/crd/bases/awx.ansible.com_awxs.yaml

    cat << 'AWXEOF' | kubectl apply -f -
    apiVersion: awx.ansible.com/v1beta1
    kind: AWX
    metadata:
      name: awx-demo
      namespace: awx
    spec:
      service_type: ClusterIP
      admin_password_secret: awx-admin-password
      projects_persistence: true
      projects_storage_size: 10Gi
    AWXEOF

Ansible Semaphore (Lightweight)
--------------------------------

`Semaphore <https://www.ansible-semaphore.com/>`_ is a lightweight alternative.

.. code-block:: bash

    cat > semaphore-compose.yaml << 'SEMEOF'
    services:
      semaphore:
        image: semaphoreui/semaphore:latest
        ports:
          - "3000:3000"
        environment:
          SEMAPHORE_DB_DIALECT: bolt
          SEMAPHORE_ADMIN_PASSWORD: changeme
          SEMAPHORE_GIT_URL: https://github.com/yourorg/ansible-prod.git
    SEMEOF

The Decline of Legacy CM Tools
========================================

+----------------+---------------------------------------+----------------------------------+
| Limitation     | Puppet / Chef                        | Ansible / GitOps                 |
+================+=======================================+==================================+
| Architecture   | Agent (Ruby/JRuby) on every node     | Agentless (SSH) or pull-based    |
+----------------+---------------------------------------+----------------------------------+
| State handling | Convergence model (re-runs every 30m) | Idempotent / continuous reconcile |
+----------------+---------------------------------------+----------------------------------+
| Immutability   | Mutates state in place               | Promotes immutable images        |
+----------------+---------------------------------------+----------------------------------+

GitOps: The Industry Standard
========================================

Principles: declarative state, Git as single source of truth, pull-based
reconciliation, self-healing.

ArgoCD
------

.. code-block:: bash

    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

    cat << 'ARGOCDEOF' | kubectl apply -f -
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: production-webapp
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/example/production-deployments.git
        targetRevision: main
        path: webapp/overlays/production
      destination:
        server: https://kubernetes.default.svc
        namespace: webapp-prod
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
    ARGOCDEOF

Flux CD
-------

.. code-block:: bash

    flux bootstrap github \
        --owner=example \
        --repository=fleet-infra \
        --path=./clusters/production
    cat << 'FLUXEOF' | kubectl apply -f -
    apiVersion: helm.toolkit.fluxcd.io/v2
    kind: HelmRelease
    metadata:
      name: nginx
      namespace: production
    spec:
      chart:
        spec:
          chart: nginx
          sourceRef:
            kind: HelmRepository
            name: bitnami
      interval: 5m
      values:
        replicaCount: 3
    FLUXEOF

Summary
===============

The 2026 verdict: **If it is not in Git, it does not exist.** GitOps eliminates drift
by continuously reconciling live state against the canonical state in version control.
