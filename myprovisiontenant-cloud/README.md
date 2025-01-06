# Project: DNS Record Management with Terraform and PowerShell

## Overview
This project automates the creation of a DNS record in an existing Azure DNS zone using Terraform, triggered by a PowerShell script.

### Directory Structure
```plaintext
project-dns-record/
├── powershell/
│   └── create-dns-record.ps1
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── variables.tfvars
│   └── .terraform/
│       └── (Terraform initialization files)
