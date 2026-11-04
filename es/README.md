# Deploying GrayMeta Iris Anywhere Search with Terraform

This module deploys the search domain used by Iris Anywhere. The Terraform directory name is `es`, but the implementation provisions an AWS-managed OpenSearch / Elasticsearch-compatible domain plus a supporting Lambda function.

## Requirements

* Terraform 1.8.x or compatible.
* Two or more subnets when using the default zone-aware HA configuration.
* Secrets Manager entries ready to store the OpenSearch connection details used by Iris Anywhere.
* An `s3_enterprise` secret field containing a JSON-encoded string with a `buckets` array (see Bucket Indexing Workflow).
* An SSM-managed Windows Iris Admin instance with `C:\ProgramData\GrayMeta\functions\s3-index.exe` installed and credentials able to assume the indexing role.
* `search_enabled = true` in the Iris Anywhere ASG deployment when you want the application tier to use this search domain.

## Example Usage

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "ia_search" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//es?ref=<tag>"

  domain                          = "irisanywhere-es"
  instance_type                   = "t2.small.elasticsearch"
  subnet_id                       = ["subnet-foo1", "subnet-foo2"]
  ia_secret_arn                   = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-anywhere"
  admin_instance_id               = "i-0123456789abcdef0"
  arn_of_indexresource            = "arn:aws:iam::123456789012:role/indexer-role"
  custom_endpoint                 = "search.example.com"
  custom_endpoint_certificate_arn = "arn:aws:acm:us-west-2:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

## Minimum Root Module

Use this module only when the customer deployment requires search integration.

Required inputs for a first successful apply:

* `subnet_id`
* `ia_secret_arn`
* `arn_of_indexresource`
* `admin_instance_id`

Usually optional on the first apply:

* `domain`
* `instance_type`
* `instance_count`
* `allowed_cidr_blocks`
* `advanced_options`
* `security_groups`
* `manage_bucket_notifications`

Required only for specific deployment modes:

* `custom_endpoint` and `custom_endpoint_certificate_arn` when `custom_endpoint_enabled = true`.
* `encrypt_at_rest_kms_key_id` when using a customer-managed KMS key.
* `advanced_security_options_master_user_arn` when you need to pin a specific IAM principal as the advanced-security master user.

## Inputs

* `domain` optional, default `irisanywhere-es`. Search domain name.
* `instance_type` optional, default `t2.small.elasticsearch`. Search node instance type.
* `es_version` optional, default `OpenSearch_3.5`. Engine version.
* `tag_domain` optional, default `var.domain`. Tag value used by the module.
* `volume_type` optional, default `gp3`. EBS volume type.
* `ebs_volume_size` optional, default `10`. EBS volume size in GiB.
* `advanced_options` optional, default `{}`. Advanced domain options.
* `advanced_security_options_enabled` optional, default `true`. Enables advanced security options.
* `advanced_security_options_master_user_arn` optional, default `""`. Required when you want to pin a specific IAM principal as the advanced-security master user.
* `custom_endpoint_enabled` optional, default `true`. Enables the custom endpoint block.
* `custom_endpoint` optional, default `""`. Required when `custom_endpoint_enabled = true`.
* `custom_endpoint_certificate_arn` optional, default `""`. Required when `custom_endpoint_enabled = true`.
* `subnet_id` required. Subnet IDs where the domain will be deployed.
* `zone_awareness_enabled` optional, default `true`. Enables zone awareness.
* `availability_zone_count` optional, default `2`. Number of availability zones used by the domain. When zone awareness is enabled, this should match the number of subnets you intend to use.
* `instance_count` optional, default `2`. Number of data nodes.
* `node_to_node_encryption_enabled` optional, default `true`. Enables node-to-node encryption.
* `encrypt_at_rest_enabled` optional, default `true`. Enables encryption at rest.
* `encrypt_at_rest_kms_key_id` optional, default `""`. Required when `encrypt_at_rest_enabled = true` and you want a customer-managed KMS key.
* `domain_endpoint_options_enforce_https` optional, default `true`. Forces HTTPS.
* `domain_endpoint_options_tls_security_policy` optional, default `Policy-Min-TLS-1-2-PFS-2023-10`. TLS policy for the endpoint.
* `base_sg` optional, default `true`. Enables creation of the base security group path.
* `security_groups` optional, default `[]`. Additional security groups allowed to connect.
* `allowed_cidr_blocks` optional, default `["0.0.0.0/0"]`. Allowed CIDR blocks.
* `ia_secret_arn` required. Secrets Manager ARN used by the indexing Lambda and integration flow.
* `manage_bucket_notifications` optional, default `false`. Creates S3 notifications and Lambda invocation permissions for enabled enterprise buckets in the provider's active region. Enabling this gives Terraform ownership of each bucket's notification configuration; coordinate with any existing notification management before enabling it.
* `arn_of_indexresource` required. ARN of the trusted indexing role or resource.
* `admin_instance_id` required. Iris Admin EC2 instance ID targeted by the SSM association for initial S3 indexing.

## Removed Input: bucketlist

`bucketlist` is no longer accepted by this module. Remove it from module calls to avoid an `Unsupported argument` error. Bucket selection now comes from the `s3_enterprise` field in the secret referenced by `ia_secret_arn`, as described below.

Terraform input variables have no native `deprecated` attribute. For a backward-compatible deprecation period, retain the old variable with its existing type, make it optional with a suitable default, and mark its description and documentation as deprecated with migration instructions. Explicitly document whether it is ignored or still used as a fallback. Remove it only in a breaking release. A variable validation that rejects the old input is a breaking change, not a deprecation warning.

## Outputs

* `arn` Domain ARN.
* `domain_id` Domain ID.
* `domain_name` Domain name.
* `endpoint` Domain endpoint.
* `kibana_endpoint` Kibana / Dashboards endpoint.
* `subnet_id` Subnet IDs passed into the module.
* `domain_arn` Joined domain ARN output.
* `domain_endpoint` Joined endpoint output.
* `lambda_arn` ARN of the Lambda function used by the indexing flow.

## Post-Deployment Integration

After deployment, update the Iris Anywhere secret with the OpenSearch connection values used by the application:

* `os_region`
* `os_endpoint` is not read by this module's indexing Lambda; it uses `custom_endpoint` when enabled, otherwise the domain endpoint created by this module.
* `os_accessid`
* `os_secretkey`

Then redeploy or update the Iris Anywhere ASG with `search_enabled = true` and `es_domain_name` set appropriately.

## Bucket Indexing Workflow

The module reads bucket configuration from the Iris Anywhere secret. The `s3_enterprise` field must be a JSON-encoded string, not a nested JSON object. For example, the secret contains this field alongside its other settings:

```json
{
  "s3_enterprise": "{\"buckets\":[{\"name\":\"media-bucket-1\",\"enabled\":true,\"region\":\"us-west-2\"},{\"name\":\"media-bucket-2\",\"enabled\":true}]}"
}
```

Only buckets with `enabled = true` in the provider's active region are selected. If `enabled` is omitted, the bucket is excluded. If `region` is omitted, it defaults to the provider's active region.

An SSM association runs initial indexing on `admin_instance_id` using `C:\ProgramData\GrayMeta\functions\s3-index.exe` and the module's indexing role. Terraform waits up to 3600 seconds for the association to succeed. Ensure the instance is managed by SSM, the utility is installed, and its credentials can assume the indexing role and access the selected buckets and search domain.

Set `manage_bucket_notifications = true` to let this module configure ongoing S3 object-created and object-removed notifications to the indexing Lambda. The default is `false`; initial indexing still runs, but ongoing notifications must be managed separately.