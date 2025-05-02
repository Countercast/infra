terraform {
  required_version = ">= 1.5"
  backend "local" {}            # we’ll swap to S3 later
}

provider "aws" {
  region  = "us-east-1"
  profile = var.aws_profile
}

module "network" {
  source = "../../modules/network"
}
