data "aws_region" "current" {}

# Security group for interface endpoints
resource "aws_security_group" "endpoints" {
  name        = "${var.name_prefix}-sg"
  description = "Security group for private VPC Interface Endpoints"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow TLS from spoke VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-sg"
    }
  )
}

# Strict IAM Policy locking interface endpoints to principals within the AWS Organization
data "aws_iam_policy_document" "org_only_endpoint_policy" {
  statement {
    sid       = "AllowOrgPrincipalsOnly"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalOrgID"
      values   = [var.organization_id]
    }
  }
}

# 1. S3 Gateway Endpoint (Free, route table driven - non-negotiable rule 10)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = var.route_table_ids

  policy = data.aws_iam_policy_document.org_only_endpoint_policy.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-s3-gw"
      Tier = "gateway"
    }
  )
}

# 2. Interface Endpoints (with aws:PrincipalOrgID enforcement)
locals {
  interface_services = toset([
    "ecr.api",
    "ecr.dkr",
    "ssm",
    "ssmmessages",
    "ec2messages",
    "secretsmanager"
  ])
}

resource "aws_vpc_endpoint" "interfaces" {
  for_each = local.interface_services

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.subnet_ids
  security_group_ids  = [aws_security_group.endpoints.id]
  private_dns_enabled = true

  policy = data.aws_iam_policy_document.org_only_endpoint_policy.json

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-${replace(each.value, ".", "-")}"
      Tier = "interface"
    }
  )
}
