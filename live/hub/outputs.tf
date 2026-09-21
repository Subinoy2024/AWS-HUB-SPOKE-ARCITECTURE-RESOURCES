output "transit_gateway_id" {
  value       = module.tgw.transit_gateway_id
  description = "Transit Gateway ID for spoke attachments."
}

output "spoke_route_table_id" {
  value       = module.tgw.spoke_route_table_id
  description = "TGW Route Table ID to which spoke attachments must associate."
}

output "inspection_route_table_id" {
  value       = module.tgw.inspection_route_table_id
  description = "TGW Route Table ID into which spoke attachments must propagate."
}

output "ingress_route_table_id" {
  value       = module.tgw.ingress_route_table_id
  description = "TGW Route Table ID for inbound traffic."
}

output "inspection_vpc_id" {
  value       = module.inspection_vpc.vpc_id
  description = "Inspection VPC ID."
}

output "ingress_vpc_id" {
  value       = module.ingress_vpc.vpc_id
  description = "Ingress VPC ID."
}

output "ingress_nlb_dns_name" {
  value       = module.ingress_vpc.nlb_dns_name
  description = "DNS name of the Ingress Public NLB."
}

output "ipam_spoke_pool_id" {
  value       = module.ipam.spoke_pool_id
  description = "IPAM pool ID that each spoke passes as ipam_pool_id."
}
