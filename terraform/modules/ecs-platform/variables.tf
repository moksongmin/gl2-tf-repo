variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "alb_subnet_ids" {
  type = list(string)
}

variable "instance_type" {
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

variable "services" {
  type = map(object({
    container_port                    = number
    cpu                               = number
    memory                            = number
    desired_count                     = number
    image                             = string
    path_patterns                     = list(string)
    health_check_path                 = string
    environment                       = map(string)
    secrets                           = map(string)
    cpu_target                        = optional(number, 70)
    memory_target                     = optional(number, 75)
    request_count_per_target          = optional(number, 1000)
    autoscaling_min_capacity          = optional(number, 1)
    autoscaling_max_capacity          = optional(number, 4)
    deployment_circuit_breaker_enable = optional(bool, true)
  }))
}

variable "ecs_optimized_ami_ssm_parameter" {
  type    = string
  default = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

variable "tags" {
  type    = map(string)
  default = {}
}
