# aws-infra

> An enhanced version of the [HashiCorp AWS Get-Started Terraform Tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create) with a professional GitHub Actions CI pipeline.

[![Terraform CI](https://github.com/thulasiramk-2310/aws-infra/actions/workflows/terraform.yml/badge.svg)](https://github.com/thulasiramk-2310/aws-infra/actions/workflows/terraform.yml)

---

## Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
  - [Install Terraform](#install-terraform)
  - [Install AWS CLI](#install-aws-cli)
- [Configuration](#configuration)
- [Usage](#usage)
  - [terraform init](#terraform-init)
  - [terraform plan](#terraform-plan)
  - [terraform apply](#terraform-apply)
  - [terraform destroy](#terraform-destroy)
- [Expected Outputs](#expected-outputs)
- [Folder Structure](#folder-structure)
- [GitHub Actions CI](#github-actions-ci)
  - [Configuring AWS Credentials as GitHub Secrets](#configuring-aws-credentials-as-github-secrets)
- [Contributing](#contributing)

---

## Project Overview

This repository provisions a simple but production-ready AWS web-server stack entirely through code, using **Terraform** as the infrastructure-as-code tool. It closely follows the official HashiCorp tutorial while adding:

- **Modular networking** via the official [`terraform-aws-modules/vpc`](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) module
- **Input validation** on all variables
- **Automatic AMI resolution** (always uses the latest Amazon Linux 2023 image)
- **Default resource tagging** for cost allocation
- **GitHub Actions CI** that runs `fmt → init → validate → plan` on every push and pull request

> **`terraform apply` is intentionally NOT automated.** Infrastructure changes must always be reviewed and applied by an authorized engineer.

---

## Architecture

```
Developer
    │
    ▼
GitHub Repository (aws-infra)
    │
    ▼
GitHub Actions CI ──────────────────────────────────────────────┐
    │  terraform fmt -check                                      │
    │  terraform init                                            │
    │  terraform validate                                        │
    │  terraform plan  ──► PR comment with plan diff             │
    │                                                            │
    │  ⚠️  terraform apply  ← manual step only                   │
    ▼                                                            │
AWS Account                                                      │
    │                                                            │
    ├── VPC (10.0.0.0/16)                                        │
    │     └── Public Subnet (10.0.1.0/24)                        │
    │           └── Internet Gateway + Route Table               │
    │                                                            │
    ├── Security Group                                           │
    │     ├── Inbound  TCP 80  (HTTP)  — 0.0.0.0/0              │
    │     ├── Inbound  TCP 22  (SSH)   — 0.0.0.0/0              │
    │     └── Outbound ALL             — 0.0.0.0/0              │
    │                                                            │
    └── EC2 Instance (Amazon Linux 2023 / t2.micro)             │
          └── Apache HTTP Server (bootstrapped via user_data)   │
```

---

## Prerequisites

| Tool       | Minimum Version | Purpose                              |
|------------|-----------------|--------------------------------------|
| Terraform  | 1.9.0           | Provision AWS resources              |
| AWS CLI    | 2.x             | Configure credentials locally        |
| Git        | any             | Clone the repository                 |

### Install Terraform

**macOS (Homebrew)**
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform -version
```

**Windows (Chocolatey)**
```powershell
choco install terraform
terraform -version
```

**Linux (apt)**
```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
terraform -version
```

For all platforms see the [official installation guide](https://developer.hashicorp.com/terraform/install).

### Install AWS CLI

**macOS / Linux**
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install
aws --version
```

**Windows**
Download and run the [AWS CLI v2 MSI installer](https://awscli.amazonaws.com/AWSCLIV2.msi).

---

## Configuration

1. **Clone the repository**
   ```bash
   git clone https://github.com/thulasiramk-2310/aws-infra.git
   cd aws-infra
   ```

2. **Configure AWS credentials locally**

   The recommended approach is a named profile:
   ```bash
   aws configure --profile terraform-dev
   # AWS Access Key ID:     <YOUR_ACCESS_KEY_ID>
   # AWS Secret Access Key: <YOUR_SECRET_ACCESS_KEY>
   # Default region name:   us-east-1
   # Default output format: json

   export AWS_PROFILE=terraform-dev
   ```

   Alternatively, export environment variables directly:
   ```bash
   export AWS_ACCESS_KEY_ID="<YOUR_ACCESS_KEY_ID>"
   export AWS_SECRET_ACCESS_KEY="<YOUR_SECRET_ACCESS_KEY>"
   export AWS_REGION="us-east-1"
   ```

   > ⚠️ **Never hardcode credentials** in `.tf` files or commit them to version control.

3. **Create your variable values file**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your preferred values
   ```

   `terraform.tfvars` is listed in `.gitignore` and will not be committed.

---

## Usage

### `terraform init`

Downloads the AWS provider plugin and the VPC module from the Terraform Registry.

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing modules...
Downloading terraform-aws-modules/vpc/aws 5.x.x...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
Terraform has been successfully initialized!
```

---

### `terraform plan`

Generates an execution plan showing exactly what Terraform will create, change, or destroy. **No AWS resources are created at this step.**

```bash
terraform plan
```

Review the plan carefully before applying. Look for:
- Resources to be **created** (`+`)
- Resources to be **changed** (`~`)
- Resources to be **destroyed** (`-`)

---

### `terraform apply`

Creates the infrastructure in AWS. Terraform will show the plan one final time and ask for confirmation.

```bash
terraform apply
```

Type `yes` when prompted. The apply typically completes in 2–3 minutes.

To apply without the interactive confirmation prompt (e.g., in a script):
```bash
terraform apply -auto-approve
```

---

### `terraform destroy`

Removes **all** resources managed by this configuration. Use this to avoid ongoing AWS charges when the infrastructure is no longer needed.

```bash
terraform destroy
```

> ⚠️ This is irreversible. Confirm you are targeting the correct AWS account and region before proceeding.

---

## Expected Outputs

After a successful `terraform apply` you will see:

```
Apply complete! Resources: 20 added, 0 changed, 0 destroyed.

Outputs:

ami_id_used        = "ami-0abcdef1234567890"
instance_id        = "i-0abcdef1234567890"
instance_public_ip = "54.123.45.67"
public_subnet_id   = "subnet-0abcdef1234567890"
security_group_id  = "sg-0abcdef1234567890"
vpc_id             = "vpc-0abcdef1234567890"
web_url            = "http://54.123.45.67"
```

Open `web_url` in your browser (~2 minutes after apply, while Apache starts) to see:

```
Hello from Terraform — hashicorp-tutorial
```

To retrieve outputs at any time:
```bash
terraform output
terraform output instance_public_ip
```

---

## Folder Structure

```
aws-infra/
│
├── main.tf                    # VPC module, Security Group, EC2 instance
├── provider.tf                # AWS provider configuration
├── variables.tf               # All input variable declarations
├── outputs.tf                 # All output value declarations
├── versions.tf                # Terraform & provider version constraints
├── terraform.tfvars.example   # Example variable values (safe to commit)
│
├── scripts/
│   ├── user_data.sh           # Apache bootstrap template (rendered by Terraform)
│   └── compress_html.py       # Gzip helper — compresses the landing page at plan time
│
├── website/
│   └── index.html             # Professional landing page served by Apache on EC2
│
├── .gitignore                 # Excludes state files, secrets, and artifacts
├── README.md                  # This file
│
└── .github/
    └── workflows/
        └── terraform.yml      # GitHub Actions CI pipeline
```

### How the landing page is delivered

The 26 KB HTML file cannot be embedded directly in `user_data` because AWS enforces a **16 KB raw limit**.

| Step | What happens |
|------|-------------|
| `terraform plan` | `scripts/compress_html.py` gzip-compresses `website/index.html` (26 KB → ~5 KB) and returns it as a base64 string via the `external` data source |
| `templatefile()` | The base64 string is injected into `scripts/user_data.sh` as `${html_gz_b64}` |
| EC2 boot | The instance runs the script, decodes + decompresses the HTML, and writes it to `/var/www/html/index.html` |
| **Result** | Total `user_data` ≈ **7 KB** — well under the 16 KB limit |

---

## GitHub Actions CI

The pipeline at [`.github/workflows/terraform.yml`](.github/workflows/terraform.yml) runs automatically on every `push` and `pull_request`:

**Phase 1 — Active (no AWS account required)**

| Step             | Command                | Description                                     |
|------------------|------------------------|-------------------------------------------------|
| **Format Check** | `terraform fmt -check` | Fails if any file is not properly formatted     |
| **Init**         | `terraform init`       | Downloads providers and modules from the Registry |
| **Validate**     | `terraform validate`   | Checks syntax and internal consistency          |

**Phase 2 — After AWS account activation** *(currently commented out)*

| Step       | Command            | Description                                              |
|------------|--------------------|----------------------------------------------------------|
| **Plan**   | `terraform plan`   | Previews changes; output posted as a PR comment          |

> `terraform apply` is **never** run automatically. Manual approval and execution by an authorized engineer is always required.

### Configuring AWS Credentials as GitHub Secrets

AWS credentials are read from [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets). **Do not hardcode them in the workflow file.**

1. Go to your repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret** and add:

   | Secret Name              | Value                                      |
   |--------------------------|--------------------------------------------|
   | `AWS_ACCESS_KEY_ID`      | Your IAM user's access key ID             |
   | `AWS_SECRET_ACCESS_KEY`  | Your IAM user's secret access key         |
   | `AWS_REGION`             | e.g. `us-east-1`                          |

3. The workflow references these as `${{ secrets.AWS_ACCESS_KEY_ID }}` etc.

> **Security tip:** Use an IAM user or role with the minimum permissions required (e.g., `AmazonEC2FullAccess`, `AmazonVPCFullAccess`). For production workloads, consider [GitHub OIDC federation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services) to avoid long-lived static credentials entirely.

---

## Contributing

1. Fork the repository and create a feature branch
2. Make your changes and run `terraform fmt` before committing
3. Open a pull request — the CI pipeline will automatically post a plan diff as a comment
4. Once reviewed and approved, apply the changes manually

---

*Built following the [HashiCorp AWS Get-Started Tutorial](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create).*
