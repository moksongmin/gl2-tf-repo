output "bastion_security_group_id" {
  value = aws_security_group.bastion.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "vpn_connection_id" {
  value = try(aws_vpn_connection.this[0].id, null)
}
