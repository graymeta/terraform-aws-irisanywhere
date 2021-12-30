# data "template_file" "iris_s3_policy" {
#   template = file("${path.module}/s3-index-policy.json")
# }

# resource "aws_iam_role" "iris_s3_indexer" {
#   name               = "iris_s3_indexer"
#   assume_role_policy = data.template_file.iris_s3_policy.rendered
# }


data "template_file" "iris_s3_policy" {
  template = file("${path.module}/s3-index-policy.json")
}

resource "aws_iam_policy" "s3_indexer_policy" {
  name   = "s3_indexer_policy-${var.domain}"
  policy = data.template_file.iris_s3_policy.rendered
}

resource "aws_iam_role" "s3_indexer_role" {
  name               = "s3_indexer_role-${var.domain}"
  assume_role_policy = data.aws_iam_policy_document.policy.json
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