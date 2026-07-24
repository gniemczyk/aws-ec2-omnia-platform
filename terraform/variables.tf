# =============================================================================
# Omnia Platform - Zmienne Terraform
# =============================================================================
# Kazda wartosc jest konfigurowalna - BRAK hardcode.
# Zmienne moga byc nadpisywane przez terraform.tfvars lub -var w CLI.
# =============================================================================

variable "aws_region" {
  description = "Region AWS do wdrozenia platformy"
  type        = string
}

variable "instance_type" {
  description = "Typ instancji EC2 (ARM64 Graviton). t4g.small = 2 vCPU, 2GB RAM"
  type        = string
  default     = "t4g.small"

  validation {
    condition     = can(regex("^t4g\\.", var.instance_type))
    error_message = "Typ instancji musi nalezec do rodziny t4g (ARM64 Graviton)."
  }
}

variable "project_name" {
  description = "Nazwa projektu - uzywana jako prefiks dla wszystkich zasobow"
  type        = string
  default     = "omnia-platform"
}

variable "vpc_cidr" {
  description = "Blok CIDR dla VPC (prywatny IPv4, RFC1918)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "Blok CIDR dla podsieci"
  type        = string
  default     = "10.0.1.0/24"
}

variable "root_volume_size" {
  description = "Rozmiar dysku glownego w GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Typ dysku glownego (gp3 najtanszy)"
  type        = string
  default     = "gp3"
}

variable "preferred_az_index" {
  description = "Indeks AZ wybieranej z listy dostepnych stref regionu (0=a, 1=b, 2=c). Nie jest to failover capacity; w razie InsufficientInstanceCapacity wybierz inny indeks lub uzyj ASG."
  type        = number
  default     = 0

  validation {
    condition     = var.preferred_az_index >= 0 && floor(var.preferred_az_index) == var.preferred_az_index
    error_message = "preferred_az_index musi byc liczba calkowita >= 0."
  }
}

variable "environment" {
  description = "Srodowisko (np. dev, staging, prod)"
  type        = string
  default     = "platform"
}

variable "additional_tags" {
  description = "Dodatkowe tagi do zastosowania na wszystkich zasobach"
  type        = map(string)
  default     = {}
}

variable "ssm_s3_bucket_name" {
  description = "Nazwa bucketa S3 uzywanego przez Ansible SSM connection plugin"
  type        = string
  default     = ""
}
