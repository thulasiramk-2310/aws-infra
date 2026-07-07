# main.tf
# Core infrastructure definition — closely follows the HashiCorp AWS
# Get-Started tutorial:
#   https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create
#
# Resources created:
#   • VPC          (via the official terraform-aws-modules/vpc module)
#   • Security Group (HTTP + SSH ingress, all egress)
#   • EC2 Instance (Amazon Linux 2023, t3.micro by default)

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
  user_data = <<-'USERDATA'
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd

    # Write the professional landing page to Apache's document root.
    # Single-quoted USERDATA delimiter prevents Terraform from interpolating
    # the HTML content (which contains $ signs in CSS variables).
    cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/><meta name="viewport" content="width=device-width,initial-scale=1.0"/><title>AWS Infrastructure Automation using Terraform</title><style>*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}:root{--aws:#FF9900;--aws-dark:#E68A00;--tf:#7B42BC;--tf-dark:#6535A0;--success:#1a8a3c;--success-bg:#e6f4ec;--text:#1a1a2e;--muted:#64748b;--border:#e2e8f0;--card-bg:#ffffff;--page-bg:#f8fafc;--radius:14px;--shadow:0 4px 24px rgba(0,0,0,.08);--shadow-hover:0 8px 32px rgba(0,0,0,.14)}html{scroll-behavior:smooth}body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;background:var(--page-bg);color:var(--text);line-height:1.6}.topbar{background:linear-gradient(90deg,var(--aws) 0%,var(--tf) 100%);height:5px}nav{background:#fff;border-bottom:1px solid var(--border);padding:0 2rem;display:flex;align-items:center;justify-content:space-between;height:60px;position:sticky;top:0;z-index:100;box-shadow:0 2px 8px rgba(0,0,0,.06)}.nav-brand{display:flex;align-items:center;gap:.6rem;font-weight:700;font-size:1rem;color:var(--text);text-decoration:none}.nav-badge{background:var(--success-bg);color:var(--success);font-size:.72rem;font-weight:700;padding:2px 10px;border-radius:20px;border:1px solid #a7d9b5;letter-spacing:.5px}.hero{background:linear-gradient(135deg,#0f172a 0%,#1e1b4b 50%,#1a0533 100%);color:#fff;padding:5rem 2rem 4.5rem;text-align:center;position:relative;overflow:hidden}.hero::before{content:'';position:absolute;inset:0;background:radial-gradient(ellipse 60% 50% at 20% 50%,rgba(255,153,0,.18) 0%,transparent 70%),radial-gradient(ellipse 60% 50% at 80% 50%,rgba(123,66,188,.22) 0%,transparent 70%);pointer-events:none}.hero-inner{position:relative;max-width:780px;margin:0 auto}.success-badge{display:inline-flex;align-items:center;gap:.45rem;background:rgba(26,138,60,.2);border:1px solid rgba(26,138,60,.45);color:#4ade80;font-size:.82rem;font-weight:700;padding:6px 18px;border-radius:30px;margin-bottom:1.6rem;letter-spacing:.6px;text-transform:uppercase}.success-badge span{font-size:1rem}.hero h1{font-size:clamp(1.8rem,5vw,3rem);font-weight:800;line-height:1.2;margin-bottom:1.1rem;letter-spacing:-.5px}.hero h1 em{font-style:normal;background:linear-gradient(90deg,var(--aws),#ffcc00);-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}.hero p{font-size:1.12rem;color:#cbd5e1;max-width:540px;margin:0 auto 2rem}.hero-pills{display:flex;justify-content:center;flex-wrap:wrap;gap:.6rem}.hero-pill{background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.18);color:#e2e8f0;font-size:.8rem;font-weight:600;padding:5px 14px;border-radius:20px}.container{max-width:1080px;margin:0 auto;padding:0 1.5rem}section{padding:3.5rem 0}.section-label{display:inline-flex;align-items:center;gap:.4rem;font-size:.75rem;font-weight:700;text-transform:uppercase;letter-spacing:1.2px;color:var(--tf);margin-bottom:.6rem}.section-title{font-size:clamp(1.35rem,3vw,1.75rem);font-weight:800;color:var(--text);margin-bottom:.5rem}.section-sub{color:var(--muted);font-size:.95rem;margin-bottom:2.2rem}.info-card{background:var(--card-bg);border:1px solid var(--border);border-radius:var(--radius);box-shadow:var(--shadow);overflow:hidden}.info-card-header{background:linear-gradient(90deg,var(--aws) 0%,#ffcc00 100%);padding:.9rem 1.6rem;display:flex;align-items:center;gap:.7rem}.info-card-header h3{font-size:1rem;font-weight:700;color:#1a1a1a}.info-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr))}.info-row{display:flex;align-items:flex-start;gap:.9rem;padding:1.1rem 1.6rem;border-bottom:1px solid var(--border);border-right:1px solid var(--border);transition:background .2s}.info-row:hover{background:#fafbff}.info-icon{font-size:1.4rem;flex-shrink:0;margin-top:.05rem}.info-label{font-size:.75rem;font-weight:700;color:var(--muted);text-transform:uppercase;letter-spacing:.6px;margin-bottom:.18rem}.info-value{font-size:.95rem;font-weight:600;color:var(--text)}.info-value code{background:#f1f5f9;border:1px solid var(--border);border-radius:5px;padding:1px 7px;font-size:.88rem;font-family:'SF Mono','Fira Code','Cascadia Code',monospace;color:var(--tf)}.components-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(140px,1fr));gap:1rem}.component-card{background:var(--card-bg);border:1px solid var(--border);border-radius:var(--radius);box-shadow:var(--shadow);padding:1.4rem 1rem;text-align:center;transition:transform .22s,box-shadow .22s,border-color .22s;cursor:default}.component-card:hover{transform:translateY(-5px);box-shadow:var(--shadow-hover);border-color:var(--aws)}.component-icon{font-size:2rem;margin-bottom:.55rem}.component-check{display:inline-block;width:20px;height:20px;background:var(--success);color:#fff;border-radius:50%;font-size:.6rem;line-height:20px;margin-bottom:.55rem}.component-name{font-size:.82rem;font-weight:700;color:var(--text)}.component-sub{font-size:.72rem;color:var(--muted);margin-top:.2rem}.workflow-wrap{background:var(--card-bg);border:1px solid var(--border);border-radius:var(--radius);box-shadow:var(--shadow);padding:2.2rem 2rem}.workflow-steps{display:flex;align-items:center;justify-content:center;flex-wrap:wrap;gap:.5rem}.wf-step{display:flex;flex-direction:column;align-items:center;gap:.35rem;min-width:110px}.wf-icon-wrap{width:64px;height:64px;border-radius:16px;display:flex;align-items:center;justify-content:center;font-size:1.7rem}.wf-icon-wrap.tf-color{background:linear-gradient(135deg,#ede9fe,#ddd6fe)}.wf-icon-wrap.aws-color{background:linear-gradient(135deg,#fff7e6,#ffe0a0)}.wf-icon-wrap.ok-color{background:linear-gradient(135deg,#e6f4ec,#bbf7d0)}.wf-label{font-size:.75rem;font-weight:700;color:var(--text);text-align:center}.wf-sub{font-size:.65rem;color:var(--muted);text-align:center}.wf-arrow{font-size:1.3rem;color:var(--muted);flex-shrink:0;margin-top:-16px}.tech-grid{display:flex;flex-wrap:wrap;gap:1rem}.tech-card{background:var(--card-bg);border:1px solid var(--border);border-radius:12px;box-shadow:var(--shadow);padding:.9rem 1.4rem;display:flex;align-items:center;gap:.75rem;transition:transform .2s,box-shadow .2s,border-color .2s;flex:1 1 140px}.tech-card:hover{transform:translateY(-3px);box-shadow:var(--shadow-hover);border-color:var(--tf)}.tech-emoji{font-size:1.5rem}.tech-name{font-size:.88rem;font-weight:700;color:var(--text)}.tech-desc{font-size:.72rem;color:var(--muted)}.stats-banner{background:linear-gradient(90deg,var(--aws) 0%,#ffcc00 50%,var(--aws-dark) 100%);border-radius:var(--radius);padding:2rem;display:flex;justify-content:space-around;flex-wrap:wrap;gap:1.5rem;margin:0 0 3.5rem}.stat-item{text-align:center}.stat-num{font-size:2.2rem;font-weight:900;color:#1a1a1a;line-height:1}.stat-lbl{font-size:.75rem;font-weight:700;color:rgba(0,0,0,.65);text-transform:uppercase;letter-spacing:.8px;margin-top:.25rem}footer{background:#0f172a;color:#94a3b8;padding:3rem 2rem 2rem}.footer-inner{max-width:1080px;margin:0 auto}.footer-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:2rem;margin-bottom:2rem}.footer-col h4{font-size:.8rem;font-weight:700;text-transform:uppercase;letter-spacing:1px;color:#e2e8f0;margin-bottom:.8rem}.footer-col p,.footer-col a{font-size:.85rem;color:#94a3b8;text-decoration:none;display:block;margin-bottom:.3rem}.footer-col a:hover{color:var(--aws)}.footer-col .highlight{color:var(--aws);font-weight:600}.footer-divider{border:none;border-top:1px solid #1e293b;margin:1.5rem 0}.footer-bottom{display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:1rem;font-size:.8rem}.footer-logo{display:flex;gap:.4rem;align-items:center}.pill-aws{background:rgba(255,153,0,.15);color:var(--aws);border:1px solid rgba(255,153,0,.3);padding:2px 10px;border-radius:20px;font-size:.75rem;font-weight:700}.pill-tf{background:rgba(123,66,188,.15);color:#a78bfa;border:1px solid rgba(123,66,188,.3);padding:2px 10px;border-radius:20px;font-size:.75rem;font-weight:700}.bg-white{background:#fff}@media(max-width:640px){.wf-arrow{display:none}.workflow-steps{flex-direction:column;align-items:center}nav{padding:0 1rem}.hero{padding:3.5rem 1rem 3rem}}</style></head><body><div class="topbar"></div><nav><a href="#" class="nav-brand">&#9729;&#65039; &nbsp;<strong>aws-infra</strong></a><span class="nav-badge">&#10003; Deployment Successful</span></nav><section class="hero"><div class="hero-inner"><div class="success-badge"><span>&#10003;</span> Deployment Successful</div><h1>AWS Infrastructure<br><em>Deployment Successful</em></h1><p>Infrastructure provisioned automatically using Terraform on AWS.</p><div class="hero-pills"><span class="hero-pill">&#127757; Amazon Web Services</span><span class="hero-pill">&#9881;&#65039; Terraform IaC</span><span class="hero-pill">&#128421;&#65039; EC2 t3.micro</span><span class="hero-pill">&#128039; Amazon Linux 2023</span><span class="hero-pill">&#128274; VPC Isolated</span></div></div></section><div class="container" style="padding-top:2.8rem"><div class="stats-banner"><div class="stat-item"><div class="stat-num">7</div><div class="stat-lbl">AWS Resources</div></div><div class="stat-item"><div class="stat-num">1</div><div class="stat-lbl">VPC Created</div></div><div class="stat-item"><div class="stat-num">1</div><div class="stat-lbl">EC2 Instance</div></div><div class="stat-item"><div class="stat-num">100%</div><div class="stat-lbl">Infrastructure as Code</div></div><div class="stat-item"><div class="stat-num">0</div><div class="stat-lbl">Manual Steps</div></div></div></div><section class="bg-white"><div class="container"><div class="section-label">&#128203; &nbsp;Project Details</div><h2 class="section-title">Project Information</h2><p class="section-sub">AWS Infrastructure Automation using Terraform</p><div class="info-card"><div class="info-card-header"><span style="font-size:1.3rem">&#128230;</span><h3>aws-infra &mdash; Infrastructure Configuration</h3></div><div class="info-grid"><div class="info-row"><span class="info-icon">&#127991;&#65039;</span><div><div class="info-label">Project Name</div><div class="info-value"><code>aws-infra</code></div></div></div><div class="info-row"><span class="info-icon">&#9729;&#65039;</span><div><div class="info-label">Cloud Provider</div><div class="info-value">Amazon Web Services</div></div></div><div class="info-row"><span class="info-icon">&#9881;&#65039;</span><div><div class="info-label">Infrastructure as Code</div><div class="info-value">Terraform <code>~&gt; 1.9</code></div></div></div><div class="info-row"><span class="info-icon">&#127760;</span><div><div class="info-label">Web Server</div><div class="info-value">Apache HTTP Server</div></div></div><div class="info-row"><span class="info-icon">&#128421;&#65039;</span><div><div class="info-label">EC2 Instance</div><div class="info-value">Amazon Linux 2023 &nbsp;<code>t3.micro</code></div></div></div><div class="info-row"><span class="info-icon">&#128205;</span><div><div class="info-label">Region</div><div class="info-value"><code>us-east-1</code> &nbsp;(N. Virginia)</div></div></div></div></div></div></section><section><div class="container"><div class="section-label">&#127959;&#65039; &nbsp;Architecture</div><h2 class="section-title">Infrastructure Components</h2><p class="section-sub">All resources provisioned and managed by Terraform</p><div class="components-grid"><div class="component-card"><div class="component-icon">&#127760;</div><div class="component-check">&#10003;</div><div class="component-name">VPC</div><div class="component-sub">10.0.0.0/16</div></div><div class="component-card"><div class="component-icon">&#128256;</div><div class="component-check">&#10003;</div><div class="component-name">Public Subnet</div><div class="component-sub">10.0.1.0/24</div></div><div class="component-card"><div class="component-icon">&#128682;</div><div class="component-check">&#10003;</div><div class="component-name">Internet Gateway</div><div class="component-sub">Public access</div></div><div class="component-card"><div class="component-icon">&#128506;&#65039;</div><div class="component-check">&#10003;</div><div class="component-name">Route Table</div><div class="component-sub">0.0.0.0/0 &rarr; IGW</div></div><div class="component-card"><div class="component-icon">&#128274;</div><div class="component-check">&#10003;</div><div class="component-name">Security Group</div><div class="component-sub">HTTP + SSH</div></div><div class="component-card"><div class="component-icon">&#128421;&#65039;</div><div class="component-check">&#10003;</div><div class="component-name">EC2 Instance</div><div class="component-sub">t3.micro</div></div><div class="component-card"><div class="component-icon">&#127757;</div><div class="component-check">&#10003;</div><div class="component-name">Apache Server</div><div class="component-sub">HTTP on port 80</div></div></div></div></section><section class="bg-white"><div class="container"><div class="section-label">&#128260; &nbsp;CI / CD Pipeline</div><h2 class="section-title">Deployment Workflow</h2><p class="section-sub">From Terraform code to a live website &mdash; fully automated</p><div class="workflow-wrap"><div class="workflow-steps"><div class="wf-step"><div class="wf-icon-wrap tf-color">&#128221;</div><div class="wf-label">Terraform Code</div><div class="wf-sub">main.tf / variables.tf</div></div><div class="wf-arrow">&rarr;</div><div class="wf-step"><div class="wf-icon-wrap tf-color">&#9654;&#65039;</div><div class="wf-label">Terraform Apply</div><div class="wf-sub">terraform apply</div></div><div class="wf-arrow">&rarr;</div><div class="wf-step"><div class="wf-icon-wrap aws-color">&#9729;&#65039;</div><div class="wf-label">AWS Infrastructure</div><div class="wf-sub">VPC + Subnet + SG</div></div><div class="wf-arrow">&rarr;</div><div class="wf-step"><div class="wf-icon-wrap aws-color">&#128421;&#65039;</div><div class="wf-label">EC2 Instance</div><div class="wf-sub">Amazon Linux 2023</div></div><div class="wf-arrow">&rarr;</div><div class="wf-step"><div class="wf-icon-wrap ok-color">&#127760;</div><div class="wf-label">Apache Web Server</div><div class="wf-sub">user_data bootstrap</div></div><div class="wf-arrow">&rarr;</div><div class="wf-step"><div class="wf-icon-wrap ok-color">&#9989;</div><div class="wf-label">Website Live</div><div class="wf-sub">Public IP accessible</div></div></div></div></div></section><section><div class="container"><div class="section-label">&#128295; &nbsp;Stack</div><h2 class="section-title">Technologies Used</h2><p class="section-sub">Open-source tools and AWS services powering this project</p><div class="tech-grid"><div class="tech-card"><span class="tech-emoji">&#9881;&#65039;</span><div><div class="tech-name">Terraform</div><div class="tech-desc">Infrastructure as Code</div></div></div><div class="tech-card"><span class="tech-emoji">&#128421;&#65039;</span><div><div class="tech-name">AWS EC2</div><div class="tech-desc">Compute &mdash; t3.micro</div></div></div><div class="tech-card"><span class="tech-emoji">&#127760;</span><div><div class="tech-name">AWS VPC</div><div class="tech-desc">Isolated network</div></div></div><div class="tech-card"><span class="tech-emoji">&#128274;</span><div><div class="tech-name">AWS Security Groups</div><div class="tech-desc">Firewall rules</div></div></div><div class="tech-card"><span class="tech-emoji">&#127757;</span><div><div class="tech-name">Apache</div><div class="tech-desc">HTTP web server</div></div></div><div class="tech-card"><span class="tech-emoji">&#128025;</span><div><div class="tech-name">GitHub</div><div class="tech-desc">Source control</div></div></div><div class="tech-card"><span class="tech-emoji">&#129302;</span><div><div class="tech-name">GitHub Actions</div><div class="tech-desc">CI/CD Ready</div></div></div></div></div></section><footer><div class="footer-inner"><div class="footer-grid"><div class="footer-col"><h4>&#128100; Created By</h4><p class="highlight">Thulasiram K</p><p>DevOps Intern</p><p>Presidio Solutions Pvt. Ltd.</p></div><div class="footer-col"><h4>&#128197; Internship</h4><p class="highlight">Week 4</p><p>AWS Infrastructure Automation</p><p>Presidio Solutions Pvt. Ltd.</p></div><div class="footer-col"><h4>&#128193; Repository</h4><p class="highlight">aws-infra</p><p>github.com/thulasiramk-2310</p><p>/aws-infra</p></div><div class="footer-col"><h4>&#128295; Stack</h4><p>Terraform ~&gt; 1.9</p><p>AWS Provider ~&gt; 5.0</p><p>Amazon Linux 2023</p></div></div><hr class="footer-divider"/><div class="footer-bottom"><p>Infrastructure successfully provisioned using Terraform and hosted on Amazon Web Services.</p><div class="footer-logo"><span class="pill-aws">AWS</span><span class="pill-tf">Terraform</span></div></div></div></footer></body></html>
HTMLEOF
  USERDATA

  # Ensure the VPC and security group are fully created before launching
  depends_on = [module.vpc, aws_security_group.web_sg]

  tags = {
    Name = "${var.project_name}-web-instance"
  }
}
