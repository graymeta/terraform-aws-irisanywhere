provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

locals {
  customer_name = "iris-admin"

  admin_access_cidrs = [
    "203.0.113.10/32",
  ]
}

module "irisadmin" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=v2.6.3"

  hostname_prefix         = local.customer_name
  instance_type           = "t3.medium"
  subnet_id               = ["subnet-aaaa1111"]
  key_name                = "my-key"
  ia_secret_arn           = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-admin"
  access_cidr             = local.admin_access_cidrs
  api_console_access_cidr = local.admin_access_cidrs
  associate_public_ip     = true
}