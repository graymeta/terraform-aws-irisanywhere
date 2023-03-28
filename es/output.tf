output "arn" {
  value = aws_elasticsearch_domain.es.arn
}
output "domain_id" {
  value = aws_elasticsearch_domain.es.domain_id
}
output "domain_name" {
  value = aws_elasticsearch_domain.es.domain_name
}
output "endpoint" {
  value = aws_elasticsearch_domain.es.endpoint
}
output "kibana_endpoint" {
  value = aws_elasticsearch_domain.es.kibana_endpoint
}
output "subnet_id" {
  value       = var.subnet_id
  description = "ARN ES domain"
}
output "domain_arn" {
  value       = join("", aws_elasticsearch_domain.es.*.arn)
  description = "ARN ES domain"
}
output "domain_endpoint" {
  value       = join("", aws_elasticsearch_domain.es.*.endpoint)
  description = "your domain endpoint URL"
}

output "lambda_arn" {
  value = aws_lambda_function.update-es-index-lambda.arn
}


