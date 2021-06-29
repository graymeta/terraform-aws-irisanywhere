data "aws_subnet" "subnet" {
  count = "${length(var.subnet_id)}"
  id    = "${element(var.subnet_id, count.index)}"
}

resource "aws_security_group" "iris_adm" {
  name_prefix = replace("${var.hostname_prefix}-${var.instance_type}-iris-admin", ".", "")
  description = replace("${var.hostname_prefix}-${var.instance_type}-iris-admin", ".", "")
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  tags = merge(
    local.merged_tags,
    map("Name", format("${var.hostname_prefix}-iris-admin"))
  )
}

# Allow all outbound traffic
resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow RDP inbound traffic
resource "aws_security_group_rule" "allow_rdp" {
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow RDP"
  type              = "ingress"
  from_port         = "3389"
  to_port           = "3389"
  protocol          = "tcp"
  cidr_blocks       = var.access_cidr
}

# Allow Postgres inbound traffic
resource "aws_security_group_rule" "allow_postgresql" {
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow Postgresql"
  type              = "ingress"
  from_port         = "5432"
  to_port           = "5432"
  protocol          = "tcp"
  cidr_blocks       = var.access_cidr
}

# Allow Postgres inbound traffic
resource "aws_security_group_rule" "allow_8020" {
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow 8020"
  type              = "ingress"
  from_port         = "8020"
  to_port           = "8020"
  protocol          = "tcp"
  cidr_blocks       = var.access_cidr
}

# Allow Postgres inbound traffic
resource "aws_security_group_rule" "allow_8021" {
  security_group_id = aws_security_group.iris_adm.id
  description       = "Allow 8021"
  type              = "ingress"
  from_port         = "8021"
  to_port           = "8021"
  protocol          = "tcp"
  cidr_blocks       = var.access_cidr
}