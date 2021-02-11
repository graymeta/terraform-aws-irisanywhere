data "null_data_source" "tags" {
  count = length(keys(var.tags))

  inputs = {
    key                 = "${element(keys(var.tags), count.index)}"
    value               = "${element(values(var.tags), count.index)}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_group" "iris" {
  name                    = replace("${var.hostname_prefix}-${var.instance_type}", ".", "-")
  desired_capacity        = var.size_desired
  disable_api_termination = true
  max_size                = var.size_max
  min_size                = var.size_min
  vpc_zone_identifier     = var.subnet_id
  target_group_arns       = ["${aws_lb_target_group.port443.id}"]

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

resource "aws_launch_template" "iris" {
  name_prefix            = replace("${var.hostname_prefix}-${var.instance_type}", ".", "-")
  image_id               = coalesce(var.base_ami, data.aws_ami.GrayMeta-Iris-Anywhere.id)
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = ["${aws_security_group.iris.id}"]
  user_data              = ""

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
    tags          = var.tags
  }

  tag_specifications {
    resource_type = "volume"
    tags          = var.tags
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "out" {
  name                   = "${var.hostname_prefix}-ScaleOut"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = var.asg_scaleout_cooldown
  autoscaling_group_name = aws_autoscaling_group.iris.name
}

resource "aws_cloudwatch_metric_alarm" "out" {
  alarm_name          = "${var.hostname_prefix}-ScaleOut"
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
