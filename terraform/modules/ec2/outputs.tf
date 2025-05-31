output "frontend_private_ip" {
  value = aws_instance.front.private_ip
}

output "frontend_public_ip" {
  value = aws_instance.front.public_ip
}

output "backend_private_ip" {
  value = aws_instance.back.private_ip
}

output "db_sg_id" {
  value = aws_security_group.private_sg.id
}

