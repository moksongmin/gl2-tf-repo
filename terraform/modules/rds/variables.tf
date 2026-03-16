variable "name" {
  type = string
}

variable "db_name" {
  type = string
}

variable "instance_class" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "max_allocated_storage" {
  type = number
}

variable "engine" {
  type    = string
  default = "sqlserver-se"
}

variable "engine_version" {
  type = string
}

variable "username" {
  type = string
}

variable "port" {
  type    = number
  default = 1433
}

variable "vpc_id" {
  type = string
}

variable "db_subnet_group_name" {
  type = string
}

variable "allowed_security_group_ids" {
  type = list(string)
}

variable "bastion_security_group_id" {
  type    = string
  default = null
}

variable "backup_retention_period" {
  type    = number
  default = 7
}

variable "multi_az" {
  type    = bool
  default = true
}

variable "deletion_protection" {
  type    = bool
  default = true
}

variable "performance_insights_enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
