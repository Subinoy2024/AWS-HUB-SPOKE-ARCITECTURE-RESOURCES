variable "name_prefix" {
  type        = string
  description = "Naming prefix for IPAM resources."
  default     = "hub-network"
}

variable "supernet_cidr" {
  type        = string
  description = "The whole private range this network may use."
  default     = "10.0.0.0/8"
}

variable "spoke_pool_cidr" {
  type        = string
  description = "The range spoke VPCs are allocated from. Must not overlap the hub VPCs (10.100.0.0/16, 10.101.0.0/16)."
  default     = "10.0.0.0/9"
}

variable "spoke_netmask_length" {
  type        = number
  description = "Netmask length issued to each spoke. Fixed so every spoke is identical."
  default     = 16
}

variable "ram_principal_org_arn" {
  type        = string
  description = "AWS Organization ARN or OU ARN to share the spoke pool with."
  default     = ""
}

variable "enable_ram_share" {
  type        = bool
  description = "Whether to share the spoke pool via AWS RAM (disabled for standalone/sandbox accounts)."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Standard resource tags."
  default     = {}
}
