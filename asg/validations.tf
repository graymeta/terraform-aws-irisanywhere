# Validate DNS hostnames/resolution is enabled for the VPC
# Human-readable outputs (optional)

data "aws_vpc" "target" {
  id = data.aws_subnet.subnet.0.vpc_id
}
output "vpc_dns_support_enabled" {
  value = data.aws_vpc.target.enable_dns_support
}
output "vpc_dns_hostnames_enabled" {
  value = data.aws_vpc.target.enable_dns_hostnames
}

# Assertion: fail if either flag is false
resource "null_resource" "assert_vpc_dns" {
  triggers = {
    vpc_id = data.aws_vpc.target.id
  }

  lifecycle {
    precondition {
      condition     = data.aws_vpc.target.enable_dns_support
      error_message = "VPC ID '${data.aws_vpc.target.id}': enableDnsSupport is FALSE. Enable it to use the VPC resolver. Please ensure your VPC is able to create DNS hostnames and resolve them.  This can be configured in VPC settings via the AWS console."
    }
    precondition {
      condition     = data.aws_vpc.target.enable_dns_hostnames
      error_message = "VPC ID '${data.aws_vpc.target.id}': enableDnsHostnames is FALSE. Instances won’t receive resolvable private DNS names. Please ensure your VPC is able to create DNS hostnames and resolve them.  This can be configured in VPC settings via the AWS console."
    }
  }
}

# Input contract checks: fail fast on invalid or conflicting combinations before apply.
resource "null_resource" "assert_input_contract" {
  triggers = {
    validation_version = "1"
  }

  lifecycle {
    precondition {
      condition     = length(var.subnet_id) > 0
      error_message = "At least one subnet_id must be provided."
    }

    precondition {
      condition     = trimspace(var.key_name) != ""
      error_message = "key_name is required and cannot be empty. An EC2 key-pair must be created in the target region and the name of that key pair must be provided."
    }

    precondition {
      condition     = trimspace(var.ia_secret_arn) != ""
      error_message = "ia_secret_arn is required and cannot be empty."
    }

    precondition {
      condition     = var.asg_size_min >= 0
      error_message = "asg_size_min must be greater than or equal to 0."
    }

    precondition {
      condition     = var.asg_size_max >= var.asg_size_min
      error_message = "asg_size_max must be greater than or equal to asg_size_min."
    }

    precondition {
      condition     = var.asg_size_desired >= var.asg_size_min && var.asg_size_desired <= var.asg_size_max
      error_message = "asg_size_desired must be between asg_size_min and asg_size_max."
    }

    precondition {
      condition     = var.asg_warm_pool_min >= 0 && var.asg_warm_pool_max >= var.asg_warm_pool_min
      error_message = "asg_warm_pool_min must be >= 0 and asg_warm_pool_max must be >= asg_warm_pool_min."
    }

    precondition {
      condition     = !var.saml_enabled || trimspace(var.saml_cert_secret_arn) != ""
      error_message = "saml_cert_secret_arn is required when saml_enabled = true."
    }

    precondition {
      condition     = !var.otlp_enabled || trimspace(var.otlp_exporter_destination) != ""
      error_message = "otlp_exporter_destination is required when otlp_enabled = true."
    }

    precondition {
      condition     = !var.haproxy || trimspace(var.instance_type_ha) != ""
      error_message = "instance_type_ha is required when haproxy = true."
    }

    precondition {
      condition     = !var.haproxy || length(var.mgmt_cidr) > 0
      error_message = "mgmt_cidr must include at least one CIDR when haproxy = true."
    }
  }
}

check "warnings" {

  #HAProxy deprecation warning
  assert {
    condition     = var.haproxy == false
    error_message = "HAProxy is set to true. HAProxy has recently been deprecated. The AWS ALB is now recommended. To deploy without HAProxy, set haproxy = false or remove the haproxy input altogether. This module will default to deploying the ALB. Be sure to provide ssl_alb_acm_arn to enable HTTPS. If you need HAProxy, contact GrayMeta support for assistance."
  }

  #Recommendation: 1 user per instance for optimal performance and best load balancing
  assert {
    condition     = var.ia_max_sessions == 1
    error_message = "Graymeta recommends 1 user per instance for optimal performance and best load balancing.  You currently have ia_max_sessions set to ${var.ia_max_sessions}. If any questions, contact GrayMeta support."
  }


  #Recommendation: warm_pool enabled when asg_size_max > 1 for cost/finops efficiency
  assert {
    condition = (
      var.asg_size_max <= 1 ||
      var.asg_warm_pool_max > 0
    )
    error_message = "(Optional) Graymeta recommends warm pools when asg_size_max is > 1 for cost/finops efficiency. Set asg_warm_pool_max > 0 to enable warm pools. You currently have asg_size_max set to ${var.asg_size_max} and asg_warm_pool_max set to ${var.asg_warm_pool_max}."
  }

  #Deprecation warning: warm_pool input is ignored and replaced by asg_warm_pool_max
  assert {
    condition     = var.warm_pool == null
    error_message = "The warm_pool input is deprecated and ignored by this module. To enable warm pools, set asg_warm_pool_max > 0 (and optionally asg_warm_pool_min)."
  }
}