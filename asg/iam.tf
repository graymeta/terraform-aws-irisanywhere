# data "template_file" "iris_role" {
#   template = file("${path.module}/role.json")
# }

# data "template_file" "iris_policy_base" {
#   template = file("${path.module}/policy.json")

#   vars = {
#     cluster = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}", ".", "")
#   }
# }


# data "template_file" "iris_policy_custom" {
#   #template =  var.s3_policy
#   template = var.iam_policy_enabled == true ? var.s3_policy : "{}"
# }

resource "aws_iam_role" "iris" {
  name               = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-Role", ".", "")
  #assume_role_policy = data.template_file.iris_role.rendered
  assume_role_policy = templatefile("${path.module}/role.json",{})
}

resource "aws_iam_instance_profile" "iris" {
  name = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-Profile", ".", "")
  role = aws_iam_role.iris.name
}

resource "aws_iam_policy" "iris_policy_base" {
  name   = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}-Policy", ".", "")
  #policy = data.template_file.iris_policy_base.rendered
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

locals {
  #template_output = templatefile("${path.module}/policy.json",{cluster = replace("${var.hostname_prefix}-${var.deployment_name != "1" ? var.deployment_name : var.instance_type}", ".", "")})
  #appended_text   = join("", [local.template_output, var.iam_policy_enabled == true ? var.s3_policy : ""]) #var.iam_policy_enabled == true ? var.s3_policy : "{}"
  appended_text = var.iam_policy_enabled == true ? var.s3_policy : "{}"
}

data "aws_iam_policy_document" "combined" {
  source_policy_documents = [
    aws_iam_policy.iris_policy_base.policy,
    local.appended_text
    #data.template_file.iris_policy_base.rendered,
    #data.template_file.iris_policy_custom.rendered
  ]
}

output "base_policy_text" {
  value = aws_iam_policy.iris_policy_base.policy
}

output "local_policy_text" {
 value = local.appended_text #aws_iam_policy_document.combined.source_policy_documents
}