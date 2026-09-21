# AWS IPAM - the single source of truth for spoke CIDR allocation.
#
# Why this exists: with 30 spoke accounts, hand-assigned CIDRs collide sooner or later,
# and a collision is unrecoverable without renumbering a live VPC. IPAM hands out a
# non-overlapping /16 per spoke and refuses to issue one twice.

data "aws_region" "current" {}

resource "aws_vpc_ipam" "this" {
  description = "Hub-and-spoke address management"

  operating_regions {
    region_name = data.aws_region.current.region
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ipam"
    }
  )
}

# Top-level pool: the whole private range this network is allowed to use.
resource "aws_vpc_ipam_pool" "top" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.this.private_default_scope_id
  description    = "Top-level private pool"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ipam-pool-top"
    }
  )
}

resource "aws_vpc_ipam_pool_cidr" "top" {
  ipam_pool_id = aws_vpc_ipam_pool.top.id
  cidr         = var.supernet_cidr
}

# Regional spoke pool: spokes allocate from here, /16 at a time.
resource "aws_vpc_ipam_pool" "spokes" {
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.this.private_default_scope_id
  source_ipam_pool_id = aws_vpc_ipam_pool.top.id
  locale              = data.aws_region.current.region
  description         = "Spoke VPC pool"

  allocation_default_netmask_length = var.spoke_netmask_length
  allocation_min_netmask_length     = var.spoke_netmask_length
  allocation_max_netmask_length     = var.spoke_netmask_length

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ipam-pool-spokes"
    }
  )
}

resource "aws_vpc_ipam_pool_cidr" "spokes" {
  ipam_pool_id = aws_vpc_ipam_pool.spokes.id
  cidr         = var.spoke_pool_cidr

  depends_on = [aws_vpc_ipam_pool_cidr.top]
}

# Share the spoke pool with the organization so spoke accounts can allocate from it.
resource "aws_ram_resource_share" "ipam" {
  count                     = var.enable_ram_share && var.ram_principal_org_arn != "" ? 1 : 0
  name                      = "${var.name_prefix}-ipam-share"
  allow_external_principals = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ipam-share"
    }
  )
}

resource "aws_ram_resource_association" "ipam" {
  count              = var.enable_ram_share && var.ram_principal_org_arn != "" ? 1 : 0
  resource_arn       = aws_vpc_ipam_pool.spokes.arn
  resource_share_arn = aws_ram_resource_share.ipam[0].arn
}

resource "aws_ram_principal_association" "ipam_org" {
  count              = var.enable_ram_share && var.ram_principal_org_arn != "" ? 1 : 0
  principal          = var.ram_principal_org_arn
  resource_share_arn = aws_ram_resource_share.ipam[0].arn
}
