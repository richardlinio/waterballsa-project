FROM golang:1.25-alpine
WORKDIR /app

# Install curl for healthcheck and Air for hot reload
RUN apk add --no-cache curl git && \
    go install github.com/air-verse/air@v1.63.4 && \
    go install mvdan.cc/gofumpt@v0.9.2 && \
    curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b $(go env GOPATH)/bin v2.7.2
    
# 依賴會透過 volume mount 提供
COPY go.mod go.sum ./
RUN go mod download

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]