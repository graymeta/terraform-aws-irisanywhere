variable "additional_tags" {
  default     = {}
  description = "Additional resource tags"
  type        = map(string)
}
variable "sqs_name" {
  default     = "iris-admin"
  description = "Name of the SQS Queue"
}