data "terraform_remote_state" "remote_vars" {
  backend = "s3"
  config = {
    bucket = "cfngin-hunterimgmgr-us-east-1"
    region = "${var.region}"
    key    = "env:/common/imgmgr-vpc.tfstate"
  }
}
