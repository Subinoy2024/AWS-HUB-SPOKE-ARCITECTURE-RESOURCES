output "vpc_id" {
  value       = aws_vpc.this.id
  description = "The ID of the Inspection VPC."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "The CIDR block of the Inspection VPC."
}

output "tgw_attachment_id" {
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
  description = "The ID of the TGW VPC Attachment for Inspection VPC."
}

output "firewall_arn" {
  value       = aws_networkfirewall_firewall.this.arn
  description = "The ARN of the Network Firewall."
}

output "firewall_endpoints_by_az" {
  value       = local.firewall_endpoints
  description = "Map of Availability Zone to Network Firewall Endpoint ID."
}

output "nat_gateway_ids" {
  value       = { for az, nat in aws_nat_gateway.this : az => nat.id }
  description = "Map of Availability Zone to NAT Gateway ID."
}

output "attachment_subnet_ids" {
  value       = [for s in aws_subnet.attachment : s.id]
  description = "List of TGW attachment subnet IDs."
}
