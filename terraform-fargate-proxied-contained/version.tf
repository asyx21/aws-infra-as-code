# Required providers configuration
terraform {
  required_version = ">= 1.1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16.0"
    }
  }
}

# AWS provider configuration
provider "aws" {
  region  = var.region
  # # Uncomment to use access keys directly from 'dev.secrets.tfvars'
  # access_key = var.aws_access_key
  # secret_key = var.aws_secret_key
}
