resource "aws_security_group" "iris_admin" {
  name_prefix = "iris-admin-nsg"
  description = "iris-admin-nsg"

  tags = {
    Source = "terraform"
  }
}

# Allow all outbound traffic
resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.iris_admin.id
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow RDP inbound traffic
resource "aws_security_group_rule" "allow_rdp" {
  security_group_id = aws_security_group.iris_admin.id
  description       = "Allow RDP"
  type              = "ingress"
  from_port         = "3389"
  to_port           = "3389"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
