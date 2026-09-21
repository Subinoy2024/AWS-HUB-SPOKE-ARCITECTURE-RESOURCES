output "vpc_id" {
  value       = aws_vpc.this.id
  description = "The ID of the Ingress VPC."
}

output "vpc_cidr" {
  value       = aws_vpc.this.cidr_block
  description = "The CIDR block of the Ingress VPC."
}

output "nlb_arn" {
  value       = aws_lb.ingress.arn
  description = "The ARN of the public Ingress Network Load Balancer."
}

output "nlb_dns_name" {
  value       = aws_lb.ingress.dns_name
  description = "The DNS name of the public Ingress Network Load Balancer."
}

output "tgw_attachment_id" {
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
  description = "The ID of the TGW VPC attachment for the Ingress VPC."
}

output "firewall_arn" {
  value       = aws_networkfirewall_firewall.this.arn
  description = "The ARN of the Ingress Network Firewall."
}

output "firewall_endpoints_by_az" {
  value       = local.firewall_endpoints
  description = "Map of Availability Zone to Network Firewall Endpoint ID."
}

output "target_group_arn" {
  value       = aws_lb_target_group.ingress.arn
  description = "ARN of the ingress target group. Register spoke application IPs here."
}

output "listener_arn" {
  value       = aws_lb_listener.ingress.arn
  description = "ARN of the public NLB listener."
}
