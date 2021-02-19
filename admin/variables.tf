variable "ami" {
  type        = string
  description = "The AMI from which to launch the instance."
  default     = ""
}

variable "instance_profile" {
  type        = string
  description = " IAM Instance Profile to launch the instance with."
}

variable "instance_type" {
  type        = string
  description = "The type of the EC2 instance."
}

variable "key_name" {
  type        = string
  description = "The key name to use for the instance(s)."
}

variable "security_groups" {
  type        = string
  description = "A list of security groups to associate with."
}

variable "subnet_id" {
  type        = string
  description = "VPC Subnet ID to launch in."
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module. (Default: source = terraform)"

  default = {
    source = "terraform"
  }
}

variable "user_data" {
  type        = string
  description = "User data to provide when launching the instance."
}

variable "volume_type" {
  type        = string
  description = "EBS volume type."
}

variable "volume_size" {
  type        = number
  description = "EBS volume size."
}
