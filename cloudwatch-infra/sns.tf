# Seoul SNS (default provider: ap-northeast-2)
resource "aws_sns_topic" "cw_alerts_seoul" {
  name = "${var.project}-cw-alerts-seoul"
}

resource "aws_sns_topic_subscription" "email_seoul" {
  topic_arn = aws_sns_topic.cw_alerts_seoul.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Singapore SNS (provider: aws.sin = ap-southeast-1)
resource "aws_sns_topic" "cw_alerts_sin" {
  provider = aws.sin
  name     = "${var.project}-cw-alerts-sin"
}

resource "aws_sns_topic_subscription" "email_sin" {
  provider  = aws.sin
  topic_arn = aws_sns_topic.cw_alerts_sin.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# us-east-1 SNS (provider: aws.use1)
resource "aws_sns_topic" "cw_alerts_use1" {
  provider = aws.use1
  name     = "${var.project}-cw-alerts-use1"
}

resource "aws_sns_topic_subscription" "email_use1" {
  provider  = aws.use1
  topic_arn = aws_sns_topic.cw_alerts_use1.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}
