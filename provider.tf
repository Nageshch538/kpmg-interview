terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.10.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region                  = var.aws_region
  shared_credentials_file = "~/.aws/credentials"
  profile                 = "default"
}