# Spoke Accounts Root Module

Root module for deploying spoke workload VPCs. Runs identically across 5 spoke accounts (spoke-01 to spoke-05).

## Design

- Takes **one meaningful variable**: `vpc_cidr` (`10.<n>.0.0/16`, allocated from AWS IPAM).
- All subnets (attachment `/28`, application `/24`, data `/24`) are derived automatically with `cidrsubnet`.
- To onboard a new spoke (e.g. spoke 06), simply create `spoke-06.tfvars`.

## Deployment

```bash
cd live/spokes
terraform init -backend-config=backend-spoke-01.hcl
terraform plan -var-file=spoke-01.tfvars
terraform apply -var-file=spoke-01.tfvars
```
