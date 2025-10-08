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

output "haproxy_certificate_secret_arn" {
  description = "The ARN of the PEM certificate secret in AWS Secrets Manager"
  value       = "COPY this ARN and place in your iris anywhere root module as the value for variable 'ssl_haproxy_cert_secret_arn':  ${aws_secretsmanager_secret.cert_secret.arn}"
}