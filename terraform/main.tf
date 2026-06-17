# =============================================================================
# Omnia Platform - Konfiguracja Terraform
# =============================================================================
# Wszechstronna platforma EC2 z kontenerami Docker.
# Wszystkie wartosci sa parametryzowane - BRAK hardcode.
# AZ failover: jesli preferowana strefa nie ma pojemnosci, przechodzi do nastepnej.
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

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

# Sprawdzenie dostepnosci typu instancji w kazdej strefie AZ
# Filtuje strefy, gdzie t4g.small jest dostepny
data "aws_ec2_instance_type_offerings" "available" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }

  filter {
    name   = "location"
    values = data.aws_availability_zones.available.names
  }

  location_type = "availability-zone"
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

  # Lista stref AZ gdzie dostepny jest t4g.small
  azs_with_instance_type = distinct(
    [for item in data.aws_ec2_instance_type_offerings.available : item.location]
  )

  # Sortowanie AZ z preferencja na preferred_az_index
  # 1. Branie pierwsze dostepne AZ ze wskazanym indeksem
  # 2. Jesli indeks poza zakresem, branie pierwsze dostepne
  # 3. Jesli prefererowana AZ niedostepna, przechodzenie do nastepnych
  preferred_az_candidates = [
    for idx in range(length(local.available_azs)) :
    local.available_azs[
      (var.preferred_az_index + idx) % length(local.available_azs)
    ]
    if contains(local.azs_with_instance_type, local.available_azs[
      (var.preferred_az_index + idx) % length(local.available_azs)
    ])
  ]

  # Wybrana strefa AZ - pierwsza dostepna z preferowanym failoverem
  selected_az = length(local.preferred_az_candidates) > 0 ? local.preferred_az_candidates[0] : (
    length(local.azs_with_instance_type) > 0 ? local.azs_with_instance_type[0] : null
  )

  # Walidacja: jesli zadna AZ nie ma pojemnosci - blad z dobrym komunikatem
  validation_error = (
    local.selected_az == null ?
    "BLAD: Typ instancji ${var.instance_type} niedostepny w zadnej strefie AZ regionu ${var.aws_region}. Dostepne AZ: ${join(", ", local.available_azs)}, ale zadna nie ma pojemnosci dla tego typu. Sprobuj inny typ instancji lub zmien region."
    : ""
  )

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

# Internet Gateway - wymagany do routingu IPv6
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

  # Trasa IPv4 przez IGW (lacznosc z VPC Endpoints)
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

# =============================================================================
# VPC ENDPOINTS DLA SSM (warunkowo - kontrolowane zmienna)
# =============================================================================
# SSM wymaga lacznosci z API AWS. Bez publicznego IPv4 potrzebujemy VPC Endpoints.

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name_prefix = "${local.name_prefix}-vpce-"
  vpc_id      = aws_vpc.platform.id
  description = "Grupa bezpieczenstwa dla VPC Endpoints (SSM) - ${var.project_name}"

  ingress {
    description = "HTTPS z VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name_prefix}-vpce-sg"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.platform.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.platform.id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${local.name_prefix}-ssm-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm_messages" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.platform.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.platform.id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${local.name_prefix}-ssmmessages-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2_messages" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.platform.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.platform.id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = {
    Name = "${local.name_prefix}-ec2messages-endpoint"
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

  # User data: uruchomienie agenta SSM przy pierwszym starcie
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e
    # Agent SSM jest preinstalowany na Debian - upewniamy sie ze dziala
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
    echo "SSM_READY" > /tmp/instance-ready
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

  # Walidacja: jesli zadna AZ nie ma pojemnosci - rzuci blad z jasnym komunikatem
  lifecycle {
    precondition {
      condition     = local.selected_az != null
      error_message = local.validation_error
    }
    ignore_changes = [ami]
  }
}
