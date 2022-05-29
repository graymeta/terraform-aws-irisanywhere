data "aws_secretsmanager_secret" "secret-arn" {
  arn = var.ia_secret_arn
}
data "aws_secretsmanager_secret_version" "iris-secret" {
  secret_id = data.aws_secretsmanager_secret.secret-arn.id
}

resource "aws_db_instance" "default" {
  allocated_storage          = var.allocated_storage
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = "false"
  backup_retention_period    = var.db_backup_retention
  backup_window              = var.db_backup_window
  db_subnet_group_name       = aws_db_subnet_group.default.id
  engine                     = "postgres"
  engine_version             = var.db_version
  final_snapshot_identifier  = "GrayMetaIrisAdmin-${var.instance_id}-final"
  identifier                 = "gm-irisadmin-${var.instance_id}"
  instance_class             = var.db_instance_size
  kms_key_id                 = var.db_kms_key_id
  multi_az                   = var.db_multi_az
  db_name                       = "postgres"
  password                   = jsondecode(data.aws_secretsmanager_secret_version.iris-secret.secret_string)["admin_db_pw"]
  storage_encrypted          = var.db_storage_encrypted
  storage_type               = "gp2"
  username                   = jsondecode(data.aws_secretsmanager_secret_version.iris-secret.secret_string)["admin_db_id"]
  vpc_security_group_ids     = ["${aws_security_group.rds.id}"]

  snapshot_identifier = "${var.db_snapshot == "final" ?
    format("GrayMetaIrisAdmin-${var.instance_id}-final") :
    var.db_snapshot
  }"

  lifecycle {
    ignore_changes = [
      storage_encrypted,
      kms_key_id,
      snapshot_identifier,
      identifier,
    ]
  }
}