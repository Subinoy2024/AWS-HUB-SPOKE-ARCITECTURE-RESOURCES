# VPC Endpoints Module

Deploys private VPC endpoints for spoke VPCs:
1. **Amazon S3 Gateway Endpoint**: Completely free, route table managed, avoiding costly NAT/firewall bandwidth.
2. **Interface Endpoints**: Secure private connectivity to ECR, SSM, and Secrets Manager.
3. **AWS Organization Lock-Down**: All endpoints enforce an `aws:PrincipalOrgID` condition policy to ensure only organization principals can access services through these endpoints.

## Usage Example

```hcl
module "vpc_endpoints" {
  source = "../../modules/vpc-endpoints"

  vpc_id          = module.spoke.vpc_id
  vpc_cidr        = "10.1.0.0/16"
  subnet_ids      = module.spoke.application_subnet_ids
  route_table_ids = [module.spoke.application_route_table_id]
  organization_id = "o-exampleorgid"

  tags = module.tags.tags
}
```
