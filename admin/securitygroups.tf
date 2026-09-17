data "aws_subnet" "subnet" {
  count = length(var.subnet_id)
  id    = element(var.subnet_id, count.index)
}

resource "aws_security_group" "iris_adm" {
  name_prefix = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-iris-admin", ".", "")
  description = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-iris-admin", ".", "")
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  tags = merge(local.merged_tags, {
  "Name" = "${var.hostname_prefix}${var.deployment_name != "1" ? "-${var.deployment_name}" : ""}-iris-admin" })
}

locals {
  nlb_private_cidr_blocks = var.enterprise_ha ? formatlist("%s/32", data.aws_network_interface.nlb_eni_details[*].private_ip) : []
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "egress" {
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# Allow RDP inbound traffic
resource "aws_vpc_security_group_ingress_rule" "allow_rdp" {
  for_each          = var.disable_rdp ? toset([]) : toset(var.rdp_access_cidr)
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow RDP"
  from_port         = 3389
  to_port           = 3389
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

# Allow Postgres inbound traffic
resource "aws_vpc_security_group_ingress_rule" "allow_postgresql" {
  for_each          = toset(var.api_console_access_cidr)
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow Postgresql"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}


# Allow HTTPS inbound traffic
resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  for_each = merge(
    { for index, cidr in var.api_console_access_cidr : "api-${index}" => cidr },
    { for index, cidr in local.nlb_private_cidr_blocks : "nlb-${index}" => cidr },
  )
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow Https"
  from_port         = var.https_console_port
  to_port           = var.https_console_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}
