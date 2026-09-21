variable "aws_region" {
  type        = string
  description = "AWS region for network infrastructure."
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
  description = "Range spoke /16s are allocated from."
  default     = "10.0.0.0/9"
}
