variable "name_prefix" {
  type        = string
  description = "Name prefix for firewall policies and rule groups."
  default     = "hub-netfw"
}

variable "allowed_domains" {
  type        = list(string)
  description = "List of allowed domains for egress HTTP/HTTPS inspection."
  default = [
    ".amazonaws.com",
    ".github.com",
    ".githubusercontent.com"
  ]
}

variable "blocked_domains" {
  type        = list(string)
  description = "List of explicitly denied domains for egress inspection."
  default = [
    ".badsite.example",
    ".malware-c2.example"
  ]
}

variable "log_destination_bucket_arn" {
  type        = string
  description = "S3 bucket ARN in the log archive account for storing Alert, Flow, and TLS logs."
}

variable "tags" {
  type        = map(string)
  description = "Standard resource tags."
  default     = {}
}
