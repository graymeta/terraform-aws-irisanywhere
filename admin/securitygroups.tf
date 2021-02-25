data "aws_subnet" "subnet" {
  id    = var.subnet_id
}

resource "aws_security_group" "iris_adm" {
  name_prefix = replace("${var.hostname_prefix}-${var.instance_type}-iris", ".", "")
  description = replace("${var.hostname_prefix}-${var.instance_type}-iris", ".", "")
  vpc_id      = data.aws_subnet.subnet.vpc_id

  ingress {
    cidr_blocks = var.access_cidr
    from_port   = 8020
    to_port     = 8020
    protocol    = "tcp"
  } 

  ingress {
    cidr_blocks = var.access_cidr
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
  } 

  ingress {
    cidr_blocks = var.access_cidr
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
  } 

# allow egress of all ports
  egress {
    cidr_blocks =  ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    
  }

  tags = merge(
    local.merged_tags,
    map("Name", replace("${var.hostname_prefix}-${var.instance_type}-iris", ".", ""))
  )
}

