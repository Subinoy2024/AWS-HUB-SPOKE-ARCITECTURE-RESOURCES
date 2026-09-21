# Transit Gateway with explicit routing control (no default association or propagation)
resource "aws_ec2_transit_gateway" "this" {
  description                     = "Hub Transit Gateway with centralised firewall routing"
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = "enable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

# 1. Spoke Route Table: ONLY carries default route to Inspection VPC attachment.
# NEVER propagate spoke VPC CIDRs here to prevent bypassing firewall.
resource "aws_ec2_transit_gateway_route_table" "spoke" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-rt-spoke"
      Role = "spoke"
    }
  )
}

# 2. Inspection Route Table: Spoke VPC CIDRs ARE propagated here for inspected return traffic.
resource "aws_ec2_transit_gateway_route_table" "inspection" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-rt-inspection"
      Role = "inspection"
    }
  )
}

# 3. Ingress Route Table: Associated with Ingress VPC attachment to route inbound traffic to spokes.
resource "aws_ec2_transit_gateway_route_table" "ingress" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-rt-ingress"
      Role = "ingress"
    }
  )
}

# 4. Hybrid Route Table: For Direct Connect Gateway / VPN attachments.
resource "aws_ec2_transit_gateway_route_table" "hybrid" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-rt-hybrid"
      Role = "hybrid"
    }
  )
}

# Share Transit Gateway across AWS Organization via AWS RAM
resource "aws_ram_resource_share" "tgw" {
  count                     = var.enable_ram_share ? 1 : 0
  name                      = "${var.name}-ram-share"
  allow_external_principals = false

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-ram-share"
    }
  )
}

resource "aws_ram_resource_association" "tgw" {
  count              = var.enable_ram_share ? 1 : 0
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

resource "aws_ram_principal_association" "tgw_org" {
  count              = var.enable_ram_share && var.ram_principal_org_arn != "" ? 1 : 0
  principal          = var.ram_principal_org_arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}
