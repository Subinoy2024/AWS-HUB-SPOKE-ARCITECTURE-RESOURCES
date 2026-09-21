variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the Inspection VPC."
  default     = "10.100.0.0/16"
}

variable "az_names" {
  type        = list(string)
  description = "List of exactly 2 availability zone names (e.g. ['us-east-1a', 'us-east-1b'])."

  validation {
    condition     = length(var.az_names) == 2
    error_message = "Exactly 2 availability zones must be specified."
  }
}

variable "transit_gateway_id" {
  type        = string
  description = "Transit Gateway ID for the attachment."
}

variable "firewall_policy_arn" {
  type        = string
  description = "ARN of the Inspection Network Firewall policy."
}

variable "log_destination_bucket_arn" {
  type        = string
  description = "S3 bucket ARN for Network Firewall alert, flow, and TLS logs."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming."
  default     = "hub-inspection"
}

variable "tags" {
  type        = map(string)
  description = "Standard resource tags."
  default     = {}
}

variable "enable_tls_inspection" {
  type        = bool
  description = "Whether a TLS inspection configuration is attached to this firewall's policy. TLS logging is only emitted when this is true."
  default     = false
}
