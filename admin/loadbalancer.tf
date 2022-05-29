resource "aws_lb" "irisadmin" {
  enable_deletion_protection = false
  load_balancer_type         = "network"
  name_prefix                = "iadm-"
  subnets                    = var.subnet_id

  tags = {
    Name            = "IrisAdmin-LB"
    ApplicationName = "IrisAdmin"
  }
}

resource "aws_lb_listener" "port8021" {
  load_balancer_arn = aws_lb.irisadmin.arn
  port              = "8021"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.iadm.arn
    type             = "forward"
  }
}

resource "aws_lb_listener" "port5432" {
  load_balancer_arn = aws_lb.irisadmin.arn
  port              = "5432"
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.iadm.arn
    type             = "forward"
  }
}

resource "aws_lb_target_group" "iadm" {
  name_prefix = "iadm"
  port        = "8021"
  protocol    = "TCP"
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  health_check {
    healthy_threshold   = 3
    interval            = 10
    port                = "8021"
    protocol            = "TCP"
    unhealthy_threshold = 3
  }

}

#Instance Attachment
resource "aws_alb_target_group_attachment" "instance_attach" {
  target_group_arn = aws_lb_target_group.iadm.arn
  count            = length(aws_instance.iris_adm.*.id)
  target_id        = element(aws_instance.iris_adm.*.id, count.index)
  port             = 8021
}