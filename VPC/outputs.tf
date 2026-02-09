output "vpc_id" {
  value = aws_vpc.dr.id
}

output "public_subnet_id" {
  value = aws_subnet.drpubSN.id
}

output "private_subnet_id" {
  value = aws_subnet.drprivSN.id
}

output "igw_id" {
  value = aws_internet_gateway.drigw.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.drnat.id
}
