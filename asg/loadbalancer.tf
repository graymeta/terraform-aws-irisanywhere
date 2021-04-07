resource "aws_lb" "iris_alb" {
  name_prefix                = substr(replace("${var.hostname_prefix}-${var.instance_type}-alb", ".", ""), 0, 6)
  internal                   = var.alb_internal
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.subnet_id
  enable_deletion_protection = false

  tags = merge(
    local.merged_tags,
    map("Name", replace("${var.hostname_prefix}-${var.instance_type}-alb", ".", ""))
  )
}

resource "aws_lb_listener" "port80" {
  load_balancer_arn = aws_lb.iris_alb.arn
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
  load_balancer_arn = aws_lb.iris_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = var.ssl_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.port443.arn
  }
}

resource "aws_lb_target_group" "port443" {
  name_prefix = substr(replace("${var.hostname_prefix}-${var.instance_type}-ScaleIn", ".", ""), 0, 6)
  port        = var.ia_cert_key_arn != "" ? "443" : "8080"
  protocol    = var.ia_cert_key_arn != "" ? "HTTPS" : "HTTP"
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  load_balancing_algorithm_type = var.lb_algorithm_type

  health_check {
    path                = "/"
    port                = "9000"
    interval            = var.lb_check_interval
    timeout             = 5
    protocol            = "HTTP"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = var.lb_unhealthy_threshold
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 1800
    enabled         = true
  }

  tags = local.merged_tags
}

resource "aws_lb_listener_rule" "port443" {
  listener_arn = aws_lb_listener.port443.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.port443.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}
