output "ipam_id" {
  value       = aws_vpc_ipam.this.id
  description = "The IPAM instance ID."
}

output "ipam_spoke_pool_id" {
  value       = aws_vpc_ipam_pool.spokes.id
  description = "The IPAM spoke pool ID for spoke VPC allocations."
}

# Inspection VPC Outputs
output "inspection_vpc_id" {
  value       = aws_vpc.inspection.id
  description = "Inspection VPC ID."
}

output "inspection_vpc_cidr" {
  value       = aws_vpc.inspection.cidr_block
  description = "Inspection VPC CIDR."
}

output "inspection_attachment_subnet_ids" {
  value       = { for az, s in aws_subnet.inspection_attachment : az => s.id }
  description = "Map of AZ to Inspection Attachment Subnet ID."
}

output "inspection_firewall_subnet_ids" {
  value       = { for az, s in aws_subnet.inspection_firewall : az => s.id }
  description = "Map of AZ to Inspection Firewall Subnet ID."
}

output "inspection_public_subnet_ids" {
  value       = { for az, s in aws_subnet.inspection_public : az => s.id }
  description = "Map of AZ to Inspection Public Subnet ID."
}

output "nat_gateway_ids" {
  value       = { for az, nat in aws_nat_gateway.this : az => nat.id }
  description = "Map of AZ to NAT Gateway ID."
}

output "inspection_igw_id" {
  value       = aws_internet_gateway.inspection.id
  description = "Inspection Internet Gateway ID."
}

# Ingress VPC Outputs
output "ingress_vpc_id" {
  value       = aws_vpc.ingress.id
  description = "Ingress VPC ID."
}

output "ingress_vpc_cidr" {
  value       = aws_vpc.ingress.cidr_block
  description = "Ingress VPC CIDR."
}

output "ingress_public_subnet_ids" {
  value       = { for az, s in aws_subnet.ingress_public : az => s.id }
  description = "Map of AZ to Ingress Public NLB Subnet ID."
}

output "ingress_firewall_subnet_ids" {
  value       = { for az, s in aws_subnet.ingress_firewall : az => s.id }
  description = "Map of AZ to Ingress Firewall Subnet ID."
}

output "ingress_attachment_subnet_ids" {
  value       = { for az, s in aws_subnet.ingress_attachment : az => s.id }
  description = "Map of AZ to Ingress Attachment Subnet ID."
}

output "ingress_igw_id" {
  value       = aws_internet_gateway.ingress.id
  description = "Ingress Internet Gateway ID."
}

output "ingress_nlb_arn" {
  value       = aws_lb.ingress.arn
  description = "Ingress Public NLB ARN."
}

output "ingress_nlb_dns_name" {
  value       = aws_lb.ingress.dns_name
  description = "Ingress Public NLB DNS Name."
}
