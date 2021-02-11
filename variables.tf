variable "base_ami" {
  type        = string
  description = "The AMI from which to launch the instance."
  default     = ""
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
  description = "EBS volume type."
  default     = "gp2"
}

variable "os_disk_size" {
  type        = number
  description = "EBS volume size."
  default     = "100"
}

variable "size_desired" {
  type        = number
  description = "The number of EC2 instances that should be running in the group."
}

variable "size_max" {
  type        = number
  description = "Maximum size of the Auto Scaling Group."
}

variable "size_min" {
  type        = number
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

variable "asg_check_interval" {
  type        = number
  description = "Autoscale check interval.  Default 300"
  default     = 300
}

variable "asg_scaleout_threshold" {
  type        = number
  description = "Scale out if the number of sessions drop below.  Default: 5"
  default     = 5
}

variable "asg_scaleout_cooldown" {
  type        = number
  description = "Scale out cooldown period. Default: 300"
  default     = 300
}

variable "asg_scaleout_evaluation" {
  type        = number
  description = "Scale out evaluation periods: Default: 2"
  default     = 2
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module. (Default: source = terraform)"

  default = {
    source = "terraform"
  }
}
