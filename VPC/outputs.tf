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

# ALB ARN suffix: app/name/id
output "dr_alb_arn_suffix" {
  value = regexreplace(
    aws_lb.dr_alb.arn,
    "^arn:aws:elasticloadbalancing:[^:]+:[0-9]+:loadbalancer/",
    ""
  )
}

# TG ARN suffix: targetgroup/name/id
output "dr_tg_arn_suffix" {
  value = regexreplace(
    aws_lb_target_group.dr_tg.arn,
    "^arn:aws:elasticloadbalancing:[^:]+:[0-9]+:targetgroup/",
    ""
  )
}

# CloudWatch 스택에서 바로 for_each로 쓰기 좋게 리스트 형태로도 제공(추천)
output "targets_sin" {
  value = [
    {
      name           = "dr"
      alb_arn_suffix = regexreplace(aws_lb.dr_alb.arn, "^arn:aws:elasticloadbalancing:[^:]+:[0-9]+:loadbalancer/", "")
      tg_arn_suffix  = regexreplace(aws_lb_target_group.dr_tg.arn, "^arn:aws:elasticloadbalancing:[^:]+:[0-9]+:targetgroup/", "")
    }
  ]
}

# (선택) DR EC2 / RDS / Route53도 같이 넘기고 싶으면
output "dr_ec2_instance_ids" {
  value = [aws_instance.drEC2.id]
}
