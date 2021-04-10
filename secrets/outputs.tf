output "secrets" {
  description = "Iris Secrets"
  value       = aws_secretsmanager_secret_version.iris_values.secret_string
}

output "admin_customer_id" {
  description = "Iris Secrets"
  value       = var.admin_customer_id
}

output "admin_db_id" {
  description = "Iris Secrets"
  value       = var.admin_db_id
}

output "admin_db_pw" {
  description = "Iris Secrets"
  value       = var.admin_db_pw
}

output "admin_server" {
  description = "Iris Secrets"
  value       = var.admin_server
}

output "iris_s3_bucketname" {
  description = "Iris Secrets"
  value       = var.iris_s3_bucketname
}

output "iris_s3_secret_key" {
  description = "Iris Secrets"
  value       = var.iris_s3_secret_key
}

output "iris_s3_access_key" {
  description = "Iris Secrets"
  value       = var.iris_s3_access_key
}

output "iris_s3_lic_id" {
  description = "Iris Secrets"
  value       = var.iris_s3_lic_id
}

output "iris_s3_lic_code" {
  description = "Iris Secrets"
  value       = var.iris_s3_lic_code
}