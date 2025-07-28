resource "aws_iam_role" "iris" {
  name = var.iam_role_name != "" ? var.iam_role_name : replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-Role", ".", "")
  assume_role_policy = templatefile("${path.module}/role.json",{})
}

resource "aws_iam_instance_profile" "iris" {
  name = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-Profile", ".", "")
  role = aws_iam_role.iris.name
}

resource "aws_iam_policy" "iris_policy_base" {
  name   = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-Policy", ".", "")
  policy = templatefile("${path.module}/policy.json",{cluster = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}", ".", "")})
}

resource "aws_iam_role_policy_attachment" "iris" {
  policy_arn = aws_iam_policy.iris_combined.arn
  role       = aws_iam_role.iris.name
}

resource "aws_iam_policy" "iris_combined" {
  name   = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-IAM-Policy", ".", "")
  policy = data.aws_iam_policy_document.combined.json
}

data "aws_secretsmanager_secret_version" "s3" {
  secret_id = var.ia_secret_arn
}

locals {
  decoded_secret         = jsondecode(data.aws_secretsmanager_secret_version.s3.secret_string)
  decoded_s3_enterprise  = jsondecode(local.decoded_secret.s3_enterprise)
  s3_buckets             = try(local.decoded_s3_enterprise.buckets, [])
  s3_bucket_names        = [for b in local.s3_buckets : b.name]
  s3_bucket_arns         = [for name in local.s3_bucket_names : "arn:aws:s3:::${name}"]
  s3_object_arns         = [for name in local.s3_bucket_names : "arn:aws:s3:::${name}/*"]
}

data "aws_iam_policy_document" "s3_custom" {
  statement {
    sid     = "AllowAllActionOnS3ToIAUsers"
    effect  = "Allow"
    actions = [
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
      "s3:PutBucketNotification",
      "s3:GetBucketNotification",
      "s3:PutLifeCycleConfiguration"
    ]
    resources = local.s3_bucket_arns
  }

  statement {
    effect  = "Allow"
    actions = [
      "s3:GetAccelerateConfiguration",
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:ListBucketMultipartUploads",
      "s3:GetBucketNotification",
      "s3:GetObject",
      "s3:GetObjectVersion"
    ]
    resources = local.s3_object_arns
  }

  # statement {
  #     effect  = "Allow"
  #     actions  = ["es:*"]
  #     resources = ["arn:aws:es:${data.aws_region.now.id}:${data.aws_caller_identity.current.account_id}:domain/*/*"]
  # }
}

data "aws_iam_policy_document" "es_statement" {
  count = var.search_enabled ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["es:*"]
    resources = [
      "arn:aws:es:${data.aws_region.now.id}:${data.aws_caller_identity.current.account_id}:domain/${var.es_domain_name}/*"
    ]
  }
}

data "aws_iam_policy_document" "combined" {
  source_policy_documents = compact([
    aws_iam_policy.iris_policy_base.policy,
    data.aws_iam_policy_document.s3_custom.json,
    try(data.aws_iam_policy_document.es_statement[0].json, null)
  ])
}

data "aws_region" "now" {}

data "aws_caller_identity" "current" {}

locals {
  invalid_es_domain_name = var.search_enabled && (var.es_domain_name == null || var.es_domain_name == "")
}

# Cause a failure if the condition is not met
resource "null_resource" "validate_es_domain_name" {
  count = local.invalid_es_domain_name ? 1 : 0
  provisioner "local-exec" {
    command = "echo 'Error: es_domain_name must be set when search_enabled = true'; exit 1"
  }
}

output "base_policy_text" {
  value = aws_iam_policy.iris_policy_base.policy
}

output "local_policy_text" {
 value = data.aws_iam_policy_document.s3_custom.json
}
