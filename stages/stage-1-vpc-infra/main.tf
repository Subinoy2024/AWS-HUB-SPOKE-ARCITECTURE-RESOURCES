provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Owner       = var.owner
      CostCenter  = var.cost_center
      ManagedBy   = "terraform"
      Stage       = "stage-1-vpc-infra"
    }
  }
}

data "aws_region" "current" {}

# ==============================================================================
# 1. AWS IPAM (IP Address Manager)
# ==============================================================================
resource "aws_vpc_ipam" "this" {
  description = "Hub-and-spoke address management"

  operating_regions {
    region_name = data.aws_region.current.region
  }

  tags = {
    Name = "hub-network-ipam"
  }
}

resource "aws_vpc_ipam_pool" "top" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.this.private_default_scope_id
  description    = "Top-level private pool"

  tags = {
    Name = "hub-network-ipam-pool-top"
  }
}

resource "aws_vpc_ipam_pool_cidr" "top" {
  ipam_pool_id = aws_vpc_ipam_pool.top.id
  cidr         = var.ipam_supernet_cidr
}

resource "aws_vpc_ipam_pool" "spokes" {
  address_family      = "ipv4"
  ipam_scope_id       = aws_vpc_ipam.this.private_default_scope_id
  source_ipam_pool_id = aws_vpc_ipam_pool.top.id
  locale              = data.aws_region.current.region
  description         = "Spoke VPC pool"

  allocation_default_netmask_length = 16
  allocation_min_netmask_length     = 16
  allocation_max_netmask_length     = 16

  tags = {
    Name = "hub-network-ipam-pool-spokes"
  }
}

resource "aws_vpc_ipam_pool_cidr" "spokes" {
  ipam_pool_id = aws_vpc_ipam_pool.spokes.id
  cidr         = var.ipam_spoke_pool_cidr

  depends_on = [aws_vpc_ipam_pool_cidr.top]
}

# ==============================================================================
# 2. Inspection VPC (10.100.0.0/16) - Outbound & East-West Inspection Base
# ==============================================================================
resource "aws_vpc" "inspection" {
  cidr_block           = var.inspection_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hub-inspection-vpc"
  }
}

resource "aws_internet_gateway" "inspection" {
  vpc_id = aws_vpc.inspection.id

  tags = {
    Name = "hub-inspection-igw"
  }
}

# Attachment Subnets: 10.100.0.0/28 (AZ a), 10.100.0.16/28 (AZ b)
resource "aws_subnet" "inspection_attachment" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(var.inspection_vpc_cidr, 12, idx)
  }

  vpc_id            = aws_vpc.inspection.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "hub-inspection-subnet-attachment-${each.key}"
    Tier = "attachment"
  }
}

# Firewall Subnets: 10.100.1.0/28 (AZ a), 10.100.1.16/28 (AZ b)
resource "aws_subnet" "inspection_firewall" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(cidrsubnet(var.inspection_vpc_cidr, 8, 1), 4, idx)
  }

  vpc_id            = aws_vpc.inspection.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "hub-inspection-subnet-firewall-${each.key}"
    Tier = "firewall"
  }
}

# Public NAT Subnets: 10.100.2.0/28 (AZ a), 10.100.2.16/28 (AZ b)
resource "aws_subnet" "inspection_public" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(cidrsubnet(var.inspection_vpc_cidr, 8, 2), 4, idx)
  }

  vpc_id                  = aws_vpc.inspection.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "hub-inspection-subnet-public-${each.key}"
    Tier = "public"
  }
}

# Elastic IPs and NAT Gateways in Public Subnets (one per AZ)
resource "aws_eip" "nat" {
  for_each = toset(var.az_names)
  domain   = "vpc"

  tags = {
    Name = "hub-inspection-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each      = toset(var.az_names)
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.inspection_public[each.key].id

  tags = {
    Name = "hub-inspection-nat-${each.key}"
  }

  depends_on = [aws_internet_gateway.inspection]
}

# ==============================================================================
# 3. Ingress VPC (10.101.0.0/16) - Inbound Inspection Base
# ==============================================================================
resource "aws_vpc" "ingress" {
  cidr_block           = var.ingress_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "hub-ingress-vpc"
  }
}

resource "aws_internet_gateway" "ingress" {
  vpc_id = aws_vpc.ingress.id

  tags = {
    Name = "hub-ingress-igw"
  }
}

# Public NLB Subnets: 10.101.0.0/28 (AZ a), 10.101.0.16/28 (AZ b)
resource "aws_subnet" "ingress_public" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(var.ingress_vpc_cidr, 12, idx)
  }

  vpc_id                  = aws_vpc.ingress.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name = "hub-ingress-subnet-public-${each.key}"
    Tier = "public-nlb"
  }
}

# Firewall Subnets: 10.101.1.0/28 (AZ a), 10.101.1.16/28 (AZ b)
resource "aws_subnet" "ingress_firewall" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(cidrsubnet(var.ingress_vpc_cidr, 8, 1), 4, idx)
  }

  vpc_id            = aws_vpc.ingress.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "hub-ingress-subnet-firewall-${each.key}"
    Tier = "firewall"
  }
}

# Attachment Subnets: 10.101.2.0/28 (AZ a), 10.101.2.16/28 (AZ b)
resource "aws_subnet" "ingress_attachment" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(cidrsubnet(var.ingress_vpc_cidr, 8, 2), 4, idx)
  }

  vpc_id            = aws_vpc.ingress.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "hub-ingress-subnet-attachment-${each.key}"
    Tier = "attachment"
  }
}

# Public Ingress Network Load Balancer (NLB)
# CRITICAL NON-NEGOTIABLE RULE 7: enable_cross_zone_load_balancing MUST BE false!
resource "aws_lb" "ingress" {
  name                             = "hub-ingress-nlb"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = [for s in aws_subnet.ingress_public : s.id]
  enable_cross_zone_load_balancing = false

  tags = {
    Name = "hub-ingress-nlb"
  }
}
