.. highlight:: bash

========================================
8.9 — Config Management & Modern IaC
========================================

This section introduces **Infrastructure as Code (IaC)** — the practice of
managing infrastructure through machine-readable definition files rather than
manual steps.  We focus on **Ansible**, then contextualize it within the
broader IaC landscape including Terraform/OpenTofu, Packer, and the paradigm
shift toward **Immutable Infrastructure** and **GitOps**.

--------------------------------
8.9.1 Why Configuration Management?
--------------------------------

CM tools solve three fundamental problems:

1. **Consistency** — Every server has the same packages, configs, and settings.
2. **Idempotency** — Running the tool multiple times yields the same result.
3. **Auditability** — Changes are code-reviewed and version-controlled.

--------------------------------
8.9.2 Ansible — Core Concepts
--------------------------------

* **Agentless** — No persistent daemon on target hosts (SSH only).
* **Push-based** — Control node pushes configurations to managed nodes.
* **Declarative** — You describe *what* state you want.
* **YAML-based** — Playbooks are written in YAML.

--------------------------------
8.9.3 Ansible Inventory
--------------------------------

.. code-block:: ini

   [webservers]
   web1.example.com
   web2.example.com ansible_host=192.168.1.20

   [databases]
   db-primary.example.com
   db-replica.example.com

   [production:children]
   webservers
   databases

For cloud environments, use dynamic inventory plugins (``aws_ec2``, etc.).

--------------------------------
8.9.4 Ansible Modules
--------------------------------

Modules are the **units of work** — each performs a specific task.

+------------------+--------------------------------------------------+
| Module           | Purpose                                          |
+==================+==================================================+
| ``apt`` / ``yum`` / ``dnf``  | Package management             |
+------------------+--------------------------------------------------+
| ``copy``         | Copy file from control node to target            |
+------------------+--------------------------------------------------+
| ``template``     | Copy a Jinja2 template with variable substitution|
+------------------+--------------------------------------------------+
| ``service`` / ``systemd`` | Manage services                    |
+------------------+--------------------------------------------------+
| ``user``         | Manage user accounts                             |
+------------------+--------------------------------------------------+
| ``file``         | Manage file attributes (permissions, ownership)  |
+------------------+--------------------------------------------------+
| ``command`` / ``shell`` | Execute commands (use sparingly)           |
+------------------+--------------------------------------------------+

**Ad-hoc commands:**

.. code-block:: bash

   ansible webservers -m ping
   ansible production -m apt -a 'name=nginx state=present' -b

--------------------------------
8.9.5 Playbooks — The Heart of Ansible
--------------------------------

.. code-block:: yaml

   ---
   - name: Configure web servers
     hosts: webservers
     become: yes
     vars:
       nginx_version: 1.24.0

     tasks:
       - name: Install Nginx
         apt:
           name: nginx={{ nginx_version }}
           state: present

       - name: Ensure Nginx is running
         service:
           name: nginx
           state: started
           enabled: yes

       - name: Copy nginx config
         template:
           src: nginx.conf.j2
           dest: /etc/nginx/nginx.conf
         notify: reload nginx

     handlers:
       - name: reload nginx
         service:
           name: nginx
           state: reloaded

**Running a playbook:**

.. code-block:: bash

   ansible-playbook --syntax-check webserver.yml  # Check syntax
   ansible-playbook --check webserver.yml          # Dry run
   ansible-playbook -v webserver.yml               # Run verbose
   ansible-playbook --diff webserver.yml           # Show changes

--------------------------------
8.9.6 Jinja2 Templates
--------------------------------

.. code-block:: jinja

   server {
       listen {{ http_port | default(80) }};
       server_name {{ server_name }};

       {% if enable_ssl %}
       listen 443 ssl;
       {% endif %}
   }

--------------------------------
8.9.7 Ansible Roles
--------------------------------

Roles organize playbooks into reusable units with a standard directory
structure: ``tasks/``, ``handlers/``, ``templates/``, ``files/``, ``vars/``,
``defaults/``, ``meta/``.

.. code-block:: bash

   ansible-galaxy role install geerlingguy.nginx

--------------------------------
8.9.8 Ansible Vault
--------------------------------

Encrypt sensitive data at rest:

.. code-block:: bash

   ansible-vault create secrets.yml
   ansible-vault edit secrets.yml
   ansible-playbook playbook.yml --ask-vault-pass

--------------------------------
8.9.9 Ansible Antipatterns
--------------------------------

**Antipattern 1:** Using ``command``/``shell`` when a dedicated module exists.
**Antipattern 2:** Writing playbooks that are not idempotent (e.g., appending
without checking).
**Antipattern 3:** Hard-coding secrets in plain text — use Ansible Vault.
**Antipattern 4:** Running playbooks without ``--check`` first.

--------------------------------
8.9.10 Modern Industry Shifts — Immutable Infrastructure & GitOps
--------------------------------

**Mutable vs Immutable Infrastructure:**

+------------------------+-----------------------------------+------------------------------------+
| Aspect                 | Mutable (Ansible model)           | Immutable                           |
+========================+===================================+====================================+
| Server lifecycle       | Install, configure, patch in place| Build image, deploy, destroy        |
+------------------------+-----------------------------------+------------------------------------+
| Configuration drift    | Constant risk                     | Zero drift                          |
+------------------------+-----------------------------------+------------------------------------+
| Rollback               | Complicated (undo changes)        | Simple — redeploy previous image   |
+------------------------+-----------------------------------+------------------------------------+

**Terraform / OpenTofu — Infrastructure Provisioning:**

Creates the servers themselves (VMs, networks, DNS).  Uses HCL and maintains
a state file (``terraform.tfstate``).

.. code-block:: hcl

   resource "aws_instance" "web" {
     ami           = data.aws_ami.ubuntu.id
     instance_type = "t3.medium"
   }

**Packer — Image Baking:**

Creates identical machine images from a single template:

.. code-block:: hcl

   source "amazon-ebs" "ubuntu" {
     ami_name      = "web-nginx-{{timestamp}}"
     instance_type = "t3.micro"
     region        = "us-east-1"
   }

**GitOps — Operational Model:**

The Git repository is the **single source of truth** for infrastructure state.
Operators (ArgoCD, Flux, Atlantis) reconcile live state with Git.

--------------------------------
8.9.11 The Convergence — A Modern IaC Stack
--------------------------------

.. code-block:: text

   Developer push → CI/CD Pipeline → Provision (Terraform) → Configure (Ansible)
         │                                                  │
         └── Bake image (Packer) ←──────────────────────────┘
                                       │
                                       ▼
                              Auto-scaling Group (immutable VMs)

**When to use which tool:**

+-------------------+-------------------------------------------------------+
| Tool              | When to use                                            |
+===================+=======================================================+
| **Ansible**       | Configuring OS packages, files, services, users        |
+-------------------+-------------------------------------------------------+
| **Terraform/OpenTofu**| Provisioning cloud resources (VMs, networks, DNS)  |
+-------------------+-------------------------------------------------------+
| **Packer**        | Creating golden images for immutable deployments       |
+-------------------+-------------------------------------------------------+
| **Shell Scripts** | Simple tasks, bootstrapping, glue logic                |
+-------------------+-------------------------------------------------------+

--------------------------------
8.9.12 Ansible for the Shell Scripter — A Practical Bridge
--------------------------------

.. code-block:: bash

   # Shell: sudo apt install -y nginx
   # Ansible: apt: name=nginx state=present

   # Shell: sudo cp nginx.conf /etc/nginx/nginx.conf
   # Ansible: template: src=nginx.conf.j2 dest=/etc/nginx/nginx.conf

   # Shell: sudo systemctl enable --now nginx
   # Ansible: service: name=nginx enabled=yes state=started

The advantage: Ansible is **idempotent**, **declarative**, and **cross-platform**.

--------------------------------
8.9.13 What NOT to Do — IaC Pitfalls
--------------------------------

**Antipattern 1:** Using Ansible like a shell script — use dedicated modules.
**Antipattern 2:** Storing state locally — use a remote backend (S3,
DynamoDB).
**Antipattern 3:** Hard-coding environment-specific values.
**Antipattern 4:** Manual changes to infrastructure managed by IaC.
**Antipattern 5:** Ignoring secrets management.

--------------------------------
8.9.14 Summary
--------------------------------

+------------------+-------------------------------------------------------+
| Concept          | Key Takeaway                                          |
+==================+=======================================================+
| **Ansible**      | Agentless, push-based CM. YAML playbooks, SSH.        |
+------------------+-------------------------------------------------------+
| **Inventory**    | Defines managed hosts; static files or dynamic cloud  |
+------------------+-------------------------------------------------------+
| **Playbooks**    | Ordered tasks; idempotent, version-controllable       |
+------------------+-------------------------------------------------------+
| **Roles**        | Reusable directory-structured units                   |
+------------------+-------------------------------------------------------+
| **Jinja2**       | Templating engine for dynamic config files            |
+------------------+-------------------------------------------------------+
| **Ansible Vault**| Encrypt secrets at rest in Git                        |
+------------------+-------------------------------------------------------+
| **Immutable Infra**| Build golden images with Packer                    |
+------------------+-------------------------------------------------------+
| **Terraform/OpenTofu**| Declarative cloud provisioning                 |
+------------------+-------------------------------------------------------+
| **GitOps**       | Git as single source of truth                         |
+------------------+-------------------------------------------------------+

--------------------------------
8.9.15 Chapter 8 — Final Words
--------------------------------

You began this chapter writing simple bash scripts.  You progressed through
variables, conditionals, loops, functions, error handling, argument parsing,
scheduling, and parallel execution.  You ended with the tools that manage
thousands of servers with a single ``git push``.

This is the path from craftsman to engineer — from typing commands to
designing systems that configure themselves.
