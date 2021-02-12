data "aws_subnet" "subnet" {
  count = length(var.subnet_id)
  id    = element(var.subnet_id, count.index)
}

resource "aws_security_group" "iris" {
  name_prefix = "${var.hostname_prefix}-nsg"
  description = "${var.hostname_prefix}-nsg"
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  tags = merge(
    map("source", "terraform"),
    map("Name", "${var.hostname_prefix}-nsg"),
    var.tags
  )
}

# Allow all outbound traffic
resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.iris.id
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# TODO: Limit this down to what we need.....
resource "aws_security_group_rule" "allow_all_traffic" {
  security_group_id = aws_security_group.iris.id
  description       = "Same Subnet"
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}