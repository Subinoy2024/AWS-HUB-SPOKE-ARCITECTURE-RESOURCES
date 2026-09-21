# Transit Gateway Module

Deploys an AWS Transit Gateway configured for strict centralised firewall inspection across 30 spoke accounts.

## Critical Routing Architecture

1. **Explicit Route Tables**: Default association and propagation are disabled.
2. **Spoke Route Table (`spoke_route_table_id`)**:
   - Contains **only** `0.0.0.0/0 -> Inspection VPC attachment`.
   - **DO NOT** propagate spoke VPC CIDRs here. Doing so enables inter-spoke direct routing and bypasses the firewall entirely.
3. **Inspection Route Table (`inspection_route_table_id`)**:
   - All spoke VPC attachments propagate their CIDRs into this table so inspected traffic returns cleanly to destination spokes.
4. **RAM Share**:
   - Shares the Transit Gateway across all accounts in the AWS Organization.

## Usage Example

```hcl
module "tgw" {
  source = "../../modules/tgw"

  name                  = "org-core-tgw"
  amazon_side_asn       = 64512
  ram_principal_org_arn = "arn:aws:organizations::123456789012:organization/o-exampleorgid"

  tags = module.tags.tags
}
```
