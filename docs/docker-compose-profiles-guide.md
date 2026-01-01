# Docker Compose Profiles 實作指南

> **前置條件**: 本指南假設你已有 Java (Spring Boot) + Next.js 的環境在運行。

## Part 1: Quick Reference

### 可用的技術棧組合

| Backend | Frontend    | 啟動命令                                            |
| ------- | ----------- | --------------------------------------------------- |
| Java    | Next.js     | `docker compose --profile java --profile nextjs up` |
| **Go**  | **Next.js** | `docker compose up` **(預設)**                      |

### 檔案結構

```
/
├── docker-compose.yml
├── .env, .env.go, .env.java, .env.nextjs
├── www_root/
│   ├── waterballsa-backend/          # Java (現有)
│   ├── waterballsa-backend-golang/   # Go (新增)
│   └── waterballsa-frontend/         # Next.js (現有)
├── golang/docker_file/Dockerfile     # Go Dockerfile
└── web_service/etc/nginx/conf.d/
    ├── backend.conf                  # 共用 API 路由
    └── frontend-nextjs.conf          # Next.js SSR
```

---

## Part 2: 新增 Go Backend

**前置條件**: 已有 Java + Next.js 運行

### Step 1: 建立 Go Repository

**操作**:

```bash
# 在其他位置建立 Go 專案
mkdir waterballsa-backend-golang
cd waterballsa-backend-golang
go mod init github.com/yourusername/waterballsa-backend-golang

# 建立基本結構
mkdir -p cmd/server internal/{api,model,repository}
touch cmd/server/main.go

# 初始化 git
git init
git remote add origin https://github.com/yourusername/waterballsa-backend-golang.git

# 回到主專案，clone 進來
cd /path/to/waterballsa-project
git clone https://github.com/yourusername/waterballsa-backend-golang.git www_root/waterballsa-backend-golang
```

**驗證**:

```bash
ls www_root/waterballsa-backend-golang
# 應該看到: cmd/ internal/ go.mod
```

### Step 2: 建立 Dockerfile

**操作**: 在 `golang/docker_file/Dockerfile` 建立檔案

```dockerfile
FROM golang:1.21-alpine
WORKDIR /app

# Install curl for healthcheck and Air for hot reload
RUN apk add --no-cache curl git && \
    go install github.com/cosmtrek/air@latest

# 依賴會透過 volume mount 提供
COPY go.mod go.sum ./
RUN go mod download

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]
```

**操作**: 在 Go 專案根目錄建立 `.air.toml`

```toml
root = "."
tmp_dir = "tmp"

[build]
  bin = "./tmp/main"
  cmd = "go build -o ./tmp/main ."
  delay = 1000
  exclude_dir = ["tmp", "vendor"]
  include_ext = ["go"]

[log]
  time = false
```

**驗證**:

```bash
docker build -t test-go-backend -f golang/docker_file/Dockerfile www_root/waterballsa-backend-golang
# 應該成功 build
```

### Step 3: 配置環境變數

**操作**: 建立 `.env.go`

```env
# Application
APP_ENV=development
LOG_LEVEL=debug
GIN_MODE=debug

# Database
DB_SSLMODE=disable
DB_MAX_OPEN_CONNS=25
DB_MAX_IDLE_CONNS=5

# CORS
CORS_ALLOWED_ORIGINS=http://localhost:3000,https://localhost
CORS_ALLOW_CREDENTIALS=true

# JWT
JWT_EXPIRATION_HOURS=24
```

**驗證**:

```bash
cat .env.go
# 確認檔案內容正確
```

### Step 4: 更新 docker-compose.yml

**操作**: 在 `services:` 區塊加入以下內容

```yaml
backend-go:
  profiles: ['go', 'default']
  container_name: backend
  build:
    context: ./www_root/waterballsa-backend-golang
    dockerfile: ../../golang/docker_file/Dockerfile
  depends_on:
    db:
      condition: service_healthy
  environment:
    - DB_HOST=db
    - DB_PORT=5432
    - DB_NAME=${POSTGRES_DB}
    - DB_USER=${POSTGRES_USER}
    - DB_PASSWORD=${POSTGRES_PASSWORD}
    - DB_SSLMODE=disable
    - SERVER_PORT=8080
    - JWT_SECRET=${JWT_SECRET}
  env_file:
    - .env
    - .env.go
  ports:
    - '${BACKEND_PORT:-8080}:8080'
  volumes:
    - ./www_root/waterballsa-backend-golang:/app
    - /app/vendor
    - /app/tmp
  healthcheck:
    test: ['CMD-SHELL', 'curl -f http://localhost:8080/health || exit 1']
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 20s
  networks:
    - app-network
```

**驗證**:

```bash
docker compose config
# 檢查沒有語法錯誤
```

### Step 5: 分離 Nginx 配置 (一次性操作)

**操作**: 將現有的 `web_service/etc/nginx/conf.d/www.conf` 拆分成兩個檔案

**建立 `web_service/etc/nginx/conf.d/backend.conf`**:

```nginx
# API proxy - 適用於所有後端
location /api/ {
    proxy_pass http://backend:8080/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Timeout 設定
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
}
```

**建立 `web_service/etc/nginx/conf.d/frontend-nextjs.conf`**:

```nginx
# Next.js SSR
location / {
    proxy_pass http://frontend:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # WebSocket support for HMR
    proxy_buffering off;
}
```

**刪除或重命名**: `www.conf` → `www.conf.backup`

**驗證**:

```bash
docker run --rm -v $(pwd)/web_service/etc/nginx/conf.d:/etc/nginx/conf.d nginx:alpine nginx -t
# 應該顯示: configuration file is ok
```

### Step 6: 更新 web_service (一次性操作)

**操作**: 在 docker-compose.yml 中，將現有的 `web_service` 改為 `web_service_nextjs`

**修改前**:

```yaml
web_service:
  image: nginx:alpine
  # ...
```

**修改後**:

```yaml
web_service_nextjs:
  profiles: ['nextjs', 'default']
  container_name: web_service
  image: nginx:alpine
  depends_on:
    ssl-init:
      condition: service_completed_successfully
    frontend-nextjs:
      condition: service_healthy
    backend-java:
      condition: service_healthy
      required: false
    backend-go:
      condition: service_healthy
      required: false
  ports:
    - '80:80'
    - '443:443'
  volumes:
    - ./web_service/etc/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    - ./web_service/etc/nginx/conf.d/backend.conf:/etc/nginx/conf.d/backend.conf:ro
    - ./web_service/etc/nginx/conf.d/frontend-nextjs.conf:/etc/nginx/conf.d/frontend.conf:ro
    - ./web_service/etc/nginx/ssl:/etc/nginx/ssl:ro
  healthcheck:
    test: ['CMD-SHELL', 'curl -f http://localhost || exit 1']
    interval: 10s
    timeout: 3s
    retries: 3
    start_period: 5s
  networks:
    - app-network
```

**驗證**:

```bash
docker compose config
# 確認配置正確
```

### Step 7: 測試 Go Backend

**操作**: 啟動 Go backend

```bash
# 停止現有服務
docker compose down

# 啟動 Go backend + Next.js frontend (預設)
docker compose up -d

# 查看日誌
docker compose logs -f backend
```

**驗證**:

```bash
# 1. 檢查容器狀態
docker compose ps
# backend 應該是 healthy

# 2. 測試 API
curl http://localhost:8080/health
# 應該返回成功

# 3. 測試 hot reload
# 修改 Go 代碼，觀察日誌是否自動重新編譯
```

---

## Part 3: 故障排除

### 問題 1: Profile 未啟動對應服務

**症狀**: `docker compose --profile java up` 但 backend-java 沒有啟動

**解決**:

```bash
# 檢查 profile 定義
docker compose config --profiles

# 檢查服務列表
docker compose --profile java config --services

# 確認 YAML 縮排正確
# 確認使用 docker compose (v2) 而非 docker-compose (v1)
```

### 問題 2: 健康檢查一直失敗

**症狀**: `docker compose ps` 顯示 backend 長時間卡在 `starting`

**解決**:

```bash
# 查看日誌
docker compose logs backend

# 手動測試健康檢查
docker compose exec backend curl -f http://localhost:8080/health

# 檢查應用是否在監聽正確端口
docker compose exec backend netstat -tlnp

# 增加 start_period 時間（特別是 Java 應用）
# 在 healthcheck 中加入: start_period: 60s
```

### 問題 3: Nginx 404 Not Found

**症狀**: 訪問 `http://localhost/api/users` 返回 404

**解決**:

```bash
# 檢查 Nginx 配置
docker compose exec web_service nginx -t

# 查看 Nginx 日誌
docker compose logs web_service

# 確認配置檔案是否正確掛載
docker compose exec web_service cat /etc/nginx/conf.d/backend.conf

# 直接訪問後端測試
curl http://localhost:8080/users
```

### 問題 4: Hot Reload 不工作

**症狀**: 修改代碼後，應用沒有自動重新載入

**解決**:

```bash
# Go: 確認 Air 正在運行
docker compose logs backend | grep -i air

# Next.js: 確認 npm run dev 在執行
docker compose logs frontend | grep -i "ready"

# 檢查 volume mount
docker compose exec backend ls -la /app/src

# 重新掛載 volume
docker compose down && docker compose up
```

### 問題 5: Volume Mount 衝突

**症狀**: `Error: named volume "frontend_node_modules" is declared as external`

**解決**:

```bash
# 列出所有 volumes
docker volume ls

# 清除未使用的 volumes
docker volume prune

# 或強制移除特定 volume
docker volume rm frontend_nextjs_node_modules
```

---

## 附錄: 完整配置參考

### 完整 docker-compose.yml

<details>
<summary>點擊展開完整配置</summary>

```yaml
services:
  # ============================================
  # Backend Services
  # ============================================

  backend-java:
    profiles: ['java']
    container_name: backend
    build:
      context: ./www_root/waterballsa-backend
      dockerfile: ../../java/docker_file/Dockerfile
    depends_on:
      db:
        condition: service_healthy
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://db:5432/${POSTGRES_DB}
      - SPRING_DATASOURCE_USERNAME=${POSTGRES_USER}
      - SPRING_DATASOURCE_PASSWORD=${POSTGRES_PASSWORD}
      - SPRING_JPA_HIBERNATE_DDL_AUTO=update
      - SERVER_PORT=8080
      - JWT_SECRET=${JWT_SECRET}
    env_file:
      - .env
      - .env.java
    ports:
      - '${BACKEND_PORT:-8080}:8080'
    volumes:
      - ./www_root/waterballsa-backend/src:/app/src
      - ./www_root/waterballsa-backend/pom.xml:/app/pom.xml
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:8080/actuator/health || exit 1']
      interval: 15s
      timeout: 15s
      retries: 10
      start_period: 30s
    networks:
      - app-network

  backend-go:
    profiles: ['go', 'default']
    container_name: backend
    build:
      context: ./www_root/waterballsa-backend-golang
      dockerfile: ../../golang/docker_file/Dockerfile
    depends_on:
      db:
        condition: service_healthy
    environment:
      - DB_HOST=db
      - DB_PORT=5432
      - DB_NAME=${POSTGRES_DB}
      - DB_USER=${POSTGRES_USER}
      - DB_PASSWORD=${POSTGRES_PASSWORD}
      - DB_SSLMODE=disable
      - SERVER_PORT=8080
      - JWT_SECRET=${JWT_SECRET}
    env_file:
      - .env
      - .env.go
    ports:
      - '${BACKEND_PORT:-8080}:8080'
    volumes:
      - ./www_root/waterballsa-backend-golang:/app
      - /app/vendor
      - /app/tmp
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:8080/health || exit 1']
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 20s
    networks:
      - app-network

  # ============================================
  # Frontend Services
  # ============================================

  frontend-nextjs:
    profiles: ['nextjs', 'default']
    container_name: frontend
    build:
      context: ./www_root/waterballsa-frontend
      dockerfile: ../../next/docker_file/Dockerfile
    depends_on:
      backend-java:
        condition: service_healthy
        required: false
      backend-go:
        condition: service_healthy
        required: false
    environment:
      - NEXT_PUBLIC_API_URL=/api
      - NEXT_PUBLIC_API_URL_INTERNAL=http://backend:8080
      - NODE_ENV=development
    env_file:
      - .env
      - .env.nextjs
    ports:
      - '${FRONTEND_PORT:-3000}:3000'
    volumes:
      - ./www_root/waterballsa-frontend:/app
      - frontend_nextjs_node_modules:/app/node_modules
      - frontend_nextjs_next_cache:/app/.next
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:3000 || exit 1']
      interval: 30s
      timeout: 3s
      start_period: 10s
      retries: 3
    networks:
      - app-network

  # ============================================
  # Reverse Proxy (Nginx)
  # ============================================

  web_service_nextjs:
    profiles: ['nextjs', 'default']
    container_name: web_service
    image: nginx:alpine
    depends_on:
      ssl-init:
        condition: service_completed_successfully
      frontend-nextjs:
        condition: service_healthy
      backend-java:
        condition: service_healthy
        required: false
      backend-go:
        condition: service_healthy
        required: false
    ports:
      - '80:80'
      - '443:443'
    volumes:
      - ./web_service/etc/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./web_service/etc/nginx/conf.d/backend.conf:/etc/nginx/conf.d/backend.conf:ro
      - ./web_service/etc/nginx/conf.d/frontend-nextjs.conf:/etc/nginx/conf.d/frontend.conf:ro
      - ./web_service/etc/nginx/ssl:/etc/nginx/ssl:ro
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost || exit 1']
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 5s
    networks:
      - app-network

  # ============================================
  # Shared Services (Always Active)
  # ============================================

  ssl-init:
    image: alpine:latest
    volumes:
      - ./web_service/etc/nginx/ssl:/ssl
    command:
      - sh
      - -c
      - |
        apk add --no-cache openssl
        if [ ! -f /ssl/localhost.crt ]; then
          echo 'Generating self-signed SSL certificate...'
          openssl req -x509 -out /ssl/localhost.crt -keyout /ssl/localhost.key \
            -newkey rsa:2048 -nodes -sha256 \
            -subj '/CN=localhost' -days 365
          echo 'SSL certificate generated successfully.'
        else
          echo 'SSL certificate already exists, skipping generation.'
        fi
    networks:
      - app-network

  db:
    platform: linux/amd64
    image: postgres:${POSTGRES_VERSION:-16-alpine}
    restart: always
    environment:
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    ports:
      - '${HOST_POSTGRES_PORT:-5432}:5432'
    volumes:
      - ./db/postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}']
      interval: 5s
      timeout: 5s
      retries: 5
    networks:
      - app-network

# ============================================
# Volumes
# ============================================
volumes:
  frontend_nextjs_node_modules:
  frontend_nextjs_next_cache:

# ============================================
# Networks
# ============================================
networks:
  app-network:
    driver: bridge
```

</details>

### 所有環境變數檔案

**`.env` (共用)**:

```env
# Database Configuration
POSTGRES_VERSION=16-alpine
POSTGRES_DB=waterballsa
POSTGRES_USER=admin
POSTGRES_PASSWORD=change_me_in_production
HOST_POSTGRES_PORT=5432

# Service Ports
BACKEND_PORT=8080
FRONTEND_PORT=3000

# Security
JWT_SECRET=your_jwt_secret_key_change_in_production
```

**`.env.java`**:

```env
SPRING_PROFILES_ACTIVE=dev
LOGGING_LEVEL_ROOT=INFO
LOGGING_LEVEL_COM_WATERBALLSA=DEBUG
SPRING_JPA_SHOW_SQL=true
```

**`.env.go`**:

```env
APP_ENV=development
LOG_LEVEL=debug
GIN_MODE=debug
DB_SSLMODE=disable
CORS_ALLOWED_ORIGINS=http://localhost:3000,https://localhost
JWT_EXPIRATION_HOURS=24
```

**`.env.nextjs`**:

```env
NODE_ENV=development
NEXT_PUBLIC_API_URL=/api
NEXT_PUBLIC_API_URL_INTERNAL=http://backend:8080
NEXT_PUBLIC_ENABLE_BETA_FEATURES=true
```

---

## 總結

完成本指南後，你將擁有一個靈活的 Docker Compose 配置，可以輕鬆在不同技術棧間切換:

- ✅ Go Backend (約 30-40 分鐘)
- ✅ 支援 2 種 Backend (Java/Go) 搭配 Next.js Frontend
- ✅ 統一的開發環境和部署流程
- ✅ 本地開發使用 Docker，生產環境 Frontend 可部署至 Vercel
