locals {
  standard_tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "terraform"
  }

  tags = merge(local.standard_tags, var.extra_tags)
}
