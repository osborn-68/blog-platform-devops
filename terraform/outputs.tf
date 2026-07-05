output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "app_private_ip" {
  value = aws_instance.app.private_ip
}

output "app_public_ip" {
  description = "Use this to open the blog in your browser"
  value       = aws_instance.app.public_ip
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}
