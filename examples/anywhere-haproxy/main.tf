provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

locals {
  customer_name = "iris-anywhere-ha"

  allowed_operator_cidrs = [
    "203.0.113.10/32",
  ]

  haproxy_management_cidrs = [
    "203.0.113.10/32",
  ]
}

module "irisanywhere" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=v2.6.3"

  hostname_prefix             = local.customer_name
  instance_type               = "c7a.4xlarge"
  key_name                    = "my-key"
  subnet_id                   = ["subnet-aaaa1111", "subnet-bbbb2222"]
  ia_secret_arn               = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-anywhere"
  access_cidr                 = local.allowed_operator_cidrs
  rdp_access_cidr             = local.allowed_operator_cidrs
  haproxy                     = true
  instance_type_ha            = "t3.xlarge"
  mgmt_cidr                   = local.haproxy_management_cidrs
  ssl_haproxy_cert_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:haproxy-cert"
  ia_max_sessions             = 2
}