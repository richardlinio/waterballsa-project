# Docker Compose Profiles 實作指南 - 後端切換

> **情境**: 本指南專注於在 Java 和 Golang 後端之間切換，前端固定使用 Next.js。

## Part 1: Quick Reference

### 可用的後端

| Backend    | 啟動命令                                                                        |
| ---------- | ------------------------------------------------------------------------------- |
| **Golang** | `docker compose up` **(預設，需要在 .env 中設定 COMPOSE_PROFILES=golang)**      |
| Java       | `COMPOSE_PROFILES=java docker compose up` 或 `docker compose --profile java up` |

> **注意**：`.env` 檔案不會被 Git 追蹤。請參考 `.env.example` 建立您的本地 `.env` 檔案。

### 檔案結構

```
/
├── docker-compose.yml
├── .env                             # 共用環境變數（包含 COMPOSE_PROFILES）
├── .env.golang                      # Golang 專用環境變數
├── www_root/
│   ├── waterballsa-backend/        # Java Spring Boot
│   ├── waterballsa-backend-golang/ # Golang 應用
│   └── waterballsa-frontend/       # Next.js（固定不變）
├── golang/docker_file/Dockerfile   # Go Dockerfile
├── java/docker_file/Dockerfile     # Java Dockerfile
└── web_service/etc/nginx/conf.d/
    └── www.conf                    # 統一的 Nginx 配置（不需拆分）
```

---

## Part 2: 配置說明

### 核心概念

#### 1. Docker Compose Profiles

使用 profiles 來控制啟動哪個後端：

- **`backend-java`**: `profiles: ['java']` - 只有在指定 `java` profile 時啟動
- **`backend-golang`**: `profiles: ['golang']` - 只有在指定 `golang` profile 時啟動
- **其他服務**（frontend, web_service, db）: 沒有 profile，永遠啟動

#### 2. 預設後端設定

在 `.env` 檔案中設定 `COMPOSE_PROFILES=golang`，這樣 `docker compose up` 會預設使用 Golang 後端。

**重要**：

- `.env` 檔案包含敏感資訊（密碼、JWT secret），**不應該被 Git 追蹤**
- 在本地開發時，從 `.env.example` 複製並建立 `.env` 檔案
- 在生產環境部署時，透過 CI/CD 或容器平台的環境變數功能注入 `COMPOSE_PROFILES`

#### 3. 容器名稱統一

兩個後端都使用 `container_name: backend`，這樣：

- Nginx 的 `proxy_pass http://backend:8080/` 會自動路由到當前啟動的後端
- 不需要修改 Nginx 配置
- 不需要修改前端配置

#### 4. 網絡配置

不需要明確定義 networks，Docker Compose 會自動：

1. 建立預設網絡（`waterballsa-project_default`）
2. 將所有服務加入這個網絡
3. 啟用 DNS 解析

### 關鍵配置段落

#### Backend Services 配置

**Java Backend**:

```yaml
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
  ports:
    - '${BACKEND_PORT:-8080}:8080'
  volumes:
    - ./www_root/waterballsa-backend/src:/app/src
    - ./www_root/waterballsa-backend/pom.xml:/app/pom.xml
    - ./www_root/waterballsa-backend/checkstyle.xml:/app/checkstyle.xml
  healthcheck:
    test: ['CMD-SHELL', 'curl -f http://localhost:8080/actuator/health || exit 1']
    interval: 15s
    timeout: 15s
    retries: 10
    start_period: 30s
```

**Golang Backend**:

```yaml
backend-golang:
  profiles: ['golang']
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
    - .env.golang
  ports:
    - '${BACKEND_PORT:-8080}:8080'
  volumes:
    - ./www_root/waterballsa-backend-golang:/app
    - /app/vendor
    - /app/tmp
  healthcheck:
    test: ['CMD-SHELL', 'curl -f http://localhost:8080/healthz || exit 1']
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 20s
```

#### Frontend 和 Web Service 配置

**Frontend**（依賴任一後端）:

```yaml
frontend:
  build:
    context: ./www_root/waterballsa-frontend
    dockerfile: ../../next/docker_file/Dockerfile
  depends_on:
    backend-java:
      condition: service_healthy
      required: false
    backend-golang:
      condition: service_healthy
      required: false
  # ... 其他配置
```

**Web Service**（依賴任一後端）:

```yaml
web_service:
  image: nginx:alpine
  depends_on:
    ssl-init:
      condition: service_completed_successfully
    frontend:
      condition: service_healthy
    backend-java:
      condition: service_healthy
      required: false
    backend-golang:
      condition: service_healthy
      required: false
  # ... 其他配置
```

**重點**：使用 `required: false` 讓服務可以依賴任一後端，只要有一個後端健康即可啟動。

---

## Part 3: 使用方式

### 啟動服務

**使用 Golang 後端（預設）**:

```bash
docker compose up -d
```

**使用 Java 後端**:

```bash
# 方法 1: 透過環境變數
COMPOSE_PROFILES=java docker compose up -d

# 方法 2: 透過 --profile 參數
docker compose --profile java up -d
```

**切換後端**:

```bash
# 先停止當前服務
docker compose down

# 啟動另一個後端
COMPOSE_PROFILES=java docker compose up -d
```

### 查看當前配置

**查看將會啟動的服務**:

```bash
# 預設（Golang）
docker compose config --services

# Java
COMPOSE_PROFILES=java docker compose config --services
```

**查看完整配置**:

```bash
docker compose config
```

### 查看日誌

```bash
# 查看後端日誌
docker compose logs -f backend

# 查看所有服務日誌
docker compose logs -f
```

---

## Part 4: 故障排除

### 問題 1: 兩個後端同時啟動

**症狀**: `docker compose ps` 顯示 `backend-java` 和 `backend-golang` 同時運行

**原因**: 可能同時指定了多個 profiles

**解決**:

```bash
# 檢查環境變數
echo $COMPOSE_PROFILES

# 停止所有服務
docker compose --profile java --profile golang down

# 只啟動一個
docker compose up -d  # 只會啟動 golang（預設）
```

### 問題 2: Profile 未啟動對應服務

**症狀**: `docker compose --profile java up` 但 backend-java 沒有啟動

**解決**:

```bash
# 檢查 profile 定義
docker compose config --profiles

# 檢查服務列表
docker compose --profile java config --services

# 確認 YAML 縮排正確
docker compose config

# 確認使用 docker compose (v2) 而非 docker-compose (v1)
docker compose version
```

### 問題 3: 健康檢查一直失敗

**症狀**: `docker compose ps` 顯示 backend 長時間卡在 `starting`

**解決**:

```bash
# 查看日誌
docker compose logs backend

# 手動測試健康檢查
docker compose exec backend curl -f http://localhost:8080/healthz  # Golang
docker compose exec backend curl -f http://localhost:8080/actuator/health  # Java

# 檢查應用是否在監聽正確端口
docker compose exec backend netstat -tlnp

# 如果是 Java，可能需要增加 start_period
# 在 healthcheck 中: start_period: 60s
```

### 問題 4: Nginx 404 Not Found

**症狀**: 訪問 `http://localhost/api/users` 返回 404

**解決**:

```bash
# 檢查 Nginx 配置
docker compose exec web_service nginx -t

# 查看 Nginx 日誌
docker compose logs web_service

# 確認配置檔案是否正確掛載
docker compose exec web_service cat /etc/nginx/conf.d/www.conf

# 直接訪問後端測試
curl http://localhost:8080/users  # 或其他 API 路徑
```

### 問題 5: 環境變數檔案找不到

**症狀**: `env file .env.golang not found`

**解決**:

```bash
# 檢查檔案是否存在
ls -la .env.golang

# 如果不存在，建立檔案
cat > .env.golang << 'EOF'
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

# JWT
JWT_EXPIRATION_HOURS=24
EOF
```

---

## Part 5: 環境變數說明

### `.env`（共用）

```env
# Database Configuration
POSTGRES_VERSION=16-alpine
POSTGRES_DB=waterballsa
POSTGRES_USER=admin
POSTGRES_PASSWORD=postgres123
HOST_POSTGRES_PORT=5432

# Docker Compose Profiles (default: golang backend)
COMPOSE_PROFILES=golang

# Backend Configuration
BACKEND_PORT=8080

# Frontend Configuration
FRONTEND_PORT=3000

# JWT Secret
JWT_SECRET=your_jwt_secret_key_change_in_production
```

### `.env.golang`（Golang 專用）

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

# JWT
JWT_EXPIRATION_HOURS=24
```

---

## Part 6: 容器化部署指南

### 本地開發

```bash
# 1. 從 .env.example 複製並建立 .env
cp .env.example .env

# 2. 編輯 .env，設定 COMPOSE_PROFILES=golang（或 java）
# 也要設定資料庫密碼、JWT secret 等

# 3. 啟動服務
docker compose up -d
```

### CI/CD 部署

在 CI/CD pipeline 中，透過環境變數注入：

```bash
# 方法 1: 使用環境變數
export COMPOSE_PROFILES=golang
export POSTGRES_PASSWORD=secure_password
export JWT_SECRET=secure_jwt_secret
docker compose up -d

# 方法 2: 使用 --profile 參數
docker compose --profile golang up -d

# 方法 3: 在 docker-compose 命令前設定環境變數
COMPOSE_PROFILES=golang \
POSTGRES_PASSWORD=secure_password \
JWT_SECRET=secure_jwt_secret \
docker compose up -d
```

### 雲端平台部署範例

#### Docker Swarm

```bash
# 在 swarm manager 設定環境變數
docker secret create postgres_password <password_file>
docker secret create jwt_secret <jwt_file>

# 部署時指定 profile
COMPOSE_PROFILES=golang docker stack deploy -c docker-compose.yml myapp
```

#### Kubernetes（使用 kompose）

```bash
# 設定環境變數
export COMPOSE_PROFILES=golang
kompose convert

# 建立 secrets
kubectl create secret generic app-secrets \
  --from-literal=postgres-password=<password> \
  --from-literal=jwt-secret=<jwt>
```

#### AWS ECS / Azure Container Instances

在任務定義或容器組設定中添加環境變數：

- `COMPOSE_PROFILES=golang`
- `POSTGRES_PASSWORD=xxx`
- `JWT_SECRET=xxx`

## 總結

### 配置重點

1. ✅ **Profile 控制後端切換**

   - `backend-java`: `profiles: ['java']`
   - `backend-golang`: `profiles: ['golang']`
   - 預設使用環境變數 `COMPOSE_PROFILES=golang`
   - `.env` 檔案不會被 Git 追蹤，部署時需要另外設定

2. ✅ **統一的容器名稱**

   - 兩個後端都使用 `container_name: backend`
   - Nginx 配置不需要修改

3. ✅ **不需要複雜的網絡配置**

   - Docker Compose 自動建立預設網絡
   - 所有服務可以互相通訊

4. ✅ **靈活的依賴關係**
   - Frontend 和 Web Service 使用 `required: false`
   - 可以依賴任一後端

### 為什麼不需要拆分 Nginx 配置？

- ✅ 兩個後端都使用相同的 API 路徑 `/api/`
- ✅ 前端保持不變（都是 Next.js）
- ✅ 容器名稱統一為 `backend`
- ✅ Nginx 的 `proxy_pass http://backend:8080/` 會自動路由到當前啟動的後端

### 優勢

- 簡單明瞭的切換方式
- 最小化配置變更
- 前端和 Nginx 配置保持穩定
- 易於維護和擴展
