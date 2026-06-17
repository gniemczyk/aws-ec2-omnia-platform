# =============================================================================
# Grafana - Dockerfile
# =============================================================================
# Przykladowy Dockerfile rozszerzajacy oficjalny obraz Grafana o dodatkowe
# pluginy i konfiguracje. Mozna go rozbudowac wg potrzeb.
# =============================================================================

FROM grafana/grafana-oss:latest

# Zmienne srodowiskowe - domyslne, nadpisywane przez apps.json
ENV GF_SECURITY_ADMIN_USER=admin
ENV GF_SECURITY_ADMIN_PASSWORD=change-me
ENV GF_INSTALL_PLUGINS=grafana-clock-panel

# Opcjonalnie: kopiowanie wlasnych dashboardow lub konfiguracji
# COPY provisioning/ /etc/grafana/provisioning/
# COPY dashboards/ /var/lib/grafana/dashboards/

EXPOSE 3000
