output "ipam_id" {
  value       = aws_vpc_ipam.this.id
  description = "The IPAM instance ID."
}

output "spoke_pool_id" {
  value       = aws_vpc_ipam_pool.spokes.id
  description = "IPAM pool ID that spoke VPCs allocate their /16 from."
}

output "spoke_pool_arn" {
  value       = aws_vpc_ipam_pool.spokes.arn
  description = "ARN of the spoke IPAM pool."
}

output "ram_resource_share_arn" {
  value       = try(aws_ram_resource_share.ipam[0].arn, null)
  description = "ARN of the RAM share exposing the spoke pool to the organization."
}
