# Deploying GrayMeta Iris Admin with Terraform

This module deploys GrayMeta Iris Admin into AWS. It supports a standalone deployment and an enterprise HA deployment that adds a load balancer. By default Iris Admin installs PostgreSQL locally on the instance. This module no longer creates or manages the RDS database. To use RDS with enterprise HA, manage the database with the [rds module](../rds/variables.tf) in its own Terraform state, and pass its hostname as `db_endpoint`. Destroying Iris Admin does not destroy that database; the Admin-managed PostgreSQL access rule is removed.

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

## Deprecated Database Inputs

The following inputs are retained in `/admin` for backward compatibility. They are optional, default to `null`, and are ignored regardless of the supplied value. Existing module calls can still pass them, but changing them does not create, upgrade, resize, restore, or otherwise configure a database. Remove them from Admin module calls and configure the separate `/rds` module instead.

| Deprecated Admin input | Type | Replacement in the RDS module |
| --- | --- | --- |
| `create_rds` | `bool` | No replacement flag. Declare a separate RDS module to manage a database. |
| `apply_immediately` | `bool` | `apply_immediately` |
| `allocated_storage` | `number` | `allocated_storage` |
| `db_backup_retention` | `number` | `db_backup_retention` |
| `db_backup_window` | `string` | `db_backup_window` |
| `db_instance_size` | `string` | `db_instance_size` |
| `db_kms_key_id` | `string` | `db_kms_key_id` |
| `db_multi_az` | `bool` | `db_multi_az` |
| `db_snapshot` | `string` | `snapshot_identifier` (for restoring a snapshot when creating a database) |
| `db_storage_encrypted` | `bool` | `db_storage_encrypted` |
| `db_version` | `string` | `db_version` |

For example, set `db_version` on the RDS module to manage the PostgreSQL engine version, not on the Admin module. The RDS module requires an explicit `db_version`; when importing an existing database, match its current engine version rather than introducing an upgrade during the state migration.

`db_endpoint` is not deprecated. It remains the connection input for enterprise HA and should be set to the RDS module's `address` output (without a port). Database settings are not automatically transferred from the Admin module to the RDS module.

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
4. Run `terraform plan`. The legacy resources `aws_db_instance.default`, `aws_db_subnet_group.default`, `aws_security_group.rds`, and `aws_vpc_security_group_ingress_rule.rds_postgresql`, if present in the Admin state, must say "will no longer be managed by Terraform, but will not be destroyed". If any says "will be destroyed" or "must be replaced", stop.
5. Run `terraform apply`.

To manage the database with Terraform again, import it and its supporting resources into a separate root module that uses the `rds` module after the Admin state has relinquished ownership. Carry over the existing database settings using the replacement inputs above, and check that the first RDS plan neither destroys nor replaces existing resources. Do not manage the same resources in both states. Remove the deprecated inputs from the Admin module call; keep `db_endpoint` set to the existing database hostname.

## Licensing

After deployment, contact support@graymeta.com for product licensing.
