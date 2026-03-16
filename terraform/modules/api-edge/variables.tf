variable "name" {
  type = string
}

variable "stage_name" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "vpc_cidr_block" {
  type = string
}

variable "cloudfront_aliases" {
  type    = list(string)
  default = []
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

variable "services" {
  type = map(object({
    path = string
  }))
}

variable "authorization_rules" {
  type = list(object({
    route_prefix = string
    methods      = list(string)
    roles        = list(string)
  }))
  default = []
}

variable "burst_limit" {
  type    = number
  default = 200
}

variable "rate_limit" {
  type    = number
  default = 100
}

variable "tags" {
  type    = map(string)
  default = {}
}
