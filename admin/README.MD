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

  hostname_prefix         = "iris-admin"
  instance_type           = "t3.xlarge"
  subnet_id               = ["subnet-foo1"]
  key_name                = "my-key"
  ia_secret_arn           = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-admin"
  associate_public_ip     = true
  rdp_access_cidr         = ["cidr1/32", "cidr2/32"]
  api_console_access_cidr = ["ia-subnet-1/24", "ia-subnet-2/24", "mycidr1/32"]
  iris_admin_ver          = "9.7.7.208"
}
```

Replace the CIDR placeholders with actual IPv4 CIDR blocks for the permitted RDP clients, Iris Anywhere subnets, and API/Admin UI clients.

## Enterprise HA Example

For RDS deployment and snapshot restore instructions, see the [RDS README](../rds/README.md).

Without `db_endpoint`, Iris Admin installs PostgreSQL locally. To use RDS, create the database first, in its own root module and state:

```hcl
module "irisadmin_rds" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//rds?ref=<tag>"

  hostname_prefix = "iris-admin-ha"
  subnet_id       = ["subnet-foo1", "subnet-foo2"]
  ia_secret_arn   = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-admin"
  db_version      = "17.11"
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

  rdp_access_cidr         = ["203.0.113.10/32", "203.0.113.20/32"]
  api_console_access_cidr = ["10.0.1.0/24", "10.0.2.0/24", "203.0.113.10/32"]
  hostname_prefix         = "iris-admin-ha"
  deployment_name         = "example"
  instance_type           = "t3.medium"
  subnet_id               = ["subnet-foo1", "subnet-foo2"]
  key_name                = "my-key"
  associate_public_ip     = true
  ia_secret_arn           = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-admin"
  ami                     = "ami-0123456789abcdef0"
  iris_admin_ver          = "9.7.7.208"

  enterprise_ha           = true
  db_endpoint             = "iris-postgres.abc123.us-west-2.rds.amazonaws.com"
  enterprise_ha_lb_public = true
  instance_count          = 2
  https_console_port      = 8021
}

output "alb_dns_name" {
  value       = module.irisadmin_ha.alb_dns_name_none
  description = "AWS DNS hostname of the Admin load balancer."
}

output "nlb_record_name" {
  value       = module.irisadmin_ha.nlb_record_name
  description = "Private DNS record name of the Admin load balancer."
}
```

Replace the example CIDRs and resource identifiers with your deployment values. Use an Iris Admin-compatible Windows AMI available in the target region and the endpoint of your separately deployed RDS database.

The NLB and target group are named using `hostname_prefix`, with `-deployment_name` appended when `deployment_name` is not `"1"`. Names are truncated to 32 characters; ensure the resulting names are unique in the account and region when old and new HA deployments coexist. Upgrading an existing HA deployment from the previous `iadm` naming scheme can replace its NLB and target group and change its endpoint; review the Terraform plan and DNS cutover before applying.

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

For example, set `db_version` on the RDS module to manage the PostgreSQL engine version, not on the Admin module. The RDS module requires an explicit `db_version`; when restoring a snapshot, select a version compatible with the snapshot and AWS restore requirements. When importing an existing database, match its current engine version rather than introducing an upgrade during the state migration.

`db_endpoint` is not deprecated. It remains the connection input for enterprise HA and should be set to the RDS module's `address` output (without a port). Database settings are not automatically transferred from the Admin module to the RDS module.

## Outputs

* `security_group` Admin security group ID.
* `private_dns` Private DNS names of the Admin instances.
* `private_ip` Private IP addresses of the Admin instances.
* `alb_dns_name` Load balancer DNS name list when HA is enabled.
* `alb_dns_name_none` Joined load balancer DNS name when HA is enabled.
* `nlb_record_name` Private NLB DNS record name, or empty when HA or private hosted zone creation is disabled.
* `endpoint` Database hostname used by Iris Admin (the value of `db_endpoint`), or empty when PostgreSQL is installed locally.

## Upgrading an HA Deployment That Created Its Own Database

Earlier versions of this module created the RDS database. The recommended migration creates a new RDS database from a snapshot and launches a new Admin deployment in separate Terraform states. Keep the old deployment on its original module version and state until it is retired; do not upgrade it in place for this workflow. Deployments that use local PostgreSQL do not need this RDS migration.

1. Create a manual snapshot of your current RDS database using the AWS console or CLI. Choose any snapshot name. For a database named `iris-postgres`, an example is:

  ```shell
  aws rds create-db-snapshot \
    --db-instance-identifier iris-postgres \
    --db-snapshot-identifier iris-postgres-migration \
    --region us-west-2
  ```

  Larger databases take longer to snapshot. You can prepare the configuration in Step 2 while the snapshot is being created. Schedule the cutover and stop writes to the old database before taking the final migration snapshot; writes made afterward will not be restored. Keep writes stopped until the new deployment is ready to serve them.

2. In your Terraform editor, create a new `rds` folder with a `main.tf` file containing the RDS deployment code. Use the snapshot from Step 1 as `snapshot_identifier`. To avoid a conflict with the existing database identifier, use a unique `hostname_prefix` and/or `deployment_name`. See the [RDS README](../rds/README.md) for example code and restore requirements. Keep this root module in its own Terraform state. Wait until the snapshot status is `available`, then run `terraform init`, `terraform plan`, and `terraform apply` from this folder. Confirm the new RDS database is available and record its endpoint before continuing.

3. After the RDS deployment succeeds, create a new `admin` folder with its own `main.tf` and separate Terraform state. Use the [Enterprise HA example](#enterprise-ha-example) and the latest released GrayMeta `/admin` module version. Set `db_endpoint` to the new RDS hostname and use the appropriate application secret. Inputs have changed in the latest version, so run `terraform init` and `terraform plan` before `terraform apply`. Confirm the plan creates the new Admin infrastructure without modifying the old deployment.

4. Configure the newly launched Iris Admin server. If applicable, update Route 53 DNS to point to the new Admin server or load balancer. Contact GrayMeta for a new license and concurrent key, if required. Iris Admin serves API requests from Iris Anywhere, so update the Iris Anywhere Server Settings > API Server Location URL to the new Admin API location, for example `nlb.{hostname_prefix}-{deployment_name}-iris-admin.internal`. Use the actual hostname, protocol, and port configured for your deployment.

5. Update the `admin_server` field in the existing AWS Secrets Manager application secret to reference the new RDS endpoint, using the AWS console or your preferred method. The existing Iris Anywhere Terraform deployment must be destroyed and relaunched for this initialization setting to take effect. Review `terraform plan -destroy` in the Iris Anywhere root module before running `terraform destroy`, then `terraform apply` to relaunch it. Confirm the plan does not include the new RDS or Admin resources, verify connectivity and application data, and resume writes only after the cutover is verified.

### Retiring the Old Deployment

Once you are satisfied with the new Iris Admin and Iris Anywhere deployment, retire the previously installed Admin module. Retain the migration snapshot and any required backups.

1. Disable termination protection on each old Admin EC2 instance using the AWS console or CLI. Replace the example instance ID and region:

  ```shell
  aws ec2 modify-instance-attribute \
    --instance-id "i-0123456789abcdef0" \
    --disable-api-termination '{"Value": false}' \
    --region us-west-2
  ```

  Disable deletion protection on the old RDS database if enabled, and ensure the original Terraform configuration will not re-enable protection before deletion. Review final snapshot settings before destroying the database.

2. Navigate to the old Admin root module, using its original module version and Terraform state. Run `terraform plan -destroy` to preview removal of the old RDS database, Admin instances, and load balancer. This command does not delete resources. Confirm only the old infrastructure is included, then run `terraform destroy` and review the confirmation before approving deletion. If the old RDS resources have already been relinquished from this state, Terraform will not delete them; inventory and retire those resources separately.

3. Once the old infrastructure is destroyed and the new deployment is verified, the migration is complete. Continue managing the new RDS and Admin deployments independently in their respective root modules and Terraform states.

Alternatively, to keep the existing database rather than create a snapshot restore, this version can relinquish its legacy RDS resources without deleting them. Set `db_endpoint` to the existing database hostname, then review the Admin plan: the legacy database, subnet group, security group, and ingress rule must no longer be managed but must not be destroyed or replaced. Apply that change before importing the database and supporting resources into a separate root module using the `rds` module. See [Importing an Existing Admin Database](../rds/README.md#importing-an-existing-admin-database) for the import steps. Do not manage the same resources in both Terraform states.

## Licensing

After deployment, contact support@graymeta.com for product licensing.
