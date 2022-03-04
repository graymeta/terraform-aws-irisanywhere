
resource "aws_iam_user" "iris_s3_index" {
  name = "iris_s3_index-${var.domain}"
}

data "aws_iam_policy_document" "es_policy" {
  statement {
    actions   = ["es:*"]
    resources = ["${aws_elasticsearch_domain.es.arn}/*"]
    effect    = "Allow"
  }
}

resource "aws_iam_policy" "es-policy" {
  name        = "${var.domain}-policy"
  description = "My test policy"
  policy      = data.aws_iam_policy_document.es_policy.json
}

resource "aws_iam_user_policy_attachment" "es-attach" {
  user       = aws_iam_user.iris_s3_index.name
  policy_arn = aws_iam_policy.es-policy.arn
}