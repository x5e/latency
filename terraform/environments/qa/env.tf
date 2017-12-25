terraform {
  backend "s3" {
    bucket = "082367326120-terraform"
    key    = "latency/qa"
    region = "us-east-1"
  }
}

variable "env_region" {
  default = "us-east-1"
}

provider "aws" {
  region = "${var.env_region}"
  allowed_account_ids = ["082367326120"]
}

module "latency" {
  source = "../../latency"
  env_name = "qa"

}
