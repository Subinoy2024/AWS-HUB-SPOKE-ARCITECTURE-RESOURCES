# Build prompt — AWS hub-and-spoke with centralised Network Firewall inspection

Hand this to a coding agent. It is self-contained: it does not assume the agent has seen the
diagram or any prior conversation.

---

## THE PROMPT

Build a complete, production-grade Terraform codebase for an AWS hub-and-spoke network with
centralised firewall inspection, serving **30 spoke accounts in one region**, in an AWS
Organizations landing zone.

### What the network must do

Every packet entering, leaving, or crossing between spoke accounts must traverse an AWS Network
Firewall endpoint. Spoke VPCs have **no internet gateway of their own** and can never reach the
internet or each other directly.

### Topology

**Network hub account** contains two VPCs and one transit gateway.

*Ingress VPC — `10.101.0.0/16` — firewall 1 — inbound only*

```
internet → IGW → [IGW edge route table] → firewall endpoint (same AZ)
        → NLB in public subnet → TGW attachment → TGW → spoke
```

Subnets per AZ: public `10.101.0.x/28` (NLB), firewall `10.101.1.x/28`, attachment `10.101.2.x/28`.

*Inspection VPC — `10.100.0.0/16` — firewall 2 — outbound, east-west and hybrid*

```
spoke → TGW → attachment subnet → firewall endpoint (same AZ) → NAT gateway → IGW → internet
```

Subnets per AZ: attachment `10.100.0.x/28`, firewall `10.100.1.x/28`, public `10.100.2.x/28` (NAT).

*Spoke account × 30 — `10.<n>.0.0/16` from IPAM*

Per AZ: attachment `/28`, application `/24` (private, internal ALB + EC2 + ECS), data `/24`
(RDS, ElastiCache, no route out). Two AZs, identical. Default route `0.0.0.0/0` → TGW attachment.

### Non-negotiable correctness rules

These are the things that silently break this design. Get every one of them right.

1. **The TGW spoke route table carries a DEFAULT ROUTE ONLY.** Do not propagate spoke VPC CIDRs
   into it. If you do, the TGW finds a specific route from spoke A to spoke B, prefers it over the
   default, and **silently bypasses the firewall**. Nothing errors. This is the single most
   important rule in the build.
2. **The TGW inspection route table DOES get every spoke CIDR propagated** — that is how inspected
   traffic finds its way back out.
3. **`appliance_mode_support = "enable"` on the inspection VPC attachment only** — not on spoke
   attachments. Without it, the two directions of a flow land on different AZs' endpoints and the
   stateful firewall drops the return traffic.
4. **Every route points at the firewall endpoint in its own AZ.** Never cross AZs. Build a
   per-AZ map of endpoint IDs and index every route table off it.
5. **Firewall comes BEFORE NAT** in the inspection VPC, so the firewall sees real source IPs.
6. **The attachment subnet route table needs two routes**: `10.0.0.0/8 → TGW attachment` (east-west
   and hybrid return) and `0.0.0.0/0 → NAT gateway` (internet egress). With only the default route,
   east-west traffic gets NAT'd to the internet instead of returning to the TGW.
7. **`enable_cross_zone_load_balancing = false` on the ingress NLB** — cross-zone would move a flow
   to another AZ and lose its firewall state.
8. **No Lambda, no EventBridge, nothing that mutates a route table at runtime.** All routing is
   static and written by Terraform. AZ failure is handled by Route 53 ARC zonal shift, never by
   rewriting routes.
9. **Two firewall policies, shared rule groups.** Ingress and egress policies differ; the rule
   groups they reference are shared and versioned in git.
10. **S3 gets a GATEWAY endpoint (free), not an interface endpoint.** Interface endpoints are
    per-AZ-per-service ENIs and get expensive fast across 30 accounts.

### Known-awkward implementation detail

The firewall endpoint ID per AZ is only available after creation, nested in the resource's status:

```hcl
firewall_status[0].sync_states[*].attachment[0].endpoint_id
```

Build a `for` expression that produces `{ az => endpoint_id }` and use it everywhere routes are
written. Do not hardcode. Expect a dependency ordering problem here and solve it explicitly.

### Repository layout

```
modules/
  tgw/                  transit gateway, 4 route tables, RAM share
  ingress-vpc/          ingress VPC, firewall 1, NLB, IGW, edge routing
  inspection-vpc/       inspection VPC, firewall 2, NAT, IGW
  firewall-policy/      rule groups + the two policies
  spoke/                the module that runs 30 times
  vpc-endpoints/        gateway + interface endpoints with policies
live/
  hub/                  root module for the hub account
  spokes/
    spoke-01.tfvars     only the /16 differs between these
    ...spoke-30.tfvars
.github/workflows/
```

### Requirements

- Terraform >= 1.6, AWS provider >= 5.x, remote state in S3 with DynamoDB locking, one state per
  account boundary.
- The spoke module takes **one meaningful variable**: its `/16`. Everything else is derived
  (`cidrsubnet`) or defaulted. Allocate the `/16` from AWS IPAM, never by hand.
- Four TGW route tables: `spoke`, `inspection`, `ingress`, `hybrid`. Explicit associations and
  propagations — no implicit default association.
- Share the TGW with the org via RAM.
- Firewall logging: alert, flow and TLS logs to S3 in a separate log archive account, object lock on.
- Tag everything: `Environment`, `Owner`, `CostCenter`, `ManagedBy = "terraform"`.
- No hardcoded account IDs, regions, or CIDRs outside tfvars.
- Every variable typed and described; every output documented.
- `README.md` per module with a usage example.

### CI

GitHub Actions using **OIDC, no static keys**:
`terraform fmt -check` → `terraform validate` → `tflint` → `checkov` → `terraform plan` posted to
the PR → apply on merge. Hub applies before spokes.

### Acceptance criteria

The build is done when all of these hold:

- [ ] `terraform validate`, `tflint` and `checkov` are clean
- [ ] A test or check asserts the **spoke TGW route table has no propagated spoke CIDRs** — this is
      the rule most likely to regress
- [ ] Every VPC route table entry referencing a firewall endpoint uses the endpoint **in its own AZ**
- [ ] `appliance_mode_support` is enabled on the inspection attachment and on nothing else
- [ ] The inspection attachment subnet route table has both the `10.0.0.0/8 → TGW` and
      `0.0.0.0/0 → NAT` routes
- [ ] NLB cross-zone load balancing is disabled
- [ ] No `aws_lambda_function` exists anywhere in the codebase
- [ ] S3 uses a gateway endpoint; every interface endpoint has a policy with an
      `aws:PrincipalOrgID` condition
- [ ] Adding a 31st spoke requires creating one tfvars file and nothing else
- [ ] `terraform plan` is empty on a second run

### How to work

Build in this order, and stop after each step so I can review:

1. Repo skeleton, versions, backend, tagging strategy
2. `modules/tgw` — transit gateway, route tables, RAM share
3. `modules/firewall-policy` — rule groups and both policies
4. `modules/inspection-vpc` — including the per-AZ endpoint map and the return route
5. `modules/ingress-vpc` — including IGW edge route table association
6. `modules/spoke` — plus `modules/vpc-endpoints`
7. `live/hub` and one spoke, then the remaining 29 tfvars
8. CI workflows

Ask before inventing anything not specified here. If a requirement above looks wrong to you, say so
before implementing it rather than silently changing it.
