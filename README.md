# terraform-aws-irisanywhere

## Iris Anywhere deployment with Terraform on AWS

Deploys:

- Autoscaling Group
- Application Load Balancer
- Security Group, IAM role, IAM policy


Example:

```
main.tf

provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "iris_anywhere_9xl" {

    # source = "../../terraform-aws-irisanywhere"
    source = "https://github.com/graymeta/terraform-aws-irisanywhere"
    asg_check_interval      = 60
    asg_scalein_cooldown    = 600
    asg_scalein_evaluation  = 2
    asg_scalein_threshold   = 10
    asg_scaleout_cooldown   = 300
    asg_scaleout_evaluation = 2
    asg_scaleout_threshold  = 3
    hostname_prefix         = "iris-anywhere"
    instance_type           = "c5d.9xlarge"
    key_name                = "my_key"
    lb_check_interval       = 30
    lb_unhealthy_threshold  = 2
    os_disk_size            = 500
    size_desired            = 1
    size_max                = 5
    size_min                = 1
    ssl_certificate_arn     = "arn:aws:acm:us-west-2:123456789:certificate/12345-abc123-1234-abc123-123456789"
    subnet_id               = ["subnet-foo1", "subnet-foo2"]
}
```

**Optional:**

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