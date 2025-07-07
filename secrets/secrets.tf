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

  secret_string = jsonencode({
    admin_console_id   = var.admin_console_id,
    admin_console_pw   = var.admin_console_pw,
    admin_db_id        = var.admin_db_id,
    admin_db_pw        = var.admin_db_pw,
    admin_server       = "",
    admin_customer_id  = "",

    s3_enterprise = jsonencode({
      buckets = [
        { name = "name1", enabled = true },
        { name = "name2", enabled = true }
      ]
    })
  })
}
