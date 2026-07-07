# Aplikacje

Każda aplikacja ma własny podkatalog `app/<nazwa>/` z `Dockerfile` i `docker-compose.yml`. Definicje znajdują się w `apps.json` w katalogu głównym.

## Uruchamianie lokalne

```bash
cd app/<nazwa>/
cp .env.example .env
# edytuj .env z wlasciwymi wartosciami
docker compose up -d --build
```

Każda aplikacja zawiera `.env.example` z opisem wymaganych zmiennych.

## Aplikacje w projekcie

| Katalog | Opis |
|---------|------|
| [grafana/](grafana/) | Panel monitoringu Grafana OSS |
| [komiser/](komiser/) | Cloud Environment Inspector (Multi-region AWS Dashboard) |

## Dodawanie nowej aplikacji

1. Utwórz `app/<nazwa>/` z `Dockerfile`, `docker-compose.yml` i `.env.example`
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

> ⚠️ **Uwaga:** `apps.json` jest jawny w repozytorium. Nie umieszczaj w `env` haseł, kluczy API ani innych sekretów. Dla wrażliwych zmiennych użyj GitHub Secrets i przekaż je przez `--extra-vars` (wzór: sekcja Grafana poniżej).

## Konfiguracja aplikacji przez GitHub Secrets

Jeśli aplikacja wymaga wrażliwych zmiennych (hasła, tokeny), dodaj je jako GitHub Secrets i przekaż w `start-platform.yml` przez `--extra-vars`.

### Grafana

| Secret | Opis |
|--------|------|
| `GRAFANA_ADMIN_USER` | Login admina Grafany (opcjonalny, domyślnie `admin`) |
| `GRAFANA_ADMIN_PASSWORD` | Hasło admina Grafany (opcjonalne, generowane losowo przy deployu) |

Jeśli nie ustawisz secretów, platforma wygeneruje losowe hasło i pokaże je w podsumowaniu workflow.

## Lokalna aktualizacja Grafany na instancji

W sytuacjach, gdy zmieniasz tylko konfigurację Grafany (np. dashboard, datasource, Dockerfile), nie musisz uruchamiać całego workflow GitHub. Możesz zrobić to bezpośrednio na instancji przez SSM.

### Krok 1: Połącz się z instancją

```bash
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx --region eu-central-1
```

### Krok 2: Zatrzymaj i usuń stare kontenery

```bash
docker ps -a --filter "label=platform=omnia" -q | xargs -r docker rm -f
```

### Krok 3: Wygeneruj plik `.env` dla Grafany

```bash
HASH=$(openssl rand -hex 12)
cat > /opt/omnia/app/grafana/.env << EOF
APP_PORT=3000
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=$HASH
AWS_DEFAULT_REGION=eu-central-1
AWS_USE_DUALSTACK_ENDPOINT=true
EOF
```

### Krok 4: Uruchom kontener

```bash
cd /opt/omnia/app/grafana && docker compose up -d --build
```

### Krok 5: Wyświetl hasło (jeśli nie znasz)

```bash
aws ssm get-parameter --name "/omnia-platform/GRAFANA_ADMIN_PASSWORD" --query Parameter.Value --output text
```

> ⚠️ **Hasło zapisane w SSM:** Jeśli uruchamiałeś wcześniej platformę przez GitHub Actions, hasło jest przechowywane w SSM Parameter Store. W kroku 3 możesz je pominąć – docker-compose odczyta je z pliku `.env` wygenerowanego podczas ostatniego wdrożenia przez workflow.
