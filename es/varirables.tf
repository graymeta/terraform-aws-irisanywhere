variable "domain" {
  type        = string
  description = "Name of Domain"
  default     = "irisanywhere-es"
}

variable "instance_type" {
  type        = string
  default     = "t2.small.elasticsearch"
  description = "Elasticsearch instance type for data nodes in the cluster"
}

variable "es_version" {
  type        = string
  default     = "OpenSearch_1.0"
  description = "(Required) Desired version of Opensearch"
}

variable "tag_domain" {
  type    = string
  default = "var.domain"
}
variable "volume_type" {
  type        = string
  default     = "gp2"
  description = "Storage type of EBS volumes"
}


variable "ebs_volume_size" {
  type        = number
  description = "EBS volumes for data storage in GB"
  default     = 10
}

variable "advanced_options" {
  type        = map(string)
  default     = {}
  description = "Key-value string pairs to specify advanced configuration options"
}

variable "advanced_security_options_enabled" {
  type        = bool
  default     = true
  description = "Enables security options for ES"
}

variable "advanced_security_options_master_user_arn" {
  type        = string
  default     = ""
  description = "ARN of IAM user with the ability to access instance"
}

variable "custom_endpoint_enabled" {
  type        = bool
  description = "Enables custom endpoint for the domain."
  default     = true
}

variable "custom_endpoint" {
  type        = string
  description = "FQDN for custom endpoint."
  default     = ""
}

variable "custom_endpoint_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for custom endpoint."
  default     = ""
}

variable "subnet_id" {
  type        = list(string)
  description = "(Required) A list of subnet IDs to launch resources in."
}

variable "zone_awareness_enabled" {
  type        = bool
  default     = true
  description = "Enable zone awareness"
}

variable "availability_zone_count" {
  type        = number
  default     = 2
  description = "Configure number of availability zones for the domain"
}

variable "instance_count" {
  type        = number
  description = "Number of instances in the cluster"
  default     = 2
}

variable "node_to_node_encryption_enabled" {
  type        = bool
  default     = true
  description = "Enables node-to-node encryption"
}

variable "encrypt_at_rest_enabled" {
  type        = bool
  default     = true
  description = "Enables encryption at rest"
}

variable "encrypt_at_rest_kms_key_id" {
  type        = string
  default     = ""
  description = "ARN of KMS ID of ES in Key Management Service"
}

variable "domain_endpoint_options_enforce_https" {
  type        = bool
  default     = true
  description = "Determine whether to require HTTPS"
}

variable "domain_endpoint_options_tls_security_policy" {
  type        = string
  default     = "Policy-Min-TLS-1-0-2019-07"
  description = "TLS policy for the endpoint"
}

variable "base_sg" {
  type        = bool
  default     = true
  description = "Base Security Groups"
}

variable "security_groups" {
  type        = list(string)
  default     = []
  description = "List of sec groups allowed to connect"
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "List of CIDR blocks to allow access to OpenSearch"
}

variable "ia_secret_arn" {
  type        = string
  description = "(Required) arn of secrets for configuring application. See Readme for instructions for required inputs"
}

variable "bucketlist" {
  type        = string
  description = "(Required) list of S3 buckets"
}

variable "arn_of_indexresource" {
  type        = string
  description = "(Required) ARN of Role trusted to index"
}
