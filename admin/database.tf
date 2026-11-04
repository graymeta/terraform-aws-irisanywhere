terraform {
  # removed blocks require Terraform 1.7+.
  required_version = ">= 1.7"
}

locals {
  # Empty means Iris Admin installs PostgreSQL locally.
  dbserver = var.enterprise_ha ? var.db_endpoint : ""

  legacy_db_identifier = "${var.hostname_prefix}${var.deployment_name != "1" ? "-${var.deployment_name}" : ""}"
}

output "endpoint" {
  value       = local.dbserver
  description = "Database hostname used by Iris Admin, or empty when PostgreSQL is installed locally."
}

# Upgrade guard: finds a database created by an older version of this module.
data "aws_db_instances" "legacy" {
  count = var.enterprise_ha && var.db_endpoint == "" ? 1 : 0

  filter {
    name   = "db-instance-id"
    values = [local.legacy_db_identifier]
  }
}

data "aws_db_instance" "existing" {
  count                  = local.dbserver != "" ? 1 : 0
  db_instance_identifier = split(".", var.db_endpoint)[0]
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_admin" {
  count                        = local.dbserver != "" ? 1 : 0
  security_group_id            = tolist(data.aws_db_instance.existing[0].vpc_security_groups)[0]
  description                  = "Allow Postgresql from Iris Admin instances"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.iris_adm.id
}

# Older versions created the database here. On upgrade, stop managing it instead of destroying it.
removed {
  from = aws_db_instance.default
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_db_subnet_group.default
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_security_group.rds
  lifecycle {
    destroy = false
  }
}

removed {
  from = aws_vpc_security_group_ingress_rule.rds_postgresql
  lifecycle {
    destroy = false
  }
}

variable "db_endpoint" {
  type        = string
  description = "(Required when enterprise_ha = true) Hostname of an RDS PostgreSQL instance, without the port, for example the address output of the rds module."
  default     = ""
}

# Deprecated: the database moved to the rds module. Kept so existing configurations still plan; values are ignored.
variable "create_rds" {
  type        = bool
  description = "DEPRECATED and ignored. The database is managed by the rds module."
  default     = null
}

variable "apply_immediately" {
  type        = bool
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}

variable "allocated_storage" {
  type        = number
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}

variable "db_backup_retention" {
  type        = number
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}

variable "db_backup_window" {
  type        = string
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}

variable "db_instance_size" {
  type        = string
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}

variable "db_kms_key_id" {
  type        = string
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}

variable "db_multi_az" {
  type        = bool
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}

variable "db_snapshot" {
  type        = string
  description = "DEPRECATED and ignored."
  default     = null
}

variable "db_storage_encrypted" {
  type        = bool
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}

variable "db_version" {
  type        = string
  description = "DEPRECATED and ignored. Set in the rds module."
  default     = null
}
