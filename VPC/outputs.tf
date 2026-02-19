output "vpc_id" {
  value = aws_vpc.dr.id
}

output "public_subnet_id" {
  value = aws_subnet.drpubSN.id
}

output "public_subnet2_id" {
  value = aws_subnet.drpubSN2.id
}

output "private_subnet_id" {
  value = aws_subnet.drprivSN.id
}

output "igw_id" {
  value = aws_internet_gateway.drigw.id
}

output "alb_dns_name" {
  value = aws_lb.dr_alb.dns_name
}

output "nat_gateway_id" {
  value = aws_nat_gateway.drnat.id
}

output "dr_alb_arn_suffix" {
  value = element(split("loadbalancer/", aws_lb.dr_alb.arn), 1)
}

output "dr_tg_arn_suffix" {
  value = element(split("targetgroup/", aws_lb_target_group.dr_tg.arn), 1)
}

output "targets_sin" {
  value = [
    {
      name           = "dr"
      alb_arn_suffix = element(split("loadbalancer/", aws_lb.dr_alb.arn), 1)
      tg_arn_suffix  = element(split("targetgroup/", aws_lb_target_group.dr_tg.arn), 1)
    }
  ]
}

output "dr_ec2_instance_ids" {
  value = [aws_instance.drEC2.id]
}

# CloudWatch Container Insights용 (CloudWatch 스택에서 remote_state로 재사용)
output "ci_cluster_name" {
  value = var.k3s_cluster_name
}

output "ci_namespace" {
  value = var.k8s_namespace
}

output "ci_service_name" {
  value = var.k8s_service_name
}
