.. _sre-practices:

============================================================
SRE Practices & Change Management
============================================================

What is Site Reliability Engineering?
==============================================

SRE applies software engineering to operations. Core principles: treat operations as
an engineering problem, use error budgets, reduce toil, conduct blameless post-mortems,
and treat everything as code.

Version-Controlling /etc with etckeeper
=================================================

`etckeeper <https://etckeeper.branchable.com/>`_ turns ``/etc`` into a Git repository.

.. code-block:: bash

    # Install
    dnf install -y etckeeper   # EPEL
    apt-get install -y etckeeper  # Debian

    # Initialise
    cd /etc && etckeeper init
    etckeeper commit "Initial commit of /etc"
    git config user.email "admin@example.com"
    git config user.name "Root Admin"

    # View history
    cd /etc && git log --oneline

    # Push to remote (audit trail)
    git remote add origin git@git.example.com:etc-backups/corp-webserver.git
    git push --all origin

.. important::
   Use a **private** repository or ``git-crypt`` to protect secrets in /etc.

Executable Runbooks
=============================

Static runbook documents are outdated under pressure. Use executable runbooks instead.

Jupyter Notebook Runbooks
--------------------------

.. code-block:: python

    # rebuild_postgres_primary.ipynb
    CLUSTER_NAME = "prod-db-cluster"
    NEW_PRIMARY = "db03.example.com"

    # Verify cluster state
    import subprocess
    result = subprocess.run(["pcs", "status"], capture_output=True, text=True)
    assert "FAILED" not in result.stdout

    # Promote new primary
    subprocess.run(["pcs", "resource", "promote", "pgsql-data-master",
                    f"node={NEW_PRIMARY}"], check=True)
    print("Runbook complete.")

Markdown + Ansible Playbooks
-------------------------------

.. code-block:: markdown

    # Runbook: Reboot a Production Node Safely
    ## Pre-Checks
    - [ ] Verify cluster health: `pcs status`
    ## Drain Node
    ```bash
    pcs node standby $HOSTNAME
    ```
    ## Reboot
    ```bash
    shutdown -r now
    ```
    ## Post-Checks
    ```bash
    pcs node unstandby $HOSTNAME
    pcs status
    ```

Toil Reduction: The 50% Rule
======================================

Toil is manual, repetitive, automatable, tactical work with no enduring value.
Every SRE should spend no more than 50% of their time on toil.

Blameless Post-Mortems
=================================

A post-mortem identifies system weaknesses, not individual mistakes.

.. code-block:: markdown

    # Post-Mortem: Outage-2026-07-19
    **Duration:** 47 minutes
    **Severity:** SEV-1
    **Root Cause:** HAProxy backend misconfiguration (single active server)

    ## Action Items
    | Action | Owner | Ticket |
    |--------|-------|--------|
    | Add haproxy -c to CI/CD | @ops-eng | #4213 |
    | Create "Less than 2 backends" alert | @monitoring | #4215 |

    ## Blameless Statement
    The engineer followed the existing process. The failure is in the process.

Change Management: The SRE Way
========================================

Replace process gatekeeping with engineering gates: automated testing, progressive
delivery, observability, and automatic rollback.

.. code-block:: bash

    # Pre-deployment validation
    haproxy -c -f /etc/haproxy/haproxy.cfg
    ansible-playbook --syntax-check deploy-webapp.yml
    echo "=== Validation passed ==="

Summary
===============

* **etckeeper** versions /etc automatically.
* **Executable runbooks** replace static documents with actionable procedures.
* **Toil reduction** is an explicit engineering goal — measure and automate.
* **Blameless post-mortems** focus on system weaknesses, not people.
* **Change management** is automated, progressive, and observable.
