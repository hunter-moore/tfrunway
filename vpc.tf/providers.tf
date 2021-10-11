
# Backend setup
terraform {
  backend "s3" {
    key = "imgmgr-vpc.tfstate"
  }
}

# Variable definitions

# Provider and access setup
provider "aws" {
  #  version = "~> 2.0"
  version = "~> 3.0"
  region  = var.region
}
