output "dashboard_name" {
  value = aws_cloudwatch_dashboard.infra.dashboard_name
}

output "sns_topic_arn_seoul" {
  value = aws_sns_topic.cw_alerts_seoul.arn
}

output "sns_topic_arn_sin" {
  value = aws_sns_topic.cw_alerts_sin.arn
}

output "sns_topic_arn_use1" {
  value = aws_sns_topic.cw_alerts_use1.arn
}

output "seoul_alarm_count" {
  value = (
    try(length(aws_cloudwatch_metric_alarm.seoul_tg_healthy_low), 0)
    + try(length(aws_cloudwatch_metric_alarm.seoul_target_5xx), 0)
    + try(length(aws_cloudwatch_metric_alarm.seoul_latency_p90), 0)
  )
}

output "sin_alarm_count" {
  value = (
    length(keys(local.sin_map))
    + length(keys(local.dr_ec2_map))
    + length(keys(local.dr_rds_map))
    + length(keys(local.r53_hc_map))
    + try(length(aws_cloudwatch_metric_alarm.ci_node_cpu_high), 0)
    + try(length(aws_cloudwatch_metric_alarm.ci_node_mem_high), 0)
    + try(length(aws_cloudwatch_metric_alarm.ci_node_disk_p90_high), 0)
  )
}

output "route53_alarm_count" {
  value = try(length(aws_cloudwatch_metric_alarm.route53_down), 0)
}
