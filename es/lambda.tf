data "aws_secretsmanager_secret" "secret-arn" {
  arn = var.ia_secret_arn
}
data "aws_secretsmanager_secret_version" "os-secret" {
  secret_id = data.aws_secretsmanager_secret.secret-arn.id
}

data "aws_region" "current" {}

locals {
  update_es_index_lambda_zip = "outputs/updateesindex.zip"
}

data "archive_file" "update-es-index" {
  type        = "zip"
  //source_file = "${path.module}/lambda/index.js"
  source_dir = "${path.module}/lambda"
  output_path = local.update_es_index_lambda_zip
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }

    principals {
      type        = "AWS"
      identifiers = ["${var.arn_of_indexresource}"]
    }

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_iam_policy" "s3_indexer_policy" {
  name   = "s3_indexer_policy-${var.domain}"
  policy = templatefile("${path.module}/s3-index-policy.json",{})
}

resource "aws_iam_role" "s3_indexer_role" {
  name                  = "s3_indexer_role-${var.domain}"
  assume_role_policy    = data.aws_iam_policy_document.policy.json
  max_session_duration  = 14400
}

resource "aws_iam_role_policy_attachment" "s3_indexer_policy_att" {
  role       = aws_iam_role.s3_indexer_role.name
  policy_arn = aws_iam_policy.s3_indexer_policy.arn
}

resource "aws_iam_role_policy_attachment" "AWSLambdaVPCAccessExecutionRole" {
  role       = aws_iam_role.s3_indexer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole" {
  role       = aws_iam_role.s3_indexer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "update-es-index-lambda" {
  filename      = local.update_es_index_lambda_zip
  function_name = "updateESindex-${var.domain}"
  role          = aws_iam_role.s3_indexer_role.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  timeout       = 30

  vpc_config {
    subnet_ids         = var.subnet_id
    security_group_ids = [aws_security_group.es.id]
  }

  environment {
    variables = {
      domain = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["os_endpoint"]
      region = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["os_region"]
    }
  }
}


locals {
  secret_json = jsondecode(nonsensitive(data.aws_secretsmanager_secret_version.os-secret.secret_string))

  # unwrap the nested JSON string stored in s3_enterprise.
  # If a bucket entry omits `region`, default to the provider's active region.
  enterprise_buckets = jsondecode(nonsensitive(local.secret_json.s3_enterprise)).buckets

  enabled_buckets = [
    for b in local.enterprise_buckets : {
      name   = b.name
      region = try(b.region, data.aws_region.current.region)
    }
    if try(b.enabled, false)
  ]

  current_region_buckets = toset([
    for b in local.enabled_buckets : b.name
    if b.region == data.aws_region.current.region
  ])
}

resource "aws_s3_bucket_notification" "s3object_events" {
  for_each = var.manage_bucket_notifications ? local.current_region_buckets : toset([])
  bucket   = each.value

  lambda_function {
    lambda_function_arn = aws_lambda_function.update-es-index-lambda.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_lambda_permission.s3objectperm]
}

resource "aws_lambda_permission" "s3objectperm" {
  for_each      = var.manage_bucket_notifications ? local.current_region_buckets : toset([])
  statement_id  = "AllowS3Invoke-${substr(sha1(each.value), 0, 16)}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update-es-index-lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${each.value}"
}

resource "aws_cloudwatch_log_group" "update-es-index" {
  name              = "/aws/lambda/${aws_lambda_function.update-es-index-lambda.function_name}"
  retention_in_days = 7
}

