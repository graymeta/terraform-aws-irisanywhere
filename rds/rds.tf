data "aws_secretsmanager_secret_version" "iris-secret" {
  secret_id = var.ia_secret_arn
}

data "aws_subnet" "subnetinfo" {
  id = var.subnet_id[0]
}

locals {
  identifier = "${var.hostname_prefix}${var.deployment_name != "1" ? "-${var.deployment_name}" : ""}"
  name_tag   = "IrisAdmin${var.deployment_name != "1" ? "-${var.deployment_name}" : ""}"
}

resource "aws_db_instance" "this" {
  allocated_storage          = var.allocated_storage
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = false
  backup_retention_period    = var.db_backup_retention
  backup_window              = var.db_backup_window
  db_name                    = "postgres"
  db_subnet_group_name       = aws_db_subnet_group.this.name
  deletion_protection        = var.deletion_protection
  engine                     = "postgres"
  engine_version             = var.db_version
  final_snapshot_identifier  = "GrayMeta-IrisAdmin-${local.identifier}-${formatdate("YYYYMMDDhhmmss", timestamp())}-final"
  identifier                 = local.identifier
  instance_class             = var.db_instance_size
  kms_key_id                 = var.db_kms_key_id != "" ? var.db_kms_key_id : null
  multi_az                   = var.db_multi_az
  password                   = jsondecode(data.aws_secretsmanager_secret_version.iris-secret.secret_string)["admin_db_pw"]
  snapshot_identifier        = var.snapshot_identifier
  storage_encrypted          = var.db_storage_encrypted
  storage_type               = "gp3"
  username                   = jsondecode(data.aws_secretsmanager_secret_version.iris-secret.secret_string)["admin_db_id"]
  vpc_security_group_ids     = [aws_security_group.this.id]

  lifecycle {
    # These force replacement; never let a config mismatch recreate the database.
    ignore_changes = [
      db_name,
      identifier,
      kms_key_id,
      snapshot_identifier,
      storage_encrypted,
      username,
    ]
  }

  tags = merge(var.additional_tags, { Name = local.name_tag })
}

resource "aws_db_subnet_group" "this" {
  subnet_ids = var.subnet_id

  tags = merge(var.additional_tags, { Name = local.name_tag })
}

resource "aws_security_group" "this" {
  description = "Access to RDS Database"
  vpc_id      = data.aws_subnet.subnetinfo.vpc_id

  tags = merge(var.additional_tags, { Name = local.name_tag })
}

resource "aws_vpc_security_group_ingress_rule" "postgresql" {
  for_each          = toset(var.allowed_cidr_blocks)
  security_group_id = aws_security_group.this.id
  description       = "Allow PostgreSQL"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}
