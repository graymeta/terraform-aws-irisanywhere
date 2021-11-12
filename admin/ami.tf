data "aws_ami" "GrayMeta-Iris-Admin" {
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
