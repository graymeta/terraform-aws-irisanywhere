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

      principals {
      type        = "AWS"
      identifiers = ["${var.arn_of_indexresource}"]
   }   

    actions = ["sts:AssumeRole"]
  }
}


resource "aws_lambda_function" "update-es-index-lambda" {
  filename      = local.update_es_index_lambda_zip
  function_name = "updateESindex-${var.domain}"
  role          = aws_iam_role.s3_indexer_role.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"

  vpc_config {
    subnet_ids         = [var.subnet_id[0], var.subnet_id[1]]
    security_group_ids = [aws_security_group.es.id]
  }

  environment {
    variables = {
      domain            = jsondecode(data.aws_secretsmanager_secret_version.os-secret.secret_string)["os_endpoint"]
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

resource "aws_cloudwatch_log_group" "update-es-index" {
  name              = "/aws/lambda/${aws_lambda_function.update-es-index-lambda.function_name}"
  retention_in_days = 7
}

