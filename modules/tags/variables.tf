variable "environment" {
  type        = string
  description = "Deployment environment name (e.g. prod, staging, dev)."

  validation {
    condition     = can(regex("^(prod|staging|dev|sandbox|hub)$", var.environment))
    error_message = "Environment must be one of: prod, staging, dev, sandbox, hub."
  }
}

variable "owner" {
  type        = string
  description = "Team or individual owner of the resource."
}

variable "cost_center" {
  type        = string
  description = "Cost center identifier for financial billing and chargeback."
}

variable "extra_tags" {
  type        = map(string)
  description = "Optional additional tags to merge with standard tags."
  default     = {}
}
