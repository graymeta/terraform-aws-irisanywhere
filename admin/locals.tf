locals {
  default_tags = {
    source = "terraform"
    Name   = replace("${var.hostname_prefix}-${var.instance_type}", ".", "")
  }
  merged_tags = merge(var.tags, local.default_tags)
}
