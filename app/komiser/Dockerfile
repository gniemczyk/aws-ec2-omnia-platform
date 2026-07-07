# =============================================================================
# Komiser - Multi-stage Dockerfile (ARM64 compatible)
# =============================================================================
# Obraz tailwarden/komiser:latest nie wspiera architektury ARM64 (Graviton).
# Ten Dockerfile buduje Komisera ze zrodel Go, dzieki czemu dziala natywnie
# na dowolnej architekturze (amd64, arm64) bez emulacji QEMU.
# =============================================================================

# --- STAGE 1: Build frontend ---
FROM node:20-alpine AS frontend-builder

RUN apk add --no-cache git

WORKDIR /app
RUN git clone --depth 1 --branch v3.1.22 https://github.com/mlabouardy/komiser.git .

WORKDIR /app/dashboard
RUN npm ci --legacy-peer-deps && npm run build

# --- STAGE 2: Build Go binary ---
FROM golang:1.23-alpine AS go-builder

RUN apk add --no-cache git gcc musl-dev

WORKDIR /app
RUN git clone --depth 1 --branch v3.1.22 https://github.com/mlabouardy/komiser.git .

# Kopiujemy zbudowany frontend do katalogu embed
COPY --from=frontend-builder /app/dashboard/out /app/dashboard/out

RUN go mod download
RUN CGO_ENABLED=0 go build -ldflags="-s -w -X github.com/tailwarden/komiser/utils.Version=3.1.22" -o /komiser .

# --- STAGE 3: Final minimal image ---
FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata

COPY --from=go-builder /komiser /usr/bin/komiser

EXPOSE 3001

ENTRYPOINT ["/usr/bin/komiser", "start", "--port", "3001"]
