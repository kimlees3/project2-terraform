############################################
# VPC
############################################
resource "aws_vpc" "dr" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dr"
  }
}

############################################
# Subnets
############################################
resource "aws_subnet" "drpubSN" {
  vpc_id                  = aws_vpc.dr.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = true  # 퍼블릭 IPv4 자동할당

  tags = {
    Name = "drpubSN"
  }
}

resource "aws_subnet" "drprivSN" {
  vpc_id            = aws_vpc.dr.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.az

  tags = {
    Name = "drprivSN"
  }
}

############################################
# Internet Gateway (VPC에 Attach)
############################################
resource "aws_internet_gateway" "drigw" {
  vpc_id = aws_vpc.dr.id

  tags = {
    Name = "drigw"
  }
}

############################################
# NAT Gateway (퍼블릭 서브넷 + EIP)
############################################
resource "aws_eip" "drnat_eip" {
  domain = "vpc"

  tags = {
    Name = "drnat_eip"
  }
}

resource "aws_nat_gateway" "drnat" {
  allocation_id = aws_eip.drnat_eip.id
  subnet_id     = aws_subnet.drpubSN.id

  tags = {
    Name = "drnat"
  }

  depends_on = [aws_internet_gateway.drigw]
}

############################################
# Route Tables (route 블록 내장형)
############################################

# Public RT: 0.0.0.0/0 -> drigw
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.dr.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.drigw.id
  }

  tags = {
    Name = "public_rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.drpubSN.id
  route_table_id = aws_route_table.public_rt.id
}

# Private RT: 0.0.0.0/0 -> drnat
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.dr.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.drnat.id
  }

  tags = {
    Name = "private_rt"
  }
}

resource "aws_route_table_association" "private_assoc" {
  subnet_id      = aws_subnet.drprivSN.id
  route_table_id = aws_route_table.private_rt.id
}


############################################
# EC2 생성
# drkeypair 생성
# drSG 생성
# EC2 생성
############################################

# drkeypair 생성

resource "aws_key_pair" "drkeypair" {
  key_name   = "drkeypair"
  public_key = file("~/.ssh/id_ed25519.pub")
}

# drSG 생성
resource "aws_security_group" "drSG" {
  name        = "drSG"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.dr.id

  tags = {
    Name = "drSG"
  }
}
# SSH 22 
resource "aws_vpc_security_group_ingress_rule" "dr_ec2_ssh" {
  security_group_id = aws_security_group.drSG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from admin IP"
}

# HTTP 80 from anywhere
resource "aws_vpc_security_group_ingress_rule" "dr_ec2_http" {
  security_group_id = aws_security_group.drSG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from Internet"
}

# HTTPS 443 from anywhere
resource "aws_vpc_security_group_ingress_rule" "dr_ec2_https" {
  security_group_id = aws_security_group.drSG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from Internet"
}

# ICMP (ping) from admin IP only
# Note: for ICMP, use from_port/to_port = -1 to allow all ICMP types/codes.
resource "aws_vpc_security_group_ingress_rule" "dr_ec2_icmp" {
  security_group_id = aws_security_group.drSG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "icmp"
  from_port         = -1
  to_port           = -1
  description       = "ICMP (ping) "
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.drSG.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}





# EC2 생성
data "aws_ami" "amazon_linux_2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023.10.*-kernel-6.1-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon
}

resource "aws_instance" "drEC2" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.large"  # or t3.xlarge
  subnet_id = aws_subnet.drprivSN.id
  key_name = aws_key_pair.drkeypair.key_name
  vpc_security_group_ids = [aws_security_group.drSG.id]
  iam_instance_profile = aws_iam_instance_profile.dr_ec2_ssm_profile.name


 # user_data 변경 시 재생성 (원하면 false로)
  user_data_replace_on_change = true
  user_data_base64            = filebase64("${path.module}/user_data_k3s.sh")

  tags = {
    Name = "drEC2"
  }
}


# EC2에 붙일 롤 정의 (SSM)만 일단 추가

resource "aws_iam_role" "dr_ec2_ssm_role" {
  name = "dr-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = ""
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "dr-ec2-ssm-role"
  }
}

# SSM 필수 (Managed Instance 등록용)
resource "aws_iam_role_policy_attachment" "dr_ec2_ssm_core" {
  role       = aws_iam_role.dr_ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# SSM Full Access (SSM 리소스 관리용)
resource "aws_iam_role_policy_attachment" "dr_ec2_ssm_full" {
  role       = aws_iam_role.dr_ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}
resource "aws_iam_instance_profile" "dr_ec2_ssm_profile" {
  name = "dr-ec2-ssm-profile"
  role = aws_iam_role.dr_ec2_ssm_role.name
}
