resource "aws_instance" "iris_adm" {
  ami                    = coalesce(var.ami, data.aws_ami.GrayMeta-Iris-Admin.id)
  count                  = var.instance_count
  iam_instance_profile   = aws_iam_instance_profile.iris_adm.name
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.iris_adm.id]
  subnet_id              = element(var.subnet_id, count.index)

  associate_public_ip_address = var.associate_public_ip
  disable_api_termination     = var.instance_protection ? true : false

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ami,
      ebs_optimized,
      instance_type,
      key_name,
      root_block_device,
      tags,
    ]
  }

  tags = merge(local.merged_tags, {
    "Name" = format(
      "${var.hostname_prefix}-%s-iris-admin-%02d",
      var.deployment_name != "1" ? var.deployment_name : var.instance_type,
      count.index + 1
  ) })

  volume_tags = merge(local.merged_tags, {
  "Name" = format("${var.hostname_prefix}-%02d", count.index + 1) })

  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = "true"
  }

  depends_on = [
    aws_db_instance.default
  ]
}

resource "aws_ssm_association" "iris_admin_install" {
  name                             = "AWS-RunPowerShellScript"
  association_name                 = replace("${var.hostname_prefix}-${var.deployment_name}-iris-admin-install", ".", "-")
  apply_only_at_cron_interval      = false
  wait_for_success_timeout_seconds = 3600
  max_concurrency                  = "1"
  max_errors                       = "0"

  parameters = {
    commands = templatefile("${path.module}/cloud_init.ps1", {
      ia_secret_arn      = var.ia_secret_arn
      enterprise_ha      = var.enterprise_ha
      dbserver           = var.enterprise_ha && var.create_rds ? element(split(":", aws_db_instance.default[0].endpoint), 0) : ""
      https_console_port = var.https_console_port
      http_console_port  = var.http_console_port
      iris_admin_ver     = var.iris_admin_ver
    })
  }

  targets {
    key    = "InstanceIds"
    values = aws_instance.iris_adm[*].id
  }

  depends_on = [aws_instance.iris_adm]
}

