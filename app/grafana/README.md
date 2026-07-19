# Grafana

Panel monitoringu Grafana OSS z pre-konfigurowanym datasource CloudWatch i gotowymi dashboardami AWS.

## Dostęp

| Parametr | Wartość |
|----------|---------|
| Port | `3000` (HTTP) |
| URL (produkcja) | Cloudflare Quick Tunnel (generowany dynamicznie) |
| URL (lokalnie) | `http://localhost:3000` |
| Login | `admin` (lub wartość z `GRAFANA_ADMIN_USER`) |
| Hasło | ustawiane przez GitHub Secret lub generowane losowo (zapisywane w SSM) |

## Uruchamianie lokalne

```bash
cd app/grafana/
cp .env.example .env
# edytuj .env (ustaw haslo, region AWS)
docker compose up -d --build
```

Otwórz `http://localhost:3000` i zaloguj się danymi z `.env`.

## Architektura

```
app/grafana/
├── Dockerfile              # Rozszerza oficjalny obraz o provisioning
├── docker-compose.yml      # Serwis + init container (dashboard loader)
├── .env.example            # Szablon zmiennych środowiskowych
├── config/
│   └── grafana.ini         # Nadpisanie konfiguracji (log level)
├── provisioning/
│   ├── datasources/
│   │   └── cloudwatch.yml  # Auto-provisioning CloudWatch datasource
│   └── dashboards/
│       └── (provider config - generowany przez Ansible)
└── dashboards/
    ├── ec2-cloudwatch-overview.json
    ├── aws-services-overview.json
    └── aws-services-alerts-errors-cloudwatch-overview.json
```

## Dashboardy

| Dashboard | Opis |
|-----------|------|
| EC2 CloudWatch Overview | CPU, Network, Disk, StatusCheck dla instancji EC2 |
| AWS Services Overview | Przegląd usług AWS (S3, Lambda, RDS, itp.) |
| AWS Alerts & Errors | Alerty CloudWatch, błędy z logów |

Dashboardy są ładowane automatycznie przez **init container** (`grafana-dashboard-loader`), który czeka na start Grafany i importuje JSON-y przez API.

## Datasource

CloudWatch skonfigurowany przez provisioning (`provisioning/datasources/cloudwatch.yml`):
- **Autentykacja:** EC2 IAM Role (produkcja) — zero kluczy w konfiguracji
- **Region:** dynamiczny z `AWS_DEFAULT_REGION` (fallback: `eu-central-1`)
- **Dualstack:** włączony (`AWS_USE_DUALSTACK_ENDPOINT=true`) dla IPv6

## Zmienne środowiskowe

| Zmienna | Domyślnie | Opis |
|---------|-----------|------|
| `GF_SECURITY_ADMIN_USER` | `admin` | Login admina |
| `GF_SECURITY_ADMIN_PASSWORD` | (wymagane) | Hasło admina |
| `AWS_DEFAULT_REGION` | `eu-central-1` | Region CloudWatch |
| `AWS_USE_DUALSTACK_ENDPOINT` | `true` | IPv6 endpointy AWS |
| `GF_LOG_LEVEL` | `info` | Poziom logowania (`debug` do diagnozy) |

## Troubleshooting

| Problem | Rozwiązanie |
|---------|-------------|
| Dashboardy puste (No data) | Sprawdź region w datasource; upewnij się że IAM role ma `cloudwatch:GetMetricData` |
| "Datasource not found" | Zrestartuj kontener — provisioning ładuje się przy starcie |
| Init container nie ładuje dashboardów | Sprawdź logi: `docker logs omnia-grafana-dashboard-loader` |
| Błąd logowania | Pobierz hasło z SSM: `aws ssm get-parameter --name "/omnia-platform/GRAFANA_ADMIN_PASSWORD" --query Parameter.Value --output text` |
