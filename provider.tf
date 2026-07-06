# provider.tf
# Configures the AWS provider. Credentials are NOT hardcoded here.
# The provider reads credentials from (in order of precedence):
#   1. Environment variables  : AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY
#   2. Shared credentials file: ~/.aws/credentials
#   3. IAM role attached to the execution environment (EC2, ECS, GitHub OIDC, etc.)
#
# The region is kept configurable via the `aws_region` variable so the same
# configuration can target any AWS region without code changes.

provider "aws" {
  region = var.aws_region

  # Optional: tag every resource created by Terraform with a common set of
  # metadata tags. This makes cost allocation and resource discovery easier.
  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "Terraform"
      Environment = "dev"
    }
  }
}
