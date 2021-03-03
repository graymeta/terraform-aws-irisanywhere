## Iris Anywhere Admin Server

### Example:

```
main.tf

provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}


module "irsadmin" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=v0.0.1"
  
  access_cidr           = ["0.0.0.0/0"]
  hostname_prefix       = "irisadm"
  instance_count        = 1
  instance_type         = "t3.large"
  subnet_id             = "subnet-id123"
  key_name              = "my_key"
}