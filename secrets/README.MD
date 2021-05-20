# Creating Secrets for GrayMeta Iris Anywhere with Terraform
Purpose: To stage secrets for Iris Anywhere into an AWS Secrets Manager.  We do not recommend populating the values here since they will be stored in state. We recommend using CLI or the console to update.  Leave the values as "null" for best practice.

***
## Iris Anywhere Credentials
In order to deploy Iris Anywhere you will need to establish the following secrets key/value pairs.

## Example Usage

```
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "iris-secrets" {    
    source = "github.com/graymeta/terraform-aws-irisanywhere//secrets?ref=v0.0.5"
    secret_name        = "yoursecretcredname"
    admin_console_id   = "null"
    admin_console_pw   = "null"
    admin_customer_id  = "null"
    admin_db_id        = "null"
    admin_db_pw        = "null"
    admin_server       = "null"
    iris_s3_bucketname = "null"
    iris_s3_access_key = "null"
    iris_s3_secret_key = "null"
    iris_s3_lic_id     = "null"
    iris_s3_lic_code   = "null"
    iris_serviceacct   = "null"

    okta_issuer        = ""
    okta_clientid      = ""
    okta_redirecturi   = ""
    okta_scope         = ""

    s3_meta_access_key = ""
    s3_meta_secret_key = ""
    s3_meta_bucketname = ""
    tags = {
    "costcenter" = "yourcostcenter"
  }
}
```

### Arguement Reference:
* `secret_name` - (Required) A unique name for your secret
* `admin_console_id` - (Required) Username for your Iris Admin console.
* `admin_console_pw` - (Required) Password for your Iris Admin console.
* `admin_customer_id` - (Required) Customer ID value for your Iris License.
* `admin_db_id` - (Required) Username for your Iris Admin database.
* `admin_db_pw` - (Required) Password for your Iris Admin database.
* `admin_server` - (Required) FQDN of Iris Admin Server.
* `iris_s3_bucketname` - (Required) Name of S3 bucket that will be attached to Iris Anywhere. Multiple buckets require same access/secert keys and comma seperation "bucket1, bucket2".
* `iris_s3_access_key` - (Required) Access Key used to attach to the S3 bucket.
* `iris_s3_secret_key` - (Required) Secret Key used to attach to the S3 bucket.
* `iris_s3_lic_id` - (Required) S3 license ID for Iris Anywhere.
* `iris_s3_lic_code` - (Required) S3 license code for Iris Anywhere.
* `iris_serviceacct` - (Required) User account used for running Iris Anywhere.

* `okta_issuer` - (Optional) User account used for running Iris Anywhere.
* `okta_clientid` - (Optional) User account used for running Iris Anywhere.
* `okta_redirecturi` - (Optional) User account used for running Iris Anywhere.
* `okta_scope` - (Optional) User account used for running Iris Anywhere.

* `s3_meta_access_key` - (Optional) User account used for running Iris Anywhere.
* `s3_meta_secret_key` - (Optional) User account used for running Iris Anywhere.
* `s3_meta_bucketname` - (Optional) User account used for running Iris Anywhere.
* `tags` -  (Optional) A map of the additional tags.
