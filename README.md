# Omnia Platform

Wszechstronna platforma EC2 z kontenerami Docker, sterowana plikiem `apps.json` i katalogiem `app/`. Uruchamiana jednym kliknieciem w GitHub Actions. Zero otwartych portow, zero SSH, zero hardcode.

## Architektura

```
GitHub Actions (workflow_dispatch)
        |
        | AWS OIDC (brak statycznych kluczy)
        v
   AWS EC2 t4g.small (ARM64 Graviton, 2GB RAM)
        |
        | Ansible przez AWS SSM (brak SSH)
        v
   app/<name>/docker-compose.yml
        |
        | cloudflared tunnel (ruch wychodzacy)
        v
   https://*.trycloudflare.com (publiczny dostep)
```

## Struktura projektu

```
.
├── apps.json                          # Definicja aplikacji do wdrozenia
├── app/                               # Katalog z aplikacjami
│   └── grafana/                       # Przykladowa aplikacja
│       ├── Dockerfile
│       └── docker-compose.yml
├── terraform/
│   ├── main.tf                        # VPC, Subnet, SG, EC2, IAM, Endpoints
│   ├── variables.tf                   # Zmienne (region, AZ, typ instancji...)
│   ├── outputs.tf                     # Wyjscia (instance_id, IPv6, AZ...)
│   └── terraform.tfvars.example       # Przykladowe wartosci
├── ansible/
│   ├── ansible.cfg                    # Konfiguracja (SSM)
│   ├── inventory.yml                  # Inventory (zmienne srodowiskowe)
│   ├── playbook.yml                   # Playbook (app/ + cloudflared)
│   └── requirements.yml               # Kolekcje Ansible Galaxy
└── .github/workflows/
    ├── start-platform.yml             # Uruchomienie platformy
    └── stop-platform.yml              # Zatrzymanie platformy
```

## Wymagania lokalne

```bash
# AWS CLI
brew install awscli

# Session Manager Plugin (wymagany do polaczenia SSM)
brew install --cask session-manager-plugin

# Terraform
brew install terraform
```

## Konfiguracja - co trzeba zrobic

Do uruchomienia calej platformy potrzeba skonfigurowac trzy rzeczy:

| Co | Gdzie | Wartosc |
|----|-------|---------|
| `AWS_REGION` | GitHub Variables | np. `eu-central-1` |
| `AWS_ROLE_ARN` | GitHub Secrets | `arn:aws:iam::ACCOUNT_ID:role/github-actions-role` |
| `PLATFORM_NAME` | GitHub Variables | np. `omnia-platform` |

Po `terraform apply` dodatkowo:

| Co | Gdzie | Wartosc |
|----|-------|---------|
| `EC2_INSTANCE_ID` | GitHub Variables | z `terraform output instance_id` |

## AWS - jednorazowa konfiguracja OIDC

### 1. OIDC Provider

IAM -> Identity Providers -> Add provider:

- **Type:** OpenID Connect
- **URL:** `https://token.actions.githubusercontent.com`
- **Audience:** `sts.amazonaws.com`

### 2. Rola IAM

Utworz role IAM z trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringLike": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:TWOJ_USER/aws-ec2-omnia-platform:*"
      }
    }
  }]
}
```

### 3. Polityka uprawnien

Do celow pokazowych/deweloperskich mozna przypisac jedna polityke:

- **`AdministratorAccess`** (`arn:aws:iam::aws:policy/AdministratorAccess`)

Daje pelny dostep do wszystkich uslug AWS. W produkcji nalezy ja rozdzielic na mniejsze polityki:

| Polityka | Zakres |
|----------|--------|
| `AmazonEC2FullAccess` | Zarzadzanie instancjami EC2 |
| `AmazonSSMFullAccess` | Session Manager + Run Command |
| `AmazonVPCFullAccess` | Siec VPC, Subnets, SG |
| `IAMFullAccess` | Role, profile instancji |

## Szybki start

### 1. Infrastruktura

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edytuj terraform.tfvars (wymagane: aws_region)
terraform init
terraform apply
```

### 2. GitHub Variables i Secrets

Settings -> Secrets and variables -> Actions:

**Variables:**
- `AWS_REGION` = `eu-central-1`
- `EC2_INSTANCE_ID` = (wartosc z `terraform output instance_id`)
- `PLATFORM_NAME` = `omnia-platform`

**Secrets:**
- `AWS_ROLE_ARN` = `arn:aws:iam::ACCOUNT_ID:role/github-actions-role`

### 3. Uzycie

- **Start:** GitHub -> Actions -> "Uruchom Platform" -> Run workflow
- **Stop:** GitHub -> Actions -> "Zatrzymaj Platform" -> Run workflow

## AZ Failover

Terraform automatycznie pobiera dostepne strefy w regionie. Zmienna `preferred_az_index` wybiera preferowana (0=a, 1=b, 2=c). Jesli strefa nie ma pojemnosci - zmien indeks i uruchom ponownie:

```hcl
preferred_az_index = 1   # przejdz na eu-central-1b
```

## Katalog aplikacji (`app/`)

Kazda aplikacja ma wlasny podkatalog z Dockerfile i docker-compose:

```
app/
├── grafana/
│   ├── Dockerfile
│   └── docker-compose.yml
├── moja-appka/
│   ├── Dockerfile
│   └── docker-compose.yml
└── ...
```

Ansible dla kazdej aplikacji z `compose: true` w `apps.json`:
1. Generuje `.env` ze zmiennymi z `apps.json`
2. Uruchamia `docker-compose up -d --build`

Dla `compose: false` - prosty `docker run`.

## Dodawanie nowej aplikacji

1. Utworz `app/<nazwa>/` z `Dockerfile` i `docker-compose.yml`
2. Dodaj wpis w `apps.json`:

```json
{
  "name": "nazwa",
  "image": "obraz:tag",
  "port": 9090,
  "compose": true,
  "env": ["KEY=value"]
}
```

3. Push do repo i uruchom workflow "Uruchom Platform"

## Bezpieczenstwo

- Zero portow przychodzacych (Security Group: brak regul ingress)
- Port 22 zamkniety, klucz SSH nie istnieje na maszynie
- Zarzadzanie wylacznie przez AWS SSM (uwierzytelnianie IAM)
- IMDSv2 wymuszone (ochrona przed SSRF)
- EBS szyfrowany
- CI/CD bez statycznych kluczy (OIDC federation)
- Tunele Cloudflare = polaczenia wychodzace, nie wymagaja otwartych portow

## Licencja

MIT
