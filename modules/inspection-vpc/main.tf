resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-igw"
    }
  )
}

# Subnets per AZ:
# Attachment subnets: 10.100.0.0/28 (AZ a), 10.100.0.16/28 (AZ b)
resource "aws_subnet" "attachment" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(var.vpc_cidr, 12, idx)
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

# Firewall subnets: 10.100.1.0/28 (AZ a), 10.100.1.16/28 (AZ b)
resource "aws_subnet" "firewall" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(cidrsubnet(var.vpc_cidr, 8, 1), 4, idx)
  }

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-subnet-firewall-${each.key}"
      Tier = "firewall"
    }
  )
}

# Public NAT subnets: 10.100.2.0/28 (AZ a), 10.100.2.16/28 (AZ b)
resource "aws_subnet" "public" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(cidrsubnet(var.vpc_cidr, 8, 2), 4, idx)
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-subnet-public-${each.key}"
      Tier = "public"
    }
  )
}

# Elastic IPs and NAT Gateways in Public Subnets (one per AZ)
resource "aws_eip" "nat" {
  for_each = toset(var.az_names)
  domain   = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-eip-${each.key}"
    }
  )
}

resource "aws_nat_gateway" "this" {
  for_each      = toset(var.az_names)
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-${each.key}"
    }
  )

  depends_on = [aws_internet_gateway.this]
}

# AWS Network Firewall (Firewall 2 - Inspection, Egress & East-West)
resource "aws_networkfirewall_firewall" "this" {
  name                = "${var.name_prefix}-firewall"
  firewall_policy_arn = var.firewall_policy_arn
  vpc_id              = aws_vpc.this.id

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall
    content {
      subnet_id = subnet_mapping.value.id
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-firewall"
    }
  )
}

# Logging configuration for Network Firewall (Alert, Flow, and TLS logs to S3)
resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        bucketName = split(":::", var.log_destination_bucket_arn)[1]
        prefix     = "alerts"
      }
      log_destination_type = "S3"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        bucketName = split(":::", var.log_destination_bucket_arn)[1]
        prefix     = "flows"
      }
      log_destination_type = "S3"
      log_type             = "FLOW"
    }

    # TLS logs only exist once a TLS inspection configuration is attached to the policy.
    # Enabling this log type without one produces an empty stream at best, so it is gated.
    dynamic "log_destination_config" {
      for_each = var.enable_tls_inspection ? [1] : []
      content {
        log_destination = {
          bucketName = split(":::", var.log_destination_bucket_arn)[1]
          prefix     = "tls"
        }
        log_destination_type = "S3"
        log_type             = "TLS"
      }
    }
  }
}

# Extract dynamic per-AZ endpoint mapping from firewall status
locals {
  firewall_endpoints = {
    for sync_state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    sync_state.availability_zone => sync_state.attachment[0].endpoint_id
  }
}

# TGW VPC Attachment:
# CRITICAL NON-NEGOTIABLE: appliance_mode_support MUST BE "enable" ONLY on this attachment!
resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.this.id
  subnet_ids                                      = [for s in aws_subnet.attachment : s.id]
  appliance_mode_support                          = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-tgw-attachment"
    }
  )
}

# --- Routing Architecture ---

# 1. Attachment Subnet Route Tables (per AZ):
# Traffic arriving from TGW is directed to the firewall endpoint in the SAME AZ.
resource "aws_route_table" "attachment" {
  for_each = toset(var.az_names)
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoints[each.key]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-attachment-${each.key}"
      Tier = "attachment"
    }
  )

  depends_on = [aws_networkfirewall_firewall.this]
}

resource "aws_route_table_association" "attachment" {
  for_each       = toset(var.az_names)
  subnet_id      = aws_subnet.attachment[each.key].id
  route_table_id = aws_route_table.attachment[each.key].id
}

# 2. Firewall Subnet Route Tables (per AZ):
# Traffic exiting the firewall endpoint is routed based on destination:
# - 0.0.0.0/0 -> NAT Gateway (Internet Egress)
# - 10.0.0.0/8 -> TGW (East-West return to other spokes and hybrid networks)
resource "aws_route_table" "firewall" {
  for_each = toset(var.az_names)
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = var.transit_gateway_id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-firewall-${each.key}"
      Tier = "firewall-post-inspection"
    }
  )
}

resource "aws_route_table_association" "firewall" {
  for_each       = toset(var.az_names)
  subnet_id      = aws_subnet.firewall[each.key].id
  route_table_id = aws_route_table.firewall[each.key].id
}

# 3. Public NAT Subnet Route Tables (per AZ):
# - 0.0.0.0/0 -> Internet Gateway
# - 10.0.0.0/8 -> Firewall endpoint in the same AZ (for return traffic inspection)
resource "aws_route_table" "public" {
  for_each = toset(var.az_names)
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  route {
    cidr_block      = "10.0.0.0/8"
    vpc_endpoint_id = local.firewall_endpoints[each.key]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-public-${each.key}"
      Tier = "public"
    }
  )

  depends_on = [aws_networkfirewall_firewall.this]
}

resource "aws_route_table_association" "public" {
  for_each       = toset(var.az_names)
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}
