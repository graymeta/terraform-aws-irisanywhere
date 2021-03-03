locals {
  default_tags = {
    source = "terraform"
  }
  merged_tags = merge(var.tags, local.default_tags)
}
