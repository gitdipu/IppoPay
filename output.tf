output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output "fargate_service_arn" {
  value = aws_ecs_service.react_app.arn
}

output "load_balancer_dns_name" {
  value = aws_lb.react_app.dns_name
}