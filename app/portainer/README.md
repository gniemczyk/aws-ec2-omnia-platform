# Portainer CE

Docker Management UI — wizualizacja i zarzadzanie kontenerami, obrazami, sieciami i wolumenami platformy Omnia.

## Dostep

| Parametr | Wartosc |
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

Otwórz `http://localhost:9000` i ustaw haslo admina (wymagane w ciagu 5 minut od startu).

## Architektura

- **Obraz:** `portainer/portainer-ce:2.27.3-alpine` (oficjalny, ARM64 natywny)
- **Dostep do Dockera:** przez zamontowany `/var/run/docker.sock` (read-only)
- **Dane:** persystentny volume `portainer_data` (konfiguracja, users, stacks)
- **Siec:** `network_mode: host` (zgodnie z konwencja platformy)

## Co widac w Portainer

Po zalogowaniu masz dostep do:

- **Containers** — lista wszystkich kontenerow platformy (omnia-grafana, omnia-komiser, omnia-api, omnia-portainer)
- **Images** — pobrane obrazy Docker
- **Volumes** — wolumeny danych (grafana_data, portainer_data)
- **Networks** — konfiguracja sieci
- **Logs** — logi kontenerow w czasie rzeczywistym
- **Stats** — zuzycie CPU/RAM/IO per kontener

## Bezpieczenstwo

- Docker socket zamontowany jako **read-only** (`:ro`) — ogranicza mozliwosc modyfikacji
- Brak portow zewnetrznych — dostep tylko przez Cloudflare Tunnel (HTTPS)
- Haslo admina ustawiane przy pierwszym logowaniu (nie przechowywane w repo)

## Troubleshooting

| Problem | Rozwiazanie |
|---------|-------------|
| "Your Portainer instance timed out" | Zaloguj sie w ciagu 5 min od startu lub zrestartuj kontener |
| Brak kontenerow na liscie | Sprawdz czy socket jest zamontowany: `docker inspect omnia-portainer` |
| Kontener nie startuje | Sprawdz logi: `docker logs omnia-portainer` |
