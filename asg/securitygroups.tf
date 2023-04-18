data "aws_subnet" "subnet" {
  count = length(var.subnet_id)
  id    = element(var.subnet_id, count.index)
}

resource "aws_security_group" "alb" {
  name_prefix = replace("${var.hostname_prefix}-${var.instance_type}-alb", ".", "")
  description = replace("${var.hostname_prefix}-${var.instance_type}-alb", ".", "")
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  tags = merge(
    local.merged_tags, {
    "Name" = replace("${var.hostname_prefix}-${var.instance_type}-alb", ".", "") }
  )
}

resource "aws_security_group_rule" "alb_egress" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_port80" {
  security_group_id = aws_security_group.alb.id
  description       = "alb_port80"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.access_cidr
}

resource "aws_security_group_rule" "alb_port443" {
  security_group_id = aws_security_group.alb.id
  description       = "alb_port443"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.access_cidr
}

resource "aws_security_group" "iris" {
  name_prefix = replace("${var.hostname_prefix}-${var.instance_type}-iris", ".", "")
  description = replace("${var.hostname_prefix}-${var.instance_type}-iris", ".", "")
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  tags = merge(
    local.merged_tags, {
    "Name" = replace("${var.hostname_prefix}-${var.instance_type}-iris", ".", "") }
  )
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.iris.id
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "iris_rdp" {
  security_group_id = aws_security_group.iris.id
  description       = "iris_port3389"
  type              = "ingress"
  from_port         = 3389
  to_port           = 3389
  protocol          = "tcp"
  cidr_blocks       = var.rdp_access_cidr
}

resource "aws_security_group_rule" "iris_health" {
  security_group_id        = aws_security_group.iris.id
  description              = "iris_port9000"
  type                     = "ingress"
  from_port                = 9000
  to_port                  = 9000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "iris_8080" {
  count                    = var.ia_cert_key_arn != "" ? 0 : 1
  security_group_id        = aws_security_group.iris.id
  description              = "iris_port8080"
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = var.haproxy == true ? aws_security_group.ha[0].id : aws_security_group.alb.id
}

resource "aws_security_group_rule" "iris_443" {
  count                    = var.ia_cert_key_arn != "" ? 1 : 0
  security_group_id        = aws_security_group.iris.id
  description              = "iris_port443"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  source_security_group_id = var.haproxy == true ? aws_security_group.ha[0].id : aws_security_group.alb.id


}

resource "aws_security_group_rule" "iris_udp" {
  security_group_id = aws_security_group.iris.id
  description       = "iris_udp"
  type              = "ingress"
  from_port         = 53000
  to_port           = 53400
  protocol          = "udp"
  cidr_blocks       = var.access_cidr
}
