🚀 Deploying GrayMeta Iris Anywhere (Simplified Guide)
This guide walks you through deploying GrayMeta Iris Anywhere using Terraform in AWS. It's designed to be clear and beginner-friendly for your GitHub repo.

🔧 Prerequisites
Before deploying, make sure you have:

✅ AWS CLI configured and working

✅ Access to required AMI IDs from support@graymeta.com

✅ Terraform v1.8.x installed

✅ AWS Certificate Manager (ACM) cert (or create one)

✅ A valid Iris Anywhere license from GrayMeta

✅ Subnets, key pair, and IAM roles ready

1️⃣ Step 1: Create Secrets with Terraform
Start by launching a Secrets Manager entry that stores required credentials.

hcl
Copy
Edit
provider "aws" {
  region  = "us-west-2"
  profile = "your-aws-profile"
}

module "iris_secrets" {
  source       = "github.com/graymeta/terraform-aws-irisanywhere//secrets?ref=v0.0.latest-tag"
  secret_name  = "iris-anywhere-secrets"

  # Fill these before launching the Admin server
  admin_console_id   = "null"
  admin_console_pw   = "null"
  admin_db_id        = "null"
  admin_db_pw        = "null"
  iris_s3_access_key = ""
  iris_s3_secret_key = ""

  # Fill these after Admin is launched and licensed
  admin_server       = "null"
  admin_customer_id  = "null"
  s3_enterprise      = ""
}
Launch the secrets module. Then manually fill in values in AWS Secrets Manager.

2️⃣ Step 2: Launch the Iris Admin Server
You'll need a specific AMI provided by GrayMeta for the Admin server.

hcl
Copy
Edit
provider "aws" {
  region  = "us-west-2"
  profile = "your-aws-profile"
}

module "iris_admin" {
  source             = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=v0.0.latest-tag"
  access_cidr        = ["0.0.0.0/0"]
  hostname_prefix    = "iris-admin"
  instance_type      = "t3.large"
  subnet_id          = ["subnet-abc123"]
  key_name           = "your-key-name"
  ami                = "ami-xxxxxx" # Get from support@graymeta.com
  ia_secret_arn      = "arn:aws:secretsmanager:us-west-2:xxxx:secret:iris-anywhere-secrets"
}
Once deployed, go to https://<PublicIP>:8021 and log in with the credentials from the secrets.

Then, email the server ID from the top of the Admin page to support@graymeta.com to get licensed.

3️⃣ Step 3: Update Secrets After Licensing
After the Admin server is licensed:

Edit the AWS Secrets Manager entry you created earlier

Add:

admin_server = the Admin instance's public DNS (e.g., iris-admin.example.com)

admin_customer_id = from license

s3_enterprise = bucket config from GrayMeta

4️⃣ Step 4: Deploy Iris Anywhere (ASG + Load Balancer)
Now you're ready to deploy the actual autoscaling group:

hcl
Copy
Edit
module "iris_anywhere" {
  source                 = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=v0.0.latest-tag"

  hostname_prefix        = "iris-anywhere"
  instance_type          = "c6id.8xlarge"
  key_name               = "your-key-name"
  ssl_certificate_arn    = "arn:aws:acm:us-west-2:xxxx:certificate/xxxx"
  subnet_id              = ["subnet-abc123", "subnet-def456"]
  ia_secret_arn          = "arn:aws:secretsmanager:us-west-2:xxxx:secret:iris-anywhere-secrets"
  base_ami               = "ami-xxxxxx"
  search_enabled         = true
  iam_policy_enabled     = true
  s3_policy              = file("custom_policy.json")

  # HAProxy Optional Settings
  haproxy                = true
  instance_type_ha       = "t3.small"
  mgmt_cidr              = ["YOUR_IP/32"]
  ssl_certificate_cert   = ""
  ia_cert_crt_arn        = ""
  ia_cert_key_arn        = ""
}
🧠 Tips
📧 Contact support@graymeta.com for:

AMI IDs

License keys

S3 bucket configuration

🛠️ Secrets should always be managed securely via AWS Secrets Manager

🌐 Use Route53 to map a domain (CNAME) to the ALB for clean URLs
