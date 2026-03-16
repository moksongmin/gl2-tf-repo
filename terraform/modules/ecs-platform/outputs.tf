output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  value = aws_ecs_cluster.this.arn
}

output "alb_listener_arn" {
  value = aws_lb_listener.http.arn
}

output "alb_dns_name" {
  value = aws_lb.internal.dns_name
}

output "alb_zone_id" {
  value = aws_lb.internal.zone_id
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs.id
}

output "task_execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}
