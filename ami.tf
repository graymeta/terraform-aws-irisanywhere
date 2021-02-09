data "aws_ami" "GrayMeta-Iris-Anywhere" {
  most_recent = true

  filter {
    name   = "name"
    values = ["GrayMeta-Iris-Anywhere-*"]
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
