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

variable "asg_scalein_threshold" {
  type        = number
  description = "Scale in if the number of sessions drop below.  Default: 5"
  default     = 5
}

variable "asg_scalein_cooldown" {
  type        = number
  description = "Scale out cooldown period. Default: 300"
  default     = 300
}

variable "asg_scalein_evaluation" {
  type        = number
  description = "Scale out evaluation periods: Default: 2"
  default     = 2
}

variable "asg_scaleout_cooldown" {
  type        = number
  description = "Scale out cooldown period. Default: 300"
  default     = 300
}

variable "asg_scaleout_evaluation" {
  type        = number
  description = "Scale out evaluation periods. Default: 2"
  default     = 2
}

variable "asg_scaleout_threshold" {
  type        = number
  description = "Scale out if the number of sessions drop below.  Default: 5"
  default     = 5
}

variable "lb_check_interval" {
  type        = number
  description = "Loadbalancer health check interval. Default: 30"
  default     = 30
}

variable "lb_unhealthy_threshold" {
  type        = number
  description = "Loadbalancer unhealthy threshold. Default: 2"
  default     = 2
}

variable "tags" {
  type        = map(string)
  description = "A map of the tags to use on the resources that are deployed with this module. (Default: source = terraform)"

  default = {
    source = "terraform"
  }
}

variable "tfliccontent" {
  type        = string
  description = "IA license file data"
}

variable "tfcertfile" {
  type        = string
  description = "Certificate in x509 format DER"
}

variable "tfcertkeycontent" {
  type        = string
  description = "Private for Cert"
}

variable "tfS3ConnID" {
  type        = string
  description = "S3 Connector SaaS license UID"
}

variable "tfS3ConnPW" {
  type        = string
  description = "S3 Connector SaaS license PW "
}

variable "tfcustomerID" {
  type        = string
  description = "Set Iris CustomerID"
}

variable "tfadminserver" {
  type        = string
  description = "Set Iris Admin Server"
}

variable "tfserviceacct" {
  type        = string
  description = "Sets Service Account for autologon"
}

variable "tfbucketname" {
  type        = string
  description = "Bucket Name that will attach to Iris"
}

variable "tfAccecssKey" {
  type        = string
  description = "Access key for bucket access"
}

variable "tfSecretKey" {
  type        = string
  description = "Secret key for bucket access"
}

