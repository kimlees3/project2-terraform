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
    length(aws_cloudwatch_metric_alarm.seoul_tg_healthy_low)
    + length(aws_cloudwatch_metric_alarm.seoul_target_5xx)
    + length(aws_cloudwatch_metric_alarm.seoul_latency_p90)
  )
}

output "sin_alarm_count" {
  value = (
    length(aws_cloudwatch_metric_alarm.sin_tg_healthy_low)
    + length(aws_cloudwatch_metric_alarm.sin_target_5xx)
    + length(aws_cloudwatch_metric_alarm.sin_latency_p90)
    + length(aws_cloudwatch_metric_alarm.dr_ec2_status_failed)
    + length(aws_cloudwatch_metric_alarm.dr_rds_replica_lag)
  )
}

output "route53_alarm_count" {
  value = length(aws_cloudwatch_metric_alarm.route53_down)
}
