#!/bin/bash
set -euo pipefail

echo "============================================="
echo " Provisioning AWS Infrastructure (Terraform)"
echo "============================================="
cd "$(dirname "$0")/terraform"
terraform init -input=false
terraform apply -auto-approve

SERVER_IP=$(terraform output -raw server_public_ip)
echo "EC2 Server created at IP: $SERVER_IP"
echo "Ansible inventory.ini updated automatically!"

echo ""
echo "================================"
echo " Waiting for Ubuntu SSH to Boot"
echo "================================"
cd ../ansible
ansible all -m wait_for_connection -a "timeout=120 delay=5"

echo ""
echo "============================================="
echo " Hardening OS and Deploying Docker (Ansible)"
echo "============================================="
ansible-playbook setup.yml

echo ""
echo "===================================================="
echo " DEPLOYMENT COMPLETE"
echo " Live Website: http://$SERVER_IP"
echo " SSH Command: ssh -i ./cloud-key ubuntu@$SERVER_IP"
echo "===================================================="
