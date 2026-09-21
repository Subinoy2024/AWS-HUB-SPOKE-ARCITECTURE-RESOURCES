variable "aws_region" {
  type        = string
  description = "AWS region for spoke deployment."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Environment name for this spoke (e.g. prod, staging, dev)."
  default     = "prod"
}

variable "owner" {
  type        = string
  description = "Owner team for this spoke account."
  default     = "workload-team"
}

variable "cost_center" {
  type        = string
  description = "Cost center for financial tracking."
  default     = "CC-APP-5001"
}

# The ONE meaningful spoke-specific network variable.
# Preferred: leave vpc_cidr empty and let IPAM allocate. Set vpc_cidr only to import or
# pin an existing spoke that predates IPAM.
variable "vpc_cidr" {
  type        = string
  description = "Explicit /16 for this spoke. Leave empty to allocate from IPAM instead."
  default     = ""
}

variable "ipam_pool_id" {
  type        = string
  description = "IPAM pool to allocate this spoke's /16 from (hub output ipam_spoke_pool_id)."
  default     = "ipam-pool-02e0cd7a4ce855527"
}

variable "spoke_name" {
  type        = string
  description = "Identifier for the spoke (e.g. spoke-01)."
  default     = "spoke"
}

variable "transit_gateway_id" {
  type        = string
  description = "Transit Gateway ID from the hub account."
  default     = "tgw-0189544e41499d14c"
}

variable "tgw_spoke_route_table_id" {
  type        = string
  description = "TGW Spoke Route Table ID (where spoke attachment is associated)."
  default     = "tgw-rtb-0cd559431c943b8b6"
}

variable "tgw_inspection_route_table_id" {
  type        = string
  description = "TGW Inspection Route Table ID (where spoke attachment is propagated)."
  default     = "tgw-rtb-04c1da3f8350c3b3c"
}

variable "tgw_ingress_route_table_id" {
  type        = string
  description = "TGW Ingress Route Table ID. The spoke propagates here so the ingress NLB can reach its application IPs."
  default     = "tgw-rtb-04eb154f01aebf36c"
}

variable "organization_id" {
  type        = string
  description = "AWS Organization ID for securing VPC endpoint resource policies."
  default     = ""
}

variable "az_names" {
  type        = list(string)
  description = "Two availability zones for spoke subnets."
  default     = ["us-east-1a", "us-east-1b"]
}
