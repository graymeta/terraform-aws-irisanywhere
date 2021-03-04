data "template_file" "cloud_init" {
  template = file("${path.module}/cloud_init.ps1")

  vars = {
    iadm_uid   = var.iadm_uid
    iadm_pw    = var.iadm_pw
    iadmdb_uid = var.iadmdb_uid
    iadmdb_pw  = var.iadmdb_pw
  }
}

resource "aws_eip" "public_ip" {
  count    = var.instance_count
  instance = element(aws_instance.iris_adm.*.id, count.index)
}

resource "aws_eip_association" "eip_assoc" {
  allocation_id = element(aws_eip.public_ip.*.id, count.index)
  count         = var.instance_count
  instance_id   = element(aws_instance.iris_adm.*.id, count.index)
}

resource "aws_instance" "iris_adm" {
  ami                  = coalesce(var.ami, data.aws_ami.GrayMeta-Iris-Admin.id)
  count                = var.instance_count
  iam_instance_profile = aws_iam_instance_profile.iris_adm.name
  instance_type        = var.instance_type
  key_name             = var.key_name
  security_groups      = [aws_security_group.iris_adm.id]
  subnet_id            = element(var.subnet_id, count.index)
  user_data            = base64encode(data.template_file.cloud_init.rendered)

  lifecycle {
    ignore_changes = [
      ami,
      ebs_optimized,
      instance_type,
      key_name,
      root_block_device,
      user_data
    ]
  }

  tags = merge(
    map("Name", format("${var.hostname_prefix}-%02d", count.index + 1)),
    local.merged_tags
  )

  volume_tags = merge(
    map("Name", format("${var.hostname_prefix}-%02d", count.index + 1)),
    local.merged_tags
  )

  root_block_device {
    volume_type           = var.volume_type
    volume_size           = var.volume_size
    delete_on_termination = "true"
  }
}

# Create instance profile
resource "aws_iam_instance_profile" "iris_adm" {
  name = "iris_adm"
  role = aws_iam_role.iris_adm_role.name
}

resource "aws_iam_role" "iris_adm_role" {
  name = "iris_adm_role"

  assume_role_policy = file("${path.module}/adm_role.json")
}
