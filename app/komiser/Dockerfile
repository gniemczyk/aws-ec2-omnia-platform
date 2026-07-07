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

FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS go-builder
ARG TARGETARCH
COPY --from=source /src /app
COPY --from=frontend-builder /app/dashboard/out /app/dashboard/out
WORKDIR /app
RUN go mod download && \
    GOARCH=$TARGETARCH CGO_ENABLED=0 go build \
    -ldflags="-s -w -X github.com/tailwarden/komiser/utils.Version=3.1.22" \
    -o /komiser .

FROM --platform=$BUILDPLATFORM alpine:3.20 AS os-packages
RUN apk add --no-cache ca-certificates tzdata && \
    mkdir -p /root/.aws && \
    printf '[default]\nregion = eu-central-1\noutput = json\n' > /root/.aws/config

FROM alpine:3.20
COPY --from=os-packages /etc/ssl/certs /etc/ssl/certs
COPY --from=os-packages /usr/share/zoneinfo /usr/share/zoneinfo
COPY --from=os-packages /root/.aws /root/.aws
COPY --from=go-builder /komiser /usr/bin/komiser
EXPOSE 3001
ENTRYPOINT ["/usr/bin/komiser", "start", "--port", "3001"]
