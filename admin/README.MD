# Deploying GrayMeta Iris Admin with Terraform

This module deploys GrayMeta Iris Admin into AWS. It supports a standalone deployment and an enterprise HA deployment that adds a load balancer and RDS.

Note: IAM resources are account-scoped, not regional. If you reuse the same role or policy names across regional deployments, manage them from one Terraform state or use region-specific names so one region does not delete resources another region still needs.

## Requirements

* Terraform 1.8.x or compatible.
* IAM permissions to deploy EC2, security groups, load balancers, IAM roles and policies, and RDS when HA is enabled.
* Required Secrets Manager values created before deployment.
* Access to the GrayMeta Iris Admin AMIs. Contact support@graymeta.com.
* ACM certificates when using HA and TLS termination on the load balancer.

## Standalone Example

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisadmin" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=<tag>"

  hostname_prefix     = "iris-admin"
  instance_type       = "t3.xlarge"
  subnet_id           = ["subnet-foo1"]
  key_name            = "my-key"
  ia_secret_arn       = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-admin"
  associate_public_ip = true
}
```

## Enterprise HA Example

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisadmin_ha" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=<tag>"

  hostname_prefix         = "iris-admin-ha"
  instance_count          = 2
  instance_type           = "t3.xlarge"
  subnet_id               = ["subnet-foo1", "subnet-foo2"]
  key_name                = "my-key"
  ia_secret_arn           = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-admin"
  enterprise_ha           = true
  enterprise_ha_lb_public = true
  https_console_port      = 443
}
```

## Minimum Root Module

Use this module when you want to deploy Iris Admin first and keep the customer root module small.

Required for a first successful apply:

* `hostname_prefix`
* `instance_type`
* `subnet_id`
* `key_name`
* `ia_secret_arn`

Usually optional on the first apply:

* `access_cidr`
* `api_console_access_cidr`
* `rdp_access_cidr`
* `associate_public_ip`
* `tags`
* `additional_tags`
* `user_init`
* `ha_secondary_install_delay_seconds`

Required only for specific deployment modes:

* `enterprise_ha = true` when you want the HA topology.
* At least two subnet IDs when `enterprise_ha = true`.
* `enterprise_ha_lb_public` only when you need a public HA load balancer.
* RDS-related inputs only when `enterprise_ha = true` and you want to override the defaults.

## Inputs

Core inputs:

* `access_cidr` optional, default `["0.0.0.0/0"]`. Allowed CIDR blocks for Admin access.
* `api_console_access_cidr` optional, default `["0.0.0.0/0"]`. Allowed CIDR blocks for the API and Admin UI.
* `rdp_access_cidr` optional, default `["0.0.0.0/0"]`. Allowed CIDR blocks for RDP.
* `ami` optional, default `""`. Override AMI ID for Iris Admin.
* `hostname_prefix` required. Name prefix used for deployed resources.
* `deployment_name` optional, default `"1"`. Overrides the naming suffix derived from instance type.
* `instance_count` optional, default `1`. Number of Admin instances.
* `instance_type` required. EC2 instance type.
* `key_name` required. EC2 key pair name.
* `subnet_id` required. Subnet IDs where the resources will be launched.
* `tags` optional, default `{}`. Resource tag map.
* `additional_tags` optional, default `{}`. Additional resource tag map.
* `volume_type` optional, default `gp3`. Root EBS volume type.
* `volume_size` optional, default `60`. Root EBS volume size in GiB.
* `ia_secret_arn` required. Secrets Manager ARN containing the Iris Admin application secrets.
* `instance_protection` optional, default `true`. Enables EC2 instance protection.
* `associate_public_ip` optional, default `false`. Associates public IPs to the Admin instances. Typically set to `true` only when you need direct public access to standalone Admin instances.
* `enterprise_ha` optional, default `false`. Enables the HA topology. When enabled, provide at least two subnet IDs.
* `ha_secondary_install_delay_seconds` optional, default `300`. Seconds to delay each secondary Admin instance install when `enterprise_ha = true`, preventing simultaneous database initialization attempts.
* `https_console_port` optional, default `8021`. HTTPS port for the Admin console.
* `http_console_port` optional, default `8020`. HTTP port for the Admin console.
* `disable_rdp` optional, default `false`. Disables RDP access in the security group.
* `user_init` optional, default `""`. Custom user-init PowerShell.
* `enterprise_ha_lb_public` optional, default `false`. Makes the Admin HA load balancer internet-facing. Applies only when `enterprise_ha = true`.

HA and RDS inputs:

* `apply_immediately` optional, default `true`. Apply RDS changes immediately. Applies only when `enterprise_ha = true`.
* `allocated_storage` optional, default `100`. RDS allocated storage in GiB. Applies only when `enterprise_ha = true`.
* `db_backup_retention` optional, default `3`. Number of automated RDS backups retained. Applies only when `enterprise_ha = true`.
* `db_backup_window` optional, default `03:00-04:00`. Preferred RDS backup window. Applies only when `enterprise_ha = true`.
* `db_instance_size` optional, default `db.m6g.large`. RDS instance class. Applies only when `enterprise_ha = true`.
* `db_kms_key_id` optional, default `""`. Customer-managed KMS key ID for RDS encryption. Required when you want RDS encrypted with a customer-managed key and `enterprise_ha = true`.
* `db_multi_az` optional, default `true`. Enables Multi-AZ RDS. Applies only when `enterprise_ha = true`.
* `db_snapshot` optional, default `iris-admin-backup`. Snapshot identifier used by the module. Applies only when `enterprise_ha = true`.
* `db_storage_encrypted` optional, default `false`. Enables RDS storage encryption. Applies only when `enterprise_ha = true`.
* `db_version` optional, default `14.8`. PostgreSQL engine version. Applies only when `enterprise_ha = true`.

## Outputs

* `security_group` Admin security group ID.
* `private_dns` Private DNS names of the Admin instances.
* `private_ip` Private IP addresses of the Admin instances.
* `alb_dns_name` Load balancer DNS name list when HA is enabled.
* `alb_dns_name_none` Joined load balancer DNS name when HA is enabled.
* `endpoint` RDS endpoint hostname when `enterprise_ha = true`.

## Licensing

After deployment, contact support@graymeta.com for product licensing.
