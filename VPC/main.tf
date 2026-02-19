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
  map_public_ip_on_launch = true # 퍼블릭 IPv4 자동할당

  tags = {
    Name = "drpubSN"
  }
}
# ✅ 추가: ALB 요건 충족용 퍼블릭 서브넷(2번째 AZ)
resource "aws_subnet" "drpubSN2" {
  vpc_id                  = aws_vpc.dr.id
  cidr_block              = var.public_subnet_cidr2
  availability_zone       = var.az2
  map_public_ip_on_launch = true

  tags = {
    Name = "drpubSN2"
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
# ✅ 추가: 2번째 퍼블릭 서브넷도 public_rt에 연결
resource "aws_route_table_association" "public_assoc2" {
  subnet_id      = aws_subnet.drpubSN2.id
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

resource "aws_key_pair" "drkeypair" {
  key_name   = "drkeypair"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "aws_security_group" "alb_sg" {
  name        = "dr-alb-sg"
  description = "ALB SG: allow inbound 80/443 from Internet"
  vpc_id      = aws_vpc.dr.id

  tags = {
    Name = "dr-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from Internet"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from Internet"
}

resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "drSG" {
  name        = "drSG"
  description = "EC2 SG: allow from ALB only"
  vpc_id      = aws_vpc.dr.id

  tags = {
    Name = "drSG"
  }
}

resource "aws_vpc_security_group_ingress_rule" "dr_ec2_ssh" {
  security_group_id = aws_security_group.drSG.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH (recommend restrict to your IP or use SSM only)"
}

resource "aws_vpc_security_group_ingress_rule" "dr_ec2_from_alb_http" {
  security_group_id            = aws_security_group.drSG.id
  referenced_security_group_id = aws_security_group.alb_sg.id
  from_port                    = 30130
  to_port                      = 30130
  ip_protocol                  = "tcp"
  description                  = "HTTP(NodePort 30130) from ALB only"
}

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
  ip_protocol       = "-1"
}

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
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.large"
  subnet_id              = aws_subnet.drprivSN.id
  key_name               = aws_key_pair.drkeypair.key_name
  vpc_security_group_ids = [aws_security_group.drSG.id]
  iam_instance_profile   = aws_iam_instance_profile.dr_ec2_ssm_profile.name

  user_data_replace_on_change = true
  user_data_base64 = base64encode(templatefile("${path.module}/user_data_k3s.sh", {
    aws_region                = var.aws_region
    k3s_cluster_name          = var.k3s_cluster_name
    enable_container_insights = var.enable_container_insights
  }))

  tags = {
    Name = "drEC2"
  }
}

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

############################################
# ✅ ALB + Target Group + Listener
############################################

resource "aws_lb" "dr_alb" {
  name               = "dr-alb"
  load_balancer_type = "application"
  internal           = false

  subnets         = [aws_subnet.drpubSN.id, aws_subnet.drpubSN2.id]
  security_groups = [aws_security_group.alb_sg.id]

  tags = {
    Name = "dr-alb"
  }
}

resource "aws_lb_target_group" "dr_tg" {
  name     = "dr-tg"
  port     = 30130
  protocol = "HTTP"
  vpc_id   = aws_vpc.dr.id

  health_check {
    path                = "/health"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "dr-tg"
  }
}

resource "aws_lb_target_group_attachment" "dr_ec2_attach" {
  target_group_arn = aws_lb_target_group.dr_tg.arn
  target_id        = aws_instance.drEC2.id
  port             = 30130
}

resource "aws_lb_listener" "dr_http" {
  load_balancer_arn = aws_lb.dr_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dr_tg.arn
  }
}

resource "aws_iam_role_policy_attachment" "dr_ec2_policy_attachments" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonSSMFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
  ])

  role       = aws_iam_role.dr_ec2_ssm_role.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "dr_ec2_ssm_profile" {
  name = "dr-ec2-ssm-profile"
  role = aws_iam_role.dr_ec2_ssm_role.name
}
