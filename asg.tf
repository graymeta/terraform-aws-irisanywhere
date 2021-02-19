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
  desired_capacity      = var.size_desired
  max_size              = var.size_max
  min_size              = var.size_min
  protect_from_scale_in = true
  vpc_zone_identifier   = var.subnet_id
  target_group_arns     = ["${aws_lb_target_group.port443.id}"]

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
    metric_check_interval = var.asg_check_interval
    health_check_interval = var.lb_check_interval
    unhealthy_threshold   = var.lb_unhealthy_threshold
    cooldown              = var.asg_scalein_cooldown
    tfliccontent          = var.tfliccontent
    tfcertfile            = var.tfcertfile
    tfcertkeycontent      = var.tfcertkeycontent
    tfS3ConnID            = var.tfS3ConnID
    tfS3ConnPW            = var.tfS3ConnPW
    tfcustomerID          = var.tfcustomerID
    tfadminserver         = var.tfadminserver
    tfserviceacct         = var.tfserviceacct
    tfbucketname          = var.tfbucketname
    tfAccecssKey          = var.tfAccecssKey
    tfSecretKey           = var.tfSecretKey

  }
}

resource "aws_launch_template" "iris" {
  name_prefix            = replace("${var.hostname_prefix}-${var.instance_type}", ".", "")
  image_id               = coalesce(var.base_ami, data.aws_ami.GrayMeta-Iris-Anywhere.id)
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.iris.id]
  user_data              = base64encode(data.template_file.cloud_init.rendered)

  iam_instance_profile {
    name = aws_iam_instance_profile.iris.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = var.os_disk_type
      volume_size           = var.os_disk_size
      delete_on_termination = "true"
    }
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
