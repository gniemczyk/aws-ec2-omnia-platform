# AWS EC2 Omnia Platform

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
├── app/                               # Katalog z aplikacjami (szczegoly: app/README.md)
│   └── README.md
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
    ├── create-infrastructure.yml      # Tworzenie infrastruktury (Terraform)
    ├── start-platform.yml             # Uruchomienie platformy (Ansible)
    ├── stop-platform.yml              # Zatrzymanie platformy
    ├── destroy-infrastructure.yml     # Zniszczenie infrastruktury (Terraform)
    └── lint-and-scan.yml              # Linting i skanowanie bezpieczenstwa
```

## Wymagania lokalne (opcjonalne)

Lokalne narzedzia sa **opcjonalne** - wszystko dziala przez GitHub Actions:

```bash
# Opcjonalnie: AWS CLI do manualnych operacji
brew install awscli

# Opcjonalnie: Session Manager Plugin do SSM
brew install --cask session-manager-plugin
```

**Terraform jest w GitHub Actions - nie trzeba go instalowac lokalnie!**

## Konfiguracja - AWS (jednorazowo)

Potrzebne sa tylko 2 rzeczy w GitHub:

| Co | Gdzie | Wartosc |
|----|-------|---------|
| `AWS_ROLE_ARN` | GitHub Secrets | `arn:aws:iam::ACCOUNT_ID:role/github-actions-role` |
| `AWS_REGION` | GitHub Variables | np. `eu-central-1` |
| `PLATFORM_NAME` | GitHub Variables | np. `omnia-platform` |

> 💡 **Ważne:** Rola IAM (`AWS_ROLE_ARN`) musi posiadać uprawnienia do tworzenia i zarządzania zasobami S3 (bucket stanu), EC2, VPC, IAM i AWS Systems Manager (SSM Parameter Store).
>
> 💡 **Aplikacje mogą wymagać dodatkowych secretów** — zobacz [app/README.md](app/README.md) dla szczegółów.

**Wszystkie inne parametry (EC2_INSTANCE_ID, PLATFORM_BASE_DIR) ustawia się automatycznie w AWS SSM Parameter Store!**

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

## Szybki start (pełna automatyzacja - GitHub Actions)

### 1. Konfiguracja AWS (OIDC) - jednorazowo

#### a) Utwórz OIDC Provider w AWS

IAM -> Identity Providers -> Add provider:

- **Type:** OpenID Connect
- **URL:** `https://token.actions.githubusercontent.com`
- **Audience:** `sts.amazonaws.com`

#### b) Utwórz IAM Role dla GitHub Actions

Utwórz rolę IAM z trust policy (patrz sekcja poniżej: "AWS - jednorazowa konfiguracja OIDC").

#### c) Ustawić Secret w GitHub

Settings -> Secrets and variables -> Actions -> Create secret:

- **Name:** `AWS_ROLE_ARN`
- **Value:** `arn:aws:iam::ACCOUNT_ID:role/github-actions-role`

### 2. Uruchom workflow "Utwórz Infrastrukturę"

GitHub -> Actions -> "Utwórz Infrastrukturę" -> Run workflow

Workflow korzysta z GitHub Variables (ustawionych w kroku 1):
- `AWS_REGION`: region AWS (np. `eu-central-1`)
- `PLATFORM_NAME`: nazwa platformy (np. `aws-omnia-platform`)

**Co się stanie:**
- ✅ Automatyczna konfiguracja backendu (S3 bucket + native locking)
- ✅ Terraform tworzy VPC, Subnet, Security Group, EC2, VPC Endpoints (SSM + S3)
- ✅ Dynamiczny failover AZ - jeśli brakuje capacity, próbuje następną
- ✅ **Parametry automatycznie zapisane w AWS SSM Parameter Store** (`/&lt;PLATFORM_NAME&gt;/` prefix):
  - `/&lt;PLATFORM_NAME&gt;/EC2_INSTANCE_ID`
  - `/&lt;PLATFORM_NAME&gt;/AWS_REGION`
  - `/&lt;PLATFORM_NAME&gt;/PLATFORM_NAME`
  - `/&lt;PLATFORM_NAME&gt;/PLATFORM_BASE_DIR`
- ✅ Gotowe do użytku!

### 3. Uruchom workflow "Uruchom Platform"

GitHub -> Actions -> "Uruchom Platform" -> Run workflow

**Co się stanie:**
- ✅ Parametry automatycznie pobierane z AWS SSM Parameter Store
- ✅ Instancja EC2 startuje
- ✅ Ansible przez SSM wdrażana aplikacje z `apps.json`
- ✅ Cloudflare tunnels tworzą publiczne URL-e

### 4. Gotowe!

Sprawdź podsumowanie workflow - tam są linki do aplikacji (https://*.trycloudflare.com).

### 5. Zatrzymanie (oszczędność kosztów)

GitHub -> Actions -> "Zatrzymaj Platform" -> Run workflow

Wpisz `stop` aby potwierdzić.

**Co się stanie:**
- ✅ Instancja zatrzymana (rachunki zamrożone)
- ✅ Dane zachowane - uruchomienie zajmie ~3-5 minut
- ✅ Tunele Cloudflare zamknięte

### 6. Zniszczenie infrastruktury (końcowe)

GitHub -> Actions -> "Zniszcz Infrastrukturę" -> Run workflow

Wpisz `destroy` aby potwierdzić.

**OSTRZEŻENIE: Ta operacja jest nieodwracalna!**
- ✅ Wszystkie zasoby AWS usunięte
- ✅ EBS volumes usunięte
- ✅ **Parametry z AWS SSM Parameter Store usunięte**
- ⚠️ Brak kopii zapasowych

---

## AWS SSM Parameter Store - Konfiguracja automatyczna

Wszystkie parametry konfiguracyjne są przechowywane w **AWS Systems Manager Parameter Store** pod prefixem `/&lt;PLATFORM_NAME&gt;/`:

| Parameter | Wartość | Źródło | Użycie |
|-----------|---------|--------|--------|
| `/&lt;PLATFORM_NAME&gt;/EC2_INSTANCE_ID` | `i-0abc123def456789` | Terraform output | start/stop/destroy |
| `/&lt;PLATFORM_NAME&gt;/AWS_REGION` | `eu-central-1` | Terraform variable | start/stop workflows |
| `/&lt;PLATFORM_NAME&gt;/PLATFORM_NAME` | `omnia-platform` | GitHub Variable | S3 bucket naming |
| `/&lt;PLATFORM_NAME&gt;/PLATFORM_BASE_DIR` | `/opt/omnia` | Workflow default | Ansible paths |

**Zalety SSM Parameter Store:**
- ✅ Brak hardcoded values w workflow'ach
- ✅ Brak konieczności ręcznego ustawiania GitHub Variables
- ✅ Parametry automatycznie czyszczone przy destroy
- ✅ Centralne miejsce konfiguracji (AWS)
- ✅ Integracja z AWS IAM (bezpieczeństwo)
- ✅ Free tier (do 10,000 parameters)

---

Terraform automatycznie:
1. Pobiera wszystkie dostępne AZ w regionie
2. Sprawdza, które AZ mają dostępny `t4g.small`
3. Zaczyna od preferowanej AZ (`preferred_az_index`)
4. Jeśli brakuje capacity - przechodzi do następnej AZ
5. Jeśli żadna AZ nie ma pojemności - wyrzuca błąd z komunikatem

**Poprzednio:** Trzeba było ręcznie zmieniać `preferred_az_index` w tfvars.

**Teraz:** Automatycznie próbuje kolejne AZ!

---

## Workflow'i GitHub Actions

| Workflow | Opis | Config Storage | Czyści koszty |
|----------|------|---|---|
| **Utwórz Infrastrukturę** | Terraform apply: VPC + EC2 + sieci | → SSM | ❌ Nie (EC2 startuje) |
| **Uruchom Platform** | Ansible: Docker + aplikacje + Cloudflare | ← SSM | ❌ Nie |
| **Zatrzymaj Platform** | Stop EC2 (oszczędza rachunki) | ← SSM | ✅ Tak |
| **Zniszcz Infrastrukturę** | Terraform destroy + SSM cleanup | ← SSM | ✅ Tak |

### Przepływ konfiguracji

```
1. Utwórz Infrastrukturę
   ↓
   Terraform outputs
   ↓
   AWS SSM Parameter Store (/&lt;PLATFORM_NAME&gt;/*)
   ↓
2. Uruchom Platform (automatycznie pobiera z SSM)
   ↓
   EC2 + Ansible + Apps
   ↓
3. Zatrzymaj Platform (czyta EC2_INSTANCE_ID z SSM)
   ↓
   EC2 stopped
   ↓
4. Zniszcz Infrastrukturę (usuwaja z SSM po Terraform destroy)
   ↓
   Clean slate
```

---

Aplikacje są definiowane w `apps.json` i wdrażane przez Ansible (docker-compose lub docker run). Każda aplikacja ma własny podkatalog `app/<nazwa>/`.

Szczegóły konfiguracji, lista dostępnych aplikacji i instrukcja dodawania nowych znajdują się w osobnej dokumentacji:

➡️ **[app/README.md](app/README.md)**

## Bezpieczenstwo

- Zero portow przychodzacych (Security Group: brak regul ingress)
- Port 22 zamkniety, klucz SSH nie istnieje na maszynie
- Zarzadzanie wylacznie przez AWS SSM (uwierzytelnianie IAM)
- IMDSv2 wymuszone (ochrona przed SSRF)
- EBS szyfrowany
- CI/CD bez statycznych kluczy (OIDC federation)
- Tunele Cloudflare = polaczenia wychodzace, nie wymagaja otwartych portow
- **Brak hardcoded credentials** - hasla przekazywane przez GitHub Secrets lub generowane losowo podczas deployu
- **Plik `apps.json` nie zawiera hasel** - wrażliwe zmienne przekazuj przez GitHub Secrets

## Licencja

MIT
