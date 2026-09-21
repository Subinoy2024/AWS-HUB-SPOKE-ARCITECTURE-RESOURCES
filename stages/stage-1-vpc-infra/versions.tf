terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }

  backend "s3" {
    bucket         = "org-tfstate-173778668295-us-east-1"
    key            = "network/stage-1-vpc-infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "org-terraform-locks"
    encrypt        = true
  }
}
