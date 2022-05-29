variable "additional_tags" {
  default     = {}
  description = "Additional resource tags"
  type        = map(string)
}
variable "access_cidr" {
  default     = ["0.0.0.0/0"]
  description = "(Optional) List of network cidr that have access.  Default to `[\"0.0.0.0/0\"]`"
  type        = list(string)
}
variable "apply_immediately" {
  default   = true
  type      = bool
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
  default     = 14 
  description = "(Required) Postgres Database version"
  type        = number
}
variable "instance_id" {
  description = "(Required) Name for your Iris Admin DB"
  type        = string   
}
variable "subnet_ids" {
  description = "(Required) List of subnets in VPC but different AZ's"
  type        = list(string)
}
variable "ia_secret_arn" {
  description = "(Required) arn of secrets for configuring the Iris Admin db. See Readme for instructions for required inputs"
  type        = string
}