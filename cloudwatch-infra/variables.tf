variable "project" {
  type    = string
  default = "project2"
}

variable "alarm_email" {
  type        = string
  description = "CloudWatch Alarm SNS 구독 이메일"
}

variable "targets_seoul" {
  description = "서울(ap-northeast-2)에서 모니터링할 ALB/TG 목록"
  type = list(object({
    name           = string
    alb_arn_suffix = string
    tg_arn_suffix  = string
  }))
  default = []
}

variable "targets_sin" {
  description = "싱가폴(ap-southeast-1)에서 모니터링할 ALB/TG 목록"
  type = list(object({
    name           = string
    alb_arn_suffix = string
    tg_arn_suffix  = string
  }))
  default = []
}

variable "dr_ec2_instance_ids" {
  description = "싱가폴 DR EC2 인스턴스 ID 목록(k3s 노드들). 비워도 됨."
  type        = list(string)
  default     = []
}

variable "dr_rds_replica_ids" {
  description = "싱가폴 RDS Replica DBInstanceIdentifier 목록. 비워도 됨."
  type        = list(string)
  default     = []
}

variable "route53_health_check_ids" {
  description = "Route53 HealthCheckId 목록(메인/DR). 비워도 됨."
  type        = list(string)
  default     = []
}

variable "threshold_target_5xx_5m" {
  description = "Target 5XX 알람 임계치 (5분 Sum)"
  type        = number
  default     = 50
}

variable "threshold_latency_p90_seconds" {
  description = "TargetResponseTime p90 알람 임계치(초)"
  type        = number
  default     = 1.0
}

variable "threshold_rds_replica_lag_seconds" {
  description = "RDS ReplicaLag 알람 임계치(초)"
  type        = number
  default     = 60
}

############################################
# CloudWatch Container Insights (k3s / node 기반)
############################################

variable "enable_container_insights" {
  description = "ContainerInsights 기반 위젯/알람 활성화"
  type        = bool
  default     = true
}

variable "ci_cluster_name" {
  description = "ContainerInsights dimension: ClusterName"
  type        = string
  default     = "dr-k3s"
}

# (참고용) namespace/service/pod prefix는 더 이상 쓰지 않지만,
# remote_state outputs 호환성 때문에 남겨둠(없애도 되지만 지금은 안전하게 유지)
variable "ci_namespace" {
  description = "ContainerInsights dimension: Namespace (compat only)"
  type        = string
  default     = "default"
}

variable "ci_service_name" {
  description = "ContainerInsights dimension: Service (compat only)"
  type        = string
  default     = "justic-web-svc"
}

variable "ci_pod_name_prefix" {
  description = "ContainerInsights PodName prefix (compat only)"
  type        = string
  default     = "justic-web-"
}

# ✅ 노드 기반 임계치 (영구 안정)
variable "threshold_ci_node_cpu_utilization" {
  description = "(%) ContainerInsights node_cpu_utilization 알람 임계치"
  type        = number
  default     = 80
}

variable "threshold_ci_node_memory_utilization" {
  description = "(%) ContainerInsights node_memory_utilization 알람 임계치"
  type        = number
  default     = 80
}

# (옵션) 디스크 p90
variable "threshold_ci_node_filesystem_utilization_p90" {
  description = "(%) ContainerInsights node_filesystem_utilization p90 임계치"
  type        = number
  default     = 85
}
