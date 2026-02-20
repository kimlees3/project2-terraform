locals {
  dashboard_name = "${var.project}-infra-main-dr"

  # ------------------------------------------------------------
  # 1) remote_state 우선 적용 (없으면 var 사용)
  # ------------------------------------------------------------
  # var.targets_sin 이 비어있지 않으면 var를 우선 사용
  targets_sin_effective = length(var.targets_sin) > 0 ? var.targets_sin : try(data.terraform_remote_state.dr_vpc.outputs.targets_sin, [])
  targets_seoul_effective       = var.targets_seoul
  dr_ec2_instance_ids_effective = try(data.terraform_remote_state.dr_vpc.outputs.dr_ec2_instance_ids, var.dr_ec2_instance_ids)

  # ✅ 서울 VPC (ROSA 제외) EC2/RDS는 tfvars로 직접 주입
  seoul_ec2_instance_ids_effective = var.seoul_ec2_instance_ids
  seoul_rds_instance_ids_effective = var.seoul_rds_instance_ids

  # ✅ Container Insights (VPC outputs 있으면 우선)
  ci_cluster_name_effective = try(data.terraform_remote_state.dr_vpc.outputs.ci_cluster_name, var.ci_cluster_name)
  ci_namespace_effective    = try(data.terraform_remote_state.dr_vpc.outputs.ci_namespace, var.ci_namespace)
  ci_service_name_effective = try(data.terraform_remote_state.dr_vpc.outputs.ci_service_name, var.ci_service_name)

  # ------------------------------------------------------------
  # 2) name 중복 방지용 map
  # ------------------------------------------------------------
  seoul_map = { for t in local.targets_seoul_effective : t.name => t }
  sin_map   = { for t in local.targets_sin_effective : t.name => t }

  seoul_ec2_map = { for id in local.seoul_ec2_instance_ids_effective : id => id }
  seoul_rds_map = { for id in local.seoul_rds_instance_ids_effective : id => id }

  dr_ec2_map = { for id in local.dr_ec2_instance_ids_effective : id => id }
  dr_rds_map = { for id in var.dr_rds_replica_ids : id => id }
  r53_hc_map = { for id in var.route53_health_check_ids : id => id }

  # ------------------------------------------------------------
  # 3) Dashboard 위젯 자동 생성 (서울)
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

  # ------------------------------------------------------------
  # 4) Dashboard 위젯 자동 생성 (싱가폴)
  # ------------------------------------------------------------
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
  # 4.5) 섹션별 Y 오프셋(대시보드 레이아웃)
  # ------------------------------------------------------------
  base_y_after_alb        = (length(local.targets_seoul_effective) + length(local.targets_sin_effective)) * 6
  base_y_after_seoul_ec2  = local.base_y_after_alb + (length(local.seoul_ec2_instance_ids_effective) * 6)
  base_y_after_seoul_rds  = local.base_y_after_seoul_ec2 + (length(local.seoul_rds_instance_ids_effective) * 6)
  base_y_after_dr_ec2     = local.base_y_after_seoul_rds + (length(local.dr_ec2_instance_ids_effective) * 6)
  base_y_after_dr_rds     = local.base_y_after_dr_ec2 + (length(var.dr_rds_replica_ids) * 6)

  # ------------------------------------------------------------
  # 4.6) 서울 EC2 위젯
  # ------------------------------------------------------------
  seoul_ec2_widgets = flatten([
    for i, id in local.seoul_ec2_instance_ids_effective : [
      {
        type   = "metric"
        x      = 0
        y      = local.base_y_after_alb + (i * 6)
        width  = 12
        height = 6
        properties = {
          region = "ap-northeast-2"
          title  = "Seoul EC2 ${id} - CPUUtilization (Avg)"
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
        y      = local.base_y_after_alb + (i * 6)
        width  = 12
        height = 6
        properties = {
          region = "ap-northeast-2"
          title  = "Seoul EC2 ${id} - StatusCheckFailed (Max)"
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
  # 4.7) 서울 RDS 위젯
  # ------------------------------------------------------------
  seoul_rds_widgets = flatten([
    for j, rid in local.seoul_rds_instance_ids_effective : [
      {
        type   = "metric"
        x      = 0
        y      = local.base_y_after_seoul_ec2 + (j * 6)
        width  = 8
        height = 6
        properties = {
          region = "ap-northeast-2"
          title  = "Seoul RDS ${rid} - CPUUtilization (Avg)"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", rid]
          ]
        }
      },
      {
        type   = "metric"
        x      = 8
        y      = local.base_y_after_seoul_ec2 + (j * 6)
        width  = 8
        height = 6
        properties = {
          region = "ap-northeast-2"
          title  = "Seoul RDS ${rid} - DatabaseConnections (Avg)"
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", rid]
          ]
        }
      },
      {
        type   = "metric"
        x      = 16
        y      = local.base_y_after_seoul_ec2 + (j * 6)
        width  = 8
        height = 6
        properties = {
          region = "ap-northeast-2"
          title  = "Seoul RDS ${rid} - FreeStorageSpace (Min)"
          period = 300
          stat   = "Minimum"
          metrics = [
            ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", rid]
          ]
        }
      }
    ]
  ])

  # ------------------------------------------------------------
  # 5) DR EC2 위젯
  # ------------------------------------------------------------
  dr_ec2_widgets = flatten([
    for i, id in local.dr_ec2_instance_ids_effective : [
      {
        type   = "metric"
        x      = 0
        y      = local.base_y_after_seoul_rds + (i * 6)
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
        y      = local.base_y_after_seoul_rds + (i * 6)
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
  # 6) DR RDS ReplicaLag 위젯
  # ------------------------------------------------------------
  dr_rds_widgets = [
    for j, rid in var.dr_rds_replica_ids : {
      type   = "metric"
      x      = 0
      y      = local.base_y_after_dr_ec2 + (j * 6)
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
  # 7) Route53 HealthCheckStatus 위젯
  # ------------------------------------------------------------
  route53_widgets = length(var.route53_health_check_ids) == 0 ? [] : [
    {
      type   = "metric"
      x      = 0
      y      = local.base_y_after_dr_rds
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
  # 8) ✅ ContainerInsights: 노드 기반 위젯
  # ------------------------------------------------------------
  ci_widgets_y = (((length(local.targets_seoul_effective) + length(local.targets_sin_effective)) * 6)
    + (length(local.seoul_ec2_instance_ids_effective) * 6)
    + (length(local.seoul_rds_instance_ids_effective) * 6)
    + (length(local.dr_ec2_instance_ids_effective) * 6)
    + (length(var.dr_rds_replica_ids) * 6)
    + (length(var.route53_health_check_ids) == 0 ? 0 : 6)
  )

  ci_widgets = [
    {
      type   = "metric"
      x      = 0
      y      = local.ci_widgets_y
      width  = 12
      height = 6
      properties = {
        region  = "ap-southeast-1"
        title   = "k3s ${local.ci_cluster_name_effective} - node_cpu_utilization (%)"
        view    = "timeSeries"
        stacked = false
        period  = 60
        stat    = "Average"
        metrics = [
          ["ContainerInsights", "node_cpu_utilization", "ClusterName", local.ci_cluster_name_effective, { stat = "Average", period = 60 }]
        ]
        legend = { position = "bottom" }
      }
    },
    {
      type   = "metric"
      x      = 12
      y      = local.ci_widgets_y
      width  = 12
      height = 6
      properties = {
        region  = "ap-southeast-1"
        title   = "k3s ${local.ci_cluster_name_effective} - node_memory_utilization (%)"
        view    = "timeSeries"
        stacked = false
        period  = 60
        stat    = "Average"
        metrics = [
          ["ContainerInsights", "node_memory_utilization", "ClusterName", local.ci_cluster_name_effective, { stat = "Average", period = 60 }]
        ]
        legend = { position = "bottom" }
      }
    }
  ]

  # ------------------------------------------------------------
  # 9) 최종 위젯 합치기
  # ------------------------------------------------------------
  all_widgets = concat(
    local.seoul_widgets,
    local.sin_widgets,
    local.seoul_ec2_widgets,
    local.seoul_rds_widgets,
    local.dr_ec2_widgets,
    local.dr_rds_widgets,
    local.route53_widgets,
    var.enable_container_insights ? local.ci_widgets : []
  )
}