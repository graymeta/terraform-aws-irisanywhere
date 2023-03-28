# Creating Secrets for GrayMeta Iris Anywhere with Terraform
Purpose: To stage secrets for Iris Anywhere into an AWS Secrets Manager.  We do not recommend populating the values here since they will be stored in state. We recommend using CLI or the console to update.  Leave the values as "null" for best practice. 

# Requirements
Requires Terraform v1.2.X or later and the ability to create secrets in Secrets Manager. 

***
## Iris Anywhere Credentials
In order to deploy Iris Anywhere you will need to establish the following secrets key/value pairs.

## Example Usage

```hcl
provider "aws" {
  region  = "region-id"
  profile = "my-aws-profile"
}

module "iris-secrets" {    
    source = "github.com/graymeta/terraform-aws-irisanywhere//secrets?ref=v0.0.latest-tag-id"
    secret_name        = "yoursecretcredname"
    admin_console_id   = "null"
    admin_console_pw   = "null"
    admin_customer_id  = "null"
    admin_db_id        = "null"
    admin_db_pw        = "null"
    admin_server       = "null"
    iris_s3_bucketname = ""
    iris_s3_access_key = ""
    iris_s3_secret_key = ""
    iris_s3_lic_id     = "null"
    iris_s3_lic_code   = "null"
    iris_serviceacct   = ""

    okta_issuer        = ""
    okta_clientid      = ""
    okta_redirecturi   = ""
    okta_scope         = ""

    s3_meta_access_key = ""
    s3_meta_secret_key = ""
    s3_meta_bucketname = ""

    os_region          = ""
    os_endpoint        = ""
    os_accessid        = ""
    os_secretkey       = ""

    saml_uniqueID           = ""
    saml_displayName        = ""
    saml_entryPoint         = ""
    saml_samlissuer         = ""
    saml_samlissuer         = ""
    saml_acsUrlBasePath     = ""
    saml_acsUrlRelativePath = ""


    s3_enterprise      = jsonencode({buckets: [{"name":"bucket1","ssetype":"SSE-KMS","kmskey":"arnofkmskey","bucketkey":true, "metabucket":"dev-tb-meta", "enabled": true},
                                              {"name":"bucket2","ssetype":"SSE-S3","kmskey":"arnofkmskey","bucketkey":true, "metabucket":"dev-tb-meta", "enabled": true}]})


    tags = {
    "env"        = "yourenv"
    "costcenter" = "yourcostcenter"
  }
}
```

### Arguement Reference:
Requirements for Iris Admin:
* `secret_name` - (Required) A unique name for your secret
* `admin_console_id` - (Required) Username for your Iris Admin console. Customers decide this value
* `admin_console_pw` - (Required) Password for your Iris Admin console. Customers decide this value
* `admin_customer_id` - (Required) Customer ID value for your Iris License. GrayMeta provides this during the licensing. 
* `admin_db_id` - (Required) Username for your Iris Admin database. Customers value.
* `admin_db_pw` - (Required) Password for your Iris Admin database.Customers value.
Requirements for Iris Anywhere:
* `admin_server` - (Required) FQDN of Iris Admin Server. Populated once server is created.
* `iris_s3_lic_id` - (Required) S3 license ID for Iris Anywhere.
* `iris_s3_lic_code` - (Required) S3 license code for Iris Anywhere.
* `iris_s3_bucketname` - (Required) Name of S3 bucket that will be attached to Iris Anywhere. Multiple buckets require same access/secert keys and comma seperation "bucket1, bucket2". Used when s3_enterprise is not "true"
* `iris_serviceacct` - (Optional) User account used for running Iris Anywhere.
Requirements for enabling metabucket:
* `s3_meta_bucketname` - (Required) S3 bucket name for write access.
Requirements for SSO SPA Integration - Leave empty if not enabled. 
* `okta_issuer` - (Optional) Okta Issuer value for SPA configuration. 
* `okta_clientid` - (Optional) Okta Client ID value for SPA configuration. 
* `okta_redirecturi` - (Optional) Okta redirect URI value for SPA configuration. 
* `okta_scope` - (Optional) Okta scope value for SPA configuration. 
Requirements for SAML Integration - Leave empty if not enabled Okta & Ping Identity supported at this time. 
Note: To enable SAML, 1.) requires creation of an AWS Secret with contents of IDP certificate. Place the ARN in the Iris Anywhere deployment config value for `saml_cert_secret_arn` value. 2.) `saml_enabled` = `true`
* `saml_uniqueID` - (Optional) ID of IDP for SAML configuration (Either okta or ping-identity). 
* `saml_displayName` - (Optional)  Display name of IDP for SAML configuration (Either Okta or Ping Identity). 
* `saml_entryPoint` - (Optional)  Identity Provider Single Sign-On URL. 
* `saml_samlissuer` - (Optional) - Identity Provider Issuer from SAML configuration (within SAML setup). 
* `saml_acsUrlBasePath` - (Optional) - URL path to visit Iris Anywhere (iris-url.domain.com/irisanywhere). 
* `saml_acsUrlRelativePath` - (Optional) ACS URL relative to Iris Anywhere server (eg. /auth/saml/idp/assertion-consumer-service) 

Requirements for Enterprise Search - Leave empty if not enabled.
* `os_region` - (Optional) Region OpenSearch node is deployed in. 
* `os_endpoint` - (Optional) FQDN of OpenSearch endpoint.
* `os_accessid` - (Optional) Access ID credential for signing OpenSearch requests. 
* `os_secretkey` - (Optional) Secret Key credential for signing OpenSearch requests.
Requirements for Enterprise S3 (SSE) - Leave empty if not enabled.
* `s3_enterprise` - (Optional) Config map for enabling SSE for S3 buckets. See Example for key/value mapping. Used when "s3_enterprise = true" in Iris Anywhere deployments.

* `tags` -  (Optional) A map of the additional tags.
