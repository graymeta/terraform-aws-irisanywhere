data "template_file" "iris_role" {
  template = file("${path.module}/role.json")
}

data "template_file" "iris_policy" {
  template = file("${path.module}/policy.json")

  vars = {
    cluster = replace("${var.hostname_prefix}-${var.instance_type}", ".", "")
  }
}

resource "aws_iam_role" "iris" {
  name               = replace("${var.hostname_prefix}-${var.instance_type}-Role", ".", "")
  assume_role_policy = data.template_file.iris_role.rendered
}

resource "aws_iam_instance_profile" "iris" {
  name = replace("${var.hostname_prefix}-${var.instance_type}-Profile", ".", "")
  role = aws_iam_role.iris.name
}

resource "aws_iam_policy" "iris" {
  name   = replace("${var.hostname_prefix}-${var.instance_type}-Policy", ".", "")
  policy = data.template_file.iris_policy.rendered
}

resource "aws_iam_role_policy_attachment" "iris" {
  policy_arn = aws_iam_policy.iris.arn
  role       = aws_iam_role.iris.name
}
