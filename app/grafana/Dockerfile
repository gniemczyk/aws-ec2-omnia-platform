# =============================================================================
# Grafana - Dockerfile
# =============================================================================
# Przykladowy Dockerfile rozszerzajacy oficjalny obraz Grafana o dodatkowe
# pluginy i konfiguracje. Mozna go rozbudowac wg potrzeb.
# =============================================================================

FROM grafana/grafana-oss:11.0.0

# Zmienne srodowiskowe - domyslne, nadpisywane przez apps.json
# UWAGA: Haslo powinno byc przekazane przez zmienne srodowiskowe w runtime
# (docker-compose.yml lub AWS Secrets Manager), NIE hardcode'owanie
ENV GF_SECURITY_ADMIN_USER=admin
# ENV GF_SECURITY_ADMIN_PASSWORD - Ustaw w runtime z bezpiecznego zrodla!
ENV GF_INSTALL_PLUGINS=grafana-clock-panel

# Opcjonalnie: kopiowanie wlasnych dashboardow lub konfiguracji
# COPY provisioning/ /etc/grafana/provisioning/
# COPY dashboards/ /var/lib/grafana/dashboards/

# Uruchomienie kontenera z non-root userem (grafana:grafana)
USER grafana

EXPOSE 3000
