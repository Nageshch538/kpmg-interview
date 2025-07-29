# Output the ALB DNS name
output "alb_dns_name" {
  value       = aws_lb.new_flask_app.dns_name
  description = "The DNS name of the ALB"
}