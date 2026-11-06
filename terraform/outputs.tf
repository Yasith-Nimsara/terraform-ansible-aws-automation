output "server_public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}

output "ssh_command" {
  description = "Command to connect to the server"
  value       = "ssh -i ~/devops-project-2/cloud-key ubuntu@${aws_instance.web_server.public_ip}"
}
