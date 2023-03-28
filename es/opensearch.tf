resource "aws_elasticsearch_domain" "es" {
  domain_name           = var.domain
  elasticsearch_version = var.es_version

  cluster_config {
    instance_count         = var.instance_count
    instance_type          = var.instance_type
    zone_awareness_enabled = var.zone_awareness_enabled

    dynamic "zone_awareness_config" {
      for_each = var.availability_zone_count > 1 ? [true] : []
      content {
        availability_zone_count = var.availability_zone_count
      }
    }
  }
  node_to_node_encryption {
    enabled = var.node_to_node_encryption_enabled
  }

  advanced_options = var.advanced_options

  advanced_security_options {
    enabled = false #var.advanced_security_options_enabled
    #AnonymousAuthEnabled = true
    #master_user_options {
    #master_user_arn = aws_iam_role.s3_indexer_role.arn
    #}
  }
  snapshot_options {
    automated_snapshot_start_hour = 23
  }
  vpc_options {
    subnet_ids = var.subnet_id

    security_group_ids = [aws_security_group.es.id]

  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.ebs_volume_size
    volume_type = var.volume_type
  }

  domain_endpoint_options {
    enforce_https                   = var.domain_endpoint_options_enforce_https
    tls_security_policy             = var.domain_endpoint_options_tls_security_policy
    custom_endpoint_enabled         = var.custom_endpoint_enabled
    custom_endpoint                 = var.custom_endpoint_enabled ? var.custom_endpoint : null
    custom_endpoint_certificate_arn = var.custom_endpoint_enabled ? var.custom_endpoint_certificate_arn : null
  }

  encrypt_at_rest {
    enabled    = var.encrypt_at_rest_enabled
    kms_key_id = var.encrypt_at_rest_kms_key_id
  }

  #ES domain policy bug in TF creates an issue with changes when none are presented setting this value for that purpose.
  lifecycle {
    ignore_changes = [advanced_options, tags]
  }

  tags = {
    Domain = var.tag_domain
  }
}

resource "aws_elasticsearch_domain_policy" "iris_s3" {
  domain_name     = aws_elasticsearch_domain.es.domain_name
  access_policies = <<CONFIG
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": [
                    "es:*"
                ],
                "Principal": {
                    "AWS": "*"
                },
                "Effect": "Allow",
                "Resource": "${aws_elasticsearch_domain.es.arn}/*"
            }
        ]
    }
CONFIG
}

data "aws_subnet" "subnet" {
  count = length(var.subnet_id)
  id    = element(var.subnet_id, count.index)
}

resource "aws_security_group" "es" {
  vpc_id      = data.aws_subnet.subnet.0.vpc_id
  name        = replace("${var.domain}-sg", ".", "")
  description = "Allow inbound traffic from Security Groups and CIDRs. Allow all outbound traffic"

  tags = {
  Name = replace("${var.domain}-sg", ".", "") }
}


resource "aws_security_group_rule" "ingress_cidr_blocks" {
  security_group_id = aws_security_group.es.id
  description       = "Allow inbound traffic from CIDR blocks"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.allowed_cidr_blocks

}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.es.id
  description       = "Allow all egress traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

    