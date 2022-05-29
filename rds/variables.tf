variable "access_cidr" {
  type        = list(string)
  description = "(Optional) List of network cidr that have access.  Default to `[\"0.0.0.0/0\"]`"
  default     = ["0.0.0.0/0"]
    }
variable "apply_immediately" {
    type      = bool
    default   = true
    }
variable "allocated_storage" {
  type        = number
  description = "Storage for Iris Aadmin db"
  default     = 100 
    }
variable "db_backup_retention" {
  type        = number
  description = "Number of backups retained by RDS"
  default     = "3" 
    }
variable "db_backup_window" {
  type        = string
  description = "Time of backup window"
  default     = "03:00-04:00" 
    }
variable "db_instance_size" {
  type        = string
  description = "Instance Size for RDS"
  default     = "db.m6g.large"
    }
variable "db_kms_key_id" {
  type        = string
  description = "Enable RDS with specific CMK"
    }
variable "db_multi_az" {
  type        = bool
  description = "Enable Multi-region support"
  default     = true
    }
variable "db_snapshot" {}
variable "db_storage_encrypted" {
  type        = bool
  description = "Encrypt DB storage"
  default     = false
    }
variable "db_version" {
  type        = number
  description = "Postgres Database version"
  default     = 14 
    }
variable "instance_id" {
  type        = string   
  description = "(Required) Name for your Iris Admin DB"
    }
variable "subnet_ids" {
  type        = list(string)
  description = "(Required) List of subnets in VPC but different AZ's"
    }
variable "ia_secret_arn" {
  type        = string
  description = "(Required) arn of secrets for configuring the Iris Admin db. See Readme for instructions for required inputs"
    }