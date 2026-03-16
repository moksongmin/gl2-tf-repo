locals {
  name = "${var.project_name}-${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  services = {
    user-management = {
      container_port           = 8080
      cpu                      = 512
      memory                   = 1024
      desired_count            = 2
      image                    = var.service_images.user_management
      path_patterns            = ["/users", "/users/*"]
      health_check_path        = "/health"
      environment              = { APP_ENV = var.environment }
      secrets                  = {}
      request_count_per_target = 800
    }
    device-management = {
      container_port           = 8080
      cpu                      = 512
      memory                   = 1024
      desired_count            = 2
      image                    = var.service_images.device_management
      path_patterns            = ["/devices", "/devices/*"]
      health_check_path        = "/health"
      environment              = { APP_ENV = var.environment }
      secrets                  = {}
      request_count_per_target = 800
    }
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name                     = local.name
  cidr_block               = var.vpc_cidr_block
  azs                      = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  tags                     = local.tags
}

module "bastion_vpn" {
  source = "../../modules/bastion-vpn"

  name                     = local.name
  vpc_id                   = module.vpc.vpc_id
  public_subnet_id         = module.vpc.public_subnet_ids[0]
  allowed_ssh_cidrs        = var.allowed_ssh_cidrs
  create_vpn               = var.create_vpn
  customer_gateway_ip      = var.customer_gateway_ip
  customer_gateway_bgp_asn = var.customer_gateway_bgp_asn
  vpn_static_routes        = var.vpn_static_routes
  tags                     = local.tags
}

module "ecs_platform" {
  source = "../../modules/ecs-platform"

  name                 = local.name
  vpc_id               = module.vpc.vpc_id
  vpc_cidr_block       = module.vpc.vpc_cidr_block
  private_subnet_ids   = module.vpc.private_app_subnet_ids
  alb_subnet_ids       = module.vpc.private_app_subnet_ids
  instance_type        = var.ecs_instance_type
  asg_min_size         = var.asg_min_size
  asg_max_size         = var.asg_max_size
  asg_desired_capacity = var.asg_desired_capacity
  services             = local.services
  tags                 = local.tags
}

module "database" {
  source = "../../modules/rds"

  name                       = local.name
  db_name                    = "golive"
  instance_class             = var.db_instance_class
  allocated_storage          = var.db_allocated_storage
  max_allocated_storage      = var.db_max_allocated_storage
  engine_version             = var.db_engine_version
  username                   = var.db_username
  vpc_id                     = module.vpc.vpc_id
  db_subnet_group_name       = module.vpc.db_subnet_group_name
  allowed_security_group_ids = [module.ecs_platform.ecs_security_group_id]
  bastion_security_group_id  = module.bastion_vpn.bastion_security_group_id
  deletion_protection        = var.environment == "prod"
  tags                       = local.tags
}

module "api_edge" {
  source = "../../modules/api-edge"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name                       = local.name
  stage_name                 = var.environment
  alb_listener_arn           = module.ecs_platform.alb_listener_arn
  vpc_id                     = module.vpc.vpc_id
  private_subnet_ids         = module.vpc.private_app_subnet_ids
  vpc_cidr_block             = module.vpc.vpc_cidr_block
  cloudfront_aliases         = var.cloudfront_aliases
  cloudfront_certificate_arn = var.cloudfront_certificate_arn
  jwt_issuer                 = var.jwt_issuer
  jwt_audience               = var.jwt_audience
  jwks_uri                   = var.jwks_uri
  services = {
    user-management = {
      path = "/users"
    }
    device-management = {
      path = "/devices"
    }
  }
  authorization_rules = [
    {
      route_prefix = "/users"
      methods      = ["GET", "POST", "PUT", "PATCH", "DELETE"]
      roles        = ["admin", "user-manager"]
    },
    {
      route_prefix = "/devices"
      methods      = ["GET", "POST", "PUT", "PATCH", "DELETE"]
      roles        = ["admin", "device-manager"]
    }
  ]
  tags = local.tags
}
