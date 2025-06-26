# Simple Deployment Guide for GrayMeta Iris Anywhere (Terraform)

### Step 1: Launch Iris Secrets (recommend creating blank, then editing values manually in AWS Secrets Manager)

```hcl
provider "aws" {
  region  = "region-id"
  profile = "my-aws-profile"
}

module "iris-secrets" {    
  source            = "github.com/graymeta/terraform-aws-irisanywhere//secrets?ref=v0.0.latest-tag-id"
  secret_name       = "yoursecretcredname"

  # Fill these in BEFORE launching Admin
  admin_console_id   = "null"
  admin_console_pw   = "null"
  admin_db_id        = "null"
  admin_db_pw        = "null"

  # Fill these in AFTER Admin is licensed
  admin_server       = "null"
  admin_customer_id  = "null"
  s3_enterprise      = ""
  iris_s3_access_key = ""
  iris_s3_secret_key = ""
}
```

---

### Step 2: Launch Iris Admin

* Contact [support@graymeta.com](mailto:support@graymeta.com) to get the required AMI ID
* Launch this once; future upgrades are done manually via RDP

```hcl
provider "aws" {
  region  = "region-id"
  profile = "desired-aws-profile"
}

module "irisadmin" {
  source           = "github.com/graymeta/terraform-aws-irisanywhere//admin?ref=latest-tag-id"

  access_cidr      = ["0.0.0.0/0"]
  hostname_prefix  = "iris-admin"
  instance_type    = "t3.large"
  subnet_id        = ["subnet-foo1"]
  key_name         = "your-key-name"
  ami              = "ami-id"
  ia_secret_arn    = "arn:aws:secretsmanager:region:your-secret-arn"
}
```

* Once deployed, go to `https://<admin-ip>:8021`
* Login using the `admin_console_id` and `admin_console_pw` from Secrets
* Email the ServerID to [support@graymeta.com](mailto:support@graymeta.com) to get licensed
* After licensing, update Secrets Manager with:

  * `admin_customer_id`
  * `admin_server`
  * `s3_enterprise`

---

### Step 3: Launch Iris Anywhere (Autoscaling Group)

```hcl
module "irisanywhere1" {
  source                 = "github.com/graymeta/terraform-aws-irisanywhere//asg?ref=latest"

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

You’re now ready to launch Iris Anywhere!

For support: **[support@graymeta.com](mailto:support@graymeta.com)**

