variable "region" {
}

variable "environment" {
  description = "The Deployment environment"
}

variable "cw_high" {
  description = "High CPU Threshold"
}

variable "cw_low" {
  description = "Low CPU Threshold"
}

variable "key_name" {
  description = "The SSH Key Pair to be used"
}

variable "bucket_name" {
  description = "s3 bucket"
}
