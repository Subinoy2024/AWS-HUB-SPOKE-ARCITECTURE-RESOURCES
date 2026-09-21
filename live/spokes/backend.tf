terraform {
  backend "s3" {
    # Values populated via -backend-config=backend.hcl or CI/CD per spoke account boundary
    # bucket         = "org-tfstate-<spoke-account-id>-<region>"
    # key            = "network/spoke/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "org-tflocks"
    # encrypt        = true
  }
}
