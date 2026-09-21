# Tags Module

Standardized tagging module enforcing organization-wide tagging standards across all hub and spoke resources.

## Mandatory Tags

- `Environment`: Deployment tier (`prod`, `staging`, `dev`, `sandbox`, `hub`).
- `Owner`: Team or individual responsible for the resource.
- `CostCenter`: Finance cost allocation code.
- `ManagedBy`: Always set to `"terraform"`.

## Usage Example

```hcl
module "tags" {
  source = "../../modules/tags"

  environment = "hub"
  owner       = "cloud-platform-netops"
  cost_center = "CC-NET-7001"
  extra_tags = {
    Project = "Centralized-Network-Hub"
  }
}

# Apply to a resource:
resource "aws_vpc" "example" {
  cidr_block = "10.100.0.0/16"
  tags       = module.tags.tags
}
```
