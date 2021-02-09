variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module. (Default: source = terraform)"

  default = {
    source = "terraform"
  }
}

variable "hostname_prefix" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "size_desired" {
  type = string
}
variable "size_max" {
  type = string
}
variable "size_min" {
  type = string
}

variable "subnet_id" {
  type = list(string)
}

variable "base_ami" {
  type    = string
  default = ""
}

variable "key_name" {
  type = string

}
variable "os_disk_type" {
  type    = string
  default = "gp2"
}
variable "os_disk_size" {
  type    = string
  default = "100"
}

variable "ssl_certificate_arn" {
  type = string
}
