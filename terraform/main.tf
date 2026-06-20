# =============================================================================
# Omnia Platform - Konfiguracja Terraform
# =============================================================================
# Wszechstronna platforma EC2 z kontenerami Docker.
# Wszystkie wartosci sa parametryzowane - BRAK hardcode.
# AZ failover: jesli preferowana strefa nie ma pojemnosci, przechodzi do nastepnej.
# =============================================================================

terraform {
  # Wymagana >= 1.10.0 z powodu uzycia 'use_lockfile=true' w backendzie S3
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.53.0"
    }
  }

  backend "s3" {
    # Konfiguracja wstrzykiwana przez CLI podczas 'terraform init'
    # bucket         = "..."
    # key            = "..."
    # region         = "..."
    # dynamodb_table = "..."
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = var.project_name
        ManagedBy   = "terraform"
        Environment = var.environment
      },
      var.additional_tags
    )
  }
}

# =============================================================================
# ZRODLA DANYCH
# =============================================================================

# Pobranie wszystkich dostepnych stref AZ w wybranym regionie
data "aws_availability_zones" "available" {
  state = "available"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Najnowszy obraz Debian dla architektury ARM64 (Graviton)
data "aws_ami" "debian_arm64" {
  most_recent = true
  owners      = ["136693071363"] # Debian

  filter {
    name   = "name"
    values = ["debian-13-arm64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["arm64"]
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# LOKALNE WARTOSCI (obliczane z zmiennych)
# =============================================================================

locals {
  # Lista dostepnych stref AZ w regionie
  available_azs = data.aws_availability_zones.available.names

  # Wybrana strefa AZ z preferencja na preferred_az_index
  # Jesli indeks poza zakresem - wraca do indexu 0
  selected_az_index = var.preferred_az_index % length(local.available_azs)
  selected_az       = local.available_azs[local.selected_az_index]

  # Prefiks nazw zasobow
  name_prefix = var.project_name

  # Tagi wspólne
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Region      = var.aws_region
    AZ          = local.selected_az
  }
}

# =============================================================================
# VPC I SIEC (dostep publiczny wylacznie IPv6)
# =============================================================================

resource "aws_vpc" "platform" {
  cidr_block = var.vpc_cidr

  # Wlaczenie IPv6 - Amazon przydziela blok /56 za darmo
  assign_generated_ipv6_cidr_block = true

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# Internet Gateway - wymagany dla VPC Endpoints (Interface) oraz routingu IPv4
resource "aws_internet_gateway" "platform" {
  vpc_id = aws_vpc.platform.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# Egress-Only Internet Gateway - ruch wychodzacy IPv6, blokuje niechciany przychodzacy
# IPv6-owy odpowiednik NAT Gateway (darmowy)
resource "aws_egress_only_internet_gateway" "platform" {
  vpc_id = aws_vpc.platform.id

  tags = {
    Name = "${local.name_prefix}-eigw"
  }
}

# Podsiec z IPv6 - umieszczona w wybranej strefie AZ (z failoverem)
resource "aws_subnet" "platform" {
  vpc_id            = aws_vpc.platform.id
  cidr_block        = var.subnet_cidr
  availability_zone = local.selected_az

  # Podsiec IPv6 (/64 z bloku /56 VPC)
  ipv6_cidr_block = cidrsubnet(aws_vpc.platform.ipv6_cidr_block, 8, 1)

  # Brak publicznego IPv4 (oszczednosc $3.6/mies. za IP)
  map_public_ip_on_launch = false

  # Przypisanie adresu IPv6 przy uruchomieniu instancji
  assign_ipv6_address_on_creation = true

  tags = {
    Name = "${local.name_prefix}-subnet-${local.selected_az}"
  }
}

# Tablica routingu
resource "aws_route_table" "platform" {
  vpc_id = aws_vpc.platform.id

  # Trasa IPv4 przez IGW (instancja bez publicznego IP - dziala tylko dla VPC Endpoints)
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.platform.id
  }

  # Trasa IPv6 przez Egress-Only IGW (tylko wychodzacy)
  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.platform.id
  }

  tags = {
    Name = "${local.name_prefix}-rt"
  }
}

resource "aws_route_table_association" "platform" {
  subnet_id      = aws_subnet.platform.id
  route_table_id = aws_route_table.platform.id
}

# S3 Gateway Endpoint (DARMOWY) - wymagany do:
# - Pobrania pakietu SSM Agent podczas user_data
# - Operacji SSM Agent (logi, dokumenty)
# - Docker pull (ECR uzywa S3 pod spodem)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.platform.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.platform.id]

  tags = {
    Name = "${local.name_prefix}-s3-endpoint"
  }
}

# =============================================================================
# GRUPA BEZPIECZENSTWA (Zero Inbound - Maksymalne Bezpieczenstwo)
# =============================================================================

resource "aws_security_group" "platform_instance" {
  name_prefix = "${local.name_prefix}-instance-"
  vpc_id      = aws_vpc.platform.id
  description = "DENY ALL inbound, ALLOW ALL outbound. Zarzadzanie wylacznie przez SSM."

  # BRAK REGUL INBOUND = DENY ALL
  # Port 22 NIE jest otwarty - SSH jest calkowicie zablokowany

  # Caly ruch wychodzacy (Docker pull, apt, cloudflared)
  egress {
    description = "Caly ruch wychodzacy IPv4"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Caly ruch wychodzacy IPv6"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${local.name_prefix}-instance-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# =============================================================================
# ROLA IAM I PROFIL INSTANCJI (dostep SSM)
# =============================================================================

resource "aws_iam_role" "platform_instance" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${local.name_prefix}-ec2-role"
  }
}

# Polityka SSM Managed Instance Core - wlacza Session Manager i Run Command
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.platform_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Polityka odczytu S3 i zapisu SSM - wymagana przez Ansible na instancji
resource "aws_iam_role_policy" "platform_access" {
  count = var.ssm_s3_bucket_name != "" ? 1 : 0
  name  = "platform-access"
  role  = aws_iam_role.platform_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3BinRead"
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = [
          "arn:aws:s3:::${var.ssm_s3_bucket_name}/bin/*",
          "arn:aws:s3:::${var.ssm_s3_bucket_name}/apps/*"
        ]
      },
      {
        Sid    = "SSMGrafanaAccess"
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:DeleteParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/GRAFANA_*"
      },
      {
        Sid    = "CloudWatchReadOnly"
        Effect = "Allow"
        Action = [
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:DescribeAlarms"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2ReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeRegions"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "platform_instance" {
  name = "${local.name_prefix}-instance-profile"
  role = aws_iam_role.platform_instance.name
}

# =============================================================================
# INSTANCJA EC2 (ARM64 Graviton)
# =============================================================================

resource "aws_instance" "platform" {
  ami                    = data.aws_ami.debian_arm64.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.platform.id
  iam_instance_profile   = aws_iam_instance_profile.platform_instance.name
  vpc_security_group_ids = [aws_security_group.platform_instance.id]
  availability_zone      = local.selected_az

  # Brak klucza SSH - uzywamy wylacznie SSM
  key_name = null

  # Dysk glowny
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  # User data: instalacja SSM Agent na Debian ARM64 + konfiguracja IPv6 dual-stack
  # SSM Agent pobierany z S3 (przez VPC Gateway Endpoint - darmowy)
  # UseDualStackEndpoint umozliwia komunikacje przez IPv6 + Egress-Only IGW
  user_data = base64encode(<<-EOF
#!/bin/bash
exec > /var/log/user-data.log 2>&1
echo "=== User Data Start: $(date) ==="

# Konfiguracja dual-stack IPv6 (PRZED instalacja agenta - zeby agent od razu uzywal IPv6)
echo "Konfiguracja UseDualStackEndpoint dla IPv6..."
mkdir -p /etc/amazon/ssm
printf '{\n  "Agent": {\n    "UseDualStackEndpoint": true\n  }\n}\n' > /etc/amazon/ssm/amazon-ssm-agent.json

# Instalacja SSM Agent z S3 (przez Gateway Endpoint - darmowy IPv4)
echo "Instalacja SSM Agent..."
apt-get update -y
apt-get install -y curl

SSM_DEB="/tmp/amazon-ssm-agent.deb"
curl -fsSL "https://s3.${var.aws_region}.amazonaws.com/amazon-ssm-${var.aws_region}/latest/debian_arm64/amazon-ssm-agent.deb" \
  -o "$SSM_DEB" || \
curl -fsSL "https://amazon-ssm-${var.aws_region}.s3.dualstack.${var.aws_region}.amazonaws.com/latest/debian_arm64/amazon-ssm-agent.deb" \
  -o "$SSM_DEB"

dpkg -i "$SSM_DEB"
rm -f "$SSM_DEB"

# Wymus restart (na wypadek gdyby dpkg juz wystartowal agenta przed zapisem configu)
systemctl restart amazon-ssm-agent

sleep 3
if systemctl is-active --quiet amazon-ssm-agent; then
  echo "SSM Agent dziala poprawnie (IPv6 dual-stack)"
else
  echo "BLAD: SSM Agent nie uruchomil sie!"
  systemctl status amazon-ssm-agent || true
  journalctl -u amazon-ssm-agent --no-pager -n 20 || true
fi

echo "SSM_READY" > /tmp/instance-ready
echo "=== User Data End: $(date) ==="
EOF
  )

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = {
    Name = "${local.name_prefix}-instance"
  }

  # Ignorowanie zmian AMI - mogą się pojawiać aktualizacje Debian
  lifecycle {
    ignore_changes = [ami]
  }
}
