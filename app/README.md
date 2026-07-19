# Aplikacje

Każda aplikacja ma własny podkatalog `app/<nazwa>/` z `Dockerfile` i `docker-compose.yml`. Definicje znajdują się w `apps.json`.

## Aplikacje w projekcie

| Katalog | Opis |
|---------|------|
| [grafana/](grafana/) | Panel monitoringu Grafana OSS — [instrukcja](grafana/README.md) |
| [komiser/](komiser/) | Cloud Environment Inspector — [instrukcja konfiguracji](komiser/README.md) |
| [portainer/](portainer/) | Docker Management UI (Portainer CE) — [instrukcja](portainer/README.md) |

## Uruchamianie lokalne

```bash
cd app/<nazwa>/
cp .env.example .env
# edytuj .env z wlasciwymi wartosciami
docker compose up -d --build
```

Każda aplikacja zawiera `.env.example` z opisem wymaganych zmiennych.

## Wdrożenie przez GitHub Actions

1. Utwórz `app/<nazwa>/` z `Dockerfile`, `docker-compose.yml` i `.env.example`
2. Dodaj wpis w `apps.json` (port, obraz, zmienne env — bez sekretów)
3. Dla sekretów użyj GitHub Secrets i `--extra-vars` w `deploy-apps.yml`
4. Push do repo i uruchom workflow "Wdróż Aplikacje"

> W `apps.json` nie umieszczaj haseł ani kluczy API — plik jest jawny w repo.

## Zmienne wrażliwe (GitHub Secrets)

| Aplikacja | Zmienna | Opis |
|-----------|---------|------|
| Grafana | `GRAFANA_ADMIN_USER` | Login admina (opcjonalny, domyślnie `admin`) |
| Grafana | `GRAFANA_ADMIN_PASSWORD` | Hasło admina (opcjonalne, generowane losowo) |
| Komiser | — | Klucze AWS dodawane przez UI, nie przez zmienne środowiskowe |
| Portainer | — | Hasło admina ustawiane przy pierwszym logowaniu przez UI |

Jeśli nie ustawisz secretów, hasło zostanie wygenerowane i zapisane w SSM Parameter Store.

## Komiser

Obraz budowany jest z patchem naprawiającym błąd obsługi `credentials-keys` dodanych przez UI. Budowa odbywa się w GitHub Actions (ARM64), obraz jest uploadowany do S3 i ładowany na EC2. Konfiguracja przez `config.toml` (tylko `source = "ENVIRONMENT_VARIABLES"`) – właściwe klucze dodaje się w UI po uruchomieniu.

## Lokalna aktualizacja na instancji przez SSM

```bash
# Połącz się
aws ssm start-session --target i-xxxxxxxx --region eu-central-1

# Zatrzymaj i usuń stare kontenery
docker ps -a --filter "label=platform=omnia" -q | xargs -r docker rm -f

# Wygeneruj .env (dostosuj do aplikacji)
cat > /opt/omnia/app/<nazwa>/.env << EOF
# zmienne z .env.example
EOF

# Uruchom
cd /opt/omnia/app/<nazwa>/ && docker compose up -d --build

# Dla Grafany: pobierz hasło z SSM
aws ssm get-parameter --name "/omnia-platform/GRAFANA_ADMIN_PASSWORD" --query Parameter.Value --output text
```
