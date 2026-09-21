output "vpc_id" {
  value       = module.spoke.vpc_id
  description = "The ID of the Spoke VPC."
}

output "vpc_cidr" {
  value       = module.spoke.vpc_cidr
  description = "The CIDR block of the Spoke VPC."
}

output "tgw_attachment_id" {
  value       = module.spoke.tgw_attachment_id
  description = "The ID of the Spoke TGW Attachment."
}

output "application_subnet_ids" {
  value       = module.spoke.application_subnet_ids
  description = "List of private application subnet IDs."
}

output "data_subnet_ids" {
  value       = module.spoke.data_subnet_ids
  description = "List of isolated data subnet IDs."
}
