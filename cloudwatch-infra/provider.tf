terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Seoul (default)
provider "aws" {
  region = "ap-northeast-2"
}

# Singapore (alias)
provider "aws" {
  alias  = "sin"
  region = "ap-southeast-1"
}

# Route53 알람용 (alias)
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}
