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
    "admin_customer_id":  "${var.admin_customer_id}",
    "admin_db_id":        "${var.admin_db_id}",
    "admin_db_pw":        "${var.admin_db_pw}",
    "admin_server":       "${var.admin_server}",
    "iris_s3_bucketname": "${var.iris_s3_bucketname}",
    "iris_s3_access_key": "${var.iris_s3_access_key}",
    "iris_s3_secret_key": "${var.iris_s3_secret_key}",
    "iris_s3_lic_code":   "${var.iris_s3_lic_code}",
    "iris_s3_lic_id":     "${var.iris_s3_lic_id}",
    "admin_console_id":   "${var.admin_console_id}",
    "admin_console_pw":   "${var.admin_console_pw}",
    "iris_serviceacct":   "${var.iris_serviceacct}",
    "okta_issuer":        "${var.okta_issuer}",
    "okta_clientid":      "${var.okta_clientid}",
    "okta_redirecturi":   "${var.okta_redirecturi}",
    "okta_scope":         "${var.okta_scope}",
    "s3_meta_access_key": "${var.s3_meta_access_key}",
    "s3_meta_secret_key": "${var.s3_meta_secret_key}",
    "s3_meta_bucketname": "${var.s3_meta_bucketname}",
    "os_region":          "${var.os_region}",
    "os_endpoint":        "${var.os_endpoint}",
    "os_accessid":        "${var.os_accessid}",
    "os_secretkey":       "${var.os_secretkey}",
    "saml_uniqueID":      "${var.saml_uniqueID}",
    "saml_displayName":   "${var.saml_displayName}",
    "saml_entryPoint":    "${var.saml_entryPoint}",
    "saml_samlissuer":    "${var.saml_samlissuer}",
    "saml_acsUrlBasePath":      "${var.saml_acsUrlBasePath}",
    "saml_acsUrlRelativePath":  "${var.saml_acsUrlRelativePath}",
    "s3_enterprise":            "${var.s3_enterprise}"
    }
EOF
}