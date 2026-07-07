# variables.tf
# Declares all input variables consumed by this configuration.
# Values are supplied via terraform.tfvars, environment variables
# (TF_VAR_*), or CLI flags (-var="key=value").

# ---------------------------------------------------------------------------
# AWS Region
# ---------------------------------------------------------------------------
variable "aws_region" {
  description = "AWS region in which all resources will be provisioned."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "aws_region must be a valid AWS region identifier, e.g. us-east-1."
  }
}

# ---------------------------------------------------------------------------
# Project / Naming
# ---------------------------------------------------------------------------
variable "project_name" {
  description = "Logical name for this project. Used as a prefix on resource names and tags."
  type        = string
  default     = "aws-infra"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vpc_cidr" {
  description = "CIDR block for the VPC. Must be a valid IPv4 CIDR (e.g. 10.0.0.0/16)."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the single public subnet carved out of the VPC."
  type        = string
  default     = "10.0.1.0/24"
}

variable "availability_zone" {
  description = <<-EOT
    Availability zone within the selected region for the public subnet and EC2 instance.
    Note: AWS does not guarantee that 'us-east-1a' maps to the same physical zone across
    all accounts. For production use, derive the AZ dynamically with the
    `data "aws_availability_zones"` data source instead of hardcoding.
  EOT
  type        = string
  default     = "us-east-1a"
}

# ---------------------------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------------------------
variable "instance_type" {
  description = "EC2 instance type for the web server. Default: t3.micro."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be one of: t2.micro, t2.small, t2.medium, t3.micro, t3.small."
  }
}


