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

variable "okta_issuer" {
  type        = string
  description = "Value for Okta Issuer SPA"
}

variable "okta_clientid" {
  type        = string
  description = "Value for Okta Client ID SPA"
}

variable "okta_redirecturi" {
  type        = string
  description = "Value for Okta callback URI SPA"
}

variable "okta_scope" {
  type        = string
  description = "Value for scope SPA"
}

variable "s3_meta_access_key" {
  type        = string
  description = "S3 Access key for alternate bucket write access"
}

variable "s3_meta_secret_key" {
  type        = string
  description = "S3 Secret key for alternate bucket write access"
}

variable "s3_meta_bucketname" {
  type        = string
  description = "S3 bucket name for alternate bucket write access"
}

variable "os_region" {
  type        = string
  description = "Region OpenSearch is deployed"
}

variable "os_endpoint" {
  type        = string
  description = "FQDN of OpenSearch endpoint"
}

variable "os_accessid" {
  type        = string
  description = "AccessID for signed OpenSearch processes"
}

variable "os_secretkey" {
  type        = string
  description = "SecretKey for signed OpenSearch processes"
}


variable "tags" {
  type        = map(string)
  description = "(Optional) A map of the additional tags."
  default     = {}
}