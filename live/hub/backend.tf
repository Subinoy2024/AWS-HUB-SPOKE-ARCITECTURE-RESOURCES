terraform {
  backend "s3" {
    # Values populated via -backend-config=backend.hcl or CI/CD pipeline
    # bucket         = "org-tfstate-<hub-account-id>-<region>"
    # key            = "network/hub/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "org-tflocks"
    # encrypt        = true
  }
}
