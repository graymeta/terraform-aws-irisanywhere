# Deploying GrayMeta Iris Anywhere QA Reporting via SQS with Terraform

This module creates an SQS queue with AWS-managed server-side encryption and attaches a simple queue policy that allows `SQS:SendMessage` to the queue ARN.

## Requirements

* Terraform 1.8.x or compatible.
* Permissions to create SQS queues and SQS queue policies.

## Example Usage

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "irisadminsqs" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//sqs?ref=<tag>"

  sqs_name = "iris-admin-sqs"

  additional_tags = {
    env = "qa"
  }
}
```

## Inputs

* `sqs_name` optional, default `iris-admin`. Name of the SQS queue.
* `additional_tags` optional, default `{}`. Additional resource tags merged onto the queue.

## Behavior Notes

* The queue is created with `sqs_managed_sse_enabled = true`.
* The module also creates a queue policy that allows `SQS:SendMessage` to the queue resource.

## Outputs

This module does not currently declare Terraform outputs.