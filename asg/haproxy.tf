#AMI
data "aws_ami" "AmazonLinux" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}
#ec2

data "aws_secretsmanager_secret" "secret-arn" {
  arn = var.ia_secret_arn
}
data "aws_secretsmanager_secret_version" "os-secret" {
  secret_id = data.aws_secretsmanager_secret.secret-arn.id
}


# data "template_file" "cloud_init_ha" {
#   template = file("${path.module}/cloud_init.tpl")

#   vars = {
#     hostname             = format("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}")
#     ssl_certificate_cert = var.haproxy == true ? var.ssl_certificate_cert : ""

#     aws_region   = data.aws_region.current.name
#     asg_name     = aws_autoscaling_group.iris.name
#     statspw      = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["admin_console_pw"]
#     port         = var.ia_cert_key_arn != "" ? "443 ssl" : "8080"
#     hap_loglevel = var.hap_loglevel
#     haproxy_user_init = base64encode(var.haproxy_user_init)
#   }
# }

resource "aws_instance" "ha" {
  ami                         = coalesce(var.ami, data.aws_ami.AmazonLinux.id)
  count                       = var.haproxy == true ? 1 : 0
  iam_instance_profile        = aws_iam_instance_profile.ha[0].name
  instance_type               = var.instance_type_ha
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.ha[0].id]
  subnet_id                   = element(var.subnet_id, count.index)
  #user_data                   = base64encode(data.template_file.cloud_init_ha.rendered)
  user_data_base64            = base64encode(templatefile("${path.module}/cloud_init.tpl",{
    hostname             = format("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}")
    ssl_certificate_cert = var.haproxy == true ? var.ssl_certificate_cert : ""
    aws_region   = data.aws_region.current.id
    asg_name     = aws_autoscaling_group.iris.name
    statspw      = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["admin_console_pw"]
    port         = var.ia_cert_key_arn != "" ? "443 ssl" : "8080"
    hap_loglevel = var.hap_loglevel
    haproxy_user_init = base64encode(var.haproxy_user_init)
  }))

  associate_public_ip_address = var.associate_public_ip
  disable_api_termination = var.instance_protection ? true : false

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      ami,
      ebs_optimized,
      instance_type,
      key_name,
      root_block_device,
      tags,
      user_data
    ]
  }
  tags = merge(local.merged_tags, {
  "Name" = format("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}-haproxy-%02d", count.index + 1) })

  volume_tags = merge(local.merged_tags, {
  "Name" = format("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}-haproxy-%02d", count.index + 1) })

  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = "true"
  }

}

resource "aws_eip" "eip_haproxy" {
  count    = var.haproxy == true && var.associate_public_ip == true ? 1 : 0
  instance = aws_instance.ha[0].id
  domain = "vpc"

  tags = {
    Name = "eip-${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}"
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_eip_association" "eip_assoc_ha" {
  count         = var.haproxy == true && var.associate_public_ip == true ? 1 : 0
  instance_id   = aws_instance.ha[0].id
  allocation_id = aws_eip.eip_haproxy[0].id
}

output "ha_proxy_lb_fqdn" {
  value = var.haproxy == true && var.associate_public_ip == true ? aws_eip.eip_haproxy[0].public_dns : null
}
#IAM

# data "template_file" "ha_role" {
#   template = file("${path.module}/ha_role.json")
# }

# data "template_file" "ha_policy" {
#   template = file("${path.module}/ha_policy.json")

#   vars = {
#     cluster = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}", ".", "")
#   }
# }

resource "aws_iam_role" "ha" {
  count              = var.haproxy ? 1 : 0
  name               = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}-Role-ha", ".", "")
  #assume_role_policy = data.template_file.ha_role.rendered
  assume_role_policy = templatefile("${path.module}/ha_role.json", {})
}

resource "aws_iam_instance_profile" "ha" {
  count = var.haproxy ? 1 : 0
  name  = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}-Profile-ha", ".", "")
  role  = aws_iam_role.ha[0].name
}

resource "aws_iam_policy" "ha" {
  count  = var.haproxy ? 1 : 0
  name   = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}-Policy-ha", ".", "")
  #policy = data.template_file.ha_policy.rendered
  policy = templatefile("${path.module}/ha_policy.json",{cluster = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}", ".", "")})
}

resource "aws_iam_role_policy_attachment" "ha" {
  count      = var.haproxy ? 1 : 0
  policy_arn = aws_iam_policy.ha[0].arn
  role       = aws_iam_role.ha[0].name
}
#sec groups
resource "aws_security_group" "ha" {
  count       = var.haproxy ? 1 : 0
  name_prefix = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-ha", ".", "")
  description = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-ha", ".", "")
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  tags = merge(local.merged_tags, {
  "Name" = format("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : ""}-ha") })
}

# Allow all outbound traffic
resource "aws_security_group_rule" "egress_ha" {
  count             = var.haproxy ? 1 : 0
  security_group_id = aws_security_group.ha[0].id
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Allow HTTPS inbound traffic
resource "aws_security_group_rule" "allow_https" {
  count             = var.haproxy ? 1 : 0
  security_group_id = aws_security_group.ha[0].id
  description       = "Allow HTTPS"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.access_cidr
}

# Allow HTTP inbound traffic
resource "aws_security_group_rule" "allow_http" {
  count             = var.haproxy ? 1 : 0
  security_group_id = aws_security_group.ha[0].id
  description       = "Allow HTTP"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.access_cidr
}

# Allow HAProxy Stats inbound traffic
resource "aws_security_group_rule" "allow_haproxystats" {
  count             = var.haproxy ? 1 : 0
  security_group_id = aws_security_group.ha[0].id
  description       = "allow haproxy stats"
  type              = "ingress"
  from_port         = 8084
  to_port           = 8084
  protocol          = "tcp"
  cidr_blocks       = var.mgmt_cidr
}

# Allow HA API inbound traffic
resource "aws_security_group_rule" "allow_ssh" {
  count             = var.haproxy ? 1 : 0
  security_group_id = aws_security_group.ha[0].id
  description       = "Allow SSH"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.mgmt_cidr
}
#variables
variable "mgmt_cidr" {
  type        = list(string)
  description = "(Optional) Management Network for Iris Anywhere- SSL and Stats.  Default to no access"
  default     = ["0.0.0.0/32"]
}

variable "ami" {
  type        = string
  description = "The AMI from which to launch the instance."
  default     = ""
}

variable "instance_type_ha" {
  type        = string
  default     = "t3.xlarge"
  description = "The type of the EC2 instance."
}

variable "volume_type" {
  type        = string
  description = "EBS volume type.  Default to `gp2`"
  default     = "gp2"
}

variable "volume_size" {
  type        = number
  description = "EBS volume size.  Default to `10`"
  default     = "60"
}

variable "instance_count" {
  default     = 1
  description = "Number of HA Proxy Instances"
  type        = number
}

variable "ssl_certificate_cert" {
  type        = string
  description = "(Required) The SSL certificate package for HAProxy."
  default     = ""
}

variable "instance_protection" {
  type        = bool
  description = "Enables instance protection"
  default     = false
}

variable "additional_tags" {
  default     = {}
  description = "Additional resource tags"
  type        = map(string)
}

variable "hap_loglevel" {
  type        = string
  default     = "info"
  description = "Logging level for Haproxy. May use info, debug, notice, error. Default is warning."
}

variable "haproxy_user_init" {
  type        = string
  description = "(Optional) Provides the ability for customers to input their own custom userinit scripts"
  default     = ""
}


