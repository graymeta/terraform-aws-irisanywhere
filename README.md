# Deploying GrayMeta Iris Anywhere with Terraform

The following contains instructions/criteria for deploying Iris Anywhere into an AWS environment.  Iris Anywhere is comprised of two key components, the Iris Admin Server that manages Users, permissions and Licenses and the Iris Anywhere Autoscaling Group that deploy the instances for usage. Iris Anywhere Autoscaling Group will not properly function without a dedicated `ia_admin_server` deployed first. 

* Contact support@graymeta.com to get access to AMI.
* Terraform 12 is only supported at this time.
* `version` - Current version is `v0.0.1`.

***
## Iris Anywhere Admin Server
Deploys Iris Admin management server. This application provides comprehensive administrative capabilities, API and development support.  Iris Admin Server must be deployed, licensed and configured prior to the deployment of the Autoscaling Groups as there are dependent variables ascertained during the process (`ia_customer_id`, `ia_admin_server`, `ia_s3_conn_id`, `ia_s3_conn_code`).  

The below example will allow you to deploy your Iris Admin Server. After the deployment is complete navigate to the instance's {Public IPv4 DNS}:8020 to log in to your Iris Admin Server.  Once successfully logged in, contact support@graymeta.com to license your product as well as retrieve the necessary variables to deploy your Iris Anywhere Autoscaling Groups.

## Example Usage

```
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisadmin" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=v0.0.1"
    
  access_cidr     = ["0.0.0.0/0"]
  hostname_prefix = "iadm"
  instance_count  = 1
  instance_type   = "t3.xlarge"
  subnet_id       = ["subnet-foo1"]
  key_name        = "my_key"
  iadm_uid        = "AdminUID"
  iadm_pw         = "YourPassword"
  iadmdb_pw       = "YourDBPassword"
}
```

### Arguement Reference:
* `access_cidr` - (Optional) List of network cidr that have access.  Default to `["0.0.0.0/0"]`
* `hostname_prefix` - (Required) A unique name.
* `instance_count` - (Required) Number of Instances to deploy.
* `instance_type` - (Required) The type of the EC2 instance.
* `subnet_id` - (Required) A list of subnet IDs to launch resources in.
* `key_name` - (Required) The key name to use for the instances.
* `iadm_uid` - (Required) The username for accessing the Iris Admin console.
* `iadm_pw` - (Required) The password for acccessing the Iris Admin console.
* `iadmdb_pw` - (Required) The password for backend database.
* `tags` -  (Optional) A map of the additional tags.
* `volume_type` - (Optional) EBS volume type. Default to `gp3`.
* `volume_size` - (Optional) EBS volume size. Default to `60`.
  
### Attributes Reference:
In addition to all the arguments above the following attributes are exported:
* `security_group` - The Security Group of the Admin instance(s).
* `private_dns` - The Private IPv4 DNS of the Admin instance(s).
* `private_ip` - The Private IPv4 address of the Admin instance(s).

***
## Iris Anywhere Autoscaling Groups
Deploys Application Load Balancer and Autoscaling group.  We recommend that you do not deploy your Autoscaling Groups until your Iris Admin Server has been licensed with GrayMeta (support@graymeta.com), during this process you will be provided additional key values to plug into your terraform code (`ia_customer_id`, `ia_admin_server`, `ia_s3_conn_id`, `ia_s3_conn_code`).

## Example Usage
```
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisanywhere1" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=v0.0.1"

  access_cidr = ["0.0.0.0/0"]

  alb_internal = true

  lb_check_interval      = 30
  lb_unhealthy_threshold = 2

  asg_check_interval = 60

  asg_scalein_cooldown   = 600
  asg_scalein_evaluation = 2
  asg_scalein_threshold  = 6

  asg_scaleout_cooldown   = 600
  asg_scaleout_evaluation = 2
  asg_scaleout_threshold  = 2

  asg_size_desired = 1
  asg_size_max     = 5
  asg_size_min     = 1

  disk_data_iops = 3000
  disk_data_size = 700
  disk_data_type = "io2"
  disk_os_size   = 300
  disk_os_type   = "gp2"

  hostname_prefix = "iris1"
  instance_type   = "c5d.9xlarge"
  key_name        = "my_key"

  ssl_certificate_arn     = "<cert_arn>"
  subnet_id               = ["subnet-foo1", "subnet-foo2"]

  tags                    = {
    "my_tag1" = "my_value1",
    "my_tag2" = "my_value2"
  }

  # Entries for IrisAnywhere and S3 information
  ia_adm_id           = module.irisadmin.ia_adm_id
  ia_adm_pw           = module.irisadmin.ia_adm_pw
  ia_admin_server     = element(module.irisadmin.private_dns, 0)
  ia_cert_file        = ""
  ia_cert_key_content = ""
  ia_customer_id      = "customerID"
  ia_lic_content      = ""
  ia_max_sessions     = "2"
  ia_s3_conn_id       = "licenced-email@domain.com"
  ia_s3_conn_code     = "licensecode"
  ia_service_acct     = "iris-service"
  ia_bucket_name      = "yourbucketname"
  ia_access_key      = "youriamaccesskeyvalue"
  ia_secret_key       = "youriamsecretkeyvalue"
}
```

### Argument Reference:
The following arguments are supported:
* `access_cidr` - (Optional) List of network cidr that have access.  Default to `["0.0.0.0/0"]`
* `alb_internal` - (Optional) sets the application load balancer for Iris Anywhere to internal mode.  Default to `false`
* `asg_check_interval` - (Optional) Autoscale check interval.  Default to `60` (seconds)
* `asg_scalein_cooldown` - (Optional) Scale in cooldown period.  Default to `300` (seconds)
* `asg_scalein_evaluation` - (Optional) Scale in evaluation periods.  Default to `2` (evaluation periods)
* `asg_scalein_threshold` - (Optional) Scale in if the number of sessions drop below.  Default to `5`
* `asg_scaleout_cooldown` - (Optional) Scale out cooldown period.  Default to `300` (seconds)
* `asg_scaleout_evaluation` - (Optional) Scale out evaluation periods. Default to `2` (evaluation periods)
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
* `lb_algorithm_type` - (Optional) Determines how the load balancer selects targets when routing requests.  The value is round_robin or least_outstanding_requests.  Default to `round_robin`
* `lb_check_interval` - (Optional) Loadbalancer health check interval. Default to `30` (seconds)
* `lb_unhealthy_threshold` - (Optional) Loadbalancer unhealthy threshold.  Default to `2` (evaluation periods)
* `ssl_certificate_arn` - (Required) The ARN of the SSL server certificate.
* `subnet_id` - (Required) A list of subnet IDs to launch resources in.
* `tags` - (Optional) A map of the additional tags.
* `ia_adm_id` - (Required) Username for authenticating to Iris Admin Server
* `ia_adm_pw` - (Required) Password for authenticating to Iris Admin Server
* `ia_admin_server` - (Required) Host name of Iris Admin installation. Provided by customer.
* `ia_cert_file` - (Optional) This enables SSL on server. Certificate format must be in x509 DER.  Default to blank
* `ia_cert_key_content` - (Optional) This enables SSL on server.  Private Key matching the cert file.  Blank will force non-SSL between LB and Server.  Default to blank
* `ia_customer_id` - (Required) The customer id associates your Iris Anywhere instances to Iris Admin (licensing). Provided by Graymeta upon licensing
* `ia_lic_content` - (Optional) License file contents for Iris Admin Server
* `ia_max_sessions` - (Optional) Set max sessions per Iris Anywhere instance before autoscaling.
* `ia_s3_conn_id` - (Required) S3 Connector license ID. Provided by GrayMeta upon licensing
* `ia_s3_conn_code` - (Required) S3 Connector license code (this will be accompanied with S3 Connector ID). Provided by GrayMeta
* `ia_service_acct` - (Required) Name of service account used to manage Iris Anywhere. Provided by customer.
* `ia_bucket_name` - (Required) Name of S3 bucket containing assets. Provided by customer.
* `ia_access_key` - (Required) Access key value to permit access to Iris Anywhere. Provided by customer.
* `ia_secret_key` - (Required) Secret key to match access key. Provided by customer.

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
