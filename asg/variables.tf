variable "access_cidr" {
  type        = list(string)
  description = "(Optional) List of network cidr that have access.  Default to `[\"0.0.0.0/0\"]`"
  default     = ["0.0.0.0/0"]
}

variable "asg_check_interval" {
  type        = number
  description = "(Optional) Autoscale check interval.  Default to `60`"
  default     = 60
}

variable "asg_scalein_cooldown" {
  type        = number
  description = "(Optional) Scale in cooldown period.  Default to `300`"
  default     = 300
}

variable "asg_scalein_evaluation" {
  type        = number
  description = "(Optional) Scale in evaluation periods.  Default to `2`"
  default     = 2
}

variable "asg_scalein_threshold" {
  type        = number
  description = "(Optional) Scale in if the number of sessions drop below.  Default to `5`"
  default     = 5
}

variable "asg_scaleout_cooldown" {
  type        = number
  description = "(Optional) Scale out cooldown period.  Default to `300`"
  default     = 300
}

variable "asg_scaleout_evaluation" {
  type        = number
  description = "(Optional) Scale out evaluation periods. Default to `2`"
  default     = 2
}

variable "asg_scaleout_threshold" {
  type        = number
  description = "(Optional) Scale out if the number of sessions drop below.  Default to `5`"
  default     = 5
}

variable "asg_size_desired" {
  type        = number
  description = "(Required) The number of EC2 instances that should be running in the group."
}

variable "asg_size_max" {
  type        = number
  description = "(Required) Maximum size of the Auto Scaling Group."
}

variable "asg_size_min" {
  type        = number
  description = "(Required) Minimum size of the Auto Scaling Group."
}

variable "base_ami" {
  type        = string
  description = "(Optional) The AMI from which to launch the instance.  Default to latest released AMI"
  default     = ""
}

variable "disk_data_iops" {
  type        = number
  description = "(Optional) The amount of provisioned IOPS. This must be set with a volume_type of io1/io2."
  default     = 0
}

variable "disk_data_size" {
  type        = number
  description = "(Optional) EBS volume size.  Default to `300`"
  default     = "300"
}

variable "disk_data_type" {
  type        = string
  description = "(Optional) EBS volume type.  Default to `io2`"
  default     = "io2"
}

variable "disk_os_size" {
  type        = number
  description = "(Optional) EBS volume size.  Default to `50`"
  default     = "60"
}

variable "disk_os_type" {
  type        = string
  description = "(Optional) EBS volume type.  Default to `gp3`"
  default     = "gp3"
}

variable "hostname_prefix" {
  type        = string
  description = "(Required) A unique name."
}

variable "instance_type" {
  type        = string
  description = "(Required) The type of the EC2 instance."
}

variable "key_name" {
  type        = string
  description = "(Required) The key name to use for the instances."
}

variable "lb_algorithm_type" {
  type        = string
  description = "(Optional) Determines how the load balancer selects targets when routing requests.  The value is round_robin or least_outstanding_requests.  Default to `round_robin`"
  default     = "round_robin"
}

variable "lb_check_interval" {
  type        = number
  description = "(Optional) Loadbalancer health check interval. Default to `30`"
  default     = 30
}

variable "lb_unhealthy_threshold" {
  type        = number
  description = "(Optional) Loadbalancer unhealthy threshold.  Default to `2`"
  default     = 2
}

variable "ssl_certificate_arn" {
  type        = string
  description = "(Required) The ARN of the SSL server certificate."
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

variable "ia_cert_crt_arn" {
  type        = string
  description = "(Optional) This enables SSL on server.  Certificate format must be in x509 DER.  Default to blank"
  default     = ""
}

variable "ia_cert_key_arn" {
  type        = string
  description = "(Optional) This enables SSL on server.  Private Key matching the cert file.  Blank will force non-SSL between LB and Server.  Default to blank"
  default     = ""
}

variable "ia_secret_arn" {
  type        = string
  description = "arn of secrets for configuring application. See Readme for instructions for required inputs- required"
}

variable "ia_max_sessions" {
  type        = string
  description = "Max sessions per instance"
  default     = "2"
}

variable "ia_domain" {
  type        = string
  description = "domain name suffix for SSL cert used by Iris"
  default     = ""
}

variable "user_init" {
  type        = string
  description = "Custom Userinit"
  default     = ""
}