# Spoke VPC - Completely isolated: NO Internet Gateway, NO direct spoke-to-spoke path
#
# CIDR comes from AWS IPAM when ipam_pool_id is set (the supported path), otherwise
# from var.vpc_cidr. Every subnet is derived from aws_vpc.this.cidr_block rather than
# the variable, so both paths behave identically.
resource "aws_vpc" "this" {
  # Three supported combinations:
  #   ipam_pool_id + vpc_cidr  -> IPAM issues that exact /16. Recommended: keeps spoke-01
  #                               pinned to 10.1.0.0/16 for firewall rules and docs, while
  #                               IPAM still tracks it and refuses to hand it out twice.
  #   ipam_pool_id only        -> IPAM picks the next free /16.
  #   vpc_cidr only            -> no IPAM. For importing spokes that predate it.
  cidr_block          = var.vpc_cidr != "" ? var.vpc_cidr : null
  ipv4_ipam_pool_id   = var.ipam_pool_id != "" ? var.ipam_pool_id : null
  ipv4_netmask_length = (var.ipam_pool_id != "" && var.vpc_cidr == "") ? var.ipam_netmask_length : null

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}

# Derived Subnets using cidrsubnet, laid out to match the published CIDR plan:
#   attachment  10.x.0.0/28   10.x.0.16/28
#   application 10.x.1.0/24   10.x.3.0/24
#   data        10.x.2.0/24   10.x.4.0/24
locals {
  vpc_cidr = aws_vpc.this.cidr_block
}

# 1. Attachment Subnets: /28 (for TGW attachment ENIs)
resource "aws_subnet" "attachment" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(local.vpc_cidr, 12, idx)
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-subnet-attachment-${each.key}"
      Tier = "attachment"
    }
  )
}

# 2. Application Subnets: /24 (Private, internal ALB + EC2 + ECS)
#    AZ-a -> 10.x.1.0/24, AZ-b -> 10.x.3.0/24
resource "aws_subnet" "application" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(local.vpc_cidr, 8, (idx * 2) + 1)
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-subnet-application-${each.key}"
      Tier = "application"
    }
  )
}

# 3. Data Subnets: /24 (RDS, ElastiCache, strictly isolated - NO route out)
#    AZ-a -> 10.x.2.0/24, AZ-b -> 10.x.4.0/24
resource "aws_subnet" "data" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(local.vpc_cidr, 8, (idx * 2) + 2)
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-subnet-data-${each.key}"
      Tier = "data"
    }
  )
}

# Spoke TGW Attachment
# NON-NEGOTIABLE RULE 3: appliance_mode_support MUST BE "disable" on spoke attachments!
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.this.id
  subnet_ids                                      = [for s in aws_subnet.attachment : s.id]
  appliance_mode_support                          = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-tgw-attachment"
    }
  )
}

# --- Route Tables ---

# Application Subnet Route Table:
# All traffic leaving the application subnet routes to TGW (0.0.0.0/0 -> TGW)
resource "aws_route_table" "application" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block         = "0.0.0.0/0"
    transit_gateway_id = var.transit_gateway_id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-application"
      Tier = "application"
    }
  )
}

resource "aws_route_table_association" "application" {
  for_each       = toset(var.az_names)
  subnet_id      = aws_subnet.application[each.key].id
  route_table_id = aws_route_table.application.id
}

# Data Subnet Route Table:
# STRICT ISOLATION: Data subnets carry NO routes to 0.0.0.0/0 or TGW. Only local VPC routing,
# plus the S3 gateway endpoint prefix list (added by the vpc-endpoints module) so RDS can
# reach S3 for backups and exports without any route leaving the VPC.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-data"
      Tier = "data-isolated"
    }
  )
}

resource "aws_route_table_association" "data" {
  for_each       = toset(var.az_names)
  subnet_id      = aws_subnet.data[each.key].id
  route_table_id = aws_route_table.data.id
}

# Attachment Subnet Route Table
resource "aws_route_table" "attachment" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-attachment"
      Tier = "attachment"
    }
  )
}

resource "aws_route_table_association" "attachment" {
  for_each       = toset(var.az_names)
  subnet_id      = aws_subnet.attachment[each.key].id
  route_table_id = aws_route_table.attachment.id
}

# Module: Private VPC Endpoints (S3 Gateway + Org-Restricted Interface Endpoints)
module "vpc_endpoints" {
  count  = var.enable_vpc_endpoints && var.organization_id != "" ? 1 : 0
  source = "../vpc-endpoints"

  vpc_id     = aws_vpc.this.id
  vpc_cidr   = local.vpc_cidr
  subnet_ids = [for s in aws_subnet.application : s.id]
  # Data subnets get the S3 gateway route too, so RDS backups/exports work
  # without punching any route out of the VPC.
  route_table_ids = [aws_route_table.application.id, aws_route_table.data.id]
  organization_id = var.organization_id
  name_prefix     = "${var.name_prefix}-vpce"

  tags = var.tags
}
