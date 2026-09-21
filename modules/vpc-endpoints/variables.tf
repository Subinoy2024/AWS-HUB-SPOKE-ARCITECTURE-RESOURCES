variable "vpc_id" {
  type        = string
  description = "The VPC ID where endpoints will be deployed."
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block of the VPC for security group ingress rules."
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of private application subnet IDs where interface endpoints will be deployed."
}

variable "route_table_ids" {
  type        = list(string)
  description = "List of route table IDs to associate with the S3 Gateway endpoint."
}

variable "organization_id" {
  type        = string
  description = "AWS Organization ID (e.g. o-xxxxxxxxx) for endpoint policies."
}

variable "name_prefix" {
  type        = string
  description = "Naming prefix for VPC endpoints."
  default     = "spoke-vpce"
}

variable "tags" {
  type        = map(string)
  description = "Standard resource tags."
  default     = {}
}
