# Grafana

Panel monitoringu Grafana OSS z pre-konfigurowanym datasource CloudWatch i gotowymi dashboardami AWS.

## Dostep

| Parametr | Wartosc |
|----------|---------|
| Port | `3000` (HTTP) |
| URL (produkcja) | Cloudflare Quick Tunnel (generowany dynamicznie) |
| URL (lokalnie) | `http://localhost:3000` |
| Login | `admin` (lub wartosc z `GRAFANA_ADMIN_USER`) |
| Haslo | ustawiane przez GitHub Secret lub generowane losowo (zapisywane w SSM) |

## Uruchamianie lokalne

```bash
cd app/grafana/
cp .env.example .env
# edytuj .env (ustaw haslo, region AWS)
docker compose up -d --build
```

Otwórz `http://localhost:3000` i zaloguj sie danymi z `.env`.

## Architektura

```
app/grafana/
├── Dockerfile              # Rozszerza oficjalny obraz o provisioning
├── docker-compose.yml      # Serwis + init container (dashboard loader)
├── .env.example            # Szablon zmiennych srodowiskowych
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
| AWS Services Overview | Przeglad uslug AWS (S3, Lambda, RDS, itp.) |
| AWS Alerts & Errors | Alerty CloudWatch, errory z logow |

Dashboardy sa ladowane automatycznie przez **init container** (`grafana-dashboard-loader`) ktory czeka na start Grafany i importuje JSON-y przez API.

## Datasource

CloudWatch skonfigurowany przez provisioning (`provisioning/datasources/cloudwatch.yml`):
- **Autentykacja:** EC2 IAM Role (produkcja) — zero kluczy w konfiguracji
- **Region:** dynamiczny z `AWS_DEFAULT_REGION` (fallback: `eu-central-1`)
- **Dualstack:** wlaczony (`AWS_USE_DUALSTACK_ENDPOINT=true`) dla IPv6

## Zmienne srodowiskowe

| Zmienna | Domyslnie | Opis |
|---------|-----------|------|
| `GF_SECURITY_ADMIN_USER` | `admin` | Login admina |
| `GF_SECURITY_ADMIN_PASSWORD` | (wymagane) | Haslo admina |
| `AWS_DEFAULT_REGION` | `eu-central-1` | Region CloudWatch |
| `AWS_USE_DUALSTACK_ENDPOINT` | `true` | IPv6 endpointy AWS |
| `GF_LOG_LEVEL` | `info` | Poziom logowania (`debug` do diagnozy) |

## Troubleshooting

| Problem | Rozwiazanie |
|---------|-------------|
| Dashboardy puste (No data) | Sprawdz region w datasource; upewnij sie ze IAM role ma `cloudwatch:GetMetricData` |
| "Datasource not found" | Zrestartuj kontener — provisioning laduje sie przy starcie |
| Init container nie laduje dashboardow | Sprawdz logi: `docker logs omnia-grafana-dashboard-loader` |
| Blad logowania | Pobierz haslo z SSM: `aws ssm get-parameter --name "/omnia-platform/GRAFANA_ADMIN_PASSWORD" --query Parameter.Value --output text` |
