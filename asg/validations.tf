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