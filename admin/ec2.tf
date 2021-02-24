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
