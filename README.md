# Deploying GrayMeta Iris Anywhere with Terraform
The following contains instructions/criteria for deploying Iris Anywhere into an AWS environment.  Iris Anywhere is comprised of two key components, the Iris Admin Server that manages Users, permissions and Licenses and the Iris Anywhere Autoscaling Group that deploy the instances for usage. Iris Anywhere Autoscaling Group will not properly function without a dedicated Iris Admin Server deployed first. 
 

### Iris Anywhere and AWS
* Iris Anywhere requires AWS core services which are supported in all AWS Regions
  
### Prerequisites
* AWS account access
* EC2 Windows Server 2022
* Registered domain name (optional)
* Certificates created or imported in AWS Certificate Manager.
* Install Terraform executable 1.8.x or compatible [Terraform binaries](https://releases.hashicorp.com/terraform/).
* `version` - Current Iris Anywhere terraform module version is `v2.2.1`. Note module version requires Iris Anywhere AMI access.
* No AWS Root user security context should be used in the deployment of any/all Iris Anywhere services.  Please follow the policy of least privilege for all access granted as part of the deployment. 
***

### Sizing of Infrastructure
* Iris Anywhere provides multiple configurable options relating to infrastructure sizing, such as instance types, disk size, and autoscaling group size.  Each customer will have unique needs which will determine their sizing configuration.  Graymeta will work with the customer to determine the best sizing plan.

### Deployment Duration
New customers can expect and initial deployment duration of 2 hours.  There are multiple components, some of which are optional, to an Iris Anywhere deployment.  The duration may vary based on specific customer needs and/or unique customer environments.

### Specialized Knowledge
* Infrastruction As Code (IAC)
  * Terraform - specifically versions 1.8.x
* Powershell scripting knowledge is beneficial
* AWS Services familiarity with...
  * IAM (Free Service)
    * Create necessary profile(s)
    * Create keys
    * Policy creation
  * Route53 (Billable Service)
  * EC2 (Billable Service)
    * Specific compute needs  
  * RDS (Billable Service)
  * OpenSearch/ElasticSearch (Billable Service)
  * S3 (Billable Service)
  * ACM (Free Service)
  * VPC/Networking (Free Service with optional Billable VPC services)
  * NAT Gateway (Billable Service)
  * SQS (optional) (Billable Service)


### Publicly Accessible Services
* In most cases, ONLY the ALB or the HAProxy Load Balancer are publicly accessible resources.

### Data Security
* EC2 key/pair creation is utilized for the secure Iris Admin and Iris Anywhere instance access.  This key_name will be utilized in the terraform modules mentioned below.
* Access/Secret Access Key - Will be created as part of the terraform execution to allow Iris Anywhere access to the S3 media content.
* AWS Secrets Manager holds sensitive configuration data for Iris Anywhere. This data contains encrypted key values.
* S3 contains encrypted media content that is pulled to an instance where the content is again encrypted on the block storage (EBS).
* As the media content is streamed to the Iris Anywhere player, it is AES encrypted. 
* The networking is configured by utilizing the Graymeta irisanywhere version best suited for the customer needs. All networking components will be created for when running the Graymeta terraform below.


## Resulting AWS Services and Architecture Diagram
![Iris Anywhere FTR](https://user-images.githubusercontent.com/13397511/191809033-b4e93fe0-42c7-4edb-baaa-132d439abcfc.jpg)

---
# Simple Deployment Guide for GrayMeta Iris Anywhere (Terraform)

### Step 1: Launch Iris Admin

* If you want to use a high availability admin (2 servers) with an rds database: Contact [support@graymeta.com](mailto:support@graymeta.com) before launching.
* Contact [support@graymeta.com](mailto:support@graymeta.com) to get the required AMI ID
* Fill in the 4 secret values below with your vaules
* Launch this once; future upgrades are done manually via RDP

```hcl
provider "aws" {
  region  = "region-id"
  profile = "desired-aws-profile"
}

module "iris-secrets" {    
  source            = "github.com/graymeta/terraform-aws-irisanywhere//secrets?ref=v2.2.1"
  secret_name       = "yoursecretcredname"

  # Fill these in BEFORE launching Admin
  admin_console_id   = ""
  admin_console_pw   = ""
  admin_db_id        = ""
  admin_db_pw        = ""
}

module "irisadmin" {
  source           = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=v2.2.1"

  access_cidr      = ["0.0.0.0/0"]
  hostname_prefix  = "iris-admin"
  instance_type    = "t3.medium"
  subnet_id        = ["subnet-foo1"]
  key_name         = "your-key-name"
  ami              = "ami-id"
  ia_secret_arn    = module.iris-secrets.secret_arn
}
```

* Once deployed, go to `https://<admin-ip>:8021`
* Login using the `admin_console_id` and `admin_console_pw` from Secrets
* Email the ServerID to [support@graymeta.com](mailto:support@graymeta.com) to get licensed
* After licensing, update Secrets Manager in the aws console for the values below:

  * `admin_customer_id`
  * `admin_server`
  * `s3_enterprise`

---

### Step 2: Launch Iris Anywhere (Autoscaling Group)

```hcl
module "irisanywhere1" {
  source                 = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=v2.2.1"

  hostname_prefix        = "iris"
  instance_type          = "c6id.8xlarge"
  key_name               = "your-key-name"
  ssl_certificate_arn    = ""
  subnet_id              = ["subnet-1", "subnet-2"]
  ia_secret_arn          = "arn:aws:secretsmanager:region:your-secret-arn"
  ia_cert_crt_arn        = ""
  ia_cert_key_arn        = ""
  rdp_access_cidr        = ["cidr1", "cidr2"]
  s3_policy              = file("custom_policy_meta.json")
  iam_policy_enabled     = true
  base_ami               = "ami-0282e3837a18fd822"
  iam_role_name          = "iris-role"
  search_enabled         = true

  # Required by HAProxy
  haproxy                = true
  instance_type_ha       = "t3.small"
  mgmt_cidr              = ["cidr1", "cidr2"]
  ssl_certificate_cert   = ""
}
```

---

### You can now launch and destroy Iris Anywhere as needed. 
# Checkout the below readme's for more options.
*Authentication options(saml,okta,active directory): [https://github.com/graymeta/terraform-aws-irisanywhere/tree/master/secrets](https://github.com/graymeta/terraform-aws-irisanywhere/blob/master/secrets/README.MD)
*Iris Anywhere auto scaling options: [https://github.com/graymeta/terraform-aws-irisanywhere/blob/master/asg/README.MD](https://github.com/graymeta/terraform-aws-irisanywhere/blob/master/asg/README.MD)
*Open Search options: https://github.com/graymeta/terraform-aws-irisanywhere/blob/master/admin/README.MD


For support: **[support@graymeta.com](mailto:support@graymeta.com)**

