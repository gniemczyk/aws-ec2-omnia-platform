# =============================================================================
# Grafana - Dockerfile
# =============================================================================
# Przykladowy Dockerfile rozszerzajacy oficjalny obraz Grafana o dodatkowe
# pluginy i konfiguracje. Mozna go rozbudowac wg potrzeb.
# =============================================================================

FROM grafana/grafana:13.1.0-ubuntu

# =============================================================================
# Zmienne srodowiskowe - domyslne (nadpisywane przez docker-compose / Ansible)
# =============================================================================
ENV GF_SECURITY_ADMIN_USER=admin
# GF_SECURITY_ADMIN_PASSWORD - ustaw w runtime (NIE hardcode'uj!)

# =============================================================================
# Poziom logowania: info (produkcja). Nadpisywane przez GF_LOG_LEVEL
# w docker-compose / Ansible gdy potrzeba debugowania.
# =============================================================================
ENV GF_LOG_LEVEL=info

# =============================================================================
# Provisioning: datasource, dashboard provider + dashboard JSON
# =============================================================================
COPY provisioning/ /etc/grafana/provisioning/
COPY dashboards/ /var/lib/grafana/dashboards/

# =============================================================================
# Niestandardowa konfiguracja (nadpisuje domyslne ustawienia)
# =============================================================================
COPY config/grafana.ini /etc/grafana/grafana.ini

# =============================================================================
# Prawa wlasciciela dla plikow provisioningowych (non-root grafana:grafana)
# =============================================================================
USER root
RUN chmod 644 /etc/grafana/grafana.ini && \
    find /etc/grafana/provisioning /var/lib/grafana/dashboards -type f -exec chmod 644 {} +

# =============================================================================
# Uruchomienie kontenera z non-root userem (UID 472 = grafana)
# =============================================================================
USER grafana

EXPOSE 3000
