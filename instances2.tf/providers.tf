
# Backend setup
terraform {
  backend "s3" {
    key = "imgmgr-app2.tfstate"
  }
}

# Variable definitions

# Provider and access setup
provider "aws" {
  version = "~> 2.0"
  region  = var.region
}
