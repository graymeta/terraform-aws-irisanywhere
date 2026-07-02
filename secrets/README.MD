# Creating Secrets for GrayMeta Iris Anywhere with Terraform

This module creates the AWS Secrets Manager resources used by Iris Admin and Iris Anywhere. It can also create a separate secret for the HAProxy PEM certificate bundle.

Do not treat this module as a secure secret-entry workflow. Any values you pass directly through Terraform can end up in state. The safer pattern is to create the secret resources with Terraform and then update the secret values through the AWS CLI, console, or a secure automation path.

## Requirements

* Terraform 1.8.x or compatible.
* Permissions to create and update AWS Secrets Manager secrets.

## Example Usage

```hcl
provider "aws" {
  region  = "us-west-2"
  profile = "my-aws-profile"
}

module "iris_secrets" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//secrets?ref=<tag>"

  secret_name = "iris-config"

  admin_console_id  = "admin"
  admin_console_pw  = "replace-me"
  admin_customer_id = "customer-id"
  admin_db_id       = "postgres"
  admin_db_pw       = "replace-me"
  s3_enterprise     = jsonencode({ buckets = [] })

  tags = {
    env = "prod"
  }
}
```

The values shown above are placeholders. Create the secret structure with Terraform, then populate production values through a secure out-of-band process rather than storing live credentials in the example variables.

## Minimum Root Module

Use this module when you want Terraform to create the secret containers and initial payload structure before deploying `admin` or `asg`.

Required for a first successful apply:

* `secret_name`
* `admin_console_id`
* `admin_console_pw`
* `admin_db_id`
* `admin_db_pw`
* `s3_enterprise`

Usually optional on the first apply:

* `admin_customer_id`
* `admin_server`
* `iris_s3_bucketname`
* `iris_s3_access_key`
* `iris_s3_secret_key`
* `okta_*`
* `s3_meta_*`
* `os_*`
* `saml_*`
* `tags`

Required only for specific deployment modes:

* `secret_name_haproxy_ssl_cert` and `certificate_path` only when you want Terraform to manage the separate HAProxy certificate secret.
* `os_region`, `os_endpoint`, `os_accessid`, and `os_secretkey` only when search integration is enabled.
* `saml_*` values only when SAML is enabled in the application deployment.

## Inputs

Base secret inputs:

* `secret_name` required. Name of the main AWS Secrets Manager secret.
* `description` optional, default `Iris Secrets`. Description for the main secret.
* `recovery_window_in_days` optional, default `7`. Recovery window for secret deletion.
* `admin_customer_id` optional, default `""`. Customer ID provided by GrayMeta. Required for licensed Iris Anywhere deployments.
* `admin_db_id` optional, default `postgres`. Iris Admin database username.
* `admin_db_pw` required in practice. Iris Admin database password.
* `admin_console_id` required in practice. Iris Admin console username.
* `admin_console_pw` required in practice. Iris Admin console password.
* `admin_server` optional, default `""`. Iris Admin FQDN. Required when deploying Iris Anywhere against an existing Admin server.
* `iris_s3_bucketname` optional, default `""`. S3 bucket name or comma-separated bucket names when not using the enterprise S3 config-map flow.
* `iris_s3_access_key` optional, default `""`. S3 access key used by Iris Anywhere when required by the chosen storage flow.
* `iris_s3_secret_key` optional, default `""`. S3 secret key used by Iris Anywhere when required by the chosen storage flow.

Optional SPA / Okta inputs:

* `okta_issuer` optional, default `""`. Required when SPA / Okta integration is enabled.
* `okta_clientid` optional, default `""`. Required when SPA / Okta integration is enabled.
* `okta_redirecturi` optional, default `""`. Required when SPA / Okta integration is enabled.
* `okta_scope` optional, default `""`. Optional scope string for SPA / Okta integration.

Optional secondary S3 bucket inputs:

* `s3_meta_access_key` optional, default `""`. Required when using a secondary metadata bucket that needs separate credentials.
* `s3_meta_secret_key` optional, default `""`. Required when using a secondary metadata bucket that needs separate credentials.
* `s3_meta_bucketname` optional, default `""`. Required when using a secondary metadata bucket.

Optional OpenSearch inputs:

* `os_region` optional, default `""`. Required when search integration is enabled.
* `os_endpoint` optional, default `""`. Required when search integration is enabled.
* `os_accessid` optional, default `""`. Required when search integration is enabled and signed requests are used.
* `os_secretkey` optional, default `""`. Required when search integration is enabled and signed requests are used.

Enterprise S3 config-map input:

* `s3_enterprise` required. JSON string representing the enterprise S3 config-map. Provide the real enterprise bucket config when that storage path is enabled, or provide an empty structure such as `jsonencode({ buckets = [] })` when you want the secret payload to include the key but you are not enabling enterprise S3 buckets yet.

Optional SAML inputs:

* `saml_uniqueID` optional, default `""`. Required when `saml_enabled = true` in the Iris Anywhere deployment.
* `saml_displayName` optional, default `""`. Required when `saml_enabled = true`.
* `saml_entryPoint` optional, default `""`. Required when `saml_enabled = true`.
* `saml_samlissuer` optional, default `""`. Required when `saml_enabled = true`.
* `saml_acsUrlBasePath` optional, default `""`. Required when `saml_enabled = true`.
* `saml_acsUrlRelativePath` optional, default `""`. Required when `saml_enabled = true`.

HAProxy certificate secret inputs:

* `secret_name_haproxy_ssl_cert` optional, default `haproxy_ssl_cert`. Name of the separate HAProxy certificate secret.
* `certificate_path` optional, default `haproxy-temp-cert.pem`. Path to the PEM bundle that will be uploaded into the HAProxy certificate secret.

Tagging:

* `tags` optional, default `{}`. Resource tag map.

## Outputs

* `arn` ARN of the main secret.
* `secret` AWS Secrets Manager secret resource for the main secret.
* `secret_payload` Current secret string stored in the main secret version.
* `haproxy_certificate_secret_arn` Helper output containing the HAProxy certificate secret ARN.
