resource "aws_lb" "irisadmin" {
  count                      = var.enterprise_ha ? 1 : 0
  enable_deletion_protection = false
  load_balancer_type         = "network"
  internal                   = var.enterprise_ha_lb_public ? false : true
  name_prefix                = "iadm-"
  subnets                    = var.subnet_id
  enable_cross_zone_load_balancing = true
  
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

resource "aws_route53_zone" "private" {
  count = var.create_private_hosted_zone && var.enterprise_ha ? 1 : 0
  name  = var.internal_domain

  vpc {
    vpc_id = data.aws_subnet.subnet.0.vpc_id
  }

  tags = merge(local.merged_tags, {
    "Name" = "${var.hostname_prefix}-internal-zone"
  })
}

# Find NLB's network interfaces
data "aws_network_interfaces" "nlb_enis" {
  count = var.create_private_hosted_zone && var.enterprise_ha ? 1 : 0
  
  filter {
    name   = "subnet-id"
    values = var.subnet_id
  }
  
  filter {
    name   = "description"
    values = ["ELB net/iadm-*"]
  }

  depends_on = [aws_lb.irisadmin]
}

# Get details of each NLB network interface
data "aws_network_interface" "nlb_eni_details" {
  count      = var.create_private_hosted_zone && var.enterprise_ha ? length(var.subnet_id) : 0
  id         = data.aws_network_interfaces.nlb_enis[0].ids[count.index]
  depends_on = [data.aws_network_interfaces.nlb_enis]
}

resource "aws_route53_record" "nlb_internal" {
  count   = var.create_private_hosted_zone && var.enterprise_ha ? 1 : 0
  zone_id = aws_route53_zone.private.0.zone_id
  name    = "nlb.${var.internal_domain}"
  type    = "A"
  ttl     = 60
  records = [for eni in data.aws_network_interface.nlb_eni_details : eni.private_ip]
}