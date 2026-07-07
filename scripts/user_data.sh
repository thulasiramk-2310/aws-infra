#!/bin/bash
# =============================================================================
# user_data.sh — EC2 bootstrap script for the aws-infra web server
#
# This script is rendered as a Terraform templatefile(). The variable
# ${html_gz_b64} is replaced at plan time with a gzip-compressed,
# base64-encoded copy of website/index.html (≈ 4 KB), keeping the total
# user_data payload well below AWS's 16 KB raw limit.
#
# Execution order on first boot (cloud-init):
#   1. Update packages
#   2. Install Apache HTTP Server
#   3. Enable + start Apache
#   4. Decode and decompress the landing page into the document root
#   5. Restart Apache to serve the new page
# =============================================================================

set -euo pipefail

# ── 1. System update ─────────────────────────────────────────────────────────
yum update -y

# ── 2. Install Apache ────────────────────────────────────────────────────────
yum install -y httpd

# ── 3. Enable and start Apache ───────────────────────────────────────────────
systemctl enable httpd
systemctl start  httpd

# ── 4. Deploy landing page ───────────────────────────────────────────────────
# The HTML is gzip-compressed and base64-encoded by Terraform at plan time.
# Decoding here avoids embedding 26 KB of raw HTML in user_data.
printf '%s' '${html_gz_b64}' | base64 -d | gunzip > /var/www/html/index.html

# ── 5. Restart Apache to serve the new content ───────────────────────────────
systemctl restart httpd
