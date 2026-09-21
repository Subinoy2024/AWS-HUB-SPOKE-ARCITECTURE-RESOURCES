variable "name" {
  type        = string
  description = "Name prefix for the Transit Gateway and associated resources."
  default     = "hub-tgw"
}

variable "amazon_side_asn" {
  type        = number
  description = "Private Autonomous System Number (ASN) for the Transit Gateway."
  default     = 64512
}

variable "ram_principal_org_arn" {
  type        = string
  description = "AWS Organization ARN or Organizational Unit ARN for RAM resource sharing."
  default     = ""
}

variable "enable_ram_share" {
  type        = bool
  description = "Whether to create RAM resource share for TGW (set to false in standalone accounts where RAM is restricted by SCP)."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Standard resource tags."
  default     = {}
}
