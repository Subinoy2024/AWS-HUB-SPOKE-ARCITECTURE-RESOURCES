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
# Public NLB subnets: 10.101.0.0/28 (AZ a), 10.101.0.16/28 (AZ b)
resource "aws_subnet" "public" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(var.vpc_cidr, 12, idx)
  }

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-subnet-public-${each.key}"
      Tier = "public-nlb"
    }
  )
}

# Firewall subnets: 10.101.1.0/28 (AZ a), 10.101.1.16/28 (AZ b)
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

# Attachment subnets: 10.101.2.0/28 (AZ a), 10.101.2.16/28 (AZ b)
resource "aws_subnet" "attachment" {
  for_each = {
    for idx, az in var.az_names : az => cidrsubnet(cidrsubnet(var.vpc_cidr, 8, 2), 4, idx)
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

# Ingress Network Firewall (Firewall 1)
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

# Logging configuration for Ingress Firewall
resource "aws_networkfirewall_logging_configuration" "this" {
  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        bucketName = split(":::", var.log_destination_bucket_arn)[1]
        prefix     = "ingress-alerts"
      }
      log_destination_type = "S3"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        bucketName = split(":::", var.log_destination_bucket_arn)[1]
        prefix     = "ingress-flows"
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
          prefix     = "ingress-tls"
        }
        log_destination_type = "S3"
        log_type             = "TLS"
      }
    }
  }
}

# Dynamic per-AZ firewall endpoint mapping
locals {
  firewall_endpoints = {
    for sync_state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    sync_state.availability_zone => sync_state.attachment[0].endpoint_id
  }
}

# Public Ingress Network Load Balancer (NLB)
# CRITICAL NON-NEGOTIABLE RULE 7: enable_cross_zone_load_balancing MUST BE false!
resource "aws_lb" "ingress" {
  name                             = "${var.name_prefix}-nlb"
  internal                         = false
  load_balancer_type               = "network"
  subnets                          = [for s in aws_subnet.public : s.id]
  enable_cross_zone_load_balancing = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nlb"
    }
  )
}

# TGW VPC Attachment for Ingress VPC:
# CRITICAL: appliance_mode_support is disabled (only enabled on inspection VPC attachment)
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

# --- Routing Architecture ---

# 1. IGW Edge Route Table:
# Inbound traffic from internet targeting public subnets is directed to the firewall endpoint in the SAME AZ.
resource "aws_route_table" "igw_edge" {
  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.az_names
    content {
      cidr_block      = aws_subnet.public[route.value].cidr_block
      vpc_endpoint_id = local.firewall_endpoints[route.value]
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-igw-edge"
      Tier = "igw-edge"
    }
  )

  depends_on = [aws_networkfirewall_firewall.this]
}

# Edge route table association directly to the Internet Gateway
resource "aws_route_table_association" "igw_edge" {
  gateway_id     = aws_internet_gateway.this.id
  route_table_id = aws_route_table.igw_edge.id
}

# 2. Public Subnet Route Tables (per AZ - where NLB sits):
# - 0.0.0.0/0 -> Firewall endpoint in the same AZ (return traffic to internet)
# - 10.0.0.0/8 -> Transit Gateway (traffic to spoke internal applications)
resource "aws_route_table" "public" {
  for_each = toset(var.az_names)
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block      = "0.0.0.0/0"
    vpc_endpoint_id = local.firewall_endpoints[each.key]
  }

  route {
    cidr_block         = "10.0.0.0/8"
    transit_gateway_id = var.transit_gateway_id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-public-${each.key}"
      Tier = "public-nlb"
    }
  )

  depends_on = [aws_networkfirewall_firewall.this]
}

resource "aws_route_table_association" "public" {
  for_each       = toset(var.az_names)
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[each.key].id
}

# 3. Firewall Subnet Route Tables (per AZ):
# Traffic leaving the firewall on its way to the internet goes through the IGW.
resource "aws_route_table" "firewall" {
  for_each = toset(var.az_names)
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-rt-firewall-${each.key}"
      Tier = "firewall"
    }
  )
}

resource "aws_route_table_association" "firewall" {
  for_each       = toset(var.az_names)
  subnet_id      = aws_subnet.firewall[each.key].id
  route_table_id = aws_route_table.firewall[each.key].id
}

# 4. Attachment Subnet Route Table:
# Routes traffic returning from spokes via TGW.
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

# --- NLB listener and target group ---
#
# Targets are IP addresses inside the spoke VPCs, reached over the transit gateway.
# NLB IP targets must be RFC1918 addresses in a connected VPC, which every spoke is.
#
# Health checks run NLB -> TGW -> spoke ALB and therefore do NOT traverse firewall 1.
# A dead ingress firewall endpoint will not show up here; that is what the Route 53
# per-AZ health checks are for. See var.enable_route53_healthcheck_targets.
resource "aws_lb_target_group" "ingress" {
  name        = "${var.name_prefix}-tg"
  port        = var.target_port
  protocol    = var.target_protocol
  target_type = "ip"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled             = true
    protocol            = var.health_check_protocol
    port                = var.health_check_port
    path                = var.health_check_protocol == "TCP" ? null : var.health_check_path
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-tg"
    }
  )
}

resource "aws_lb_target_group_attachment" "ingress" {
  for_each = toset(var.target_ips)

  target_group_arn  = aws_lb_target_group.ingress.arn
  target_id         = each.value
  port              = var.target_port
  availability_zone = "all" # targets live outside the load balancer's VPC, across the TGW
}

resource "aws_lb_listener" "ingress" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = var.listener_port
  protocol          = var.listener_protocol
  certificate_arn   = var.listener_protocol == "TLS" ? var.certificate_arn : null
  ssl_policy        = var.listener_protocol == "TLS" ? var.ssl_policy : null

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ingress.arn
  }
}
