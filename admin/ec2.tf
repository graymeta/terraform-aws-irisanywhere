data "template_file" "cloud_init" {
  template = file("${path.module}/cloud_init.ps1")

  vars = {
    ia_secret_arn = var.ia_secret_arn
  }
}

resource "aws_instance" "iris_adm" {
  ami                    = coalesce(var.ami, data.aws_ami.GrayMeta-Iris-Admin.id)
  count                  = var.instance_count
  iam_instance_profile   = aws_iam_instance_profile.iris_adm.name
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.iris_adm.id]
  subnet_id              = element(var.subnet_id, count.index)
  user_data              = base64encode(data.template_file.cloud_init.rendered)
  associate_public_ip_address = var.associate_public_ip

  disable_api_termination = var.instance_protection ? true : false

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ami,
      ebs_optimized,
      instance_type,
      key_name,
      root_block_device,
      user_data
    ]
  }

  tags = merge(
    map("Name", format("${var.hostname_prefix}-%02d", count.index + 1)),
    local.merged_tags
  )

  volume_tags = merge(
    map("Name", format("${var.hostname_prefix}-%02d", count.index + 1)),
    local.merged_tags
  )

  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = "true"
  }
}

