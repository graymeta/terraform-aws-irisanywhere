variable "secret_name" {
  type        = string
  description = "Name of secret credential in AWS Secrets Manager"
}

variable "admin_customer_id" {
  type        = string
  description = "Customer ID for Iris Admin - provided by Graymeta"
}

variable "admin_db_id" {
  type        = string
  description = "Database ID for Iris Admin"
  default     = "postgres"
}

variable "admin_db_pw" {
  type        = string
  description = "Database credential for Iris Admin"
}

variable "admin_console_id" {
  type        = string
  description = "Username for Iris Admin console"
}

variable "admin_console_pw" {
  type        = string
  description = "Password for Iris Admin console"
}


variable "admin_server" {
  type        = string
  description = "FQDN of Iris Admin Server"
}

variable "iris_s3_bucketname" {
  type        = string
  description = "Name of S3 Bucket"
}

variable "iris_s3_access_key" {
  type        = string
  description = "S3 access key cred for Iris"
}

variable "iris_s3_secret_key" {
  type        = string
  description = "S3 secret key cred for Iris"
}

variable "iris_s3_lic_code" {
  type        = string
  description = "S3 license code - provided by GrayMeta"
}

variable "iris_s3_lic_id" {
  type        = string
  description = "S3 license ID - provided by GrayMeta"
}

variable "iris_serviceacct" {
  type        = string
  description = "account name for application"
}

variable "tags" {
  type        = map(string)
  description = "(Optional) A map of the additional tags."
  default     = {}
}