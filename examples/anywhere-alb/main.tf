provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

locals {
  customer_name = "iris-anywhere"

  allowed_operator_cidrs = [
    "203.0.113.10/32",
  ]

  asg_tuning = {
    warm_pool_enabled     = true
    warm_pool_min         = 1
    warm_pool_max         = 1
    min_size              = 0
    max_size              = 2
    desired_size          = 1
    check_interval        = 60
    scalein_threshold     = 1
    scaleout_threshold    = 0
    sessions_per_instance = 2
  }
}

module "irisanywhere" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=v2.6.3"

  hostname_prefix = local.customer_name
  instance_type   = "c7a.4xlarge"
  key_name        = "my-key"
  subnet_id       = ["subnet-aaaa1111", "subnet-bbbb2222"]
  ia_secret_arn   = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-anywhere"
  ssl_alb_acm_arn = "arn:aws:acm:us-west-2:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  access_cidr     = local.allowed_operator_cidrs
  rdp_access_cidr = local.allowed_operator_cidrs

  warm_pool              = local.asg_tuning.warm_pool_enabled ? { enabled = true } : null
  asg_warm_pool_min      = local.asg_tuning.warm_pool_min
  asg_warm_pool_max      = local.asg_tuning.warm_pool_max
  asg_size_min           = local.asg_tuning.min_size
  asg_size_max           = local.asg_tuning.max_size
  asg_size_desired       = local.asg_tuning.desired_size
  asg_check_interval     = local.asg_tuning.check_interval
  asg_scalein_threshold  = local.asg_tuning.scalein_threshold
  asg_scaleout_threshold = local.asg_tuning.scaleout_threshold
  ia_max_sessions        = local.asg_tuning.sessions_per_instance
}