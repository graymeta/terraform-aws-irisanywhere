# Deploying GrayMeta Iris Admin RDS with Terraform

## Example Usage

```
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisadminrds" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//rds?ref=v0.0.XX"
  instance_id          = "YourNameHere"
  db_snapshot          = ""
  subnet_ids           = ["subnet-id-az1", "subnet-id-az2"]
  ia_secret_arn        = "arn:aws:secretsmanager:region:acct#:secret:secretarn"
  }

  ```