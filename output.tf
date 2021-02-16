output "asg_name" {
  value = aws_autoscaling_group.iris.name
}

output "endpoint" {
  value = aws_lb.iris_alb.dns_name
}
