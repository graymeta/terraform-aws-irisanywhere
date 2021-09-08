data "aws_region" "current" {}

data "template_file" "dashboard" {
  template = file("${path.module}/dashboard.json")

  vars = {
    region                 = data.aws_region.current.name
    asg_name               = aws_autoscaling_group.iris.name
    asg_check_interval     = var.asg_check_interval
    asg_scalein_threshold  = var.asg_scalein_threshold
    asg_scaleout_threshold = var.asg_scaleout_threshold
  }
}

resource "aws_cloudwatch_dashboard" "dashboard" {
  dashboard_name = replace("${var.hostname_prefix}-${var.instance_type}", ".", "")
  dashboard_body = data.template_file.dashboard.rendered
}