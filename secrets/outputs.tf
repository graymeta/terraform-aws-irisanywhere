output "arn" {
  description = "AWS SecretManager Secret ARN"
  value       = aws_secretsmanager_secret.iris_config.arn
}

output "secret" {
  description = "AWS SecretManager Secret resource"
  value       = aws_secretsmanager_secret.iris_config
}

output "secret_payload" {
  description = "AWS SecretManager Secret Version resource"
  value       = aws_secretsmanager_secret_version.iris_config.secret_string
  sensitive   = true
}
