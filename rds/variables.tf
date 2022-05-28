variable "access_cidr" {
  type        = list(string)
  description = "(Optional) List of network cidr that have access.  Default to `[\"0.0.0.0/0\"]`"
  default     = ["0.0.0.0/0"]
}
variable "apply_immediately" {}
variable "allocated_storage" {}
variable "db_backup_retention" {}
variable "db_backup_window" {}
variable "db_instance_size" {}
variable "db_kms_key_id" {}
variable "db_multi_az" {}
variable "db_password" {}
variable "db_snapshot" {}
variable "db_storage_encrypted" {}
variable "db_username" {}
variable "db_version" {}
variable "instance_id" {}
variable "subnet_ids" {
type = list 
}   
