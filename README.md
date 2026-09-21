# AWS Hub-and-Spoke Network with Centralised Network Firewall Inspection

Production-grade Terraform codebase for a centralised hub-and-spoke AWS network architecture serving 30 spoke accounts in an AWS Organizations landing zone.

## Architecture Highlights

- **Centralized Hub Architecture**:
  - Ingress VPC (`10.101.0.0/16`) for inbound traffic filtering via Network Firewall 1, IGW edge routing, and public NLB.
  - Inspection VPC (`10.100.0.0/16`) for egress and east-west inspection via Network Firewall 2, NAT Gateways, and IGW.
  - AWS Transit Gateway with 4 dedicated route tables (`spoke`, `inspection`, `ingress`, `hybrid`).
- **Zero-Bypass Spoke Routing**:
  - The TGW spoke route table contains **only** `0.0.0.0/0 -> Inspection VPC attachment`.
  - Spoke VPC CIDRs are strictly forbidden from being propagated into the TGW spoke route table.
  - All inter-spoke and egress traffic must traverse the Inspection Firewall.
- **Symmetric Stateful Inspection**:
  - `appliance_mode_support = "enable"` is set strictly on the inspection VPC TGW attachment.
  - Dynamic per-AZ firewall endpoint mapping ensures traffic never crosses AZs into the firewall.
  - Attachment subnet has dual routes: `10.0.0.0/8 -> TGW` (return east-west) and `0.0.0.0/0 -> NAT` (internet egress).
- **Spoke Account Autonomy & Cost Efficiency**:
  - Spoke subnets derived automatically from a single IPAM `/16` assignment.
  - Free Gateway VPC endpoint for Amazon S3.
  - Interface VPC endpoints secured by `aws:PrincipalOrgID` resource policies.
- **Zero Runtime Route Mutation**:
  - 100% static routing managed by Terraform. No Lambda or EventBridge runtime route modifiers.

## Repository Layout

```
.
├── .editorconfig
├── .gitignore
├── .tflint.hcl
├── README.md
├── modules/
│   ├── firewall-policy/   # Rule groups and two distinct policies (ingress & inspection)
│   ├── ingress-vpc/       # Ingress VPC, firewall 1, NLB, IGW edge routing
│   ├── inspection-vpc/    # Inspection VPC, firewall 2, NAT, dual return routing
│   ├── spoke/             # Spoke module executed across 30 spoke accounts
│   ├── tags/              # Standard mandatory tagging module
│   ├── tgw/               # Transit Gateway, 4 route tables, RAM share
│   └── vpc-endpoints/     # Gateway & interface endpoints with PrincipalOrgID policies
├── live/
│   ├── hub/               # Root module for the hub account
│   └── spokes/            # Root module and 30 tfvars files (spoke-01.tfvars .. spoke-30.tfvars)
└── scripts/               # Architecture validation and test scripts
```

## Mandatory Tagging

Every resource is tagged with:
- `Environment` (`hub`, `prod`, `staging`, `dev`, `sandbox`)
- `Owner`
- `CostCenter`
- `ManagedBy = "terraform"`

## State Management

- Terraform >= 1.6.0, AWS Provider >= 5.0.0
- Remote state stored in S3 with DynamoDB state locking.
- State is strictly segregated across account boundaries (`live/hub` vs `live/spokes`).
