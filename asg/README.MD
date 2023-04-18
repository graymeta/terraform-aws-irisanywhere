# Deploying GrayMeta Iris Anywhere with Terraform

The following contains instructions/criteria for deploying Iris Anywhere into an AWS environment.  Iris Anywhere is comprised of two key components, the Iris Admin Server that manages Users, permissions and Licenses and the Iris Anywhere Autoscaling Group that deploy the instances for usage. Iris Anywhere Autoscaling Group will not properly function without a dedicated Iris Admin Server deployed first. 

Prerequisites:
* Stored credentials in [Secrets Manager](#creating-secrets-for-iris-anywhere) prior to deploying.
* Access to GrayMeta Iris Admin and Iris Anywhere AMI's - Contact support@graymeta.com.
* Certificates created or imported in AWS Certificate Manager.
* Terraform 1.2.X or later compatible
* No AWS Root user security context should be used in the deployment of any/all Iris Anywhere services.  Please follow the policy of least privilege for all access granted as part of the deployment. 

***

## Resulting AWS Services and Architecture Diagram

![Iris Anywhere FTR](https://user-images.githubusercontent.com/13397511/191809033-b4e93fe0-42c7-4edb-baaa-132d439abcfc.jpg)


***
## Iris Anywhere Autoscaling Groups
Deploys Application Load Balancer and Autoscaling group.  We recommend that you do not deploy your Autoscaling Groups until your Iris Admin Server has been licensed with GrayMeta (support@graymeta.com).

## Example Usage
```
provider "aws" {
  region  = "my-region-id"
  profile = "my-aws-profile"
}


locals {
    s3buckets = [
            "media-content-bucket1", 
            "media-content-bucket2"
            ]
    s3meta = ["media-meta-bucket1"]
    }

module "irisanywhere1" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=v0.0.latest-tag-id"
  
    hostname_prefix             = "iris-cluster-1"
    instance_type               = "c5n.9xlarge"
    key_name                    = "my_key"
    ssl_certificate_arn         = "<cert_arn>"
    subnet_id                   = ["subnet-foo1", "subnet-foo2"]
    ia_secret_arn               = "arn:aws:secretsmanager:secret:1234567913397769129"
    iam_role_name               = "ia-role-prod"
    s3_enterprise               = "true"
    ia_max_sessions             = 3
    iam_policy_enabled          = true
    iam_role_name               = "prod-irisanywhere-role"
    
    
    s3_policy                   = templatefile("${path.module}/policy.json",
    {
      s3arns                    = [for i in local.s3buckets : "arn:aws:s3:::${i}"],
      s3objs                    = [for i in local.s3buckets : "arn:aws:s3:::${i}/*"],
      s3meta                    = [for i in local.s3meta : "arn:aws:s3:::${i}/*"],
      })
}
    

```


## Example Usage with HAProxy
```
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}


locals {
    s3buckets = [
            "media-content-bucket1", 
            "media-content-bucket2"
            ]
    s3meta = ["media-meta-bucket1"]
    }

module "irisanywhere1" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=v0.0.latest-tag-id"
  
    hostname_prefix             = "iris-cluster-1"
    instance_type               = "c5n.9xlarge"
    key_name                    = "my_key"
    ssl_certificate_arn         = "<cert_arn>"
    subnet_id                   = ["subnet-foo1", "subnet-foo2"]
    ia_secret_arn               = "arn:aws:secretsmanager:secret:1234567913397769129"
    iam_role_name               = "ia-role-prod"
    s3_enterprise               = "true"
    ia_max_sessions             = 3
    iam_policy_enabled          = true
    iam_role_name               = "prod-irisanywhere-role"
    
    s3_policy                   = templatefile("${path.module}/policy.json",
    {
      s3arns                    = [for i in local.s3buckets : "arn:aws:s3:::${i}"],
      s3objs                    = [for i in local.s3buckets : "arn:aws:s3:::${i}/*"],
      s3meta                    = [for i in local.s3meta : "arn:aws:s3:::${i}/*"],
      })
    
}

#Required by HAproxy
    haproxy                     = true
    ssl_certificate_cert        = "arn of secrets manager for cert in complete chain format (key, cert, intermediate, root)"

    
```

### Argument Reference:
The following arguments are supported:
* `access_cidr` - (Optional) List of network cidr that have access.  Default to `["0.0.0.0/0"]`
* `alb_internal` - (Optional) sets the application load balancer for Iris Anywhere to internal mode.  When set to `true` this also disables allocating public IP addresses to Iris Anywhere EC2 instances. Default to `false`
* `asg_check_interval` - (Optional) Autoscale check interval.  Default to `60` (seconds)
* `asg_scalein_cooldown` - (Optional) Scale in cooldown period.  Default to `300` (seconds)
* `asg_scalein_evaluation` - (Optional) Scale in evaluation periods.  Default to `2` (evaluation periods)
* `asg_scalein_threshold` - (Optional) Scale in if the number of sessions drop below.  Default to `5`
* `asg_scaleout_cooldown` - (Optional) Scale out cooldown period.  Default to `300` (seconds)
* `asg_scaleout_evaluation` - (Optional) Scale out evaluation periods. Default to `2` (evaluation periods)
* `asg_scaleout_threshold` - (Optional) Scale out if the number of sessions drop below.  Default to `5`
* `asg_size_desired` - (Optional) The number of EC2 instances that should be running in the group.
* `asg_size_max` - (Optional) Maximum size of the Auto Scaling Group.
* `asg_size_min` - (Optional) Minimum size of the Auto Scaling Group.
* `warm_pool` (Optional) "Defaults to false, requires warm_pool = { enabled = true} in config to enable. To disable, remove from config"
* `asg_warm_pool_min` - (Optional) Minimum size of the Auto Scaling Group Warm Pool. Default is 1.
* `asg_warm_pool_max` - (Optional) Maximum size of the Auto Scaling Group Warm Pool. Default is 1.
* `base_ami` - (Optional) The AMI from which to launch the instance.  Default to latest released AMI
* `disk_data_iops` - (Optional) The amount of provisioned IOPS. Default to 3000.
* `disk_data_size` - (Optional) EBS volume size.  Default to `300`
* `disk_data_type` - (Optional) EBS volume type.  Default to `io2`
* `disk_os_size` - (Optional) EBS volume size.  Default to `60`
* `disk_os_type` - (Optional) EBS volume type.  Default to `gp3`
* `hostname_prefix` - (Required) A unique name.
* `iam_policy_enabled` - (Required) Enables the ability to add custom IAM policies for the instance profile
* `instance_type` - (Optional) The type of the EC2 instance. Default set to c5n.9xlarge.
* `key_name` - (Required) The key name to use for the instances.
* `lb_algorithm_type` - (Optional) Determines how the load balancer selects targets when routing requests.  The value is round_robin or least_outstanding_requests.  Default to `least_outstanding_requests`
* `lb_check_interval` - (Optional) Loadbalancer health check interval. Default to `30` (seconds)
* `lb_unhealthy_threshold` - (Optional) Loadbalancer unhealthy threshold.  Default to `2` (evaluation periods)
* `s3_policy` - (Required) Provides customers the ability to supply their own IAM policy for instance profile to access S3 buckets - file("custom_policy.json")
* `ssl_certificate_arn` - (Required) The ARN from ACM of the SSL server certificate for Load Balancer.
* `subnet_id` - (Required) A list of subnet IDs to launch resources in.
* `tags` - (Optional) A map of the additional tags.
* `ia_cert_crt_arn` - (Optional) ARN from AWS Secrets. This enables end to end SSL on Iris Anywhere application server. Blank will force non-SSL between LB and Server.  Default to `disabled`
* `ia_cert_key_arn` - (Optional) ARN from AWS Secrets. This enables end to end SSL on Iris Anywhere application server. Blank will force non-SSL between LB and Server.  Default to `disabled`
* `ia_domain` - (Required) domain name of SSL wildcard SSL used for end to end SSL, ie "yourdomain.com", or "test.yourdomain.com". Domain must match cert SAN.
* `ia_secret_arn` - (Required) ARN of secrets for configurating Iris Anywhere.
* `ia_max_sessions` - (Required) Set max sessions per Iris Anywhere instance before autoscaling.
* `iam_role_name` - (Required) Set name for IAM Role.
* `search_enabled` - (Optional) Enable use of Elastic Search for s3 indexing.
* `s3_sse_cmk_enabled` - (Optional) Enables S3 SSE CMK for customers with managed keys.
* `s3_sse_cmk_arn` - (Optional) ARN of Customer Managed KMS Key.
* `ia_video_bitrate` - (Optional) Sets video bitrate for Iris Anywhere. Default is `10000`.
* `ia_video_codec` - (Optional) Sets video codec for Iris Anywhere streams. Default is VP8.
* `ia_keepalivetimeout` - (Optional) Sets timeout value when sessions are idle and no QC operations/activity occur. Default is 5.
* `asg_warm_pool_min` - (Optional) Warm pool minimum value. Default is `off`
* `asg_warm_pool_max` "(Optional) Warm pool maximum value
* `update_asg_lt` - (Optional) Updates launch template to latest. Default is true
* `s3_progressive_retrieval` = (Optional) Sets the s3 download retrieval option for Iris Anywhere.  Default to `True`
* `s3_reclaim_maxused` = (Optional) Sets the Max used scratch space available threshold before data is offlined.  Default to `90` 
* `s3_reclaim_minused` = (Optional) Sets the Minimum used scratch space available threshold before data is offlined.  Default to `80` 
* `s3_reclaim_age` (Optional) Sets the age of files threshold for data stored before data is offlined.  Default to `8h`
* `s3_enterprise` (Optional) "Uses Config Map for S3 buckets configured with SSE - Contact GrayMeta for key/value info. Default set to `false`"
* `haproxy` (Optional) "When set to enable, used haproxy as a load balancer instead of AWS ALB. Default set to `false` "
* `mgmt_cidr` (Optional) "Subnet used to allow access to stats and ssh to HAProxy. Default is `["0.0.0.0/32"]`"
* `ssl_certificate_cert` (Optional) "When HAProxy is enabled this certificate is used to terminate SSL on the load balancer. Cert with full chain (key, cert, intermediates) required" Place contents of cert in Secrets Manager and reference the arn of the secret to configure the LB.
* `hap_loglevel` (Optional) "Logging level for Haproxy. May use info, debug, notice, error. Default is `warning`."
* `saml_enabled` (Optional) ". Enables SAML in iris anywhere deployments. Requires populating secrets manager with configuration items. See secrets for more information. Default is `false`."
* `saml_cert_secret_arn` (Optional) "Secret ARN containing SAML IDP certificate. Default is `null`. See Secrets for more info"
* `disable_rdp` (Optional) "Disables RDP for Iris Anywhere instances. Defaults to `false`"
* `rdp_access_cidr` (Optional) "Specifies the network range for RDP. Default to `["0.0.0.0/32"]`"


### Attributes Reference:
In addition to all the arguments above the following attributes are exported:
* `alb_dns_name` - The DNS name of the load balancer.
* `asg_name` - The autoscaling group name
* `nsg_alb_id` - Network Security Group for ALB
* `nsg_iris_id` - Network Security Group for ASG instances

### Optional Additional Resources

Set your own scaling schedule. For example, if you expect more usage during business hours Monday - Friday, you can plan your scaling actions accordingly.

Example: Add a resource block like this to your `main.tf`.

```
resource "aws_autoscaling_schedule" "iris1_schedule_start" {
  scheduled_action_name  = "iris1-schedule-start"
  recurrence             = "0 16 * * MON-FRI"
  desired_capacity       = 2
  max_size               = 10
  min_size               = 2
  autoscaling_group_name = module.iris1.asg_name
}

resource "aws_autoscaling_schedule" "iris_anywhere_9xl_schedule_end" {
  scheduled_action_name  = "iris1-schedule-end"
  recurrence             = "0 6 * * MON-FRI"
  desired_capacity       = 0
  max_size               = 10
  min_size               = 0
  autoscaling_group_name = module.iris1.asg_name
}
```

`recurrence` - (Optional) The time when recurring future actions will start. Start time is specified by the user following the Unix cron syntax format.   Based on UTC/GMT.
`desired_capacity`, `max_size`, `min_size` - (Optional) Default `0`. Set to `-1` if you don't want to change the value at the scheduled time.


Secrets required for End to End SSL (optional).  Create two seperate secret credentials:
* `Certificate in X509 DER format` in plain text.
* `Certificate Private Key` in plain text.

### Creating DNS for the Iris ASG load balancer
Create a DNS record for your Iris Anywhere implementation. A CNAME pointing to the load balancer.
***
