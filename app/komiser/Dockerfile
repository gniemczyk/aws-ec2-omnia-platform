FROM --platform=$BUILDPLATFORM alpine:3.20 AS source
RUN apk add --no-cache curl && \
    mkdir -p /src && \
    curl -sL https://github.com/tailwarden/komiser/archive/refs/tags/v3.1.22.tar.gz | \
    tar -xz --strip-components=1 -C /src

FROM --platform=$BUILDPLATFORM node:20-alpine AS frontend-builder
COPY --from=source /src /app
WORKDIR /app/dashboard
ENV NODE_OPTIONS="--max-old-space-size=512"
RUN npm ci --legacy-peer-deps && npm run build && \
    rm -rf node_modules /root/.npm

FROM --platform=$BUILDPLATFORM python:3.13-alpine AS patcher
COPY --from=source /src /src
COPY scripts/patch-credentials.py /tmp/patch-credentials.py
COPY scripts/patch-accounts.py /tmp/patch-accounts.py
RUN python3 /tmp/patch-credentials.py && python3 /tmp/patch-accounts.py

FROM --platform=linux/arm64 golang:1.23-alpine AS go-builder
ARG TARGETARCH=arm64
COPY --from=patcher /src /app
COPY --from=frontend-builder /app/dashboard/out /app/dashboard/out
WORKDIR /app
RUN go mod download && \
    GOARCH=arm64 CGO_ENABLED=0 go build \
    -ldflags="-s -w -X github.com/tailwarden/komiser/utils.Version=3.1.22" \
    -o /komiser .

FROM --platform=$BUILDPLATFORM alpine:3.20 AS os-packages
RUN apk add --no-cache ca-certificates tzdata

FROM alpine:3.20
RUN addgroup -S komiser && adduser -S -G komiser komiser && \
    mkdir -p /app /home/komiser/.aws && \
    chown -R komiser:komiser /app /home/komiser
COPY --from=os-packages /etc/ssl/certs /etc/ssl/certs
COPY --from=os-packages /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=go-builder /komiser /usr/bin/komiser
WORKDIR /app
USER komiser
EXPOSE 3001
ENTRYPOINT ["/usr/bin/komiser", "start", "--port", "3001"]
