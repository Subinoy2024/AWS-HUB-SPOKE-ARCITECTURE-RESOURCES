variable "vpc_cidr" {
  type        = string
  description = "The IPv4 /16 CIDR for this spoke VPC. Ignored when ipam_pool_id is set."
  default     = ""

  validation {
    condition     = var.vpc_cidr == "" || can(regex("^10\\.[0-9]+\\.0\\.0/16$", var.vpc_cidr))
    error_message = "VPC CIDR must be empty (when using IPAM) or a valid 10.<n>.0.0/16 network."
  }
}

variable "ipam_pool_id" {
  type        = string
  description = "AWS IPAM pool to allocate this spoke's CIDR from. Preferred over vpc_cidr: IPAM guarantees no two spokes collide. Leave empty to use vpc_cidr."
  default     = ""
}

variable "ipam_netmask_length" {
  type        = number
  description = "Netmask length to request from the IPAM pool."
  default     = 16

  validation {
    condition     = var.ipam_netmask_length >= 16 && var.ipam_netmask_length <= 24
    error_message = "IPAM netmask length must be between 16 and 24."
  }
}

variable "transit_gateway_id" {
  type        = string
  description = "The ID of the central Transit Gateway."
}

variable "az_names" {
  type        = list(string)
  description = "List of exactly 2 availability zone names."
  default     = ["us-east-1a", "us-east-1b"]

  validation {
    condition     = length(var.az_names) == 2
    error_message = "Exactly 2 availability zones must be specified."
  }
}

variable "organization_id" {
  type        = string
  description = "AWS Organization ID for securing VPC endpoint policies."
  default     = ""
}

variable "name_prefix" {
  type        = string
  description = "Name prefix for the spoke VPC resources."
  default     = "spoke"
}

variable "enable_vpc_endpoints" {
  type        = bool
  description = "Whether to deploy the spoke VPC endpoints."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Standard resource tags."
  default     = {}
}
