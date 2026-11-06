# Cloud Infrastructure Provisioning and OS Hardening with Terraform and Ansible

![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![Ansible](https://img.shields.io/badge/Ansible-EE0000?style=for-the-badge&logo=ansible&logoColor=white)
![AWS](https://img.shields.io/badge/AWS_EC2-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu_24.04-E95420?style=for-the-badge&logo=ubuntu&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)

An end-to-end **Infrastructure as Code (IaC)** and **Configuration Management** pipeline that provisions an AWS EC2 cloud server using **Terraform**, dynamically bridges the server IP into **Ansible**, hardens the Linux operating system (SSH & UFW Firewall), and deploys a containerized **Nginx** web server using a single command (`./deploy.sh`).

---

## Table of Contents
1. [Architecture and Workflow Overview](#1-architecture--workflow-overview)
2. [Why Terraform + Ansible?](#2-why-terraform--ansible)
3. [DevOps and Security Best Practices Implemented](#3-devops--security-best-practices-implemented)
4. [Project Directory Structure](#4-project-directory-structure)
5. [Prerequisites](#5-prerequisites)
6. [Step-by-Step Usage Guide](#6-step-by-step-usage-guide)
7. [Verification and Idempotency Testing](#7-verification--idempotency-testing)
8. [Automated Cloud Teardown](#8-automated-cloud-teardown-zero-cost-cleanup)
9. [Troubleshooting Common Issues](#9-troubleshooting-common-issues)

---

## 1. Architecture & Workflow Overview


```text
                [ Local Ubuntu Control Node (./deploy.sh) ]
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         ▼ (Phase 1: Provisioning)                               ▼ (Phase 2 and 3: Config and Deploy)
┌─────────────────────────┐                             ┌─────────────────────────┐
│        Terraform        │                             │         Ansible         │
│  (AWS Provider + Local) │──── Writes Dynamic IP ─────►│   (ansible/setup.yml)   │
└────────────┬────────────┘     to inventory.ini        └────────────┬────────────┘
             │                                                       │
             │                                                       │ 
             ▼                                                       ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud (us-east-1)                              │
│                                                                                 │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │ AWS Security Group (devops-project2-sg) — Inbound: 22 (SSH), 80 (HTTP)    │  │
│  │                                                                           │  │
│  │  ┌─────────────────────────────────────────────────────────────────────┐  │  │
│  │  │ EC2 Instance: Ubuntu 24.04 LTS                                      │  │  │
│  │  │                                                                     │  │  │
│  │  │  1. OS Hardening: Root SSH Disabled, Password Auth Disabled         │  │  │
│  │  │  2. Host Firewall: UFW Active (Deny Incoming, Allow 22/tcp & 80/tcp)│  │  │
│  │  │  3. Container Runtime: Docker Engine                                │  │  │
│  │  │  4. Web Workload: Nginx 1.27 Alpine Container (Port 80:80)          │  │  │
│  │  └─────────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Why Terraform + Ansible?

A core DevOps principle in this project is using the right tool for each layer of the stack:

| Layer | Tool Used | Responsibility in This Project |
| :--- | :--- | :--- |
| **Cloud Infrastructure Layer** | **Terraform** | Queries AWS for the latest Ubuntu 24.04 LTS AMI, uploads the public SSH key (`aws_key_pair`), configures the outer cloud firewall (`aws_security_group`), provisions the EC2 VM (`aws_instance`), and outputs the public IP into `ansible/inventory.ini`. |
| **Bridge / Orchestration** | **Bash (`deploy.sh`) + Ansible `wait_for_connection`** | Solves the "SSH race condition" by polling the newly created EC2 instance until the Ubuntu SSH daemon finishes booting before triggering configuration playbooks. |
| **OS & Application Layer** | **Ansible** | Connects over SSH, updates APT repositories, hardens `/etc/ssh/sshd_config`, enables the host-level `ufw` firewall, installs and starts `docker.io`, and deploys the `nginx-web` container with a custom bind-mounted UI. |

---

## 3. DevOps & Security Best Practices Implemented

* **Dynamic AMI Resolution (`data "aws_ami"`):** Avoids hardcoded AMI IDs by dynamically querying Canonical's official owner ID (`099720109477`) for the latest Ubuntu 24.04 HVM GP3 image on every deployment.
* **Dynamic Inventory Handoff (`local_file` Resource):** Terraform automatically generates `ansible/inventory.ini` with the new EC2 instance's public IP address, eliminating manual copy-pasting when IP addresses change.
* **SSH Boot Race-Condition Handling:** Uses `ansible all -m wait_for_connection` with a 120-second timeout so automation never fails while waiting for AWS EC2 cloud-init and `sshd` to initialize.
* **Defense-in-Depth Firewalling:** Combines perimeter network security (**AWS Security Groups**) with host-level operating system firewalling (**Ubuntu UFW** configured to deny all incoming traffic except ports `22` and `80`).
* **SSH Daemon Hardening (`sshd_config`):** Enforces key-only authentication (`PasswordAuthentication no`) and blocks direct root logins (`PermitRootLogin no`), utilizing **Ansible Handlers** (`notify: Restart SSH`) so the SSH service only restarts when configuration changes occur.
* **True Idempotency:** Running `ansible-playbook setup.yml` multiple times results in `changed=0` on subsequent runs, preventing configuration drift without disrupting running containers.

---

## 4. Project Directory Structure

```text
devops-project-3/
├── terraform/
│   ├── main.tf               # AWS Provider, dynamic AMI data source, EC2, SG, KeyPair & local_file
│   └── outputs.tf            # Outputs EC2 Public IP and ready-to-run SSH command
├── ansible/
│   ├── ansible.cfg           # Sets default inventory path, remote user (ubuntu), and SSH key path
│   ├── index.html            # Custom status dashboard deployed into the Nginx container
│   └── setup.yml             # Idempotent playbook for OS patching, SSH/UFW hardening & Docker deploy
├── deploy.sh                 # One-command pipeline: Terraform Apply -> Wait for SSH -> Ansible Playbook
├── destroy.sh                # One-command teardown: cleanly destroys all AWS resources
├── .gitignore                # Prevents SSH keys, .tfstate files, and dynamic inventories from leaking
└── README.md                 # Project documentation
```

---

## 5. Prerequisites

Ensure the following tools are installed on your local Linux machine (Control Node):
* **AWS Account** (Free-Tier eligible) & **AWS CLI v2** configured via `aws configure`
* **Terraform** (v1.5+)
* **Ansible** (v2.14+ with `community.general` and `community.docker` collections)
* **OpenSSH Client** (`ssh-keygen`)

---

## 6. Step-by-Step Usage Guide

### 1. Clone the Repository
```bash
git clone [https://github.com/Yasith-Nimsara/](https://github.com/Yasith-Nimsara/)<your-repo-name>.git
cd <your-repo-name>
```

### 2. Generate Your Local Cloud SSH Key Pair
Because private SSH keys are never committed to Git, generate a fresh `ed25519` key pair in the project root before deploying:
```bash
ssh-keygen -t ed25519 -f ./cloud-key -N ""
```

### 3. Run the One-Command Deployment Pipeline
Execute `deploy.sh` to provision the AWS server, wait for SSH readiness, harden the OS, and launch the Docker container:
```bash
chmod +x deploy.sh destroy.sh
./deploy.sh
```

### 4. Access the Live Cloud Server
Once the script displays `DEPLOYMENT COMPLETE!`, open the printed `http://<SERVER_PUBLIC_IP>` URL in your browser (or run `curl http://<SERVER_PUBLIC_IP>`).

---

## 7. Verification & Idempotency Testing

### Test 1: Verify Ansible Idempotency
Re-run the playbook against the live server:
```bash
cd ansible
ansible-playbook setup.yml
```
**Expected Output:** `changed=0` across all tasks in the `PLAY RECAP`, confirming desired state alignment.

### Test 2: Verify Host Firewall (UFW) Rules
```bash
ansible all -m command -a "sudo ufw status verbose"
```
**Expected Output:** `Status: active`, `Default: deny (incoming)`, with only `22/tcp` and `80/tcp` allowed.

### Test 3: Verify SSH Hardening
```bash
ansible all -m command -a "sudo grep -E '^(PermitRootLogin|PasswordAuthentication)' /etc/ssh/sshd_config"
```
**Expected Output:**
```text
PermitRootLogin no
PasswordAuthentication no
```

### Test 4: Verify Running Docker Container
```bash
ansible all -m command -a "docker ps"
```
**Expected Output:** Shows the `nginx-web` container (`nginx:1.27-alpine`) healthy and listening on `0.0.0.0:80->80/tcp`.

---

## 8. Automated Cloud Teardown (Zero-Cost Cleanup)

To avoid incurring AWS charges after testing, destroy the EC2 instance, Security Group, and Key Pair with a single command:

```bash
./destroy.sh
```

---

## 9. Troubleshooting Common Issues

* **Mobile Browser Fails to Open `http://<SERVER_IP>` While Laptop Works:**
  * **Cause:** Modern mobile browsers automatically upgrade bare IP addresses to `https://` (Port 443), which is closed on this HTTP-only (Port 80) lab server.
  * **Fix:** Explicitly type `http://<SERVER_IP>:80` in an Incognito mobile tab or disable "Always use secure connections" in mobile browser settings.
* **Ansible Fails with `UNREACHABLE! => Connection refused` When Run Manually:**
  * **Cause:** AWS marks the EC2 instance as `running` before Ubuntu finishes initializing the SSH daemon.
  * **Fix:** Use `./deploy.sh`, which runs `ansible all -m wait_for_connection` before executing the playbook.

---
