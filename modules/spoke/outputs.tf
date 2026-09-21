output "vpc_id" {
  value       = aws_vpc.this.id
  description = "The ID of the Spoke VPC."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "The CIDR block of the Spoke VPC."
}

output "tgw_attachment_id" {
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
  description = "The ID of the TGW VPC Attachment for the Spoke."
}

output "application_subnet_ids" {
  value       = [for s in aws_subnet.application : s.id]
  description = "List of private application subnet IDs."
}

output "data_subnet_ids" {
  value       = [for s in aws_subnet.data : s.id]
  description = "List of isolated data subnet IDs."
}

output "attachment_subnet_ids" {
  value       = [for s in aws_subnet.attachment : s.id]
  description = "List of TGW attachment subnet IDs."
}

output "application_route_table_id" {
  value       = aws_route_table.application.id
  description = "The route table ID for the application tier (default route 0.0.0.0/0 -> TGW)."
}

output "data_route_table_id" {
  value       = aws_route_table.data.id
  description = "The route table ID for the isolated data tier (no route out)."
}
