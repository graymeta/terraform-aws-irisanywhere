locals {
  default_tags = {
    source  = "terraform"
    instance_name = aws_instance.iris_admin.name
  }

  merged_tags = merge(var.tags, local.default_tags)
}
