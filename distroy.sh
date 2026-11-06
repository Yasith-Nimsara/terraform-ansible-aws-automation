#!/bin/bash
set -euo pipefail

echo "==========================================="
echo " Destroying AWS Infrastructure (Terraform)"
echo "==========================================="
cd "$(dirname "$0")/terraform"
terraform destroy -auto-approve

echo "All AWS resources destroyed cleanly"
