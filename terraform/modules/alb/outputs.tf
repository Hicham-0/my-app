output "dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_arn" {
  value = aws_lb.main.arn
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "target_group_blue_arn" {
  value = aws_lb_target_group.blue.arn
}

output "target_group_green_arn" {
  value = aws_lb_target_group.green.arn
}

output "listener_http_arn" {
  value = aws_lb_listener.http.arn
}

output "listener_test_arn" {
  value = aws_lb_listener.test.arn
}