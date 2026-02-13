resource "aws_cloudwatch_dashboard" "infra" {
  dashboard_name = local.dashboard_name

  dashboard_body = jsonencode({
    widgets = local.all_widgets
  })
}
