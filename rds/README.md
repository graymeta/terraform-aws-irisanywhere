# Deploying GrayMeta Iris Admin RDS with Terraform

This module manages an AWS RDS PostgreSQL database for Iris Admin, along with its DB subnet group, security group, and optional CIDR-based PostgreSQL access rules. It is independent of the [admin module](../admin/README.MD). Keep it in a separate root module and Terraform state so destroying Iris Admin does not destroy its database.

## Requirements

* Terraform and an AWS provider version supporting the resources in this module. Migrating from the Admin module requires Terraform 1.7 or later for its `removed` blocks.
* AWS permissions to manage RDS, DB subnet groups, security groups and ingress rules, read subnet details, and read the application secret.
* At least two subnet IDs in different Availability Zones within the same VPC.
* A Secrets Manager secret containing `admin_db_id` and `admin_db_pw`, with credentials that meet RDS PostgreSQL requirements.
* A PostgreSQL engine version and DB instance class available in the target AWS region.
* KMS permissions when using a customer-managed encryption key.

## Example Usage

Deploy the database in its own root module:

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisadmin_rds" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//rds?ref=<tag>"

  hostname_prefix      = "iris-admin-ha"
  subnet_id            = ["subnet-foo1", "subnet-foo2"]
  ia_secret_arn        = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-admin"
  db_version           = "17.9"
  db_storage_encrypted = true
  allowed_cidr_blocks  = []
}

output "db_endpoint" {
  value = module.irisadmin_rds.address
}
```

The example disables CIDR-based ingress. When deployed with `enterprise_ha = true` and `db_endpoint` set, the Admin module manages a separate security-group rule allowing its instances to connect on port 5432. For other clients, supply only the required private network CIDRs in `allowed_cidr_blocks` and ensure network routing is available.

## Minimum Root Module

Required inputs:

* `hostname_prefix`
* `subnet_id`
* `ia_secret_arn`
* `db_version`

Review these settings before the first apply:

* `deployment_name` should match the Admin deployment; it affects the database identifier.
* `allowed_cidr_blocks` defaults to `["0.0.0.0/0"]`. Restrict it or use `[]` for Admin-managed security-group access only. This ingress default does not itself make the database publicly accessible.
* `db_storage_encrypted` defaults to `false`. Set it to `true` when creating a new encrypted database.
* `db_kms_key_id` selects a customer-managed KMS key when storage encryption is enabled.
* `db_instance_size`, `allocated_storage`, and `db_multi_az` determine capacity and availability.
* `snapshot_identifier` is only needed when creating a database from a snapshot.

## Inputs

* `hostname_prefix` required, string. Database identifier prefix; should match the Admin deployment.
* `deployment_name` optional, string, default `"1"`. Appends `-<deployment_name>` to the identifier when not `"1"`; should match the Admin deployment.
* `subnet_id` required, list of strings. At least two subnets in different Availability Zones in the same VPC. The first subnet determines the security group's VPC.
* `ia_secret_arn` required, string. Secrets Manager ARN containing `admin_db_id` and `admin_db_pw`.
* `additional_tags` optional, map of strings, default `{}`. Tags merged with the module's `Name` tag; the module's `Name` value takes precedence.
* `allowed_cidr_blocks` optional, list of strings, default `["0.0.0.0/0"]`. IPv4 CIDRs allowed to connect on TCP port 5432. Use `[]` to create no CIDR-based ingress rules.
* `deletion_protection` optional, bool, default `true`. RDS deletion protection; must be disabled before intentionally deleting the database.
* `apply_immediately` optional, bool, default `true`. Applies eligible database changes immediately rather than waiting for the maintenance window; changes may interrupt service.
* `allocated_storage` optional, number, default `100`. Allocated gp3 storage in GiB.
* `db_backup_retention` optional, number, default `3`. Automated backup retention in days.
* `db_backup_window` optional, string, default `"03:00-04:00"`. Daily backup window in UTC.
* `db_instance_size` optional, string, default `"db.m6g.large"`. RDS instance class.
* `db_kms_key_id` optional, string, default `""`. Customer-managed storage-encryption KMS key. An empty value leaves key selection to AWS when encryption is enabled. Changes are ignored after creation.
* `db_multi_az` optional, bool, default `true`. Enables an RDS Multi-AZ deployment.
* `db_storage_encrypted` optional, bool, default `false`. Enables encryption when creating the database. Changes are ignored after creation.
* `db_version` required, string. PostgreSQL engine version, for example `"17.9"`. Match the existing engine version when importing a database.
* `snapshot_identifier` optional, string, default `null`. Snapshot identifier or ARN to restore when creating a database. Must be `null` or a non-empty string. Changes are ignored after creation.

## Outputs

* `address` Database hostname without a port; pass this as `db_endpoint` to the Admin module.
* `identifier` RDS database instance identifier.
* `security_group_id` Database security group ID.

## Database Behavior

* The engine is PostgreSQL, the database name is `postgres`, and storage uses gp3.
* Automatic minor-version upgrades are disabled. Manage the desired engine version through `db_version` and review AWS upgrade requirements before changing it. This module does not expose an `allow_major_version_upgrade` input.
* The identifier is `hostname_prefix`, with `-deployment_name` appended when `deployment_name` is not `"1"`.
* Lifecycle rules ignore changes to `db_name`, `identifier`, `kms_key_id`, `snapshot_identifier`, `storage_encrypted`, and `username`. Changing the corresponding inputs does not update or replace an existing database. This is not a blanket guarantee against replacement; always review the plan.
* The module supplies a timestamped final snapshot identifier when deleting the database. Review the deletion plan and retain required backups before disabling deletion protection and destroying resources.
* The module reads database credentials from Secrets Manager. Protect the Terraform state as sensitive data; secret values used in resource configuration can be stored there.

## Admin Integration

After the RDS apply succeeds, obtain the hostname from the database root module:

```shell
terraform output -raw db_endpoint
```

In the separate Admin root module, set:

```hcl
enterprise_ha = true
db_endpoint   = "iris-admin-ha.abc123.us-west-2.rds.amazonaws.com"
```

Use the same application secret and matching `hostname_prefix` and `deployment_name` values. The Admin module looks up the existing RDS instance and manages its own PostgreSQL ingress rule. Its deprecated database inputs, including `db_version` and `allocated_storage`, are ignored; configure those settings here instead.

## Importing an Existing Admin Database

Import the existing database rather than applying a configuration that creates a second one. See the [Admin upgrade instructions](../admin/README.MD#upgrading-an-ha-deployment-that-created-its-own-database) for relinquishing its old database resources without destroying them.

1. Take a manual RDS snapshot and record the existing database identifier, hostname, subnet group name, security group ID, and ingress rule IDs.
2. Upgrade the Admin module, set `db_endpoint` to the existing hostname, and review its plan. Its legacy database resources must be removed from state without destruction. Apply that change before importing those resources into the RDS state.
3. Configure this module in a separate root module and state. Match the current engine version, instance class, storage, backup, encryption, Multi-AZ, and naming settings. Supply the existing credentials through `ia_secret_arn`.
4. Import the database and its supporting resources using the commands below. For each existing CIDR rule that this module will manage, import it into the matching `allowed_cidr_blocks` entry; do not create a duplicate rule. Admin-managed security-group access rules remain in the Admin state.
5. Run `terraform plan` in the RDS root module. Stop if it proposes destroying or replacing existing resources, or makes unintended database changes. Resolve configuration differences before applying. Never manage the same resource in both states.

Example import commands, run from the RDS root module and adjusted to the recorded resource IDs:

```shell
terraform import 'module.irisadmin_rds.aws_db_instance.this' '<db-identifier>'
terraform import 'module.irisadmin_rds.aws_db_subnet_group.this' '<db-subnet-group-name>'
terraform import 'module.irisadmin_rds.aws_security_group.this' 'sg-xxxxxxxxxxxxxxxxx'
terraform import 'module.irisadmin_rds.aws_vpc_security_group_ingress_rule.postgresql["10.0.0.0/16"]' 'sgr-xxxxxxxxxxxxxxxxx'
```

Import only ingress rules whose CIDRs are included in your RDS configuration. Any legacy rule not imported remains outside Terraform management; review it separately to avoid leaving unintended access in place.

## Snapshot Restore

For a new database restored from a snapshot, set `snapshot_identifier` to the snapshot identifier or ARN. The former Admin input `db_snapshot` is not an input to this module. Ensure the snapshot, credentials, engine version, encryption key, and target configuration are compatible with AWS restore requirements. Updating `snapshot_identifier` after creation does not restore or replace the database because changes to that field are ignored.