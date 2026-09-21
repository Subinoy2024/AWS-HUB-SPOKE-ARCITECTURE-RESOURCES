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
    SpokeName = var.spoke_name
  }
}

# Spoke VPC Module (Derives all subnets from vpc_cidr via cidrsubnet)
module "spoke" {
  source = "../../modules/spoke"

  vpc_cidr           = var.vpc_cidr
  ipam_pool_id       = var.ipam_pool_id
  transit_gateway_id = var.transit_gateway_id
  az_names           = var.az_names
  organization_id    = var.organization_id
  name_prefix        = var.spoke_name

  tags = module.tags.tags
}

# --- TGW Route Table Configuration for Spoke ---

# 1. Spoke Attachment Association:
# Associated strictly with the TGW Spoke Route Table (which has ONLY 0.0.0.0/0 -> Inspection VPC)
resource "aws_ec2_transit_gateway_route_table_association" "spoke" {
  transit_gateway_attachment_id  = module.spoke.tgw_attachment_id
  transit_gateway_route_table_id = var.tgw_spoke_route_table_id
}

# 2. Spoke Attachment Propagation:
# NON-NEGOTIABLE RULE 2: Propagate spoke CIDR into Inspection TGW Route Table ONLY!
# NON-NEGOTIABLE RULE 1: DO NOT propagate spoke CIDR into Spoke TGW Route Table!
resource "aws_ec2_transit_gateway_route_table_propagation" "inspection" {
  transit_gateway_attachment_id  = module.spoke.tgw_attachment_id
  transit_gateway_route_table_id = var.tgw_inspection_route_table_id
}

# 3. Spoke Attachment Propagation into the INGRESS route table.
#
# Without this, inbound traffic dies at the TGW. The ingress NLB sends 10.0.0.0/8 to the
# transit gateway, the TGW consults the ingress route table because that is what the
# ingress attachment is associated with, finds no route to this spoke, and drops the packet.
# Propagating here is what lets the NLB reach spoke application IPs.
#
# This is still safe with respect to RULE 1: the spoke route table gets no propagation at
# all, so spoke-to-spoke traffic has nothing but the default route to inspection.
resource "aws_ec2_transit_gateway_route_table_propagation" "ingress" {
  transit_gateway_attachment_id  = module.spoke.tgw_attachment_id
  transit_gateway_route_table_id = var.tgw_ingress_route_table_id
}
