data "template_file" "cloud_init" {
  template = file("${path.module}/cloud_init.ps1")
}

resource "aws_instance" "iris_admin" {
  ami                  = coalesce(var.ami, data.aws_ami.GrayMeta-Iris-Anywhere.id)
  iam_instance_profile = aws_iam_instance_profile.iris_admin.name
  instance_type        = var.instance_type
  key_name             = var.key_name
  security_groups      = [aws_security_group.iris_admin.id]
  subnet_id            = var.subnet_id
  user_data            = base64encode(data.template_file.cloud_init.rendered)

  lifecycle {
    ignore_changes = [
      ami,
      ebs_optimized,
      instance_type,
      key_name,
      root_block_device,
      user_data
    ]
  }

  tags = local.merged_tags

  volume_tags = local.merged_tags

  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = "true"
  }

}

# Create instance profile
resource "aws_iam_instance_profile" "iris_admin" {
  name = "iris_admin"
  role = aws_iam_role.iris_admin_role.name
}

resource "aws_iam_role" "iris_admin_role" {
  name = "iris_admin_role"

  assume_role_policy = file("${path.module}/admin_role.json")
}

# Create the security group
resource "aws_security_group" "iris_admin" {
  name_prefix = "iris-admnin-nsg"
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
resource "aws_security_group_rule" "allowd_rdp" {
  security_group_id = aws_security_group.iris_admin.id
  description       = "Allow RDP"
  type              = "ingress"
  from_port         = "3389"
  to_port           = "3389"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}
