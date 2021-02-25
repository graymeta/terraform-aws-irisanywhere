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
  description = "(Required) A list of subnet IDs to launch resources in."
}


variable "tags" {
  type        = map(string)
  description = "(Optional) A map of the additional tags."
  default     = {}
}

variable "volume_type" {
  type        = string
  description = "Volume type."
  default     = "gp2"
}

variable "volume_size" {
  type        = number
  description = "Volume size."
  default     = "60"
}
