# Firewall Policy Module

Defines shared Suricata rule groups and two distinct firewall policies:
1. **Ingress Policy**: Threat prevention, strict protocol/port controls.
2. **Inspection (Egress / East-West) Policy**: Threat prevention, SNI/HTTP domain allow/deny lists, and exfiltration prevention.

Both policies share the `shared_threat_ips` stateful rule group, ensuring consistent threat definitions across boundaries while maintaining policy separation.

## Usage Example

```hcl
module "firewall_policy" {
  source = "../../modules/firewall-policy"

  name_prefix = "hub-network-fw"
  allowed_domains = [
    ".amazonaws.com",
    ".github.com"
  ]
  blocked_domains = [
    ".badsite.example"
  ]
  log_destination_bucket_arn = "arn:aws:s3:::org-log-archive-firewall-logs"

  tags = module.tags.tags
}
```
