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

variable "volume_type" {
  type        = string
  description = "EBS volume type."
}

variable "volume_size" {
  type        = number
  description = "EBS volume size."
}
