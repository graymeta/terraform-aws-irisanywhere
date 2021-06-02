data "aws_ami" "GrayMeta-Iris-Admin" {
  # How is AMI Versioning controlled? eg: if we want to be on a pinned version?
  most_recent = true

  filter {
    name   = "name"
    values = ["GrayMeta-Iris-Admin-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  owners = ["913397769129"]

}
