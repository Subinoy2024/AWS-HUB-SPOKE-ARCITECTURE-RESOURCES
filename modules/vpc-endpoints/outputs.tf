output "s3_gateway_endpoint_id" {
  value       = aws_vpc_endpoint.s3.id
  description = "The ID of the S3 Gateway VPC Endpoint."
}

output "interface_endpoint_ids" {
  value       = { for k, ep in aws_vpc_endpoint.interfaces : k => ep.id }
  description = "Map of interface service name to VPC Endpoint ID."
}

output "endpoint_security_group_id" {
  value       = aws_security_group.endpoints.id
  description = "The ID of the security group attached to the interface endpoints."
}
