locals {
  dashboard_name = "${var.project}-infra-main-dr"

  # ------------------------------------------------------------
  # 1) remote_state 우선 적용 (없으면 var 사용)
  # ------------------------------------------------------------
  # DR(싱가폴) targets는 VPC 스택 outputs.targets_sin을 우선 사용
  targets_sin_effective = try(data.terraform_remote_state.dr_vpc.outputs.targets_sin, var.targets_sin)

  # 서울도 추후 remote_state를 붙이면 try()로 동일하게 만들면 됨
  targets_seoul_effective = var.targets_seoul

  # DR EC2도 VPC outputs에서 우선 사용
  dr_ec2_instance_ids_effective = try(data.terraform_remote_state.dr_vpc.outputs.dr_ec2_instance_ids, var.dr_ec2_instance_ids)

  # ------------------------------------------------------------
  # 2) name 중복 방지용 map (반드시 effective를 써야 함)
  # ------------------------------------------------------------
  seoul_map = { for t in local.targets_seoul_effective : t.name => t }
  sin_map   = { for t in local.targets_sin_effective : t.name => t }

  dr_ec2_map = { for id in local.dr_ec2_instance_ids_effective : id => id }
  dr_rds_map = { for id in var.dr_rds_replica_ids : id => id }
  r53_hc_map = { for id in var.route53_health_check_ids : id => id }

  # ------------------------------------------------------------
  # 3) Dashboard 위젯 자동 생성 (effective 기준)
  #    ALB/TG별로 "Healthy/Unhealthy + Target5XX + Latency p90" 3개씩
  # ------------------------------------------------------------
  seoul_widgets = flatten([
    for i, t in local.targets_seoul_effective : [
      {
        type   = "metric"
        x      = 0
        y      = i * 6
        width  = 8
        height = 6
        properties = {
          region = "ap-northeast-2"
          title  = "Seoul ${t.name} - TG Healthy/Unhealthy (Max)"
          period = 60
          stat   = "Maximum"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", t.alb_arn_suffix, "TargetGroup", t.tg_arn_suffix],
            [".", "UnHealthyHostCount", "LoadBalancer", t.alb_arn_suffix, "TargetGroup", t.tg_arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = i * 6
        width  = 8
        height = 6
        properties = {
          region = "ap-northeast-2"
          title  = "Seoul ${t.name} - Target 5XX (Sum/5m)"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", t.alb_arn_suffix, "TargetGroup", t.tg_arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = i * 6
        width  = 8
        height = 6
        properties = {
          region = "ap-northeast-2"
          title  = "Seoul ${t.name} - TargetResponseTime p90"
          period = 60
          stat   = "p90"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", t.alb_arn_suffix, "TargetGroup", t.tg_arn_suffix]
          ]
        }
      }
    ]
  ])

  sin_widgets = flatten([
    for i, t in local.targets_sin_effective : [
      {
        type   = "metric"
        x      = 0
        y      = (length(local.targets_seoul_effective) * 6) + (i * 6)
        width  = 8
        height = 6
        properties = {
          region = "ap-southeast-1"
          title  = "SIN ${t.name} - TG Healthy/Unhealthy (Max)"
          period = 60
          stat   = "Maximum"
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", t.alb_arn_suffix, "TargetGroup", t.tg_arn_suffix],
            [".", "UnHealthyHostCount", "LoadBalancer", t.alb_arn_suffix, "TargetGroup", t.tg_arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = (length(local.targets_seoul_effective) * 6) + (i * 6)
        width  = 8
        height = 6
        properties = {
          region = "ap-southeast-1"
          title  = "SIN ${t.name} - Target 5XX (Sum/5m)"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", t.alb_arn_suffix, "TargetGroup", t.tg_arn_suffix]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = (length(local.targets_seoul_effective) * 6) + (i * 6)
        width  = 8
        height = 6
        properties = {
          region = "ap-southeast-1"
          title  = "SIN ${t.name} - TargetResponseTime p90"
          period = 60
          stat   = "p90"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", t.alb_arn_suffix, "TargetGroup", t.tg_arn_suffix]
          ]
        }
      }
    ]
  ])

  # ------------------------------------------------------------
  # 4) 선택 위젯: DR EC2 (effective 기준)
  # ------------------------------------------------------------
  dr_ec2_widgets = flatten([
    for i, id in local.dr_ec2_instance_ids_effective : [
      {
        type   = "metric"
        x      = 0
        y      = ((length(local.targets_seoul_effective) + length(local.targets_sin_effective)) * 6) + (i * 6)
        width  = 12
        height = 6
        properties = {
          region = "ap-southeast-1"
          title  = "DR EC2 ${id} - CPUUtilization (Avg)"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", id]
          ]
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = ((length(local.targets_seoul_effective) + length(local.targets_sin_effective)) * 6) + (i * 6)
        width  = 12
        height = 6
        properties = {
          region = "ap-southeast-1"
          title  = "DR EC2 ${id} - StatusCheckFailed (Max)"
          period = 60
          stat   = "Maximum"
          metrics = [
            ["AWS/EC2", "StatusCheckFailed", "InstanceId", id]
          ]
        }
      }
    ]
  ])

  # ------------------------------------------------------------
  # 5) 선택 위젯: DR RDS ReplicaLag
  #    ⚠️ 여기 y 계산식은 줄바꿈 + 때문에 깨지는 경우가 있어서 한 줄로 고정
  # ------------------------------------------------------------
  dr_rds_widgets = [
    for j, rid in var.dr_rds_replica_ids : {
      type   = "metric"
      x      = 0
      y      = (((length(local.targets_seoul_effective) + length(local.targets_sin_effective)) * 6) + (length(local.dr_ec2_instance_ids_effective) * 6) + (j * 6))
      width  = 24
      height = 6
      properties = {
        region = "ap-southeast-1"
        title  = "DR RDS ${rid} - ReplicaLag (Avg)"
        period = 60
        stat   = "Average"
        metrics = [
          ["AWS/RDS", "ReplicaLag", "DBInstanceIdentifier", rid]
        ]
      }
    }
  ]

  # ------------------------------------------------------------
  # 6) 선택 위젯: Route53 HealthCheckStatus
  #    ⚠️ 여기도 y 계산식 한 줄로 고정
  # ------------------------------------------------------------
  route53_widgets = length(var.route53_health_check_ids) == 0 ? [] : [
    {
      type   = "metric"
      x      = 0
      y      = (((length(local.targets_seoul_effective) + length(local.targets_sin_effective)) * 6) + (length(local.dr_ec2_instance_ids_effective) * 6) + (length(var.dr_rds_replica_ids) * 6))
      width  = 24
      height = 6
      properties = {
        region = "us-east-1"
        title  = "Route53 HealthCheckStatus (Min) - Main/DR"
        period = 60
        stat   = "Minimum"
        metrics = [
          for hc in var.route53_health_check_ids : ["AWS/Route53", "HealthCheckStatus", "HealthCheckId", hc]
        ]
      }
    }
  ]

  # ------------------------------------------------------------
  # 7) 최종 위젯 합치기
  # ------------------------------------------------------------
  all_widgets = concat(
    local.seoul_widgets,
    local.sin_widgets,
    local.dr_ec2_widgets,
    local.dr_rds_widgets,
    local.route53_widgets
  )
}
