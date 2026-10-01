output "address" {
  value       = aws_db_instance.this.address
  description = "Database hostname; use as db_endpoint in the admin module."
}

output "identifier" {
  value = aws_db_instance.this.identifier
}

output "security_group_id" {
  value = aws_security_group.this.id
}
