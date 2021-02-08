resource "aws_lb" "iris_alb" {
  name_prefix                = "iris-"
  internal                   = false
  security_groups            = ["${aws_security_group.iris.id}"]
  subnets                    = "${var.subnet_id}"
  enable_deletion_protection = false

  tags {
    Name               = "Iris-${var.hostname_prefix}-ALB"
  }
}

resource "aws_lb_listener" "port80" {
  load_balancer_arn = "${aws_lb.iris_alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "port443" {
  load_balancer_arn = "${aws_lb.iris_alb.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${var.ssl_certificate_arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.port443.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "port443" {
  name_prefix = "iris-"
  port        = "443"
  protocol    = "HTTP"
  vpc_id      = "${data.aws_subnet.subnet.0.vpc_id}"

  health_check {
    path                = "/healthz"
    interval            = 30
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags {}
}

resource "aws_lb_listener_rule" "port443" {
  listener_arn = "${aws_lb_listener.port443.arn}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.port443.arn}"
  }

  condition {
    field  = "path-pattern"
    values = ["/"]
  }
}
