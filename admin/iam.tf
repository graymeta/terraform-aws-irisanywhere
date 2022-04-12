
data "template_file" "iris_adm_role" {
  template = file("${path.module}/adm_role.json")
}

data "template_file" "iris_adm_policy" {
  template = file("${path.module}/adm_policy.json")

  vars = {
    cluster = replace("${var.hostname_prefix}-${var.instance_type}", ".", "")
  }
}

resource "aws_iam_role" "iris_adm" {
  name               = replace("${var.hostname_prefix}-${var.instance_type}-Role", ".", "")
  assume_role_policy = data.template_file.iris_adm_role.rendered
}

resource "aws_iam_instance_profile" "iris_adm" {
  name = replace("${var.hostname_prefix}-${var.instance_type}-Profile", ".", "")
  role = aws_iam_role.iris_adm.name
}

resource "aws_iam_policy" "iris_adm" {
  name   = replace("${var.hostname_prefix}-${var.instance_type}-Policy", ".", "")
  policy = data.template_file.iris_adm_policy.rendered
}

resource "aws_iam_role_policy_attachment" "iris_adm" {
  policy_arn = aws_iam_policy.iris_adm.arn
  role       = aws_iam_role.iris_adm.name
}
