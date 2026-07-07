FROM alpine:3.20 AS source
RUN apk add --no-cache curl && \
    mkdir -p /src && \
    curl -sL https://github.com/tailwarden/komiser/archive/refs/tags/v3.1.22.tar.gz | \
    tar -xz --strip-components=1 -C /src

FROM node:20-alpine AS frontend-builder
COPY --from=source /src /app
WORKDIR /app/dashboard
ENV NODE_OPTIONS="--max-old-space-size=512"
RUN npm ci --legacy-peer-deps && \
    npm run build && \
    rm -rf node_modules /root/.npm

FROM golang:1.23-alpine AS go-builder
COPY --from=source /src /app
COPY --from=frontend-builder /app/dashboard/out /app/dashboard/out
WORKDIR /app
RUN go mod download && \
    CGO_ENABLED=0 go build \
    -ldflags="-s -w -X github.com/tailwarden/komiser/utils.Version=3.1.22" \
    -o /komiser .

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
COPY --from=go-builder /komiser /usr/bin/komiser
EXPOSE 3001
ENTRYPOINT ["/usr/bin/komiser", "start", "--port", "3001"]
