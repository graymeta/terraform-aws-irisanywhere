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
  default     = "" 
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
  default     = ""
  sensitive   = true
}

variable "iris_s3_bucketname" {
  type        = string
  description = "Name of S3 Bucket"
  default     = ""
}

variable "iris_s3_access_key" {
  type        = string
  description = "S3 access key cred for Iris"
  sensitive   = true
  default     = ""
}

variable "iris_s3_secret_key" {
  type        = string
  description = "S3 secret key cred for Iris"
  sensitive   = true
  default     = ""
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
  default     = ""
}

variable "okta_clientid" {
  type        = string
  description = "Value for Okta Client ID SPA"
  default     = ""
}

variable "okta_redirecturi" {
  type        = string
  description = "Value for Okta callback URI SPA"
  default     = ""
}

variable "okta_scope" {
  type        = string
  description = "Value for scope SPA"
  default     = ""
}

variable "s3_meta_access_key" {
  type        = string
  description = "S3 Access key for alternate bucket write access"
  sensitive   = true
  default     = ""
}

variable "s3_meta_secret_key" {
  type        = string
  description = "S3 Secret key for alternate bucket write access"
  sensitive   = true
  default     = ""
}

variable "s3_meta_bucketname" {
  type        = string
  description = "S3 bucket name for alternate bucket write access"
  default     = ""
}

variable "os_region" {
  type        = string
  description = "Region OpenSearch is deployed"
  default     = ""
}

variable "os_endpoint" {
  type        = string
  description = "FQDN of OpenSearch endpoint"
  default     = ""
}

variable "os_accessid" {
  type        = string
  description = "AccessID for signed OpenSearch processes"
  sensitive   = true
  default     = ""
}

variable "os_secretkey" {
  type        = string
  description = "SecretKey for signed OpenSearch processes"
  sensitive   = true
  default     = ""
}

variable "s3_enterprise" {
  type        = string
  description = "List of S3 buckets and configs for SSE - requires keypair values"
  default     = "{}"  
}

variable "saml_uniqueID" {
  type        = string
  description = "(Optional) ID of IDP for SAML configuration (Either okta or ping-identity)."
  default     = ""
}

variable "saml_displayName" {

  type        = string
  description = "(Optional) Display name of IDP for SAML configuration (Either Okta or Ping Identity)."
  default     = ""
}

variable "saml_entryPoint" {
  type        = string
  description = "(Optional) Identity Provider Single Sign-On URL."
  default     = ""
}

variable "saml_samlissuer" {
  type        = string
  description = "(Optional) - Identity Provider Issuer from SAML configuration (within SAML setup)."
  default     = ""
}

variable "saml_acsUrlBasePath" {
  type        = string
  description = "(Optional) - URL path to visit Iris Anywhere (iris-url.domain.com/irisanywhere)."
  default     = ""
}

variable "saml_acsUrlRelativePath" {
  type        = string
  description = "(Optional) ACS URL relative to Iris Anywhere server (eg. /auth/saml/idp/assertion-consumer-service)"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "(Optional) A map of the additional tags."
  default     = {}
}