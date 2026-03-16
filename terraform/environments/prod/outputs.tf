output "api_url" {
  value = module.api_edge.api_endpoint
}

output "cloudfront_domain_name" {
  value = module.api_edge.cloudfront_domain_name
}

output "rds_endpoint" {
  value = module.database.endpoint
}

output "db_secret_arn" {
  value     = module.database.secret_arn
  sensitive = true
}

output "bastion_public_ip" {
  value = module.bastion_vpn.bastion_public_ip
}
