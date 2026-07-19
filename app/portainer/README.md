# Portainer CE

Docker Management UI — wizualizacja i zarządzanie kontenerami, obrazami, sieciami i wolumenami platformy Omnia.

## Dostęp

| Parametr | Wartość |
|----------|---------|
| Port | `9000` (HTTP) |
| URL (produkcja) | Cloudflare Quick Tunnel (generowany dynamicznie) |
| URL (lokalnie) | `http://localhost:9000` |
| Login | ustawiany przy pierwszym logowaniu |

## Uruchamianie lokalne

```bash
cd app/portainer/
docker compose up -d
```

Otwórz `http://localhost:9000` i ustaw hasło admina (wymagane w ciągu 5 minut od startu).

## Architektura

- **Obraz:** `portainer/portainer-ce:2.27.3-alpine` (oficjalny, ARM64 natywny)
- **Dostęp do Dockera:** przez zamontowany `/var/run/docker.sock` (read-only)
- **Dane:** persystentny volume `portainer_data` (konfiguracja, users, stacks)
- **Sieć:** `network_mode: host` (zgodnie z konwencją platformy)

## Co widać w Portainer

Po zalogowaniu masz dostęp do:

- **Containers** — lista wszystkich kontenerów platformy (omnia-grafana, omnia-komiser, omnia-api, omnia-portainer)
- **Images** — pobrane obrazy Docker
- **Volumes** — wolumeny danych (grafana_data, portainer_data)
- **Networks** — konfiguracja sieci
- **Logs** — logi kontenerów w czasie rzeczywistym
- **Stats** — zużycie CPU/RAM/IO per kontener

## Bezpieczeństwo

- Docker socket zamontowany jako **read-only** (`:ro`) — ogranicza możliwość modyfikacji
- Brak portów zewnętrznych — dostęp tylko przez Cloudflare Tunnel (HTTPS)
- Hasło admina ustawiane przy pierwszym logowaniu (nie przechowywane w repo)

## Troubleshooting

| Problem | Rozwiązanie |
|---------|-------------|
| "Your Portainer instance timed out" | Zaloguj się w ciągu 5 min od startu lub zrestartuj kontener |
| Brak kontenerów na liście | Sprawdź czy socket jest zamontowany: `docker inspect omnia-portainer` |
| Kontener nie startuje | Sprawdź logi: `docker logs omnia-portainer` |
