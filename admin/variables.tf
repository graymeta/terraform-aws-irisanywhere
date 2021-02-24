variable "ami" {
  type        = string
  description = "The AMI from which to launch the instance."
  default     = ""
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
  type        = string
  description = "VPC Subnet ID to launch in."
}

variable "tags" {
  type        = map(string)
  description = "(Optional) A map of the additional tags."
  default     = {}
}

variable "volume_type" {
  type        = string
  description = "EBS volume type."
}

variable "volume_size" {
  type        = number
  description = "EBS volume size."
}
