data "null_data_source" "tags" {
  count = length(keys(local.merged_tags))

  inputs = {
    key                 = "${element(keys(local.merged_tags), count.index)}"
    value               = "${element(values(local.merged_tags), count.index)}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "iris" {
  name                  = replace("${var.hostname_prefix}-${var.instance_type}", ".", "")
  desired_capacity      = var.asg_size_desired
  max_size              = var.asg_size_max
  min_size              = var.asg_size_min
  protect_from_scale_in = true
  vpc_zone_identifier   = var.subnet_id
  target_group_arns     = ["${aws_lb_target_group.port443.id}"]

  warm_pool {
    pool_state                  = "Stopped"
    min_size                    = var.asg_size_max - (var.asg_size_max - 1)
    max_group_prepared_capacity = var.asg_size_max - (var.asg_size_max - 1)
  }

  launch_template {
    id      = aws_launch_template.iris.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupPendingCapacity",
    "GroupMinSize",
    "GroupMaxSize",
    "GroupInServiceInstances",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupStandbyCapacity",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
  ]

  tags = flatten(["${data.null_data_source.tags.*.outputs}"])

  lifecycle {
    ignore_changes = [
      desired_capacity,
    ]
  }
}

data "template_file" "cloud_init" {
  template = file("${path.module}/cloud_init.ps1")

  vars = {
    name                  = replace("${var.hostname_prefix}-${var.instance_type}", ".", "")
    metric_check_interval = var.asg_check_interval
    health_check_interval = var.lb_check_interval
    unhealthy_threshold   = var.lb_unhealthy_threshold
    cooldown              = var.asg_scalein_cooldown
    ia_cert_crt_arn       = var.ia_cert_crt_arn
    ia_cert_key_arn       = var.ia_cert_key_arn
    ia_max_sessions       = var.ia_max_sessions
    ia_secret_arn         = var.ia_secret_arn
    ia_domain             = var.ia_domain
    search_enabled        = var.search_enabled
    s3_sse_cmk_enabled    = var.s3_sse_cmk_enabled
    s3_sse_cmk_arn        = var.s3_sse_cmk_arn
  }
}

resource "aws_launch_template" "iris" {
  name_prefix   = replace("${var.hostname_prefix}-${var.instance_type}", ".", "")
  image_id      = coalesce(var.base_ami, data.aws_ami.GrayMeta-Iris-Anywhere.id)
  instance_type = var.instance_type
  key_name      = var.key_name
  user_data     = base64encode(join("\n", ["<powershell>", "${data.template_file.cloud_init.rendered}", "${var.user_init}", "\n", "Restart-Computer -Force", "\n", "</powershell>"]))
  ebs_optimized = true

  iam_instance_profile {
    name = aws_iam_instance_profile.iris.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = var.disk_os_type
      volume_size           = var.disk_os_size
      encrypted             = true
      delete_on_termination = "true"
    }
  }

  block_device_mappings {
    device_name = "/dev/sda2"

    ebs {
      volume_type           = var.disk_data_type
      volume_size           = var.disk_data_size
      iops                  = var.disk_data_iops
      encrypted             = true
      delete_on_termination = "true"
    }
  }

  network_interfaces {
    associate_public_ip_address = var.alb_internal ? false : true
    security_groups             = [aws_security_group.iris.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags          = local.merged_tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = local.merged_tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "out" {
  name                   = replace("${var.hostname_prefix}-${var.instance_type}-ScaleOut", ".", "")
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.asg_scaleout_cooldown
  autoscaling_group_name = aws_autoscaling_group.iris.name
}

resource "aws_cloudwatch_metric_alarm" "out" {
  alarm_name          = replace("${var.hostname_prefix}-${var.instance_type}-ScaleOut", ".", "")
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = var.asg_scaleout_evaluation
  metric_name         = "IrisAvailableSessions"
  namespace           = "AWS/EC2"
  period              = var.asg_check_interval
  statistic           = "Sum"
  threshold           = var.asg_scaleout_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.iris.name
  }

  alarm_description = "This metric monitors iris anywhere available sessions"
  alarm_actions     = [aws_autoscaling_policy.out.arn]
}

resource "aws_autoscaling_policy" "in" {
  name                   = replace("${var.hostname_prefix}-${var.instance_type}-ScaleIn", ".", "")
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.asg_scalein_cooldown
  autoscaling_group_name = aws_autoscaling_group.iris.name
}

resource "aws_cloudwatch_metric_alarm" "in" {
  alarm_name          = replace("${var.hostname_prefix}-${var.instance_type}-ScaleIn", ".", "")
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.asg_scalein_evaluation
  metric_name         = "IrisAvailableSessions"
  namespace           = "AWS/EC2"
  period              = var.asg_check_interval
  statistic           = "Sum"
  threshold           = var.asg_scalein_threshold

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.iris.name
  }

  alarm_description = "This metric monitors iris anywhere available sessions"
  alarm_actions     = [aws_autoscaling_policy.in.arn]
}