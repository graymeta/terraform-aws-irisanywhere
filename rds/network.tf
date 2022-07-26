resource "aws_db_subnet_group" "default" {
  subnet_ids = var.subnet_ids

  tags = merge(
    var.additional_tags,
    {
      Name = "IrisAdmin"
    },
  )
}
