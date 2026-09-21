variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the Ingress VPC."
  default     = "10.101.0.0/16"
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
  description = "ARN of the Ingress Network Firewall policy."
}

variable "log_destination_bucket_arn" {
  type        = string
  description = "S3 bucket ARN for Network Firewall alert, flow, and TLS logs."
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming."
  default     = "hub-ingress"
}

variable "tags" {
  type        = map(string)
  description = "Standard resource tags."
  default     = {}
}

# --- Listener / target group ---

variable "listener_port" {
  type        = number
  description = "Port the public NLB listens on."
  default     = 443
}

variable "listener_protocol" {
  type        = string
  description = "NLB listener protocol: TCP or TLS. Use TLS to terminate with an ACM certificate."
  default     = "TCP"

  validation {
    condition     = contains(["TCP", "TLS"], var.listener_protocol)
    error_message = "listener_protocol must be TCP or TLS."
  }
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate ARN. Required when listener_protocol is TLS."
  default     = null
}

variable "ssl_policy" {
  type        = string
  description = "SSL policy for a TLS listener."
  default     = "ELBSecurityPolicy-TLS13-1-2-2021-06"
}

variable "target_port" {
  type        = number
  description = "Port the spoke-side targets listen on."
  default     = 443
}

variable "target_protocol" {
  type        = string
  description = "Target group protocol."
  default     = "TCP"
}

variable "target_ips" {
  type        = list(string)
  description = "Private IPs of spoke-side targets (typically the internal ALB ENIs), reached over the transit gateway."
  default     = []
}

variable "health_check_protocol" {
  type        = string
  description = "Health check protocol: TCP, HTTP or HTTPS."
  default     = "TCP"
}

variable "health_check_port" {
  type        = string
  description = "Health check port, or \"traffic-port\"."
  default     = "traffic-port"
}

variable "health_check_path" {
  type        = string
  description = "Health check path, used only for HTTP/HTTPS."
  default     = "/healthz"
}

variable "enable_tls_inspection" {
  type        = bool
  description = "Whether a TLS inspection configuration is attached to this firewall's policy. TLS logging is only emitted when this is true."
  default     = false
}
