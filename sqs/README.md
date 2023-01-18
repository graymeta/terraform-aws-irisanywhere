# Deploying GrayMeta Iris Anywhere QA Reporting via SQS with Terraform


## Example Usage for deploying an SQS queue for Iris Admin.

```

provider "aws" {
  region  = "region-id"
  profile = "desired-aws-profile"
}
module "irisadminsqs" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//sqs?ref=v0.23"
  sqs_name = "iris-admin-sqs"
}

```