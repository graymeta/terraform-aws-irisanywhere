variable "base_ami" {
  type        = string
  default     = ""
  description = "The AMI from which to launch the instance."
}

variable "hostname_prefix" {
  type        = string
  description = "Creates a unique name beginning with the specified prefix. Cannot be longer than 6 characters."
}

variable "instance_type" {
  type        = string
  description = "The type of the EC2 instance."
}

variable "key_name" {
  type        = string
  description = "The key name to use for the instance(s)."
}

variable "os_disk_type" {
  type        = string
  default     = "gp2"
  description = "EBS volume type."
}
variable "os_disk_size" {
  type        = string
  default     = "100"
  description = "EBS volume size."
}

variable "size_desired" {
  type        = string
  description = "The number of EC2 instances that should be running in the group."
}
variable "size_max" {
  type        = string
  description = "Maximum size of the Auto Scaling Group."
}
variable "size_min" {
  type        = string
  description = "Minimum size of the Auto Scaling Group."
}

variable "subnet_id" {
  type        = list(string)
  description = "A list of subnet IDs to launch resources in."
}

variable "ssl_certificate_arn" {
  type        = string
  description = "The ARN of the default SSL server certificate."
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module. (Default: source = terraform)"

  default = {
    source = "terraform"
  }
}
