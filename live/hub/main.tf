provider "aws" {
  region = var.aws_region

  default_tags {
    tags = module.tags.standard_tags
  }
}

# Standard mandatory tags
module "tags" {
  source = "../../modules/tags"

  environment = var.environment
  owner       = var.owner
  cost_center = var.cost_center
  extra_tags = {
    Layer = "hub-network"
  }
}

# Transit Gateway & Route Tables
module "tgw" {
  source = "../../modules/tgw"

  name                  = "hub-network-tgw"
  ram_principal_org_arn = var.ram_principal_org_arn
  tags                  = module.tags.tags
}

# IPAM - hands every spoke a non-overlapping /16
module "ipam" {
  source = "../../modules/ipam"

  name_prefix           = "hub-network"
  supernet_cidr         = var.ipam_supernet_cidr
  spoke_pool_cidr       = var.ipam_spoke_pool_cidr
  ram_principal_org_arn = var.ram_principal_org_arn
  tags                  = module.tags.tags
}

# Shared Firewall Rule Groups and Policies
module "firewall_policy" {
  source = "../../modules/firewall-policy"

  name_prefix                = "hub-netfw"
  log_destination_bucket_arn = var.log_destination_bucket_arn
  tags                       = module.tags.tags
}

# Inspection VPC (Firewall 2, NAT, IGW, East-West & Egress)
module "inspection_vpc" {
  source = "../../modules/inspection-vpc"

  vpc_cidr                   = var.inspection_vpc_cidr
  az_names                   = var.az_names
  transit_gateway_id         = module.tgw.transit_gateway_id
  firewall_policy_arn        = module.firewall_policy.inspection_policy_arn
  log_destination_bucket_arn = var.log_destination_bucket_arn
  name_prefix                = "hub-inspection"
  tags                       = module.tags.tags
}

# Ingress VPC (Firewall 1, NLB, IGW, Edge Routing)
module "ingress_vpc" {
  source = "../../modules/ingress-vpc"

  vpc_cidr                   = var.ingress_vpc_cidr
  az_names                   = var.az_names
  transit_gateway_id         = module.tgw.transit_gateway_id
  firewall_policy_arn        = module.firewall_policy.ingress_policy_arn
  log_destination_bucket_arn = var.log_destination_bucket_arn
  name_prefix                = "hub-ingress"
  tags                       = module.tags.tags
}

# --- TGW Route Table Associations and Routes ---

# 1. Spoke Route Table:
# NON-NEGOTIABLE RULE 1: CARRIES DEFAULT ROUTE ONLY to inspection attachment!
# Spoke VPC CIDRs MUST NEVER be propagated here.
resource "aws_ec2_transit_gateway_route" "spoke_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = module.tgw.spoke_route_table_id
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
}

# 2. Inspection Route Table Association:
# Associate the Inspection VPC attachment with the Inspection TGW route table
resource "aws_ec2_transit_gateway_route_table_association" "inspection" {
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.tgw.inspection_route_table_id
}

# 3. Ingress Route Table Association:
# Associate the Ingress VPC attachment with the Ingress TGW route table
resource "aws_ec2_transit_gateway_route_table_association" "ingress" {
  transit_gateway_attachment_id  = module.ingress_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.tgw.ingress_route_table_id
}

# 4. Ingress VPC propagated into the Inspection route table.
#
# Without this the RETURN leg of every inbound request is dropped: the spoke replies to the
# NLB's address, that reply goes spoke -> TGW -> inspection VPC -> firewall, the firewall
# sends 10.0.0.0/8 back to the TGW, and the TGW then looks up the ingress VPC CIDR in the
# INSPECTION route table. If the ingress attachment is not propagated here, there is no
# route and the packet is silently discarded.
resource "aws_ec2_transit_gateway_route_table_propagation" "ingress_to_inspection" {
  transit_gateway_attachment_id  = module.ingress_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.tgw.inspection_route_table_id
}

# 5. Hybrid route table wiring for Direct Connect / VPN.
#
# Optional: supply hybrid_attachment_ids once the DX gateway or VPN attachments exist.
# On-premises traffic is associated with the hybrid table and propagated into inspection,
# so it crosses the firewall exactly like spoke traffic does.
resource "aws_ec2_transit_gateway_route_table_association" "hybrid" {
  for_each = toset(var.hybrid_attachment_ids)

  transit_gateway_attachment_id  = each.value
  transit_gateway_route_table_id = module.tgw.hybrid_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "hybrid_to_inspection" {
  for_each = toset(var.hybrid_attachment_ids)

  transit_gateway_attachment_id  = each.value
  transit_gateway_route_table_id = module.tgw.inspection_route_table_id
}

# The hybrid table itself only needs a default route to inspection, same as the spokes.
resource "aws_ec2_transit_gateway_route" "hybrid_default" {
  count = length(var.hybrid_attachment_ids) > 0 ? 1 : 0

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_route_table_id = module.tgw.hybrid_route_table_id
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
}

# 6. Blackhole routes: drop traffic to prefixes nothing should ever reach.
resource "aws_ec2_transit_gateway_route" "blackhole_spoke" {
  for_each = toset(var.blackhole_cidrs)

  destination_cidr_block         = each.value
  transit_gateway_route_table_id = module.tgw.spoke_route_table_id
  blackhole                      = true
}
