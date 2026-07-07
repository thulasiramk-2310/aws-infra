#!/usr/bin/env python3
"""
compress_html.py — Terraform external data source helper.

Reads the HTML file passed as the first CLI argument, compresses it with
gzip (level 9), and returns a JSON object containing the base64-encoded
compressed bytes.  The Terraform external data source calls this script
and reads the JSON output.

Usage (called automatically by Terraform):
    python3 scripts/compress_html.py website/index.html

Output format expected by the Terraform external data source:
    { "html_gz_b64": "<base64-encoded gzip bytes>" }
"""

import sys
import json
import gzip
import base64

if len(sys.argv) < 2:
    print(json.dumps({"error": "usage: compress_html.py <path-to-html>"}))
    sys.exit(1)

html_path = sys.argv[1]

with open(html_path, "rb") as fh:
    raw = fh.read()

compressed = gzip.compress(raw, compresslevel=9)
encoded    = base64.b64encode(compressed).decode("ascii")

print(json.dumps({"html_gz_b64": encoded}))
