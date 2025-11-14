output "alb_dns_name" {
  description = "Public ALB DNS URL"
  value       = aws_lb.demo_terramino_alb.dns_name
}

output "ec2_private_instance" {
  description = "Private EC2 Instance ID"
  value       = aws_instance.demo_terramino_ec2_001.id
}
