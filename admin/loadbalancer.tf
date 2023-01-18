resource "aws_lb" "irisadmin" {
  count                      = var.enterprise_ha ? 1 : 0
  enable_deletion_protection = false
  load_balancer_type         = "network"
  name_prefix                = "iadm-"
  subnets                    = var.subnet_id

  tags = {
    Name            = "IrisAdmin-LB"
    ApplicationName = "IrisAdmin"
  }
}

resource "aws_lb_listener" "porthttps" {
  count             = var.enterprise_ha ? 1 : 0
  load_balancer_arn = aws_lb.irisadmin.0.arn
  port              = var.https_console_port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.iadm.0.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "port5432" {
  count             = var.enterprise_ha ? 1 : 0
  load_balancer_arn = aws_lb.irisadmin.0.arn
  port              = "5432"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.iadm.0.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "iadm" {
  count       = var.enterprise_ha ? 1 : 0
  name_prefix = "iadm"
  port        = var.https_console_port
  protocol    = "TCP"
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  health_check {
    healthy_threshold   = 3
    interval            = 10
    port                = var.https_console_port
    protocol            = "TCP"
    unhealthy_threshold = 3
  }

}

#Instance Attachment
resource "aws_alb_target_group_attachment" "instance_attach" {
  count            = length(aws_instance.iris_adm.*.id) == 2 ? 2 : 0
  target_group_arn = aws_lb_target_group.iadm.0.arn
  target_id        = element(aws_instance.iris_adm.*.id, count.index)
  port             = var.https_console_port
}
