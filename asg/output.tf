output "alb_dns_name" {
  description = "The DNS name of the load balancer."
  #  value       = aws_lb.iris_alb[0].dns_name
  value = var.haproxy == true ? null : aws_lb.iris_alb[0].dns_name
}

output "asg_name" {
  description = "The autoscaling group name"
  value       = aws_autoscaling_group.iris.name
}

output "nsg_alb_id" {
  description = "Network Security Group for ALB"
  value       = aws_security_group.alb.id
}

output "nsg_iris_id" {
  description = "Network Security Group for ASG instances"
  value       = aws_security_group.iris.id
}

output "access_cidr" {
  value = var.access_cidr
}

output "asg_check_interval" {
  value = var.asg_check_interval
}

output "asg_scalein_cooldown" {
  value = var.asg_scalein_cooldown
}

output "asg_scalein_evaluation" {
  value = var.asg_scalein_evaluation
}

output "asg_scalein_threshold" {
  value = var.asg_scalein_threshold
}

output "asg_scaleout_cooldown" {
  value = var.asg_scaleout_cooldown
}

output "asg_scaleout_evaluation" {
  value = var.asg_scaleout_evaluation
}

output "asg_scaleout_threshold" {
  value = var.asg_scaleout_threshold
}

output "asg_size_desired" {
  value = var.asg_size_desired
}

output "asg_size_max" {
  value = var.asg_size_max
}

output "asg_size_min" {
  value = var.asg_size_min
}

output "base_ami" {
  value = coalesce(var.base_ami, data.aws_ami.GrayMeta-Iris-Anywhere.id)
}

output "disk_data_size" {
  value = var.disk_data_size
}

output "disk_data_type" {
  value = var.disk_data_type
}

output "disk_os_size" {
  value = var.disk_os_size
}

output "disk_os_type" {
  value = var.disk_os_type
}

output "ha_proxy_instance_id" {
  value = var.haproxy == true ? aws_instance.ha[0].id : null
}

output "hostname_prefix" {
  value = var.hostname_prefix
}

output "instance_type" {
  value = var.instance_type
}

output "key_name" {
  value = var.key_name
}

output "lb_check_interval" {
  value = var.lb_check_interval
}

output "lb_unhealthy_threshold" {
  value = var.lb_unhealthy_threshold
}

output "ssl_certificate_arn" {
  value = var.ssl_certificate_arn
}

output "subnet_id" {
  value = var.subnet_id
}

output "tags" {
  value = var.tags
}
