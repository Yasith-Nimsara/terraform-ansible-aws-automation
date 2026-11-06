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
2. [DevOps and Security Best Practices Implemented](#2-devops--security-best-practices-implemented)
3. [Project Directory Structure](#3-project-directory-structure)
4. [Prerequisites](#4-prerequisites)
5. [Step-by-Step Usage Guide](#5-step-by-step-usage-guide)
6. [Automated Cloud Teardown](#6-automated-cloud-teardown-zero-cost-cleanup)


---

## 1. Architecture and Workflow Overview


```text
                     [ Local Ubuntu Control Node (./deploy.sh) ]
                                         │
             ┌───────────────────────────┴───────────────────────────┐
             ▼                                                       ▼ 
   (Phase 1: Provisioning)                           (Phase 2 and 3: Config and Deploy)
             |                                                       |
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

## 2. DevOps and Security Best Practices Implemented

* **Dynamic AMI Resolution (`data "aws_ami"`):** Avoids hardcoded AMI IDs by dynamically querying Canonical's official owner ID (`099720109477`) for the latest Ubuntu 24.04 HVM GP3 image on every deployment.
* **Dynamic Inventory Handoff (`local_file` Resource):** Terraform automatically generates `ansible/inventory.ini` with the new EC2 instance's public IP address, eliminating manual copy-pasting when IP addresses change.
* **SSH Boot Race-Condition Handling:** Uses `ansible all -m wait_for_connection` with a 120-second timeout so automation never fails while waiting for AWS EC2 cloud-init and `sshd` to initialize.
* **Defense-in-Depth Firewalling:** Combines perimeter network security (**AWS Security Groups**) with host-level operating system firewalling (**Ubuntu UFW** configured to deny all incoming traffic except ports `22` and `80`).
* **SSH Daemon Hardening (`sshd_config`):** Enforces key-only authentication (`PasswordAuthentication no`) and blocks direct root logins (`PermitRootLogin no`), utilizing **Ansible Handlers** (`notify: Restart SSH`) so the SSH service only restarts when configuration changes occur.
* **True Idempotency:** Running `ansible-playbook setup.yml` multiple times results in `changed=0` on subsequent runs, preventing configuration drift without disrupting running containers.

---

## 3. Project Directory Structure

```text
devops-project-2/
├── terraform/
│   ├── main.tf 
│   └── outputs.tf            # Outputs EC2 Public IP and ready-to-run SSH command
├── ansible/
│   ├── ansible.cfg           # Sets default inventory path, remote user (ubuntu), and SSH key path
│   ├── index.html            # Custom status dashboard deployed into the Nginx container
│   └── setup.yml             # Idempotent playbook for OS patching, SSH/UFW hardening & Docker deploy
├── deploy.sh                 # One-command pipeline: Terraform Apply -> Wait for SSH -> Ansible Playbook
├── destroy.sh                # One-command teardown: cleanly destroys all AWS resources
├── .gitignore  
└── README.md                 # Project documentation
```

---

## 4. Prerequisites

* **AWS Account** and **AWS CLI v2** 
* **Terraform** 
* **Ansible**
* **OpenSSH Client** (`ssh-keygen`)

---

## 5. Step-by-Step Usage Guide

### 1. Clone the Repository

```bash
git clone https://github.com/Yasith-Nimsara/terraform-ansible-aws-automation.git
cd terraform-ansible-aws-automation
```

### 2. Generate Your Local Cloud SSH Key Pair

```bash
ssh-keygen -t ed25519 -f ./cloud-key -N ""
```

### 3. Run the One-Command Deployment Pipeline

```bash
chmod +x deploy.sh destroy.sh
./deploy.sh
```

### 4. Access the Live Cloud Server
`http://<SERVER_PUBLIC_IP>` 


---


## 6. Automated Cloud Teardown

```bash
./destroy.sh
```

---

