variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "azs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "private_app_subnet_cidrs" {
  type = list(string)
}

variable "private_db_subnet_cidrs" {
  type = list(string)
}

variable "allowed_ssh_cidrs" {
  type = list(string)
}

variable "cloudfront_aliases" {
  type = list(string)
}

variable "cloudfront_certificate_arn" {
  type = string
}

variable "jwt_issuer" {
  type = string
}

variable "jwt_audience" {
  type = list(string)
}

variable "jwks_uri" {
  type = string
}

variable "db_engine_version" {
  type = string
}

variable "db_instance_class" {
  type = string
}

variable "db_allocated_storage" {
  type = number
}

variable "db_max_allocated_storage" {
  type = number
}

variable "db_username" {
  type = string
}

variable "ecs_instance_type" {
  type = string
}

variable "asg_min_size" {
  type = number
}

variable "asg_max_size" {
  type = number
}

variable "asg_desired_capacity" {
  type = number
}

variable "create_vpn" {
  type    = bool
  default = true
}

variable "customer_gateway_ip" {
  type    = string
  default = null
}

variable "customer_gateway_bgp_asn" {
  type    = number
  default = 65000
}

variable "vpn_static_routes" {
  type    = list(string)
  default = []
}

variable "service_images" {
  type = object({
    user_management   = string
    device_management = string
  })
}
