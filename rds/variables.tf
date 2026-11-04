variable "hostname_prefix" {
  type        = string
  description = "(Required) Name prefix; also the RDS instance identifier. Must match the admin deployment."
}

variable "deployment_name" {
  type        = string
  description = "(Optional) Appended to the identifier when not \"1\". Must match the admin deployment."
  default     = "1"
}

variable "subnet_id" {
  type        = list(string)
  description = "(Required) At least two subnet IDs in different Availability Zones for the DB subnet group."
}

variable "ia_secret_arn" {
  type        = string
  description = "(Required) Secrets Manager ARN containing admin_db_id and admin_db_pw."
}

variable "additional_tags" {
  type        = map(string)
  description = "(Optional) Additional resource tags."
  default     = {}
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "IPv4 CIDR blocks allowed to connect to PostgreSQL on port 5432. Defaults to open IPv4 access."
  default     = ["0.0.0.0/0"]
}

variable "deletion_protection" {
  type        = bool
  description = "(Optional) Prevents the database from being deleted."
  default     = true
}

variable "apply_immediately" {
  type    = bool
  default = true
}

variable "allocated_storage" {
  type        = number
  description = "(Optional) Storage in GiB."
  default     = 100
}

variable "db_backup_retention" {
  type        = number
  description = "(Optional) Number of days automated backups are kept."
  default     = 3
}

variable "db_backup_window" {
  type        = string
  description = "(Optional) Daily backup window (UTC)."
  default     = "03:00-04:00"
}

variable "db_instance_size" {
  type        = string
  description = "(Optional) RDS instance class."
  default     = "db.m6g.large"
}

variable "db_kms_key_id" {
  type        = string
  description = "(Optional) Customer-managed KMS key for storage encryption."
  default     = ""
}

variable "db_multi_az" {
  type        = bool
  description = "(Optional) Enables Multi-AZ."
  default     = true
}

variable "db_storage_encrypted" {
  type        = bool
  description = "(Optional) Encrypts storage. Only applies when the database is created."
  default     = false
}

variable "db_version" {
  type        = string
  description = "(Required) PostgreSQL engine version, for example \"17.9\". Must match the existing database when importing."
}

variable "snapshot_identifier" {
  type        = string
  description = "(Optional) RDS snapshot identifier or ARN to restore when creating the database. Leave null to create a fresh database."
  default     = null
  nullable    = true

  validation {
    condition     = var.snapshot_identifier == null || trimspace(var.snapshot_identifier) != ""
    error_message = "snapshot_identifier must be null or a non-empty snapshot identifier or ARN."
  }
}
