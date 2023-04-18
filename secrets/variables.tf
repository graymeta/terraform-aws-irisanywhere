variable "secret_name" {
  type        = string
  description = "Name of secret credential in AWS Secrets Manager"
}

variable "description" {
  type        = string
  description = "Name of secret credential in AWS Secrets Manager"
  default     = "Iris Secrets"
}

variable "recovery_window_in_days" {
  type        = number
  description = "Recover window in days"
  default     = 7
}

variable "admin_customer_id" {
  type        = string
  description = "Customer ID for Iris Admin - provided by Graymeta"
}

variable "admin_db_id" {
  type        = string
  description = "Database ID for Iris Admin"
  default     = "postgres"
  sensitive   = true
}

variable "admin_db_pw" {
  type        = string
  description = "Database credential for Iris Admin"
  sensitive   = true
}

variable "admin_console_id" {
  type        = string
  description = "Username for Iris Admin console"
  sensitive   = true
}

variable "admin_console_pw" {
  type        = string
  description = "Password for Iris Admin console"
  sensitive   = true
}

variable "admin_server" {
  type        = string
  description = "FQDN of Iris Admin Server"
  sensitive   = true
}

variable "iris_s3_bucketname" {
  type        = string
  description = "Name of S3 Bucket"
}

variable "iris_s3_access_key" {
  type        = string
  description = "S3 access key cred for Iris"
  sensitive   = true
}

variable "iris_s3_secret_key" {
  type        = string
  description = "S3 secret key cred for Iris"
  sensitive   = true
}

variable "iris_s3_lic_code" {
  type        = string
  description = "S3 license code - provided by GrayMeta"
  sensitive   = true
}

variable "iris_s3_lic_id" {
  type        = string
  description = "S3 license ID - provided by GrayMeta"
  sensitive   = true
}

variable "iris_serviceacct" {
  type        = string
  description = "account name for application"
  default     = "iris-service"
  sensitive   = true
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
  sensitive   = true
}

variable "s3_meta_secret_key" {
  type        = string
  description = "S3 Secret key for alternate bucket write access"
  sensitive   = true
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
  sensitive   = true
}

variable "os_secretkey" {
  type        = string
  description = "SecretKey for signed OpenSearch processes"
  sensitive   = true
}

variable "s3_enterprise" {
  type        = string
  description = "List of S3 buckets and configs for SSE - requires keypair values"
}

variable "saml_uniqueID" {
  type        = string
  description = "(Optional) ID of IDP for SAML configuration (Either okta or ping-identity)."
}

variable "saml_displayName" {

  type        = string
  description = "(Optional) Display name of IDP for SAML configuration (Either Okta or Ping Identity)."
}

variable "saml_entryPoint" {
  type        = string
  description = "(Optional) Identity Provider Single Sign-On URL."
}

variable "saml_samlissuer" {
  type        = string
  description = "(Optional) - Identity Provider Issuer from SAML configuration (within SAML setup)."
}

variable "saml_acsUrlBasePath" {
  type        = string
  description = "(Optional) - URL path to visit Iris Anywhere (iris-url.domain.com/irisanywhere)."
}

variable "saml_acsUrlRelativePath" {
  type        = string
  description = "(Optional) ACS URL relative to Iris Anywhere server (eg. /auth/saml/idp/assertion-consumer-service)"
}

variable "tags" {
  type        = map(string)
  description = "(Optional) A map of the additional tags."
  default     = {}
}