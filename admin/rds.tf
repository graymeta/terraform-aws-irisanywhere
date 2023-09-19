data "aws_secretsmanager_secret" "secret-arn" {
  arn = var.ia_secret_arn
}
data "aws_secretsmanager_secret_version" "iris-secret" {
  secret_id = data.aws_secretsmanager_secret.secret-arn.id
}

resource "aws_db_instance" "default" {
  #count = var.enterprise_ha == "true" ? 1 : 0
  count = var.enterprise_ha ? 1 : 0

  allocated_storage          = var.allocated_storage
  apply_immediately          = var.apply_immediately
  auto_minor_version_upgrade = "false"
  backup_retention_period    = var.db_backup_retention
  backup_window              = var.db_backup_window
  db_subnet_group_name       = aws_db_subnet_group.default.id
  engine                     = "postgres"
  engine_version             = var.db_version
  final_snapshot_identifier  = "GrayMeta-IrisAdmin-final"
  identifier                 = var.hostname_prefix
  instance_class             = var.db_instance_size
  kms_key_id                 = var.db_kms_key_id
  multi_az                   = var.db_multi_az
  db_name                    = "postgres"
  password                   = jsondecode(data.aws_secretsmanager_secret_version.iris-secret.secret_string)["admin_db_pw"]
  storage_encrypted          = var.db_storage_encrypted
  storage_type               = "gp2"
  username                   = jsondecode(data.aws_secretsmanager_secret_version.iris-secret.secret_string)["admin_db_id"]
  vpc_security_group_ids     = ["${aws_security_group.rds.id}"]

  #   snapshot_identifier = "${var.db_snapshot == "final" ?
  #     format("GrayMetaIrisAdmin-${var.hostname_prefix}-final") :
  #     var.db_snapshot
  #   }"

  lifecycle {
    ignore_changes = [
      storage_encrypted,
      kms_key_id,
      snapshot_identifier,
      identifier,
    ]
  }
  tags = merge(
    var.additional_tags,
    {
      Name = "IrisAdmin"
    },
  )
}

### Network ###
resource "aws_db_subnet_group" "default" {
  subnet_ids = var.subnet_id

  tags = merge(
    var.additional_tags,
    {
      Name = "IrisAdmin"
    },
  )
}

### Output ###
output "endpoint" {
  value = var.enterprise_ha == true ? "${element(split(":", "${aws_db_instance.default.0.endpoint}"), 0)}" : ""
}

data "aws_subnet" "subnetinfo" {
  count = length(var.subnet_id)
  id    = element(var.subnet_id, count.index)
}

resource "aws_security_group" "rds" {
  description = "Access to RDS Database"
  vpc_id      = data.aws_subnet.subnetinfo.0.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.access_cidr
  }

  tags = merge(
    var.additional_tags,
    {
      Name = "IrisAdmin"
    },
  )
}

variable "apply_immediately" {
  default = true
  type    = bool
}
variable "allocated_storage" {
  default     = 100
  description = "(Required) Storage for Iris Aadmin db"
  type        = number
}
variable "db_backup_retention" {
  default     = "3"
  description = "(Required) Number of backups retained by RDS"
  type        = number
}
variable "db_backup_window" {
  default     = "03:00-04:00"
  description = "(Required) Time of backup window"
  type        = string
}
variable "db_instance_size" {
  default     = "db.m6g.large"
  description = "(Required) Instance Size for RDS"
  type        = string
}
variable "db_kms_key_id" {
  default     = ""
  description = "(Required) Enable RDS with specific CMK"
  type        = string
}
variable "db_multi_az" {
  default     = true
  description = "(Required) Enable Multi-region support"
  type        = bool
}
variable "db_snapshot" {
  default     = "iris-admin-backup"
  description = ""
  type        = string
}
variable "db_storage_encrypted" {
  default     = false
  description = "Encrypt DB storage"
  type        = bool
}
variable "db_version" {
  default     = 14.8
  description = "(Required) Postgres Database version"
  type        = number
}
