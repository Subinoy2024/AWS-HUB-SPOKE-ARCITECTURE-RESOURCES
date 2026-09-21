output "ingress_policy_arn" {
  value       = aws_networkfirewall_firewall_policy.ingress.arn
  description = "The ARN of the Ingress Network Firewall Policy."
}

output "inspection_policy_arn" {
  value       = aws_networkfirewall_firewall_policy.inspection.arn
  description = "The ARN of the Inspection/Egress Network Firewall Policy."
}

output "shared_threat_ips_arn" {
  value       = aws_networkfirewall_rule_group.shared_threat_ips.arn
  description = "The ARN of the shared Suricata IPS rule group."
}

output "egress_domain_filter_arn" {
  value       = aws_networkfirewall_rule_group.egress_domain_filter.arn
  description = "The ARN of the egress domain filter rule group."
}

output "ingress_strict_filter_arn" {
  value       = aws_networkfirewall_rule_group.ingress_strict_filter.arn
  description = "The ARN of the ingress strict protocol/port filter rule group."
}
