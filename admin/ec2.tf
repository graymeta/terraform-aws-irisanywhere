# userdata powershell

resource "aws_instance" "iris_admin" {
  ami                  = coalesce(var.ami, path.root.data.aws_ami.GrayMeta-Iris-Anywhere.id)
  iam_instance_profile = var.instance_profile
  instance_type        = var.instance_type
  key_name             = var.key_name
  security_groups      = [var.security_groups]
  subnet_id            = var.subnet_id
  user_data            = base64encode(data.template_file.cloud_init.rendered)

  lifecycle {
    ignore_changes = [
      "ami",
      "ebs_optimized",
      "instance_type",
      "key_name",
      "root_block_device",
      "user_data",
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
