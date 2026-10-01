# Deploying GrayMeta Iris Admin with Terraform

This module deploys GrayMeta Iris Admin into AWS. It supports a standalone deployment and an enterprise HA deployment that adds a load balancer. By default Iris Admin installs PostgreSQL locally on the instance. To use an RDS PostgreSQL database instead, create it with the `rds` module, in its own Terraform state so destroying Iris Admin never affects it, and pass its hostname as `db_endpoint`.

Note: IAM resources are account-scoped, not regional. If you reuse the same role or policy names across regional deployments, manage them from one Terraform state or use region-specific names so one region does not delete resources another region still needs.

## Requirements

* Terraform 1.7 or later.
* IAM permissions to deploy EC2, security groups, load balancers, and IAM roles and policies.
* For HA with RDS: a database created with the `rds` module.
* Required Secrets Manager values created before deployment.
* Access to the GrayMeta Iris Admin AMIs. Contact support@graymeta.com.
* ACM certificates when using HA and TLS termination on the load balancer.
* The Admin AMI must include a running Amazon SSM Agent and have network access to SSM and the public installer URL.

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

Without `db_endpoint`, Iris Admin installs PostgreSQL locally. To use RDS, create the database first, in its own root module and state:

```hcl
module "irisadmin_rds" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//rds?ref=<tag>"

  hostname_prefix = "iris-admin-ha"
  subnet_id       = ["subnet-foo1", "subnet-foo2"]
  ia_secret_arn   = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-admin"
  db_version      = "17.9"
}

output "db_endpoint" {
  value = module.irisadmin_rds.address
}
```

Then deploy Iris Admin in a separate root module, using that output as `db_endpoint` (omit it for local PostgreSQL):

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
  db_endpoint             = "iris-admin-ha.abc123.us-west-2.rds.amazonaws.com"
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

Required only for specific deployment modes:

* `enterprise_ha = true` when you want the HA topology.
* At least two subnet IDs when `enterprise_ha = true`.
* `db_endpoint` when `enterprise_ha = true` and the database is on RDS.
* `enterprise_ha_lb_public` only when you need a public HA load balancer.

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
* `iris_admin_ver` required. Iris Admin installer version to download, for example `9.7.5.205`.
* `instance_protection` optional, default `true`. Enables EC2 instance protection.
* `associate_public_ip` optional, default `false`. Associates public IPs to the Admin instances. Typically set to `true` only when you need direct public access to standalone Admin instances.
* `enterprise_ha` optional, default `false`. Enables the HA topology. When enabled, provide at least two subnet IDs.
* `https_console_port` optional, default `8021`. HTTPS port for the Admin console.
* `http_console_port` optional, default `8020`. HTTP port for the Admin console.
* `disable_rdp` optional, default `false`. Disables RDP access in the security group.
* `enterprise_ha_lb_public` optional, default `false`. Makes the Admin HA load balancer internet-facing. Applies only when `enterprise_ha = true`.

HA database input:

* `db_endpoint` optional, default `""`. Applies when `enterprise_ha = true`. Hostname of an RDS PostgreSQL instance, without the port (the `address` output of the `rds` module). The module looks up the instance and adds a rule to its security group allowing PostgreSQL from the Iris Admin instances; destroying Iris Admin removes only that rule. Leave empty to install PostgreSQL locally on the Iris Admin instance. As an upgrade safeguard, the plan fails if `db_endpoint` is empty but an RDS instance named like one created by earlier versions of this module (`hostname_prefix`, plus `-deployment_name` when set) exists.

Deprecated inputs, accepted but ignored (the database is managed by the `rds` module): `create_rds`, `apply_immediately`, `allocated_storage`, `db_backup_retention`, `db_backup_window`, `db_instance_size`, `db_kms_key_id`, `db_multi_az`, `db_snapshot`, `db_storage_encrypted`, `db_version`.

## Outputs

* `security_group` Admin security group ID.
* `private_dns` Private DNS names of the Admin instances.
* `private_ip` Private IP addresses of the Admin instances.
* `alb_dns_name` Load balancer DNS name list when HA is enabled.
* `alb_dns_name_none` Joined load balancer DNS name when HA is enabled.
* `endpoint` Database hostname used by Iris Admin (the value of `db_endpoint`), or empty when PostgreSQL is installed locally.

## Upgrading an HA Deployment That Created Its Own Database

Earlier versions of this module created the RDS database. This version stops managing it without deleting it. Deployments that use local PostgreSQL need no changes.

1. Take a manual RDS snapshot.
2. Record the database hostname from your current state:
   `terraform state show 'module.<name>.aws_db_instance.default[0]' | grep -E '^\s+address'`
3. Update `source` to this version and set `db_endpoint` to that hostname.
4. Run `terraform plan`. Every `aws_db_instance`, `aws_db_subnet_group`, and `aws_security_group.rds` entry must say "will no longer be managed by Terraform, but will not be destroyed". If any says "will be destroyed" or "must be replaced", stop.
5. Run `terraform apply`.

To manage the database with Terraform again, import it into a separate root module that uses the `rds` module, and check that its first plan replaces nothing.

## Licensing

After deployment, contact support@graymeta.com for product licensing.
