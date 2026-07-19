.. _chapter-11-7:

============================================================
11.7 Infrastructure as Code & Cloud Initialization
============================================================

The final piece of the cloud native puzzle is **Infrastructure as Code (IaC)** — the
practice of managing infrastructure (servers, networks, load balancers, DNS records)
through machine-readable definition files rather than manual command-line operations or
click-ops in a web console. IaC brings version control, code review, automated testing,
and repeatability to infrastructure management.

In this section, we cover three interrelated pillars:

1. **cloud-init:** The industry-standard tool for bootstrapping virtual machines on
   first boot.
2. **OpenTofu:** The open-source, community-driven successor to Terraform for
   declarative cloud resource provisioning.
3. **Cloud CLIs:** The AWS CLI, Google Cloud CLI (``gcloud``), and Azure CLI (``az``)
   for imperative operations and automation.

11.7.1 cloud-init: Bootstrapping Virtual Machines
==================================================

When a virtual machine boots for the first time in a cloud environment (AWS, GCP,
Azure, OpenStack, or even a local libvirt VM), it needs to configure networking,
set the hostname, create users, install packages, and start services. Doing this
manually at scale is impossible. **cloud-init** (Canonical, 2009) is the de-facto
standard for this first-boot automation.

**How cloud-init works:**

The boot sequence is:

.. code-block:: none

   VM Boot → BIOS/UEFI → Kernel → init/systemd
     │
     ├── [1] cloud-init-local.service
     │       └── Reads data source (metadata service, ISO, config drive)
     │
     ├── [2] cloud-init-networking.service
     │       └── Configures network interfaces (DHCP or static)
     │
     ├── [3] cloud-init.service
     │       ├── Processes user-data (scripts, cloud-config YAML)
     │       ├── Sets hostname
     │       ├── Adds users/SSH keys
     │       ├── Mounts ephemeral disks
     │       └── Executes runcmd scripts
     │
     └── [4] cloud-final.service
             └── Handles late tasks (package installs via apt/yum,
                  Chef/Puppet/Ansible runs)

**User-data formats:**

cloud-init accepts several user-data formats, detected by the first line:

.. list-table:: cloud-init User-data Formats
   :header-rows: 1
   :widths: 20 30 50

   * - Shebang / Header
     - Type
     - Use case
   * - ``#!/bin/bash``
     - Shell script
     - Arbitrary boot-time commands (runs as root)
   * - ``#cloud-config``
     - YAML config
     - Declarative configuration (users, packages, files, etc.)
   * - ``#cloud-boothook``
     - Boothook script
     - Runs every boot (not just first boot)
   * - ``#include``
     - Include file
     - Pulls in multiple user-data files from URLs
   * - ``## template: jinja2``
     - Jinja2 template
     - Templated cloud-config with instance metadata variables

**Example: cloud-config for an Ubuntu web server:**

.. code-block:: yaml

   #cloud-config
   hostname: webserver01
   manage_etc_hosts: true

   users:
     - name: admin
       groups: [wheel, docker]
       sudo: ALL=(ALL) NOPASSWD:ALL
       ssh_authorized_keys:
         - ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTY... user@example.com
     - name: appuser
       uid: 1001
       shell: /bin/bash
       ssh_authorized_keys:
         - ssh-ed25519 AAAAC3NzaC... appuser@example.com

   packages:
     - nginx
     - docker.io
     - python3-pip
     - htop
     - fail2ban

   package_update: true
   package_upgrade: true

   write_files:
     - path: /etc/nginx/sites-available/default
       content: |
         server {
             listen 80 default_server;
             root /var/www/html;
             index index.html;
         }
       permissions: '0644'

   runcmd:
     - [systemctl, enable, --now, nginx]
     - [systemctl, enable, --now, docker]
     - [ufw, allow, 22/tcp]
     - [ufw, allow, 80/tcp]
     - [ufw, --force, enable]

   power_state:
     delay: now
     mode: reboot
     message: Initial setup complete, rebooting
     timeout: 30

**Injecting cloud-init into local VMs (libvirt):**

.. code-block:: bash

   # Create a cloud-init ISO (NoCloud datasource)
   mkdir -p /tmp/ci-data
   cat > /tmp/ci-data/meta-data << 'EOF'
   instance-id: ubuntu-vm-01
   local-hostname: webserver01
   EOF

   # Copy the user-data above to /tmp/ci-data/user-data
   # Then create the ISO
   sudo mkisofs -o /var/lib/libvirt/images/ci.iso \
     -V cidata \
     -r -J \
     /tmp/ci-data/meta-data /tmp/ci-data/user-data

   # Attach it to the VM (virt-install or virsh edit)
   # <disk type='file' device='cdrom'>
   #   <driver name='qemu' type='raw'/>
   #   <source file='/var/lib/libvirt/images/ci.iso'/>
   #   <target dev='sda' bus='sata'/>
   #   <readonly/>
   # </disk>

**cloud-init on AWS:**

On AWS, cloud-init reads user-data from the **instance metadata service** at
``http://169.254.169.254/latest/user-data`` (link-local address, no internet
required). You can specify user-data when launching an instance via the AWS Console,
CLI, or OpenTofu.

.. code-block:: bash

   # Pass user-data on EC2 launch
   aws ec2 run-instances \
     --image-id ami-0abcdef1234567890 \
     --instance-type t3.medium \
     --key-name my-key \
     --user-data file://cloud-config.yaml \
     --security-group-ids sg-01234567

.. note::
   cloud-init runs only on **first boot** by default. To trigger it again on a
   running instance, clean the instance state:
   ``sudo cloud-init clean --logs``, then reboot. For subsequent boots, use
   ``cloud-boothook`` or ``scripts/per-boot.d/``.

11.7.2 OpenTofu: Declarative Cloud Provisioning
=================================================

**OpenTofu** is the open-source, community-driven fork of Terraform created in
response to HashiCorp's 2023 license change from MPL to BSL (Business Source License).
OpenTofu is governed by the Linux Foundation, is fully compatible with Terraform
providers and modules, and has been adopted as the default IaC tool by most of the
community.

**Core concepts:**

* **Providers:** Plugins that interface with cloud APIs (AWS, GCP, Azure, Kubernetes,
  etc.). A provider translates OpenTofu's declarative resources into API calls.
* **Resources:** Infrastructure objects (``aws_instance``, ``aws_s3_bucket``,
  ``kubernetes_deployment``).
* **State:** A JSON file (``terraform.tfstate``) that maps your declared resources to
  real-world infrastructure. This state is stored locally or, better, in a **remote
  backend** (S3, GCS, Azure Storage) with state locking to prevent concurrent
  modifications.
* **Module:** A reusable collection of resources (e.g., a VPC module, a database
  module). Modules can be sourced from the registry, Git, or local paths.

**Anatomy of an OpenTofu configuration:**

.. code-block::

   project/
   ├── main.tf           # Root configuration (providers, modules)
   ├── variables.tf      # Input variables
   ├── outputs.tf        # Output values
   ├── versions.tf       # Provider version constraints
   └── terraform.tfstate # State file (auto-generated)

.. code-block::

   # versions.tf
   terraform {
     required_version = ">= 1.8.0"
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = "~> 5.0"
       }
       random = {
         source  = "hashicorp/random"
         version = "~> 3.0"
       }
     }
     backend "s3" {
       bucket         = "myorg-tofu-state"
       key            = "production/network/terraform.tfstate"
       region         = "us-east-1"
       dynamodb_table = "tofu-state-locks"
       encrypt        = true
     }
   }

.. code-block::

   # variables.tf
   variable "region" {
     description = "AWS region"
     type        = string
     default     = "us-east-1"
   }

   variable "instance_type" {
     description = "EC2 instance type"
     type        = string
     default     = "t3.medium"
   }

   variable "ami_id" {
     description = "AMI ID (should come from Packer or data source)"
     type        = string
   }

.. code-block::

   # main.tf
   provider "aws" {
     region = var.region
   }

   # Security group
   resource "aws_security_group" "web_sg" {
     name        = "web-sg-${var.region}"
     description = "Web server security group"

     ingress {
       from_port   = 80
       to_port     = 80
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
     }

     ingress {
       from_port   = 443
       to_port     = 443
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
     }

     egress {
       from_port   = 0
       to_port     = 0
       protocol    = "-1"
       cidr_blocks = ["0.0.0.0/0"]
     }

     tags = {
       Name = "web-sg"
     }
   }

   # EC2 instance with cloud-init
   resource "aws_instance" "web" {
     ami                    = var.ami_id
     instance_type          = var.instance_type
     key_name               = "my-key"
     vpc_security_group_ids = [aws_security_group.web_sg.id]

     user_data = <<-EOF
       #!/bin/bash
       echo "Hello from OpenTofu!" > /var/www/html/index.html
       systemctl enable --now nginx
     EOF

     user_data_replace_on_change = true

     root_block_device {
       volume_type = "gp3"
       volume_size = 20
     }

     tags = {
       Name = "web-instance"
     }
   }

   # Output the instance's public IP
   output "instance_public_ip" {
     description = "Public IP of the web instance"
     value       = aws_instance.web.public_ip
   }

**The OpenTofu workflow:**

.. code-block:: bash

   # 1. Initialise (download providers, set up backend)
   tofu init

   # 2. Format and validate
   tofu fmt
   tofu validate

   # 3. Plan (preview changes)
   tofu plan -out=plan.tfplan

   # 4. Apply (execute changes)
   tofu apply plan.tfplan

   # 5. Destroy (tear down)
   tofu destroy

**Managing Kubernetes with OpenTofu:**

OpenTofu also provisions Kubernetes resources directly:

.. code-block::

   provider "kubernetes" {
     config_path = "~/.kube/config"
   }

   resource "kubernetes_namespace" "app" {
     metadata {
       name = "production"
     }
   }

   resource "kubernetes_deployment" "nginx" {
     metadata {
       name      = "nginx-deployment"
       namespace = kubernetes_namespace.app.metadata[0].name
     }
     spec {
       replicas = 3
       selector {
         match_labels = {
           app = "nginx"
         }
       }
       template {
         metadata {
           labels = {
             app = "nginx"
           }
         }
         spec {
           container {
             image = "nginx:1.27-alpine"
             name  = "nginx"
             port {
               container_port = 80
             }
           }
         }
       }
     }
   }

.. note::
   **OpenTofu vs Terraform in 2026:** OpenTofu 1.9+ includes features not present in
   Terraform, including client-side provider signing verification, ``tofu test``
   for end-to-end infrastructure testing, and enhanced encryption for state files.
   The community and most third-party tooling (CI/CD integrations, policy engines
   like OPA/Conftest, Terragrunt) now support OpenTofu as a first-class target.

11.7.3 Cloud CLIs: AWS CLI, gcloud, az
========================================

While OpenTofu is the declarative, stateful approach to infrastructure, cloud CLIs are
essential for **imperative** operations — one-off commands, automation scripts, and
tasks that do not warrant a full IaC module.

**AWS CLI (v2):**

.. code-block:: bash

   # Install (Linux)
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Configure
   aws configure
   # AWS Access Key ID: AKIA...
   # AWS Secret Access Key: ...
   # Default region: us-east-1
   # Default output format: json

   # Common operations
   aws ec2 describe-instances --filters "Name=tag:Name,Values=web-*"
   aws s3 ls s3://my-bucket --recursive --human-readable
   aws s3 sync ./dist/ s3://my-bucket/ --delete
   aws ecs update-service --cluster prod --service api --desired-count 5
   aws lambda invoke --function-name my-function output.json
   aws logs tail /aws/lambda/my-function --follow

   # SSM Session Manager (SSH-less access)
   aws ssm start-session --target i-0123456789abcdef0

**Google Cloud CLI (gcloud):**

.. code-block:: bash

   # Install
   # Follow https://cloud.google.com/sdk/docs/install
   # Or use the apt/yum repository:
   sudo apt install google-cloud-cli

   # Authenticate
   gcloud auth login
   gcloud config set project my-project-id
   gcloud config set compute/region europe-west1

   # Common operations
   gcloud compute instances list
   gcloud compute ssh my-instance --zone=europe-west1-b
   gcloud container clusters get-credentials my-cluster --region=europe-west1
   gcloud storage cp /local/file gs://my-bucket/
   gcloud run deploy my-service --image gcr.io/my-project/my-image:latest
   gcloud builds submit --tag gcr.io/my-project/my-image:latest

**Azure CLI (az):**

.. code-block:: bash

   # Install
   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

   # Authenticate
   az login
   az account set --subscription "My Subscription"

   # Common operations
   az vm list --output table
   az vm create \
     --resource-group my-rg \
     --name my-vm \
     --image Ubuntu2204 \
     --admin-username azureuser \
     --generate-ssh-keys
   az aks get-credentials --resource-group my-rg --name my-aks-cluster
   az acr login --name myregistry
   docker tag my-app myregistry.azurecr.io/my-app:v1
   docker push myregistry.azurecr.io/my-app:v1

**Multi-cloud authentication strategies:**

For production automation, never use static access keys. Adopt one of:

* **AWS:** IAM Instance Profiles (for EC2) or IAM Roles for Service Accounts (IRSA)
  in EKS.
* **GCP:** Service Account keys (JSON) with limited scope, or Workload Identity
  Federation for GitHub/GitLab Actions.
* **Azure:** Managed Identity for VMs, or Azure AD Workload Identity for AKS.

.. code-block:: bash

   # AWS: Use an instance profile
   aws sts assume-role --role-arn arn:aws:iam::123456789:role/my-role \
     --role-session-name auto-session

   # GCP: Use a workload identity federation
   gcloud iam workload-identity-pools create my-pool

   # Azure: Use managed identity
   az vm identity assign --resource-group my-rg --name my-vm

11.7.4 The GitOps Workflow
============================

**GitOps** (pioneered by Weaveworks) extends IaC to make Git the **single source of
truth** for both application code and infrastructure configuration. The pattern is:

1. **Desired state** in Git (OpenTofu configs, Kubernetes manifests).
2. **An operator** (Flux, Argo CD, Crossplane) continuously reconciles the live
   environment with Git.
3. **Pull requests** are the mechanism for change. Any deviation from Git is
   automatically corrected (self-healing).

This is the operational model for 2026 cloud native environments. The tools you have
learned in this chapter — OpenTofu, cloud-init, Kubernetes — form the foundation that
makes GitOps possible.

11.7.5 Antipatterns
===================

.. admonition:: Antipattern: Hard-Coding Cloud Credentials
   :class: danger

   Never embed access keys in source code, OpenTofu configs, or Git repositories.
   Use environment variables (for local dev), cloud provider IAM roles (for
   production), or a secrets manager (HashiCorp Vault, AWS Secrets Manager).

.. admonition:: Antipattern: Manually SSH-ing Into Cloud VMs
   :class: warning

   Every manual SSH session is configuration drift. If you need to change a running
   instance, update the OpenTofu config + cloud-init user-data, then replace the
   instance. If you need to debug, use **ephemeral debug containers** or cloud
   provider session manager (AWS SSM), never persistent SSH.

.. admonition:: Antipattern: Storing State Files in Git
   :class: warning

   OpenTofu state files contain sensitive information (resource IDs, connection
   strings, sometimes plaintext secrets). Never commit ``terraform.tfstate`` to
   version control. Always use a **remote backend** (S3 + DynamoDB, GCS, Azure
   Storage) with encryption at rest.

11.7.6 Practical Exercises
==========================

**1. Write and Test a cloud-config**

.. code-block:: bash

   # Write a cloud-config that installs nginx and creates a custom index.html
   cat > test-cloud-config.yaml << 'EOF'
   #cloud-config
   packages:
     - nginx
   write_files:
     - path: /var/www/html/index.html
       content: |
         <h1>Provisioned by cloud-init</h1>
         <p>Boot time: $(date)</p>
       permissions: '0644'
   runcmd:
     - [systemctl, enable, --now, nginx]
   EOF

   # Validate with cloud-init's built-in checker
   sudo apt install cloud-init
   cloud-init devel schema --config-file test-cloud-config.yaml

**2. Deploy an EC2 Instance with OpenTofu**

.. code-block:: bash

   # If you have an AWS account, create a minimal deployment
   mkdir -p ~/tofu-lab && cd ~/tofu-lab

   cat > main.tf << 'EOF'
   terraform {
     required_providers {
       aws = { source = "hashicorp/aws", version = "~> 5.0" }
     }
   }

   provider "aws" {
     region = "us-east-1"
   }

   data "aws_ami" "ubuntu" {
     most_recent = true
     filter {
       name   = "name"
       values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
     }
     owners = ["099720109477"]  # Canonical
   }

   resource "aws_instance" "web" {
     ami                    = data.aws_ami.ubuntu.id
     instance_type          = "t3.micro"
     vpc_security_group_ids = [aws_security_group.web.id]

     user_data = <<-EOF
       #!/bin/bash
       apt update && apt install -y nginx
       echo "Hello from OpenTofu!" > /var/www/html/index.html
       systemctl enable --now nginx
     EOF

     tags = { Name = "tofu-lab-web" }
   }

   resource "aws_security_group" "web" {
     name        = "tofu-lab-web-sg"
     description = "Allow HTTP"

     ingress {
       from_port   = 80
       to_port     = 80
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
     }

     egress {
       from_port   = 0
       to_port     = 0
       protocol    = "-1"
       cidr_blocks = ["0.0.0.0/0"]
     }
   }

   output "public_ip" {
     value = aws_instance.web.public_ip
   }
   EOF

   tofu init
   tofu plan
   tofu apply -auto-approve
   curl http://$(tofu output -raw public_ip)

   # Clean up
   tofu destroy -auto-approve

**3. Cloud CLI Multi-Cloud Query**

.. code-block:: bash

   # List instances across clouds (assumes credentials configured)
   echo "=== AWS ===" && aws ec2 describe-instances --query \
     'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' \
     --output table

   echo "=== GCP ===" && gcloud compute instances list

   echo "=== Azure ===" && az vm list --output table
