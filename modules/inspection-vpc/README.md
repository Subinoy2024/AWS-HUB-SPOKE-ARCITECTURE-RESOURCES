# Inspection VPC Module

Deploys the Centralised Inspection VPC (`10.100.0.0/16`) for outbound internet egress, inter-spoke (east-west), and hybrid inspection.

## Architecture & Correctness Rules

1. **Firewall Before NAT**:
   - Traffic arriving from the TGW into the attachment subnets is routed directly to the Network Firewall endpoint in the same AZ. Real source IPs are preserved during inspection.
2. **Appliance Mode Enabled**:
   - `appliance_mode_support = "enable"` is set on the TGW attachment so both directions of each flow use the same AZ's firewall endpoint.
3. **Dual Post-Inspection Routing**:
   - The firewall subnet route table splits traffic cleanly:
     - `0.0.0.0/0 -> NAT Gateway` (for internet egress).
     - `10.0.0.0/8 -> Transit Gateway` (for return east-west inter-spoke and hybrid traffic).
4. **Dynamic Endpoint Lookup**:
   - Extracts `{ az => endpoint_id }` dynamically from `firewall_status`.

## Usage Example

```hcl
module "inspection_vpc" {
  source = "../../modules/inspection-vpc"

  vpc_cidr                   = "10.100.0.0/16"
  az_names                   = ["us-east-1a", "us-east-1b"]
  transit_gateway_id         = module.tgw.transit_gateway_id
  firewall_policy_arn        = module.firewall_policy.inspection_policy_arn
  log_destination_bucket_arn = "arn:aws:s3:::org-log-archive-firewall-logs"

  tags = module.tags.tags
}
```
