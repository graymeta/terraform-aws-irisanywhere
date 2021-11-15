# Deploying GrayMeta Iris Anywhere AWS OpenSearch with Terraform


## Example Usage

```
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "ia-opensearch" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//opensearch?ref=v0.0.10"

domain                                    = "es-domain-name" 
instance_type                             = "m4.xlarge.elasticsearch"
subnet_id                                 = ["subnet-foo1", "subnet-foo2"]
custom_endpoint                           = "youres.domain.com"
custom_endpoint_certificate_arn           = "arn:aws:acm:region:########:certificate/1234"
encrypt_at_rest_kms_key_id                = "arn:aws:kms:region:########:key/1234"
advanced_security_options_master_user_arn = "arn:aws:iam::#######:user/username"
}

```
