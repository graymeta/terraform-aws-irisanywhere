resource "aws_secretsmanager_secret" "iris_config" {
  name                    = var.secret_name
  description             = var.description
  recovery_window_in_days = var.recovery_window_in_days
  tags = {
    Name = var.secret_name
  }
}
resource "aws_secretsmanager_secret_version" "iris_config" {
  secret_id     = aws_secretsmanager_secret.iris_config.id
  secret_string = <<EOF
  {
  "admin_console_id":   "${var.admin_console_id}",
  "admin_console_pw":   "${var.admin_console_pw}",
  "admin_db_id":        "${var.admin_db_id}",
  "admin_db_pw":        "${var.admin_db_pw}",
  "iris_s3_access_key": "${var.iris_s3_access_key}",
  "iris_s3_secret_key": "${var.iris_s3_secret_key}",
  "iris_s3_lic_id":     "${var.iris_s3_lic_id}",
  "iris_s3_lic_code":   "${var.iris_s3_lic_code}",
  "admin_server":       "${var.admin_server}",
  "admin_customer_id":  "${var.admin_customer_id}"
}
EOF
}