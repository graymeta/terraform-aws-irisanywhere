
resource "aws_secretsmanager_secret" "iris_secrets" {
  name = var.secret_name
  description = "Iris Secrets"
}

resource "aws_secretsmanager_secret_version" "iris_values" {
  secret_id     = aws_secretsmanager_secret.iris_secrets.id
  secret_string = "{\"admin_customer_id\":\"${var.admin_customer_id}\",\"admin_db_id\":\"${var.admin_db_id}\",\"admin_db_pw\":\"${var.admin_db_pw}\",\"admin_server\":\"${var.admin_server}\",\"iris_s3_bucketname\":\"${var.iris_s3_bucketname}\",\"iris_s3_access_key\":\"${var.iris_s3_access_key}\",\"iris_s3_secret_key\":\"${var.iris_s3_secret_key}\",\"iris_s3_lic_code\":\"${var.iris_s3_lic_code}\",\"iris_s3_lic_id\":\"${var.iris_s3_lic_id}\",\"admin_console_id\":\"${var.admin_console_id}\",\"admin_console_pw\":\"${var.admin_console_pw}\",\"iris_serviceacct\":\"${var.iris_serviceacct}\"}"
}
