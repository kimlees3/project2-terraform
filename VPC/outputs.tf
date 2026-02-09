output "vpc_id" {
  value = aws_vpc.dr.id
}

output "public_subnet_id" {
  value = aws_subnet.drpubSN.id
}
# ✅ 추가
output "public_subnet2_id" {
  value = aws_subnet.drpubSN2.id
}
output "private_subnet_id" {
  value = aws_subnet.drprivSN.id
}

output "igw_id" {
  value = aws_internet_gateway.drigw.id
}
# ✅ 추가: ALB 접속용 DNS (Route53 Alias로 연결할 때 사용)
output "alb_dns_name" {
  value = aws_lb.dr_alb.dns_name
}

output "nat_gateway_id" {
  value = aws_nat_gateway.drnat.id
}
