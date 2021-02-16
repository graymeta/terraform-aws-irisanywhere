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

variable "schedule_size_min" {
  type        = number
  description = "(Optional) The minimum size for the Auto Scaling group. Set to -1 if you don't want to change the minimum size at the scheduled time."
  default     = -1
}

variable "schedule_size_max" {
  type        = number
  description = "(Optional) The maximum size for the Auto Scaling group. Set to -1 if you don't want to change the maximum size at the scheduled time."
  default     = -1
}

variable "schedule_size_desired" {
  type        = string
  description = "(Optional) The number of EC2 instances that should be running in the group. Set to -1 if you don't want to change the desired capacity at the scheduled time."
  default     = -1
}

variable "schedule_recurrence" {
  type        = string
  description = "The time when recurring future actions will start. Start time is specified by the user following the Unix cron syntax format."
  default     = "0 8-17 * * MON-FRI"
}

variable "schedule_start" {
  type        = string
  description = "(Optional) The time for this action to start, in 'YYYY-MM-DDThh:mm:ssZ' format in UTC/GMT only (for example, 2014-06-01T00:00:00Z ). If you try to schedule your action in the past, Auto Scaling returns an error message."
  default     = "2030-01-01T00:00:00Z"
}

variable "schedule_end" {
  type        = string
  description = "(Optional) The time for this action to end, in 'YYYY-MM-DDThh:mm:ssZ' format in UTC/GMT only (for example, 2014-06-01T00:00:00Z ). If you try to schedule your action in the past, Auto Scaling returns an error message."
  default     = "2030-01-02T00:00:00Z"
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
