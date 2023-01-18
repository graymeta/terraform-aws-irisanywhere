output "security_group" {
  value = aws_security_group.iris_adm.id
}

output "private_dns" {
  value = aws_instance.iris_adm.*.private_dns
}

output "private_ip" {
  value = aws_instance.iris_adm.*.private_ip
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer."
  value       = aws_lb.irisadmin.*.dns_name
}

output "alb_dns_name_none" {
  description = "The DNS name of the load balancer."
  value       = join("", aws_lb.irisadmin.*.dns_name)
}

