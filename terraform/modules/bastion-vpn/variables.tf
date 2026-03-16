variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_id" {
  type = string
}

variable "allowed_ssh_cidrs" {
  type = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "create_vpn" {
  type    = bool
  default = false
}

variable "customer_gateway_ip" {
  type    = string
  default = null
}

variable "customer_gateway_bgp_asn" {
  type    = number
  default = 65000
}

variable "static_routes_only" {
  type    = bool
  default = true
}

variable "vpn_static_routes" {
  type    = list(string)
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
