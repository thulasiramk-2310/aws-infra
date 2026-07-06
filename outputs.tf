# outputs.tf
# Declares values that Terraform prints after every `apply` and that can
# be consumed by other configurations via `terraform_remote_state`.
# These mirror the outputs shown in the HashiCorp AWS tutorial.

# ---------------------------------------------------------------------------
# EC2 Instance
# ---------------------------------------------------------------------------
output "instance_id" {
  description = "The EC2 instance ID of the web server."
  value       = aws_instance.web.id
}

output "instance_public_ip" {
  description = "Public IPv4 address assigned to the EC2 instance. Use this to access the web server."
  value       = aws_instance.web.public_ip
}

# Convenience URL — open this in a browser after `terraform apply`
output "web_url" {
  description = "HTTP URL of the web server (accessible after the instance bootstraps, ~2 min)."
  value       = "http://${aws_instance.web.public_ip}"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
output "vpc_id" {
  description = "ID of the VPC created by the aws-vpc module."
  value       = module.vpc.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet in which the EC2 instance runs."
  value       = module.vpc.public_subnets[0]
}

# ---------------------------------------------------------------------------
# Security
# ---------------------------------------------------------------------------
output "security_group_id" {
  description = "ID of the security group attached to the EC2 instance."
  value       = aws_security_group.web_sg.id
}

# ---------------------------------------------------------------------------
# AMI (informational)
# ---------------------------------------------------------------------------
output "ami_id_used" {
  description = "AMI ID resolved by Terraform at plan time (Amazon Linux 2023)."
  value       = data.aws_ami.amazon_linux.id
}
