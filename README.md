# AWS EC2 Omnia Platform and Applications

Wszechstronna platforma EC2 z kontenerami Docker, sterowana plikiem `apps.json` i katalogiem `app/`. Uruchamiana jednym kliknięciem w GitHub Actions. Zero otwartych portów, zero SSH, zero hardcode. Zoptymalizowana kosztowo dzięki rezygnacji z publicznego adresu IPv4 – instancja posiada wyłącznie IPv6, a z klasycznym internetem komunikuje się przez "ukryte" wyjście na świat via Cloudflare WARP.

## Architektura

```text
GitHub Actions (workflow_dispatch)
        |
        | AWS OIDC (brak statycznych kluczy)
        v
   AWS EC2 t4g.small (ARM64 Graviton, 2GB RAM) - IPv6 Only
        |
        | Ansible przez AWS SSM (brak SSH)
        v
   app/<name>/docker-compose.yml
        |
        | [Inbound] cloudflared tunnel (dostęp publiczny)
        | [Outbound] Cloudflare WARP (ukryte wyjście NAT64/IPv4 w świat)
        v
   https://*.trycloudflare.com / Internet
```

## Struktura projektu

```
.
├── apps.json                          # Definicja aplikacji do wdrożenia
├── app/                               # Katalog z aplikacjami (szczegóły: app/README.md)
│   └── README.md
├── terraform/
│   ├── main.tf                        # VPC, Subnet, SG, EC2, IAM, Endpoints
│   ├── variables.tf                   # Zmienne (region, AZ, typ instancji...)
│   ├── outputs.tf                     # Wyjścia (instance_id, IPv6, AZ...)
│   └── terraform.tfvars.example       # Przykładowe wartości
├── ansible/
│   ├── ansible.cfg                    # Konfiguracja (SSM)
│   ├── inventory.yml                  # Inventory (zmienne środowiskowe)
│   ├── playbook.yml                   # Playbook (app/ + cloudflared + WARP)
│   ├── requirements.yml               # Kolekcje Ansible Galaxy
│   └── tasks/
│       └── warp.yml                   # Cloudflare WARP - hybrydowy dostęp do Internetu po IPv6
└── .github/workflows/
    ├── create-infrastructure.yml      # Tworzenie infrastruktury (Terraform)
    ├── start-platform.yml             # Uruchomienie platformy (Ansible)
    ├── stop-platform.yml              # Zatrzymanie platformy
    ├── destroy-infrastructure.yml     # Zniszczenie infrastruktury (Terraform)
    └── lint-and-scan.yml              # Linting i skanowanie bezpieczeństwa
```

## Wymagania lokalne (opcjonalne)

Lokalne narzędzia są **opcjonalne** – wszystko działa przez GitHub Actions:

```bash
# Opcjonalnie: AWS CLI do manualnych operacji
brew install awscli

# Opcjonalnie: Session Manager Plugin do SSM
brew install --cask session-manager-plugin
```

**Terraform jest w GitHub Actions – nie trzeba go instalować lokalnie!**

## Konfiguracja - AWS (jednorazowo)

Potrzebne są tylko 3 rzeczy w GitHub:

| Co | Gdzie | Wartość |
|----|-------|---------|
| `AWS_ROLE_ARN` | GitHub Secrets | `arn:aws:iam::ACCOUNT_ID:role/github-actions-role` |
| `AWS_REGION` | GitHub Variables | np. `eu-central-1` |
| `PLATFORM_NAME` | GitHub Variables | np. `omnia-platform` |

> 💡 **Ważne:** Rola IAM (`AWS_ROLE_ARN`) musi posiadać uprawnienia do tworzenia i zarządzania zasobami S3 (bucket stanu), EC2, VPC, IAM i AWS Systems Manager (SSM Parameter Store).

**Wszystkie inne parametry (`EC2_INSTANCE_ID`, `PLATFORM_BASE_DIR`) ustawiają się automatycznie w AWS SSM Parameter Store!**

## AWS - jednorazowa konfiguracja OIDC

### 1. OIDC Provider

IAM -> Identity Providers -> Add provider:

- **Type:** OpenID Connect
- **URL:** `https://token.actions.githubusercontent.com`
- **Audience:** `sts.amazonaws.com`

### 2. Rola IAM

Utwórz rolę IAM z trust policy:

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

### 3. Polityka uprawnień

Do celów pokazowych/deweloperskich można przypisać jedną politykę:

- **`AdministratorAccess`** (`arn:aws:iam::aws:policy/AdministratorAccess`)

Daje pełny dostęp do wszystkich usług AWS. W produkcji należy ją rozdzielić na mniejsze polityki:

| Polityka | Zakres |
|----------|--------|
| `AmazonEC2FullAccess` | Zarządzanie instancjami EC2 |
| `AmazonSSMFullAccess` | Session Manager + Run Command |
| `AmazonVPCFullAccess` | Sieć VPC, Subnets, SG |
| `IAMFullAccess` | Role, profile instancji |

### 4. GitHub Secrets & Variables

Settings -> Secrets and variables -> Actions:

**Secrets:**
- `AWS_ROLE_ARN`: `arn:aws:iam::ACCOUNT_ID:role/github-actions-role`

**Variables:**

| Name | Value | Opis |
|------|-------|------|
| `AWS_REGION` | `eu-central-1` | Region AWS |
| `PLATFORM_NAME` | `omnia-platform` | Nazwa platformy (prefix SSM i S3 bucket) |

> 💡 **Hasło Grafana:** Workflow automatycznie zarządza hasłem przez SSM Parameter Store. Jeśli hasło nie istnieje, generuje nowe i zapisuje jako `SecureString`. Hasło jest przekazywane do Ansible i używane przez aplikację.

## Szybki start (GitHub Actions)

### 1. Utwórz infrastrukturę

GitHub -> Actions -> "Utwórz Infrastrukturę" -> Run workflow

**Co się stanie:**
- ✅ Automatyczna konfiguracja backendu (S3 bucket + native locking)
- ✅ Terraform tworzy VPC, Subnet, Security Group, EC2, VPC Endpoints (SSM + S3)
- ✅ Dynamiczny failover AZ - jeśli brakuje capacity, próbuje następną
- ✅ **Parametry automatycznie zapisane w AWS SSM Parameter Store** (`/<PLATFORM_NAME>/` prefix):
  - `/<PLATFORM_NAME>/EC2_INSTANCE_ID`
  - `/<PLATFORM_NAME>/AWS_REGION`
  - `/<PLATFORM_NAME>/PLATFORM_NAME`
  - `/<PLATFORM_NAME>/PLATFORM_BASE_DIR`

### 2. Uruchom platformę

GitHub -> Actions -> "Uruchom Platform" -> Run workflow

**Co się stanie:**
- ✅ Parametry automatycznie pobierane z AWS SSM Parameter Store
- ✅ Instancja EC2 startuje
- ✅ Hasło Grafana zarządzane automatycznie przez SSM
- ✅ Ansible przez SSM wdraża aplikacje z `apps.json`
- ✅ Cloudflare tunnels tworzą publiczne URL-e

### 3. Gotowe!

Sprawdź podsumowanie workflow - tam są linki do aplikacji (https://*.trycloudflare.com).

### 4. Zatrzymanie platformy (oszczędność kosztów)

GitHub -> Actions -> "Zatrzymaj Platform" -> Run workflow

Potwierdź wpisując `stop`.

**Co się stanie:**
- ✅ Instancja zatrzymana (rachunki zamrożone)
- ✅ Dane zachowane – ponowne uruchomienie zajmie ~3–5 minut
- ✅ Tunele Cloudflare zamknięte

### 5. Zniszczenie infrastruktury (końcowe)

GitHub -> Actions -> "Zniszcz Infrastrukturę" -> Run workflow

Potwierdź wpisując `destroy`.

**OSTRZEŻENIE: Ta operacja jest nieodwracalna!**
- ❌ Wszystkie zasoby AWS usunięte
- ❌ EBS volumes usunięte
- ❌ Parametry z AWS SSM Parameter Store usunięte
- ⚠️ Brak kopii zapasowych

---

## AWS SSM Parameter Store - Konfiguracja automatyczna

Wszystkie parametry konfiguracyjne są przechowywane w **AWS Systems Manager Parameter Store** pod prefixem `/<PLATFORM_NAME>/`:

| Parameter | Wartość | Źródło | Użycie |
|-----------|---------|--------|--------|
| `/<PLATFORM_NAME>/EC2_INSTANCE_ID` | `i-0abc123def456789` | Terraform output | start/stop/destroy |
| `/<PLATFORM_NAME>/AWS_REGION` | `eu-central-1` | Terraform variable | start/stop workflows |
| `/<PLATFORM_NAME>/PLATFORM_NAME` | `omnia-platform` | GitHub Variable | S3 bucket naming |
| `/<PLATFORM_NAME>/PLATFORM_BASE_DIR` | `/opt/omnia` | Workflow default | Ansible paths |

**Zalety SSM Parameter Store:**
- ✅ **Brak hardcoded values w workflow’ach**
- ✅ **Brak konieczności ręcznego ustawiania GitHub Variables**
- ✅ **Parametry automatycznie czyszczone przy destroy**
- ✅ **Centralne miejsce konfiguracji (AWS)**
- ✅ **Integracja z AWS IAM (bezpieczeństwo)**
- ✅ **Free tier (do 10 000 parametrów)**

---

Terraform automatycznie:
1. Pobiera wszystkie dostępne AZ w regionie
2. Sprawdza, które AZ mają dostępny `t4g.small`
3. Zaczyna od preferowanej AZ (`preferred_az_index`)
4. Jeśli brakuje capacity - przechodzi do następnej AZ
5. Jeśli żadna AZ nie ma pojemności - wyrzuca błąd z komunikatem

**Poprzednio:** Trzeba było ręcznie zmieniać `preferred_az_index` w `tfvars`.

**Teraz:** Automatycznie próbuje kolejne AZ!

## Workflow GitHub Actions

| Workflow | Opis | Config Storage | Czyści koszty |
|----------|------|----------------|---------------|
| **Utwórz Infrastrukturę** | Terraform apply: VPC + EC2 + sieci | → SSM | ❌ Nie (EC2 startuje) |
| **Uruchom Platform** | Ansible: Docker + aplikacje + Cloudflare | ← SSM | ❌ Nie |
| **Zatrzymaj Platform** | Stop EC2 (oszczędza rachunki) | ← SSM | ✅ Tak |
| **Zniszcz Infrastrukturę** | Terraform destroy + SSM cleanup | ← SSM | ✅ Tak |
| **Wdróż Aplikacje** | Ansible: Wdrożenie aplikacji z apps.json | ← SSM | ❌ Nie |

### Przepływ konfiguracji

```
1. Utwórz Infrastrukturę
   ↓
   Terraform outputs
   ↓
   AWS SSM Parameter Store (/<PLATFORM_NAME>/*)
   ↓
2. Uruchom Platform (automatycznie pobiera z SSM)
   ↓
   EC2 + Ansible + Apps
   ↓
3. Zatrzymaj Platform (czyta EC2_INSTANCE_ID z SSM)
   ↓
   EC2 stopped
   ↓
4. Zniszcz Infrastrukturę (usuwa z SSM po Terraform destroy)
   ↓
   Clean slate
```

## Aplikacje

Aplikacje są definiowane w `apps.json` i wdrażane przez Ansible (docker-compose lub docker run). Każda aplikacja ma własny podkatalog `app/<nazwa>/`.

Szczegóły konfiguracji, lista dostępnych aplikacji i instrukcja dodawania nowych znajdują się w osobnej dokumentacji:

➡️ **[app/README.md](app/README.md)**

## Bezpieczeństwo i Architektura Sieciowa (Zero Trust)

Projekt demonstruje zaawansowane podejście DevOps do bezpieczeństwa, infrastruktury jako kodu (IaC) oraz optymalizacji kosztów:

- **Ukryte wyjście na świat (Cloudflare WARP):** Instancja EC2 celowo nie posiada publicznego adresu IPv4, co znacząco obniża koszty AWS (EIP). Komunikacja w stronę klasycznego internetu IPv4 tunelowana jest bezpiecznie przez wdrożonego klienta WARP (`ansible/tasks/warp.yml`), dostarczając tzw. "kamuflaż" NAT64. Serwer ma dostęp do internetu, ale internet nie widzi serwera.
- **Zero Inbound (Zamknięta Twierdza):** Security Group w AWS nie posiada żadnych reguł Ingress. Port 22 fizycznie nie funkcjonuje, pliki z kluczami SSH na maszynie nie istnieją. Wystawienie usług webowych na świat realizowane jest wyłącznie przez odwrócone tunele (`cloudflared`).
- **Zarządzanie wyłącznie przez AWS Systems Manager (SSM)** autoryzowane via IAM, z wewnętrznym ruchem po bezpłatnym AWS Gateway Endpoint.
- **Ochrona przed atakami SSRF** (wymuszone użycie IMDSv2).
- **CI/CD z pełną automatyzacją** oraz autoryzacją OIDC (federacja GitHub Actions → AWS) bez konieczności utrzymywania długowiecznych kluczy statycznych.
- **Brak hardcoded credentials** – wszystkie hasła i tajne klucze aplikacyjne są przekazywane poprzez GitHub Secrets lub generowane automatycznie (np. Grafana) i bezpiecznie przetrzymywane w AWS SSM Parameter Store.

---
**Autor:** Grzegorz N  
**Data:** Czerwiec 2026
