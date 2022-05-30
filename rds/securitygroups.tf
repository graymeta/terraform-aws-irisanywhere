data "aws_subnet" "subnet" {
  count = "${length(var.subnet_ids)}"
  id    = "${element(var.subnet_ids, count.index)}"
}

resource "aws_security_group" "rds" {
  description = "Access to RDS Database"
  vpc_id      = data.aws_subnet.subnet.0.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.access_cidr
  }
  
   tags = merge(
    var.additional_tags,
    {
      Name = "IrisAdmin"
    },
  )
}
