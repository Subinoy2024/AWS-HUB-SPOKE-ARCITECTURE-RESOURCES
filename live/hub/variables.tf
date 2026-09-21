variable "aws_region" {
  type        = string
  description = "AWS region for network hub infrastructure."
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name."
  default     = "hub"
}

variable "owner" {
  type        = string
  description = "Team or individual owner of the resource."
  default     = "cloud-platform-netops"
}

variable "cost_center" {
  type        = string
  description = "Cost center for financial tracking."
  default     = "CC-NET-7001"
}

variable "ram_principal_org_arn" {
  type        = string
  description = "AWS Organization ARN or OU ARN for RAM resource sharing."
  default     = ""
}

variable "log_destination_bucket_arn" {
  type        = string
  description = "S3 bucket ARN in log archive account for firewall logs (Alert, Flow, TLS)."
  default     = "arn:aws:s3:::hub-netfw-logs-173778668295"
}

variable "az_names" {
  type        = list(string)
  description = "Two availability zones for hub deployment."
  default     = ["us-east-1a", "us-east-1b"]
}

variable "inspection_vpc_cidr" {
  type        = string
  description = "CIDR block for the Inspection VPC."
  default     = "10.100.0.0/16"
}

variable "ingress_vpc_cidr" {
  type        = string
  description = "CIDR block for the Ingress VPC."
  default     = "10.101.0.0/16"
}

variable "ipam_supernet_cidr" {
  type        = string
  description = "Top-level private range IPAM manages."
  default     = "10.0.0.0/8"
}

variable "ipam_spoke_pool_cidr" {
  type        = string
  description = "Range spoke /16s are allocated from. Kept clear of the hub VPCs at 10.100.0.0/16 and 10.101.0.0/16."
  default     = "10.0.0.0/9"
}

variable "hybrid_attachment_ids" {
  type        = list(string)
  description = "Direct Connect gateway / Site-to-Site VPN TGW attachment IDs. Empty until the circuits exist."
  default     = []
}

variable "blackhole_cidrs" {
  type        = list(string)
  description = "Prefixes to blackhole on the TGW spoke route table (unallocated or known-bad ranges)."
  default     = []
}
