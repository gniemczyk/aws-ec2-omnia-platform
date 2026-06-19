# Aplikacje

Każda aplikacja ma własny podkatalog `app/<nazwa>/` z `Dockerfile` i `docker-compose.yml`. Definicje znajdują się w `apps.json` w katalogu głównym.

## Uruchamianie lokalne

```bash
cd app/<nazwa>/
cp .env.example .env
# edytuj .env z wlasciwymi wartosciami
docker-compose up -d --build
```

Każda aplikacja zawiera `.env.example` z opisem wymaganych zmiennych.

## Aplikacje w projekcie

| Katalog | Opis |
|---------|------|
| [grafana/](grafana/) | Panel monitoringu Grafana OSS |

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
