# Deploying GrayMeta Iris Anywhere with Terraform

This module deploys the Iris Anywhere application tier on AWS. It supports an ALB-based deployment and an optional HAProxy-based deployment.

Note: IAM resources are account-scoped, not regional. If you reuse the same role or policy names across regional deployments, manage them from one Terraform state or use region-specific names so one region does not delete resources another region still needs.

## Requirements

* Terraform 1.8.x or compatible.
* Required Secrets Manager entries created before deployment.
* An EC2 key pair created in the target AWS region before deployment.
* Access to the GrayMeta Iris Anywhere AMIs. Contact support@graymeta.com.
* ACM certificates when using the ALB path.
* If the Iris Admin server is deployed in a different AWS region than the Iris Anywhere application tier, complete inter-region network connectivity before deployment. This includes a VPC peering connection between the regions and the required route table entries on both sides so the application tier can reach Iris Admin.

## ALB Example

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisanywhere1" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=<tag>"

  hostname_prefix = "iris-cluster-1"
  instance_type   = "c7a.4xlarge"
  key_name        = "my-key"
  subnet_id       = ["subnet-foo1", "subnet-foo2"]
  ia_secret_arn   = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-anywhere"
  ssl_alb_acm_arn = "arn:aws:acm:us-west-2:123456789012:certificate/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

## HAProxy Example

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisanywhere1" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=<tag>"

  hostname_prefix             = "iris-cluster-1"
  instance_type               = "c7a.4xlarge"
  key_name                    = "my-key"
  subnet_id                   = ["subnet-foo1", "subnet-foo2"]
  ia_secret_arn               = "arn:aws:secretsmanager:us-west-2:123456789012:secret:iris-anywhere"
  haproxy                     = true
  instance_type_ha            = "t3.xlarge"
  ssl_haproxy_cert_secret_arn = "arn:aws:secretsmanager:us-west-2:123456789012:secret:haproxy-cert"
}
```

## Minimum Root Module

Use this module after Iris Admin is already deployed, licensed, and reachable from the application tier.

Required for a first successful apply:

* `hostname_prefix`
* `instance_type`
* `key_name`
* `subnet_id`
* `ia_secret_arn`
* `ssl_alb_acm_arn` when `haproxy = false`

Usually optional on the first apply:

* `access_cidr`
* `rdp_access_cidr`
* `tags`
* `base_ami`
* autoscaling tuning inputs such as `asg_size_*`, `asg_scalein_*`, and `asg_scaleout_*`
* `iam_role_name`
* `user_init`

Required only for specific deployment modes:

* `haproxy = true` when you want the HAProxy path instead of the ALB path.
* `instance_type_ha`, `mgmt_cidr`, and `ssl_haproxy_cert_secret_arn` when `haproxy = true`.
* `search_enabled = true` plus `es_domain_name` when search integration is enabled.
* `ia_cert_crt_arn`, `ia_cert_key_arn`, and `ia_domain` when enabling end-to-end TLS to the application nodes.
* `saml_enabled = true` plus `saml_cert_secret_arn` when enabling SAML.
* `otlp_enabled = true` plus `otlp_exporter_destination` when enabling OTLP export.

## Inputs

Core inputs:

* `access_cidr` optional, default `["0.0.0.0/0"]`. Allowed CIDR blocks for application access.
* `alb_internal` optional, default `false`. Makes the ALB internal. Applies only when `haproxy = false`.
* `asg_check_interval` optional, default `60`. CloudWatch sampling period in seconds.
* `asg_scalein_cooldown` optional, default `70`. ASG scale-in cooldown in seconds.
* `asg_scalein_evaluation` optional, default `30`. Number of evaluation periods for scale in.
* `asg_scalein_threshold` optional, default `3`. Scale-in threshold.
* `asg_scaleout_cooldown` optional, default `70`. ASG scale-out cooldown in seconds.
* `heartbeat_timeout` optional, default `600`. Lifecycle hook timeout in seconds.
* `asg_scaleout_evaluation` optional, default `2`. Number of evaluation periods for scale out.
* `asg_scaleout_adjustment` optional, default `1`. Number of instances to add during scale out.
* `asg_scaleout_threshold` optional, default `1`. Scale-out threshold.
* `asg_size_desired` optional, default `1`. Desired ASG size.
* `asg_size_max` optional, default `1`. Maximum ASG size.
* `asg_size_min` optional, default `1`. Minimum ASG size.
* `base_ami` optional, default `""`. Override AMI ID for the application instances.
* `disk_data_iops` optional, default `3000`. Provisioned IOPS for the data volume when supported.
* `disk_data_size` optional, default `300`. Data EBS volume size in GiB.
* `disk_data_type` optional, default `io2`. Data EBS volume type.
* `disk_os_size` optional, default `60`. Root EBS volume size in GiB.
* `disk_os_type` optional, default `gp3`. Root EBS volume type.
* `hostname_prefix` required. Name prefix used for deployed resources.
* `iam_policy_enabled` optional, default `true`. Enables custom IAM policy attachment.
* `iam_role_name` optional, default `""`. Existing or desired IAM role name.
* `instance_type` optional, default `c5n.9xlarge`. EC2 instance type for application nodes.
* `deployment_name` optional, default `"1"`. Overrides the naming suffix derived from instance type.
* `key_name` required. EC2 key pair name.
* `lb_algorithm_type` optional, default `least_outstanding_requests`. Target group algorithm.
* `lb_check_interval` optional, default `30`. Load balancer health check interval in seconds.
* `lb_unhealthy_threshold` optional, default `2`. Load balancer unhealthy threshold.
* `s3_policy` optional, default `{}`. IAM policy JSON for S3 access.
* `ssl_certificate_arn` optional, default `null`. Deprecated. Use `ssl_alb_acm_arn`.
* `ssl_alb_acm_arn` optional, default `null`. ACM certificate ARN for the ALB path. Required when `haproxy = false` and you are terminating TLS on the ALB.
* `subnet_id` required. Subnet IDs where resources are launched.
* `tags` optional, default `{}`. Resource tag map.
* `ia_cert_crt_arn` optional, default `""`. Secret ARN for the application certificate. Required together with `ia_cert_key_arn` when enabling end-to-end TLS between the load balancer and the application nodes.
* `ia_cert_key_arn` optional, default `""`. Secret ARN for the application private key. Required together with `ia_cert_crt_arn` when enabling end-to-end TLS between the load balancer and the application nodes.
* `ia_secret_arn` required. Secrets Manager ARN containing the application secrets.
* `ia_max_sessions` optional, default `3`. Max sessions per instance.
* `ia_domain` optional, default `""`. Domain suffix used with end-to-end TLS. Required when `ia_cert_crt_arn` and `ia_cert_key_arn` are set.
* `user_init` optional, default `""`. Custom user-init PowerShell.
* `sqs_arn_s3` optional, default `""`. SQS ARN used for S3 polling.
* `search_enabled` optional, default `false`. Enables search integration.
* `es_domain_name` optional, default `""`. Required when `search_enabled = true`.
* `ia_video_codec` optional, default `VP8`. Stream video codec.
* `ia_video_bitrate` optional, default `10000`. Stream video bitrate in Kbps.
* `asg_warm_pool_min` optional, default `1`. Warm pool minimum size.
* `asg_warm_pool_max` optional, default `1`. Warm pool maximum prepared capacity.
* `alb_cookie_duration` optional, default `60`. ALB cookie duration in seconds.
* `s3_enterprise` optional, default `true`. Enables enterprise S3 config-map behavior.
* `associate_public_ip` optional, default `true`. Associates public IPs to application instances.
* `update_asg_lt` optional, default `true`. Marks the latest launch template version as default.
* `haproxy` optional, default `false`. Enables the HAProxy path instead of the ALB path.
* `terminate_on_shutdown` optional, default `false`. Terminates ASG instances when the guest shuts down.
* `saml_enabled` optional, default `false`. Enables SAML configuration on application instances.
* `saml_cert_secret_arn` optional, default `""`. Secret ARN containing the SAML IdP certificate. Required when `saml_enabled = true`.
* `ia_keepalivetimeout` optional, default `5`. Session keep-alive timeout in seconds.
* `rdp_access_cidr` optional, default `["0.0.0.0/32"]`. Allowed CIDR blocks for RDP.
* `disable_rdp` optional, default `false`. Disables RDP ingress.
* `wasabi` optional, default `false`. Uses Wasabi storage instead of S3 for rclone.
* `deregistration_delay` optional, default `0`. Load balancer deregistration delay in seconds.
* `otlp_enabled` optional, default `false`. Enables OTLP integration.
* `otlp_exporter_destination` optional, default `""`. OTLP destination for metrics and logs. Required when `otlp_enabled = true`.

HAProxy-specific inputs:

* `mgmt_cidr` optional, default `["0.0.0.0/32"]`. Allowed management CIDR blocks for HAProxy. Applies only when `haproxy = true`.
* `ami` optional, default `""`. Override AMI ID for HAProxy. Applies only when `haproxy = true`.
* `instance_type_ha` optional, default `t3.xlarge`. HAProxy instance type. Required when `haproxy = true` unless the default is acceptable.
* `volume_type` optional, default `gp3`. HAProxy root volume type. Applies only when `haproxy = true`.
* `volume_size` optional, default `60`. HAProxy root volume size in GiB. Applies only when `haproxy = true`.
* `instance_count` optional, default `1`. Number of HAProxy instances. Applies only when `haproxy = true`.
* `haproxy_eip_allocation_id` optional, default `null`. Existing Elastic IP allocation ID for HAProxy. Applies only when `haproxy = true`.
* `ssl_haproxy_cert_secret_arn` optional, default `null`. Secret ARN containing the HAProxy certificate bundle. Required when `haproxy = true` and TLS is terminated on HAProxy.
* `ssl_certificate_cert` optional, default `null`. Deprecated. Use `ssl_haproxy_cert_secret_arn`.
* `instance_protection` optional, default `false`. Enables EC2 instance protection on HAProxy. Applies only when `haproxy = true`.
* `additional_tags` optional, default `{}`. Additional resource tag map. Applies only to HAProxy resources.
* `hap_loglevel` optional, default `info`. HAProxy logging level. Applies only when `haproxy = true`.
* `haproxy_user_init` optional, default `""`. Custom HAProxy user-init script. Applies only when `haproxy = true`.

## Outputs

* `alb_dns_name` ALB DNS name when `haproxy = false`.
* `asg_name` Auto Scaling group name.
* `nsg_alb_id` ALB security group ID.
* `nsg_iris_id` Application instance security group ID.
* `access_cidr` Effective access CIDR blocks.
* `asg_check_interval`
* `asg_scalein_cooldown`
* `asg_scalein_evaluation`
* `asg_scalein_threshold`
* `asg_scaleout_cooldown`
* `asg_scaleout_evaluation`
* `asg_scaleout_threshold`
* `asg_size_desired`
* `asg_size_max`
* `asg_size_min`
* `base_ami`
* `disk_data_size`
* `disk_data_type`
* `disk_os_size`
* `disk_os_type`
* `hostname_prefix`
* `instance_type`
* `key_name`
* `lb_check_interval`
* `lb_unhealthy_threshold`
* `ssl_certificate_arn`
* `subnet_id`
* `tags`
* `ha_proxy_fqdn_private` HAProxy private DNS when `haproxy = true`.
* `ha_proxy_fqdn_public` HAProxy public DNS when `haproxy = true` and `associate_public_ip = true`.
* `ha_proxy_private_ip` HAProxy private IP when `haproxy = true`.
* `ha_proxy_lb_fqdn` HAProxy load balancer DNS output from the HAProxy path.
* `ha_proxy_public_ip` HAProxy public IP output from the HAProxy path.
* `ia_domain`
* `haproxy`
* `base_policy_text`
* `local_policy_text`
* `vpc_dns_support_enabled`
* `vpc_dns_hostnames_enabled`

## DNS

Create a DNS record for the deployment endpoint after apply. For the ALB path, this is typically a CNAME pointing to the load balancer DNS name.
