variable "environment" {
  description = "The Deployment environment"
}

variable "vpc_cidr" {
  description = "The CIDR block of the vpc"
}

variable "region" {
  description = "The region to launch the bastion host"
}

data "aws_availability_zones" "azs" {}

variable "public_subnets_count"  {
  description = "Total number of public subnets"
}

variable "private_subnets_count"  {
  description = "Total number of public subnets"
}
