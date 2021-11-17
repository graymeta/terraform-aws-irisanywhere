data "aws_secretsmanager_secret" "secret-arn" {
  arn = var.ia_secret_arn
}
data "aws_secretsmanager_secret_version" "os-secret" {
  secret_id = data.aws_secretsmanager_secret.secret-arn.id
}

locals {
  update_es_index_lambda_zip = "outputs/updateesindex.zip"
}


data "archive_file" "update-es-index" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.js"
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

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lamda_es_role" {
  name               = "lambda_es_role"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

resource "aws_lambda_function" "update-es-index-lambda" {
  filename      = local.update_es_index_lambda_zip
  function_name = "updateESindex"
  role          = aws_iam_role.lamda_es_role.arn
  handler       = "add-to-es-index"
  runtime       = "nodejs12.x"
  environment {
    variables = {
      domain            = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["os_endpoint"]
      domain_key_id     = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["os_accessid"]
      domain_secret_key = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["os_secretkey"]
      region            = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["os_region"]
    }

  }
}

resource "aws_s3_bucket_notification" "s3object-events" {
  bucket = var.bucketlist

  lambda_function {
    lambda_function_arn = aws_lambda_function.update-es-index-lambda.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}

resource "aws_lambda_permission" "s3objectperm" {
  statement_id  = "AllowS3Invoke-${var.bucketlist}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update-es-index-lambda.arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.bucketlist}"
}