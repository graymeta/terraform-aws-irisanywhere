# Deploying GrayMeta Iris Anywhere Search with Terraform

This module deploys the search domain used by Iris Anywhere. The Terraform directory name is `es`, but the implementation provisions an AWS-managed OpenSearch / Elasticsearch-compatible domain plus a supporting Lambda function.

## Requirements

* Terraform 1.8.x or compatible.
* Two or more subnets when using the default zone-aware HA configuration.
* Secrets Manager entries ready to store the OpenSearch connection details used by Iris Anywhere.
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
  bucketlist                      = "media-bucket-1,media-bucket-2"
  arn_of_indexresource            = "arn:aws:iam::123456789012:role/indexer-role"
  custom_endpoint                 = "search.example.com"
  custom_endpoint_certificate_arn = "arn:aws:acm:us-west-2:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

## Minimum Root Module

Use this module only when the customer deployment requires search integration.

Required for a first successful apply:

* `domain`
* `subnet_id`
* `ia_secret_arn`
* `bucketlist`
* `arn_of_indexresource`

Usually optional on the first apply:

* `instance_type`
* `instance_count`
* `allowed_cidr_blocks`
* `advanced_options`
* `security_groups`

Required only for specific deployment modes:

* `custom_endpoint` and `custom_endpoint_certificate_arn` when `custom_endpoint_enabled = true`.
* `encrypt_at_rest_kms_key_id` when using a customer-managed KMS key.
* `advanced_security_options_master_user_arn` when you need to pin a specific IAM principal as the advanced-security master user.

## Inputs

* `domain` optional, default `irisanywhere-es`. Search domain name.
* `instance_type` optional, default `t2.small.elasticsearch`. Search node instance type.
* `es_version` optional, default `OpenSearch_1.0`. Engine version.
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
* `bucketlist` required. Comma-separated bucket list used by the indexing workflow.
* `arn_of_indexresource` required. ARN of the trusted indexing role or resource.

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
* `os_endpoint`
* `os_accessid`
* `os_secretkey`

Then redeploy or update the Iris Anywhere ASG with `search_enabled = true` and `es_domain_name` set appropriately.

## Bucket Indexing Workflow

The repository also contains helper content for indexing S3 buckets into the search domain. To use that workflow:

* Install the indexing utility on the Iris Admin server.
* Configure AWS credentials with access to the target bucket and search domain.
* Run the indexing command with the correct region, bucket, and domain values.