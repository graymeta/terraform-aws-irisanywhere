# terraform-aws-irisanywhere

## Iris Anywhere deployment with Terraform on AWS

Deploys:

- Autoscaling Group
- Application Load Balancer
- Security Group, IAM role, IAM policy


Example:

```
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}
module "iris-anywhere" {

    # source = "../../terraform-aws-irisanywhere"
    source = "https://github.com/graymeta/terraform-aws-irisanywhere"

    subnet_id = ["subnet-foo1", "subnet-foo2"]
    hostname_prefix = "iris-anywhere"
    instance_type = "c5d.9xlarge"
    key_name = "my_key"
    os_disk_size = 500
    size_desired = 1
    size_max = 5
    size_min = 1
    ssl_certificate_arn = "arn:aws:acm:us-west-2:123456789:certificate/12345-abc123-1234-abc123-123456789"
}
```