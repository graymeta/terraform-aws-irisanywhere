# Deploying GrayMeta Iris Admin with Terraform

The following contains instructions for deploying Iris Admin into an AWS environment.  Iris Admin can be deployed with a single instance or in High Availability mode. This application provides comprehensive administrative capabilities, API and development support.  An Iris Admin Server must be deployed, licensed and configured prior to the deployment of Iris Anywhere/Play products. Further Iris Admin manages Users, permissions and Licenses for Iris products (Anywhere & Play). 

# Requirements
* Terraform v1.2.X or later.
* IAM priviliges to deploy EC2, Load balancers and DB instances; Create, attach IAM policies and roles.
* Stored credentials in [Secrets Manager](#creating-secrets-for-iris-anywhere) prior to deploying.
* Access to GrayMeta Iris Admin AMI's - Contact support@graymeta.com.
* Certificates created or imported in AWS Certificate Manager (for HA mode).
* No AWS Root user security context should be used in the deployment of any/all Iris Anywhere services.  Please follow the policy of least privilege for all access granted as part of the deployment. 

The below example will allow you to deploy your Iris Admin Server. After the deployment is complete navigate to the instance's https://{IPv4 DNS}:https_port to log in to your Iris Admin Server.  Once successfully logged in, contact support@graymeta.com to license your product.

## Example Usage for Stand alone Iris Admin with local Postgres DB.

```
provider "aws" {
  region  = "region-id"
  profile = "desired-aws-profile"
}

module "irisadmin" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=vlatest-tag-id" # where latest-tagid is highest tag available.
    
  access_cidr     = ["0.0.0.0/0"]
  hostname_prefix = "iris-admin-standalone"
  instance_count  = 1
  instance_type   = "t3.xlarge"
  subnet_id       = ["subnet-foo1"]
  key_name        = "your-key-name"
  ia_secret_arn   = "arn:aws:secretsmanager:region:your-secret-arn"
}

# Note: To retreive the Server ID for instances, check the instance tags.
```

## Example Usage for Iris Admin with High Availability / AWS RDS (multisite) enabled.

```

provider "aws" {
  region  = "region-id"
  profile = "desired-aws-profile"
}

module "irisadmin-ha" {
  source = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=vlatest-tag-id"
  
  hostname_prefix       = "iris-admin-ha"
  instance_count        = 2
  instance_type         = "t3.xlarge"
  subnet_id             = ["subnet-foo1", "subnet-foo2"]
  key_name              = "your-key-name"
  ia_secret_arn         = "arn:aws:secretsmanager:region:your-secret-arn"
  enterprise_ha         = true
  https_console_port    = 443
      }

    # To retreive the Server ID for instances, check the instance tags.
```
### Argument Reference:
* `access_cidr` - (Optional) List of network cidr that have access.  Default to `["0.0.0.0/0"]`
* `associate_public_ip` - (Optional) Configures instances with public IP addresses. Default to `false`.
* `hostname_prefix` - (Required) A unique name.
* `instance_count` - (Required) Number of Instances to deploy.
* `instance_type` - (Required) The type of the EC2 instance.
* `subnet_id` - (Required) A list of subnet IDs to launch resources in.
* `key_name` - (Required) The key name to use for the instances.
* `ia_secret_arn` - (Required) ARN of secrets for configurating Iris Anywhere.
* `tags` -  (Optional) A map of the additional tags.
* `volume_type` - (Optional) EBS volume type. Default to `gp3`.
* `volume_size` - (Optional) EBS volume size. Default to `60`.
* `disable_rdp` - (Optional) Disabled RDP access to the ec2 instances. Default to `false`.
* `instance_protection` - (Optional) Configures instances with instance protection Enabled to avoid prevent losing local data. Default to `true`.
* `enterprise_ha` - (Optional) Builds multiple Iris Admin instances in diverse AZ along with RDS to support HA. Default to `false`.
* `https_console_port` - (Optional) Configures port that Iris Admin web Console listens on with HTTPS. Default to `8021`.
* `http_console_port` - (Optional) Configures port that Iris Admin web Console listens on HTTP. Default to `8020`.

### Attributes Reference:
In addition to all the arguments above the following attributes are exported:
* `security_group` - The Security Group of the Admin instance(s).
* `private_dns` - The Private IPv4 DNS of the Admin instance(s).
* `private_ip` - The Private IPv4 address of the Admin instance(s).

## Licensing Iris Admin
Once Iris Admin has been deployed, you must contact GrayMeta for licensing. Send an email to support@graymeta.com with your Server ID information.
