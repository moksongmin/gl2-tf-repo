output "api_id" {
  value = aws_apigatewayv2_api.this.id
}

output "api_endpoint" {
  value = aws_apigatewayv2_stage.this.invoke_url
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.this.domain_name
}
