# Deploying GrayMeta Iris Anywhere AWS OpenSearch with Terraform

The following contains instructions for deploying OpenSearch (within a VPC) with Iris Anywhere into an AWS environment. This module creates a domain with two instances for HA. We enable end-to-end encryption along with data encryption at rest.

Prerequisites:
* Stored credentials in [Secrets Manager](#creating-secrets-for-iris-anywhere) prior to deploying with the specific attributes specified for OpenSearch.
* Secret and Access keys for the IAM user account created by this module. These must be populated in AWS Secrets Manager see below. These are used to authenticate with OpenSearch when managing indexes.
* Iris Anywhere ASG set search_enabled to "true".
* Certificates created or imported in AWS Certificate Manager.
* OpenSearch requires two subnets for high availability.
* Terraform 12 > compatible.
* `version` - Current version is `v0.0.13`.

## Example Usage
  
```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "ia-opensearch" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//es?ref=v0.0.13"

domain                                    = "es-domain-name" 
instance_type                             = "m4.xlarge.elasticsearch"
subnet_id                                 = ["subnet-foo1", "subnet-foo2"]
custom_endpoint                           = "youres.domain.com"
custom_endpoint_certificate_arn           = "arn:aws:acm:region:########:certificate/1234"
encrypt_at_rest_kms_key_id                = "arn:aws:kms:region:########:key/1234"
ia_secret_arn                             = "arn:aws:secretsmanager:region:##########/credname"
bucketlist                                = "s3bucket1"

}

```
### Argument Reference:
Name of Domain
* `allowed_cidr_blocks` - (Required) List of network cidr that have access.  Default to `["0.0.0.0/0"]`
* `domain` - (Required) Name of es domain for cluster.  Default to `irisanywhere-es`
* `instance_type` - (Required) Elasticsearch instance type for data nodes in the cluster.
* `subnet_id` - (Required) A list of subnet IDs to launch resources in.
* `custom_endpoint` - (Required) Specifies custom FQDN for the domain.
* `custom_endpoint_certificate_arn` - (Required) ARN of certificate for configurating Iris Anywhere.
* `encrypt_at_rest_kms_key_id` - (Required) ARN of ES key in Key Management Service to support encryption at rest.
* `tags` -  (Optional) A map of the additional tags.
* `volume_type` - (Optional) EBS volume type. Default to `gp2`.
* `volume_size` - (Optional) EBS volume size. Default to `10`.

The following secret keys must be set for OpenSearch to work properly.

    os_region          = ""
    os_endpoint        = ""
    os_accessid        = ""
    os_secretkey       = ""


### Attributes Reference:
***
* Create an IAM access and secret keys for the user OpenSearch created and store data in AWS Secrets Manager
* Populate the key info created by OS in the secrets used by IA ASG created by OS
* Add the IAM user created by OpenSearch as a Master User (OpenSearch, Select Domain, Edit Security, Set IAM ARN as master user by adding the IAM User ARN )
* Redeploy IA ASG with newly created secrets for OpenSearch

## Configuring ASG for OpenSearch


## Indexing The S3 Bucket
### Prerequisites:
* s3-index.exe is installed on the Iris Admin server instance.
* AWS CLI is installed on the AWS Iris Admin server instance.
* AWS IAM policy credentials have access to the desired S3 bucket.
* AWS IAM policy credentials have access to the OpenSearch endpoint.

### Configure The AWS Environment
From the terminal execute the aws configure command.
``` 
~ % aws configure
```
You will be prompted for the following configuration credentials...
```
AWS Access Key ID []: [Enter Your Access Key ID Here]
AWS Secrete Access Key []: [Enter Your Secret Access Key ID Here]
Default region name []: [Enter aws region name i.e. us-east-1]
Default output format []: [Enter your preferred output format i.e. json]
```
Once the AWS environment is configured with proper credentials, proceed to executing the next step.

### Executing The s3-index.exe
Locate the s3-index.exe directory and run the following command from that directory
```
.\s3-index --region [AWS region] --bucket [bucket name] --domain [domain name] --awsProfile [profile name]
```
Required by s3-index.exe
* `region`  : AWS region
* `bucket`  : Name of s3 bucket to be indexed
* `domain`  : Domain of the OpenSearch service

Optional
* `awsProfile` : Name of AWS profile if other than default