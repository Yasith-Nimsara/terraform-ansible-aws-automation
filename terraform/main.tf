terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# 1. Configure AWS Provider (us-east-1 Free Tier region)
provider "aws" {
  region = "us-east-1"
}

# 2. Automatically find the latest Ubuntu 24.04 LTS AMI ID
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Official Canonical (Ubuntu) Owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 3. Upload your public SSH key to AWS
resource "aws_key_pair" "deployer_key" {
  key_name   = "devops-project2-key"
  public_key = file("~/devops-project-2/cloud-key.pub")
}

# 4. Create Cloud Firewall (Security Group: allow SSH 22 and HTTP 80)
resource "aws_security_group" "web_sg" {
  name        = "devops-project2-sg"
  description = "Allow SSH and HTTP traffic"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Launch the Free-Tier EC2 Instance
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.deployer_key.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  tags = {
    Name    = "DevOps-Project-2-Server"
    Project = "Terraform-Ansible-Lab"
  }
}

# 6. Automatically generate Ansible's inventory.ini file
resource "local_file" "ansible_inventory" {
  content = <<-EOT
    [webservers]
    ${aws_instance.web_server.public_ip}
  EOT
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
}
