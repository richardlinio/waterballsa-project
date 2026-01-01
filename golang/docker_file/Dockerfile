FROM golang:1.25-alpine
WORKDIR /app

# Install curl for healthcheck and Air for hot reload
RUN apk add --no-cache curl git && \
    go install github.com/air-verse/air@v1.63.4

# 依賴會透過 volume mount 提供
COPY go.mod go.sum ./
RUN go mod download

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]