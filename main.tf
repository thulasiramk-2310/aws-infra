# main.tf
# Core infrastructure definition — closely follows the HashiCorp AWS
# Get-Started tutorial:
#   https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create
#
# Resources created:
#   • VPC          (via the official terraform-aws-modules/vpc module)
#   • Security Group (HTTP + SSH ingress, all egress)
#   • EC2 Instance (Amazon Linux 2023, t2.micro by default)

# ---------------------------------------------------------------------------
# Data Source — look up a recent Amazon Linux 2023 AMI automatically
# ---------------------------------------------------------------------------
# This data source lets Terraform resolve the correct AMI ID at plan time.
# If you prefer to pin a specific AMI, set var.ami_id in terraform.tfvars
# and replace `data.aws_ami.amazon_linux.id` with `var.ami_id` below.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"] # Only trust images published by Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"] # Amazon Linux 2023 pattern
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# VPC — Official HashiCorp / AWS VPC Terraform Module
# Source: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws
# ---------------------------------------------------------------------------
# The module creates the VPC, subnets, route tables, and internet gateway
# in one call — mirroring the tutorial's "use a module" step.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0" # Stay on the 5.x major release line

  # VPC name and CIDR block
  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  # Availability zones — the tutorial uses a single AZ for simplicity
  azs            = [var.availability_zone]
  public_subnets = [var.public_subnet_cidr]

  # Networking options
  enable_nat_gateway = false # Keep it simple — no private subnets needed
  enable_vpn_gateway = false

  # Attach Name tag to every sub-resource created by the module
  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ---------------------------------------------------------------------------
# Security Group
# ---------------------------------------------------------------------------
# Controls inbound and outbound traffic for the EC2 instance.
# Following the tutorial pattern: allow HTTP (80) and SSH (22) inbound,
# and allow all outbound traffic.
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Allow HTTP and SSH inbound traffic"
  vpc_id      = module.vpc.vpc_id # Attach to the VPC created above

  # Inbound rule — HTTP
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Inbound rule — SSH
  # ⚠️  Allowing SSH from 0.0.0.0/0 is for demonstration purposes only.
  # In production, restrict cidr_blocks to your own IP: ["<YOUR_IP>/32"]
  ingress {
    description = "SSH from anywhere - DEMO ONLY, restrict to MyIP/32 in production"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rule — allow all traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

# ---------------------------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------------------------
# Launches an Amazon Linux 2023 instance in the public subnet.
# The user_data script installs and starts the Apache HTTP server so you
# can verify the instance is reachable via its public IP on port 80.
resource "aws_instance" "web" {
  # AMI resolved at plan time via the data source above.
  # To use a fixed AMI instead, replace with: ami = var.ami_id
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  # Place the instance in the first (and only) public subnet
  subnet_id = module.vpc.public_subnets[0]

  # Attach the security group defined above
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Request a public IP so the instance is reachable from the internet
  associate_public_ip_address = true

  # Bootstrap script — installs Apache and writes a simple HTML page.
  # This matches the "Hello, World" pattern from the HashiCorp tutorial.
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello from Terraform — ${var.project_name}</h1>" > /var/www/html/index.html
  EOF

  # Ensure the VPC and security group are fully created before launching
  depends_on = [module.vpc, aws_security_group.web_sg]

  tags = {
    Name = "${var.project_name}-web-instance"
  }
}
