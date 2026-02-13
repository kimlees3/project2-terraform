variable "project" {
  type    = string
  default = "project2"
}

variable "alarm_email" {
  type        = string
  description = "CloudWatch Alarm SNS 구독 이메일"
}

# ===== ALB/TG 목록 (리전별) =====
# alb_arn_suffix 예: app/my-alb/1234567890abcdef
# tg_arn_suffix  예: targetgroup/my-tg/1234567890abcdef
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

# ===== (선택) DR EC2 / RDS Replica / Route53 Health Check =====
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

# ===== 임계치(원하면 조정) =====
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
