# Optional AWS S3 File Gateway.
# Creates one SMB share per enabled bucket in the ia_secret s3_enterprise config map.
# Iris Anywhere instances map the shares at boot (see cloud_local.ps1).

locals {
  fgw_enabled      = var.file_gateway
  fgw_name         = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-fgw", ".", "")
  fgw_buckets      = local.fgw_enabled ? [for b in local.s3_buckets : b.name if try(b.enabled, true)] : []
  fgw_smb_password = try(local.decoded_secret.filegateway_smb_password, "")
  fgw_subnet_id    = coalesce(var.file_gateway_subnet_id, var.subnet_id[0])
}

#AMI
data "aws_ssm_parameter" "fgw_ami" {
  count = local.fgw_enabled ? 1 : 0
  name  = "/aws/service/storagegateway/ami/FILE_S3/latest"
}

#ec2
resource "aws_instance" "fgw" {
  count                       = local.fgw_enabled ? 1 : 0
  ami                         = data.aws_ssm_parameter.fgw_ami[0].value
  instance_type               = var.file_gateway_instance_type
  subnet_id                   = local.fgw_subnet_id
  vpc_security_group_ids      = [aws_security_group.fgw[0].id]
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.file_gateway_root_size
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    # A new AMI in SSM must not replace an activated gateway.
    ignore_changes = [ami]
  }

  tags        = merge(local.merged_tags, { "Name" = local.fgw_name })
  volume_tags = merge(local.merged_tags, { "Name" = local.fgw_name })
}

# Cache disk. Once allocated as cache it cannot be resized, so size changes are ignored;
# to grow the cache, attach an additional disk. IOPS/throughput/type can be changed in place.
resource "aws_ebs_volume" "fgw_cache" {
  count             = local.fgw_enabled ? 1 : 0
  availability_zone = aws_instance.fgw[0].availability_zone
  size              = var.file_gateway_cache_size
  type              = var.file_gateway_cache_type
  iops              = contains(["gp3", "io1", "io2"], var.file_gateway_cache_type) ? var.file_gateway_cache_iops : null
  throughput        = var.file_gateway_cache_type == "gp3" ? var.file_gateway_cache_throughput : null
  encrypted         = true

  lifecycle {
    ignore_changes = [size]
  }

  tags = merge(local.merged_tags, { "Name" = "${local.fgw_name}-cache" })
}

resource "aws_volume_attachment" "fgw_cache" {
  count       = local.fgw_enabled ? 1 : 0
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.fgw_cache[0].id
  instance_id = aws_instance.fgw[0].id
}

#gateway
resource "aws_storagegateway_gateway" "fgw" {
  count = local.fgw_enabled ? 1 : 0
  # Terraform fetches the activation key over HTTP (port 80) from wherever it runs.
  gateway_ip_address    = var.associate_public_ip ? aws_instance.fgw[0].public_ip : aws_instance.fgw[0].private_ip
  gateway_name          = local.fgw_name
  gateway_timezone      = var.file_gateway_timezone
  gateway_type          = "FILE_S3"
  smb_guest_password    = local.fgw_smb_password
  smb_security_strategy = var.file_gateway_smb_security_strategy

  lifecycle {
    # The public IP changes on stop/start; it is only needed for activation.
    ignore_changes = [gateway_ip_address, activation_key]
  }

  depends_on = [aws_security_group_rule.fgw_activation]

  tags = merge(local.merged_tags, { "Name" = local.fgw_name })
}

data "aws_storagegateway_local_disk" "fgw_cache" {
  count       = local.fgw_enabled ? 1 : 0
  disk_node   = aws_volume_attachment.fgw_cache[0].device_name
  gateway_arn = aws_storagegateway_gateway.fgw[0].arn
}

resource "aws_storagegateway_cache" "fgw" {
  count       = local.fgw_enabled ? 1 : 0
  disk_id     = data.aws_storagegateway_local_disk.fgw_cache[0].disk_id
  gateway_arn = aws_storagegateway_gateway.fgw[0].arn
}

resource "aws_storagegateway_smb_file_share" "fgw" {
  for_each              = toset(local.fgw_buckets)
  authentication        = "GuestAccess"
  gateway_arn           = aws_storagegateway_gateway.fgw[0].arn
  location_arn          = "arn:aws:s3:::${each.key}"
  role_arn              = aws_iam_role.fgw[0].arn
  file_share_name       = each.key
  default_storage_class = "S3_STANDARD"
  case_sensitivity      = "ClientSpecified"
  oplocks_enabled       = true

  dynamic "cache_attributes" {
    for_each = var.file_gateway_cache_refresh_seconds != null ? [1] : []
    content {
      cache_stale_timeout_in_seconds = var.file_gateway_cache_refresh_seconds
    }
  }

  depends_on = [aws_storagegateway_cache.fgw]

  tags = merge(local.merged_tags, { "Name" = "${local.fgw_name}-${each.key}" })
}

output "file_gateway_id" {
  value = local.fgw_enabled ? aws_storagegateway_gateway.fgw[0].gateway_id : null
}

output "file_gateway_private_ip" {
  value = local.fgw_enabled ? aws_instance.fgw[0].private_ip : null
}

output "file_gateway_shares" {
  value = [for s in aws_storagegateway_smb_file_share.fgw : s.path]
}

#IAM
resource "aws_iam_role" "fgw" {
  count = local.fgw_enabled ? 1 : 0
  name  = "${local.fgw_name}-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "storagegateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

data "aws_iam_policy_document" "fgw_s3" {
  count = local.fgw_enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads"
    ]
    resources = [for b in local.fgw_buckets : "arn:aws:s3:::${b}"]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:GetObjectVersion",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [for b in local.fgw_buckets : "arn:aws:s3:::${b}/*"]
  }
}

resource "aws_iam_role_policy" "fgw" {
  count  = local.fgw_enabled ? 1 : 0
  name   = "${local.fgw_name}-s3"
  role   = aws_iam_role.fgw[0].id
  policy = data.aws_iam_policy_document.fgw_s3[0].json
}

#sec groups
resource "aws_security_group" "fgw" {
  count       = local.fgw_enabled ? 1 : 0
  name_prefix = local.fgw_name
  description = local.fgw_name
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  tags = merge(local.merged_tags, { "Name" = local.fgw_name })
}

# Allow all outbound traffic (S3 and Storage Gateway endpoints)
resource "aws_security_group_rule" "fgw_egress" {
  count             = local.fgw_enabled ? 1 : 0
  security_group_id = aws_security_group.fgw[0].id
  description       = "Allow all outbound"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# SMB from Iris Anywhere instances
resource "aws_security_group_rule" "fgw_smb" {
  count                    = local.fgw_enabled ? 1 : 0
  security_group_id        = aws_security_group.fgw[0].id
  description              = "Allow SMB from Iris Anywhere"
  type                     = "ingress"
  from_port                = 445
  to_port                  = 445
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.iris.id
}

resource "aws_security_group_rule" "fgw_smb_139" {
  count                    = local.fgw_enabled ? 1 : 0
  security_group_id        = aws_security_group.fgw[0].id
  description              = "Allow SMB session service from Iris Anywhere"
  type                     = "ingress"
  from_port                = 139
  to_port                  = 139
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.iris.id
}

# Activation only. Clear file_gateway_activation_cidr after the first apply to close it.
resource "aws_security_group_rule" "fgw_activation" {
  count             = local.fgw_enabled && length(var.file_gateway_activation_cidr) > 0 ? 1 : 0
  security_group_id = aws_security_group.fgw[0].id
  description       = "Allow gateway activation"
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.file_gateway_activation_cidr
}

resource "null_resource" "assert_file_gateway" {
  count = local.fgw_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = length(local.fgw_buckets) > 0
      error_message = "file_gateway = true but no enabled buckets were found in the s3_enterprise config map of ia_secret_arn."
    }
    precondition {
      condition     = length(local.fgw_smb_password) >= 6
      error_message = "file_gateway = true requires a filegateway_smb_password key (6-512 characters) in the ia_secret_arn secret."
    }
    precondition {
      condition     = !contains(["io1", "io2"], var.file_gateway_cache_type) || var.file_gateway_cache_iops != null
      error_message = "file_gateway_cache_iops is required when file_gateway_cache_type is io1 or io2."
    }
  }
}

#variables
variable "file_gateway" {
  type        = bool
  description = "(Optional) Deploys an S3 File Gateway with an SMB share per enabled s3_enterprise bucket and maps the shares on Iris Anywhere instances. Default to `false`"
  default     = false
}

variable "file_gateway_instance_type" {
  type        = string
  description = "(Optional) File Gateway instance type. Minimum xlarge (2xlarge for compute-optimized). Default to `m5.xlarge`"
  default     = "m5.xlarge"
}

variable "file_gateway_subnet_id" {
  type        = string
  description = "(Optional) Subnet for the File Gateway. Default to the first subnet_id."
  default     = ""
}

variable "file_gateway_root_size" {
  type        = number
  description = "(Optional) File Gateway root volume size in GiB. Minimum 80. Default to `80`"
  default     = 80
}

variable "file_gateway_cache_size" {
  type        = number
  description = "(Optional) File Gateway cache disk size in GiB (150 - 65536). Cannot be resized after creation. Default to `1024`"
  default     = 1024

  validation {
    condition     = var.file_gateway_cache_size >= 150 && var.file_gateway_cache_size <= 65536
    error_message = "file_gateway_cache_size must be between 150 and 65536 GiB."
  }
}

variable "file_gateway_cache_type" {
  type        = string
  description = "(Optional) File Gateway cache disk type: gp3, gp2, io1, io2, st1 or sc1. Default to `gp3`"
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "gp2", "io1", "io2", "st1", "sc1"], var.file_gateway_cache_type)
    error_message = "file_gateway_cache_type must be one of gp3, gp2, io1, io2, st1, sc1."
  }
}

variable "file_gateway_cache_iops" {
  type        = number
  description = "(Optional) Provisioned IOPS for a gp3, io1 or io2 cache disk. Required for io1/io2. Default to `null` (gp3 baseline 3000)"
  default     = null
}

variable "file_gateway_cache_throughput" {
  type        = number
  description = "(Optional) Throughput in MiB/s for a gp3 cache disk (125 - 1000). Default to `null` (gp3 baseline 125)"
  default     = null
}

variable "file_gateway_smb_security_strategy" {
  type        = string
  description = "(Optional) SMB security strategy: ClientSpecified, MandatorySigning, MandatoryEncryption or MandatoryEncryptionNoAes128. Default to `ClientSpecified`"
  default     = "ClientSpecified"
}

variable "file_gateway_cache_refresh_seconds" {
  type        = number
  description = "(Optional) Automatic cache refresh interval in seconds (300 - 2592000) so objects written directly to S3 appear on the shares. Default to `null` (disabled)"
  default     = null
}

variable "file_gateway_timezone" {
  type        = string
  description = "(Optional) File Gateway timezone, used for the maintenance window. Default to `GMT`"
  default     = "GMT"
}

variable "file_gateway_activation_cidr" {
  type        = list(string)
  description = "(Optional) CIDR blocks allowed to reach the gateway on port 80 for activation. Must include the address Terraform runs from on the first apply; can be cleared afterwards. Default to `[]`"
  default     = []
}

variable "file_gateway_link_root" {
  type        = string
  description = "(Optional) Folder on Iris Anywhere instances where share symlinks are created. Default to `D:\\IrisAnywhere`"
  default     = "D:\\IrisAnywhere"
}

variable "file_gateway_link_suffix" {
  type        = string
  description = "(Optional) Suffix appended to each bucket name for the share symlink, so it does not collide with the rclone mount. Default to `-fgw`"
  default     = "-fgw"
}
