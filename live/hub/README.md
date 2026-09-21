# Hub Account Root Module

Root Terraform configuration for deploying the core network hub infrastructure in the dedicated network hub account.

## Resources Provisioned
- AWS Transit Gateway with 4 segregated route tables.
- RAM resource share distributing the TGW to the AWS Organization.
- Inspection VPC (`10.100.0.0/16`) with appliance mode enabled and Network Firewall 2.
- Ingress VPC (`10.101.0.0/16`) with IGW edge routing, Network Firewall 1, and public NLB.
- Default route `0.0.0.0/0` on the spoke TGW route table pointing to the inspection attachment.

## Deployment Instructions

```bash
cd live/hub
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```
