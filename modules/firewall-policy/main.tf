# --- Shared Rule Groups ---

# Shared Suricata IPS Rule Group for common exploits and malware C2 detection
resource "aws_networkfirewall_rule_group" "shared_threat_ips" {
  capacity = 500
  name     = "${var.name_prefix}-shared-threat-ips"
  type     = "STATEFUL"

  rule_group {
    rules_source {
      rules_string = <<EOF
drop tcp any any -> any any (msg:"DROP known exploit attempt"; flow:to_server,established; content:"/etc/passwd"; nocase; sid:1000001; rev:1;)
drop tcp any any -> any any (msg:"DROP reverse shell attempt"; flow:to_server,established; content:"/bin/sh"; nocase; sid:1000002; rev:1;)
EOF
    }
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-shared-threat-ips"
    }
  )
}

# --- Egress / Inspection Specific Rule Groups ---

# Domain filtering rule group for egress and exfiltration control
resource "aws_networkfirewall_rule_group" "egress_domain_filter" {
  capacity = 500
  name     = "${var.name_prefix}-egress-domain-filter"
  type     = "STATEFUL"

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = ["10.0.0.0/8"]
        }
      }
    }
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["TLS_SNI", "HTTP_HOST"]
        targets              = var.blocked_domains
      }
    }
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-egress-domain-filter"
    }
  )
}

# --- Ingress Specific Rule Groups ---

# Ingress port and protocol filtering
resource "aws_networkfirewall_rule_group" "ingress_strict_filter" {
  capacity = 500
  name     = "${var.name_prefix}-ingress-strict-filter"
  type     = "STATEFUL"

  rule_group {
    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
    rules_source {
      stateful_rule {
        action = "PASS"
        header {
          direction        = "FORWARD"
          protocol         = "TCP"
          source           = "ANY"
          source_port      = "ANY"
          destination      = "10.101.0.0/16"
          destination_port = "443"
        }
        rule_option {
          keyword = "sid:2000001"
        }
      }
      stateful_rule {
        action = "PASS"
        header {
          direction        = "FORWARD"
          protocol         = "TCP"
          source           = "ANY"
          source_port      = "ANY"
          destination      = "10.101.0.0/16"
          destination_port = "80"
        }
        rule_option {
          keyword = "sid:2000002"
        }
      }
      stateful_rule {
        action = "DROP"
        header {
          direction        = "FORWARD"
          protocol         = "IP"
          source           = "ANY"
          source_port      = "ANY"
          destination      = "10.101.0.0/16"
          destination_port = "ANY"
        }
        rule_option {
          keyword = "sid:2000003"
        }
      }
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ingress-strict-filter"
    }
  )
}

# --- Policies ---

# 1. Ingress Firewall Policy
resource "aws_networkfirewall_firewall_policy" "ingress" {
  name = "${var.name_prefix}-ingress-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    # Reference shared rule group first, then ingress specific
    stateful_rule_group_reference {
      priority     = 10
      resource_arn = aws_networkfirewall_rule_group.shared_threat_ips.arn
    }

    stateful_rule_group_reference {
      priority     = 20
      resource_arn = aws_networkfirewall_rule_group.ingress_strict_filter.arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-ingress-policy"
    }
  )
}

# 2. Inspection (Egress / East-West) Firewall Policy
resource "aws_networkfirewall_firewall_policy" "inspection" {
  name = "${var.name_prefix}-inspection-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    # Reference shared rule group first, then egress domain filter
    stateful_rule_group_reference {
      priority     = 10
      resource_arn = aws_networkfirewall_rule_group.shared_threat_ips.arn
    }

    stateful_rule_group_reference {
      priority     = 20
      resource_arn = aws_networkfirewall_rule_group.egress_domain_filter.arn
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-inspection-policy"
    }
  )
}
