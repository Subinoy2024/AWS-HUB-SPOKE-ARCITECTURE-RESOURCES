output "transit_gateway_id" {
  value       = aws_ec2_transit_gateway.this.id
  description = "The ID of the Transit Gateway."
}

output "transit_gateway_arn" {
  value       = aws_ec2_transit_gateway.this.arn
  description = "The ARN of the Transit Gateway."
}

output "spoke_route_table_id" {
  value       = aws_ec2_transit_gateway_route_table.spoke.id
  description = "The ID of the Spoke TGW route table (default route only, zero propagations)."
}

output "inspection_route_table_id" {
  value       = aws_ec2_transit_gateway_route_table.inspection.id
  description = "The ID of the Inspection TGW route table (receives spoke CIDR propagations)."
}

output "ingress_route_table_id" {
  value       = aws_ec2_transit_gateway_route_table.ingress.id
  description = "The ID of the Ingress TGW route table."
}

output "hybrid_route_table_id" {
  value       = aws_ec2_transit_gateway_route_table.hybrid.id
  description = "The ID of the Hybrid TGW route table."
}

output "ram_resource_share_arn" {
  value       = try(aws_ram_resource_share.tgw[0].arn, null)
  description = "The ARN of the RAM resource share for the Transit Gateway."
}
