# modules/ipam

Hands every spoke a non-overlapping `/16`.

With 30 spoke accounts, hand-assigned CIDRs collide sooner or later, and a collision is
unrecoverable without renumbering a live VPC. IPAM issues each spoke a block and refuses to
issue the same one twice.

## Structure

```
IPAM (private scope)
 └─ top-level pool        10.0.0.0/8      the whole range this network may use
     └─ spoke pool        10.0.0.0/9      what spokes allocate from, /16 at a time
```

The spoke pool is deliberately kept clear of the hub VPCs at `10.100.0.0/16` and
`10.101.0.0/16`, which sit in the upper half of `10.0.0.0/8`.

The pool is shared to the organization over RAM so spoke accounts can allocate from it
directly.

## Usage

```hcl
module "ipam" {
  source = "../../modules/ipam"

  name_prefix           = "hub-network"
  supernet_cidr         = "10.0.0.0/8"
  spoke_pool_cidr       = "10.0.0.0/9"
  ram_principal_org_arn = var.ram_principal_org_arn
  tags                  = module.tags.tags
}
```

Then in each spoke:

```hcl
module "spoke" {
  source = "../../modules/spoke"

  ipam_pool_id = var.ipam_pool_id   # hub output: ipam_spoke_pool_id
  vpc_cidr     = "10.1.0.0/16"      # optional, see below
  # ...
}
```

## Pinned or floating

`modules/spoke` supports three combinations:

| `ipam_pool_id` | `vpc_cidr` | Result |
|---|---|---|
| set | set | **Recommended.** IPAM issues that exact `/16`, so `spoke-01` stays on `10.1.0.0/16` for firewall rules and documentation, and IPAM still tracks it. |
| set | empty | IPAM picks the next free `/16`. Simplest, but the CIDR is not predictable. |
| empty | set | No IPAM. For importing spokes created before this module existed. |

Pinning is usually what you want: the diagram, the firewall rules and the runbooks all name
specific spoke CIDRs, and a floating allocation quietly invalidates them.

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name_prefix` | string | `hub-network` | Naming prefix |
| `supernet_cidr` | string | `10.0.0.0/8` | Top-level range IPAM manages |
| `spoke_pool_cidr` | string | `10.0.0.0/9` | Range spoke `/16`s come from |
| `spoke_netmask_length` | number | `16` | Fixed, so every spoke is identical |
| `ram_principal_org_arn` | string | — | Org or OU ARN to share the pool with |
| `tags` | map(string) | `{}` | Standard tags |

## Outputs

| Name | Description |
|---|---|
| `ipam_id` | IPAM instance ID |
| `spoke_pool_id` | Pool ID each spoke passes as `ipam_pool_id` |
| `spoke_pool_arn` | ARN of the spoke pool |
| `ram_resource_share_arn` | RAM share exposing the pool to the organization |
