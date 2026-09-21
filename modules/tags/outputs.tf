output "tags" {
  value       = local.tags
  description = "Standardized map of merged tags to be applied to all resources."
}

output "standard_tags" {
  value       = local.standard_tags
  description = "Map of baseline mandatory tags (Environment, Owner, CostCenter, ManagedBy)."
}
