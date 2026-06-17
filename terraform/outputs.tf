# =============================================================================
# Wyjscia Terraform - Uzywane przez GitHub Actions i Ansible
# =============================================================================

output "instance_id" {
  description = "ID instancji EC2 (uzywane przez workflow start/stop oraz Ansible SSM)"
  value       = aws_instance.platform.id
}

output "instance_arn" {
  description = "ARN instancji EC2"
  value       = aws_instance.platform.arn
}

output "vpc_id" {
  description = "ID sieci VPC"
  value       = aws_vpc.platform.id
}

output "subnet_id" {
  description = "ID podsieci"
  value       = aws_subnet.platform.id
}

output "security_group_id" {
  description = "ID Security Group (brak regul inbound)"
  value       = aws_security_group.platform_instance.id
}

output "iam_role_arn" {
  description = "ARN roli IAM przypisanej do instancji"
  value       = aws_iam_role.platform_instance.arn
}

output "instance_ipv6" {
  description = "Adres IPv6 instancji (brak publicznego IPv4)"
  value       = aws_instance.platform.ipv6_addresses
}

output "ami_id" {
  description = "ID obrazu AMI uzywanego przez instancje"
  value       = data.aws_ami.ubuntu_arm64.id
}

output "region" {
  description = "Region AWS"
  value       = data.aws_region.current.name
}

output "availability_zone" {
  description = "Wybrana strefa dostepnosci (AZ)"
  value       = local.selected_az
}

output "available_azs" {
  description = "Wszystkie dostepne strefy AZ w regionie"
  value       = local.available_azs
}

output "project_name" {
  description = "Nazwa projektu"
  value       = var.project_name
}
