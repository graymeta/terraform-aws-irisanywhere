variable "access_cidr" {
  type        = list(string)
  description = "(Optional) List of network cidr that have access.  Default to `[\"0.0.0.0/0\"]`"
  default     = ["0.0.0.0/0"]
}

variable "ami" {
  type        = string
  description = "The AMI from which to launch the instance."
  default     = ""
}

variable "hostname_prefix" {
  type        = string
  description = "(Required) A unique name."
}

variable "instance_count" {
  type        = number
  description = "Number of EC2 instances to deploy."
  default     = 1
}

variable "instance_type" {
  type        = string
  description = "The type of the EC2 instance."
}

variable "key_name" {
  type        = string
  description = "The key name to use for the instance(s)."
}

variable "subnet_id" {
  type        = list(string)
  description = "(Required) A list of subnet IDs to launch resources in."
}

variable "tags" {
  type        = map(string)
  description = "(Optional) A map of the additional tags."
  default     = {}
}

variable "volume_type" {
  type        = string
  description = "EBS volume type.  Default to `gp2`"
  default     = "gp2"
}

variable "volume_size" {
  type        = number
  description = "EBS volume size.  Default to `60`"
  default     = "60"
}

variable "ia_secret_arn" {
  type        = string
  description = "ARN containing secrets for Iris Admin"
}

variable "instance_protection" {
  type        = bool
  description = "Enables instance protection"
  default     = true
}

variable "ssl_certificate_arn" {
  type        = string
  description = "(Required) The ARN of the SSL server certificate."
}

variable "associate_public_ip" {
  type        = bool
  description = "(Optional) Associates Public IP to instances. Default is false."
  default     = false
}

