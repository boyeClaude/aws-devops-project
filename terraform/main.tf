terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Security Group ───────────────────────────────────────────────────────────

resource "aws_security_group" "devops_sg" {
  name        = "devops-project-sg"
  description = "Security group for devops project EC2 instance"

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana
  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus
  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Node Exporter
  ingress {
    description = "Node Exporter"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "devops-project-sg"
    Project = "aws-devops-project"
  }
}

# ─── EC2 Instance ─────────────────────────────────────────────────────────────

resource "aws_instance" "devops_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.devops_sg.id]

  user_data = file("${path.module}/scripts/setup.sh")

  tags = {
    Name    = "devops-project-server-tf"
    Project = "aws-devops-project"
  }
}

# ─── Auto-generate Ansible inventory with correct IP ─────────────────────────

resource "local_file" "ansible_inventory" {
  content = <<EOF
[devops_server]
${aws_instance.devops_server.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/devops-project-key.pem

[devops_server:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
  filename = "../ansible/inventory.ini"
}


/*What this does — every time `terraform apply` runs and creates a new EC2, Terraform automatically writes the new IP into `ansible/inventory.ini`. So the flow becomes:

terraform apply 
      ↓
EC2 created with new IP
      ↓
inventory.ini updated automatically with that IP
      ↓
ansible-playbook playbook.yml  ← always points to the right server */