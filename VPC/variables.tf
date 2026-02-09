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

