output "vpc_id" {
  value = aws_vpc.this.id
}

output "vpc_cidr_block" {
  value = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  value = values(aws_subnet.public)[*].id
}

output "private_app_subnet_ids" {
  value = values(aws_subnet.private_app)[*].id
}

output "private_db_subnet_ids" {
  value = values(aws_subnet.private_db)[*].id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}
