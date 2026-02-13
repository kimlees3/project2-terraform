locals {
  alarm_actions_seoul = [aws_sns_topic.cw_alerts_seoul.arn]
  alarm_actions_sin   = [aws_sns_topic.cw_alerts_sin.arn]
  alarm_actions_use1  = [aws_sns_topic.cw_alerts_use1.arn]
}

############################
# 서울 ALB/TG 알람 (for_each)
############################

# 1) HealthyHostCount < 1
resource "aws_cloudwatch_metric_alarm" "seoul_tg_healthy_low" {
  for_each = local.seoul_map

  alarm_name          = "${var.project}-seoul-${each.key}-healthy<1"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = each.value.alb_arn_suffix
    TargetGroup  = each.value.tg_arn_suffix
  }

  alarm_actions = local.alarm_actions_seoul
}

# 2) Target 5XX > threshold (Sum/5m)
resource "aws_cloudwatch_metric_alarm" "seoul_target_5xx" {
  for_each = local.seoul_map

  alarm_name          = "${var.project}-seoul-${each.key}-target5xx>${var.threshold_target_5xx_5m}-5m"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = var.threshold_target_5xx_5m
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.alb_arn_suffix
    TargetGroup  = each.value.tg_arn_suffix
  }

  alarm_actions = local.alarm_actions_seoul
}

# 3) Latency p90 > threshold (3분 지속)
resource "aws_cloudwatch_metric_alarm" "seoul_latency_p90" {
  for_each = local.seoul_map

  alarm_name          = "${var.project}-seoul-${each.key}-latency-p90>${var.threshold_latency_p90_seconds}s"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p90"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = var.threshold_latency_p90_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.alb_arn_suffix
    TargetGroup  = each.value.tg_arn_suffix
  }

  alarm_actions = local.alarm_actions_seoul
}

############################
# 싱가폴 ALB/TG 알람 (for_each, provider alias)
############################

resource "aws_cloudwatch_metric_alarm" "sin_tg_healthy_low" {
  provider = aws.sin
  for_each = local.sin_map

  alarm_name          = "${var.project}-sin-${each.key}-healthy<1"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = each.value.alb_arn_suffix
    TargetGroup  = each.value.tg_arn_suffix
  }

  alarm_actions = local.alarm_actions_sin
}

resource "aws_cloudwatch_metric_alarm" "sin_target_5xx" {
  provider = aws.sin
  for_each = local.sin_map

  alarm_name          = "${var.project}-sin-${each.key}-target5xx>${var.threshold_target_5xx_5m}-5m"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = var.threshold_target_5xx_5m
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.alb_arn_suffix
    TargetGroup  = each.value.tg_arn_suffix
  }

  alarm_actions = local.alarm_actions_sin
}

resource "aws_cloudwatch_metric_alarm" "sin_latency_p90" {
  provider = aws.sin
  for_each = local.sin_map

  alarm_name          = "${var.project}-sin-${each.key}-latency-p90>${var.threshold_latency_p90_seconds}s"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p90"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = var.threshold_latency_p90_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = each.value.alb_arn_suffix
    TargetGroup  = each.value.tg_arn_suffix
  }

  alarm_actions = local.alarm_actions_sin
}

############################
# (선택) DR EC2 / RDS / Route53 알람
############################

# DR EC2: StatusCheckFailed > 0
resource "aws_cloudwatch_metric_alarm" "dr_ec2_status_failed" {
  provider = aws.sin
  for_each = local.dr_ec2_map

  alarm_name          = "${var.project}-dr-ec2-${each.key}-statuscheckfailed>0"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = each.value
  }

  alarm_actions = local.alarm_actions_sin
}

# DR RDS: ReplicaLag > threshold (10분 지속)
resource "aws_cloudwatch_metric_alarm" "dr_rds_replica_lag" {
  provider = aws.sin
  for_each = local.dr_rds_map

  alarm_name          = "${var.project}-dr-rds-${each.key}-replicalag>${var.threshold_rds_replica_lag_seconds}s"
  namespace           = "AWS/RDS"
  metric_name         = "ReplicaLag"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 10
  datapoints_to_alarm = 10
  threshold           = var.threshold_rds_replica_lag_seconds
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = each.value
  }

  alarm_actions = local.alarm_actions_sin
}

# Route53 HealthCheckStatus < 1
resource "aws_cloudwatch_metric_alarm" "route53_down" {
  provider = aws.use1
  for_each = local.r53_hc_map

  alarm_name          = "${var.project}-route53-${each.key}-down"
  namespace           = "AWS/Route53"
  metric_name         = "HealthCheckStatus"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  datapoints_to_alarm = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = each.value
  }

  alarm_actions = local.alarm_actions_use1
}
