# terraform-aws-irisanywhere

## Iris Anywhere deployment with Terraform on AWS

Deploys:

- Autoscaling Group
- Application Load Balancer
- Security Group, IAM role, IAM policy


### Example:

```
main.tf

provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "iris_anywhere_9xl" {
  source = "https://github.com/graymeta/terraform-aws-irisanywhere?ref=v0.0.1"

  access_cidr             = ["0.0.0.0/0"]
  asg_size_desired        = 1
  asg_size_max            = 5
  asg_size_min            = 1
  disk_data_iops          = 2000
  disk_data_size          = 500
  disk_data_type          = "io2"
  disk_os_size            = 100
  hostname_prefix         = "iris-anywhere"
  instance_type           = "c5d.9xlarge"
  key_name                = "my_key"
  ssl_certificate_arn     = "cert_arn"
  subnet_id               = ["subnet-foo1", "subnet-foo2"]
  tags                    = {
    "my_tag1" = "my_value1",
    "my_tag2" = "my_value2"
  }

  # Entries for IrisAnywhere and S3 information
  ia_lic_content          = ""
  ia_cert_file            = ""
  ia_cert_key_content     = ""
  ia_s3_conn_id           = "licenced-email@domain.com"
  ia_s3_conn_code         = "licensecode"
  ia_customer_id          = "customerID"
  ia_admin_server         = "iris-admin.fqdn.com"
  ia_service_acct         = "iris-service"
  ia_bucket_name          = "bucketname"
  ia_accecss_key          = "accesskeyvalue"
  ia_secret_key           = "secretkeyvalue"
}
```

### Arguement Reference
The following arguments are supported:
* `access_cidr` - (Optional) List of network cidr that have access.  Default to `["0.0.0.0/0"]`
* `asg_check_interval` - (Optional) Autoscale check interval.  Default to `60`
* `asg_scalein_cooldown` - (Optional) Scale in cooldown period.  Default to `300`
* `asg_scalein_evaluation` - (Optional) Scale in evaluation periods.  Default to `2`
* `asg_scalein_threshold` - (Optional) Scale in if the number of sessions drop below.  Default to `5`
* `asg_scaleout_cooldown` - (Optional) Scale out cooldown period.  Default to `300`
* `asg_scaleout_evaluation` - (Optional) Scale out evaluation periods. Default to `2`
* `asg_scaleout_threshold` - (Optional) Scale out if the number of sessions drop below.  Default to `5`
* `asg_size_desired` - (Required) The number of EC2 instances that should be running in the group.
* `asg_size_max` - (Required) Maximum size of the Auto Scaling Group.
* `asg_size_min` - (Required) Minimum size of the Auto Scaling Group.
* `base_ami` - (Optional) The AMI from which to launch the instance.  Default to latest released AMI
* `disk_data_iops` - (Optional) The amount of provisioned IOPS. This must be set with a volume_type of io1/io2.
* `disk_data_size` - (Optional) EBS volume size.  Default to `300`
* `disk_data_type` - (Optional) EBS volume type.  Default to `io2`
* `disk_os_size` - (Optional) EBS volume size.  Default to `50`
* `disk_os_type` - (Optional) EBS volume type.  Default to `gp3`
* `hostname_prefix` - (Required) A unique name.
* `instance_type` - (Required) The type of the EC2 instance.
* `key_name` - (Required) The key name to use for the instances.
* `lb_check_interval` - (Optional) Loadbalancer health check interval. Default to `30`
* `lb_unhealthy_threshold` - (Optional) Loadbalancer unhealthy threshold.  Default to `2`
* `ssl_certificate_arn` - (Required) The ARN of the SSL server certificate.
* `subnet_id` - (Required) A list of subnet IDs to launch resources in.
* `tags` - (Optional) A map of the additional tags.

* `ia_lic_content` - (Optional) License file contents for Iris Admin Server
* `ia_cert_file` - (Optional) This enables SSL with non ACM deployments. Certificate format must be in x509 DER
* `ia_cert_key_content` - (Optional) Private Key matching the cert file.
* `ia_max_sessions` - (Optional) - Set max sessions per Iris Anywhere instance before autoscaling.
* `ia_s3_conn_id` - (Required) S3 Connector license ID. Provided by GrayMeta upon licensing
* `ia_s3_conn_code` - (Required) S3 Connector license code (this will be accompanied with S3 Connector ID). Provided by GrayMeta
* `ia_customer_id` - (Required) The customer id associates your Iris Anywhere instances to Iris Admin (licensing). Provided by Graymeta upon licensing
* `ia_admin_server` - (Required) Host name of Iris Admin installation. Provided by customer.
* `ia_service_acct` - (Required) Name of service account used to manage Iris Anywhere. Provided by customer.
* `ia_bucket_name` - (Required) Name of S3 bucket containing assets. Provided by customer.
* `ia_accecss_key` - (Required) Access key value to permit access to Iris Anywhere. Provided by customer.
* `ia_secret_key` - (Required) - secret key to match access key. Provided by customer.



### Attributes Reference
In addition to all the arguements above the following attributes are exported:
* `alb_dns_name` - The DNS name of the load balancer.
* `asg_name` - The autoscaling group name
* `nsg_alb_id` - Network Security Group for ALB
* `nsg_iris_id` - Network Security Group for ASG instances

***
### Optional

Set your own scaling schedule. For example, if you expect more usage during business hours Monday - Friday, you can plan your scaling actions accordingly.

Example: Add a resource block like this to your `main.tf`.

```
resource "aws_autoscaling_schedule" "9xlarge_schedule" {
  scheduled_action_name  = "9xlarge-asg-schedule"
  recurrence             = "0 8-17 * * MON-FRI"
  start_time             = "2021-01-01T00:00:00Z"
  end_time               = "2022-01-01T00:00:00Z"
  desired_capacity       = 2
  max_size               = 10
  min_size               = 2
  autoscaling_group_name = module.iris_anywhere_9xl.asg_name
}
```

`recurrence` - (Optional) The time when recurring future actions will start. Start time is specified by the user following the Unix cron syntax format.

`start_time`, `end_time` - (Optional) The time for this action to start/end, in "YYYY-MM-DDThh:mm:ssZ" format in UTC/GMT only (for example, 2014-06-01T00:00:00Z ). If you try to schedule your action in the past, Auto Scaling returns an error message.

`desired_capacity`, `max_size`, `min_size` - (Optional) Default `0`. Set to `-1` if you don't want to change the value at the scheduled time. 