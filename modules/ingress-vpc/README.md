# Ingress VPC Module

Deploys the Ingress VPC (`10.101.0.0/16`) for perimeter inspection of inbound traffic before reaching public-facing Network Load Balancers and backend spoke applications.

## Architecture & Correctness Rules

1. **IGW Edge Routing**:
   - The Internet Gateway is associated with an edge route table redirecting incoming traffic for public subnets to the firewall endpoint in the matching AZ.
2. **Cross-Zone Balancing Disabled**:
   - `enable_cross_zone_load_balancing = false` on the NLB prevents asymmetric firewall state dropping.
3. **Strict Per-AZ Firewalls**:
   - Ingress firewall endpoints are mapped per AZ so traffic never crosses AZ boundaries during inspection.

## Usage Example

```hcl
module "ingress_vpc" {
  source = "../../modules/ingress-vpc"

  vpc_cidr                   = "10.101.0.0/16"
  az_names                   = ["us-east-1a", "us-east-1b"]
  transit_gateway_id         = module.tgw.transit_gateway_id
  firewall_policy_arn        = module.firewall_policy.ingress_policy_arn
  log_destination_bucket_arn = "arn:aws:s3:::org-log-archive-firewall-logs"

  tags = module.tags.tags
}
```
