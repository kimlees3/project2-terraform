variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "az" {
  description = "Availability Zone"
  type        = string
  default     = "ap-southeast-1a"
}

# ✅ 추가: ALB용 2번째 AZ (서비스는 안 올려도 됨)
variable "az2" {
  description = "Availability Zone (secondary for ALB requirement)"
  type        = string
  default     = "ap-southeast-1b"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public Subnet CIDR"
  type        = string
  default     = "10.0.1.0/24"
}

# ✅ 추가: ALB용 퍼블릭 서브넷 2개째
variable "public_subnet_cidr2" {
  description = "Public Subnet CIDR (secondary for ALB requirement)"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_cidr" {
  description = "Private Subnet CIDR"
  type        = string
  default     = "10.0.2.0/24"
}

############################################
# CloudWatch Container Insights (k3s)
############################################

variable "enable_container_insights" {
  description = "k3s 클러스터에서 CloudWatch Container Insights(cwagent+fluent-bit) 설치 여부"
  type        = bool
  default     = true
}

variable "k3s_cluster_name" {
  description = "CloudWatch Container Insights에 표시될 Kubernetes 클러스터 이름"
  type        = string
  default     = "dr-k3s"
}

variable "k8s_namespace" {
  description = "모니터링 대상 웹 파드가 속한 namespace (CloudWatch 대시보드/알람에서 사용)"
  type        = string
  default     = "default"
}

variable "k8s_service_name" {
  description = "모니터링 대상 웹 Service 이름 (CloudWatch ContainerInsights metric dimension: Service)"
  type        = string
  default     = "justic-web-svc"
}
