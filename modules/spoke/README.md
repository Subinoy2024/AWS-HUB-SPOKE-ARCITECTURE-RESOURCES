# Spoke VPC Module

Reusable module deployed across 30 spoke workload accounts in the AWS Organizations landing zone.

## Architecture & Correctness Rules

1. **Single Meaningful Input**:
   - Accepts only `vpc_cidr` (`10.<n>.0.0/16`, allocated from IPAM).
   - All subnets are derived deterministically with `cidrsubnet`:
     - Attachment: `/28`
     - Application: `/24`
     - Data: `/24`
2. **Zero Internet Gateway**:
   - No IGW is created. All non-local egress is forced to the Transit Gateway (`0.0.0.0/0 -> TGW`).
3. **Strict Data Tier Isolation**:
   - Data subnets (RDS, ElastiCache) have **no route out**, preventing lateral movement.
4. **Appliance Mode Disabled**:
   - `appliance_mode_support = "disable"` on spoke TGW attachments (only enabled on inspection VPC).
5. **Direct VPC Endpoints Integration**:
   - Deploys private endpoints for S3 (free Gateway endpoint) and key AWS services (Interface endpoints restricted by `aws:PrincipalOrgID`).

## Usage Example

```hcl
module "spoke" {
  source = "../../modules/spoke"

  vpc_cidr           = "10.1.0.0/16"
  transit_gateway_id = "tgw-0123456789abcdef0"
  organization_id    = "o-exampleorgid"
  az_names           = ["us-east-1a", "us-east-1b"]

  tags = module.tags.tags
}
```
