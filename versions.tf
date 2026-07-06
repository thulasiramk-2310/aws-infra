# versions.tf
# Specifies the minimum required version of Terraform and the required
# provider plugins for this configuration. Pinning versions ensures
# reproducible, stable deployments across all environments.

terraform {
  # Require Terraform 1.9 or newer (latest stable line as of 2025)
  required_version = "~> 1.9"

  required_providers {
    # AWS provider — sourced from the official HashiCorp registry
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Allow any 5.x release; blocks unexpected major-version bumps
    }
  }
}
