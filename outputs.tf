# outputs.tf
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.flask_alb.dns_name
}

/*output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.cluster.name
}

output "ecs_service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.service.name
}

output "ecs_task_definition_arn" {
  description = "The ARN of the ECS task definition"
  value       = aws_ecs_task_definition.task.arn
}

output "security_group_id" {
  description = "The security group ID used by ECS tasks"
  value       = aws_security_group.ecs_sg.id
}

output "vpc_id" {
  description = "The VPC ID where ECS is deployed"
  value       = aws_vpc.main.id
}
*/