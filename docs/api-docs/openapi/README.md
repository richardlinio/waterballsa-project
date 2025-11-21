# OpenAPI 模組化結構說明

此目錄包含了 WaterBall SA API 的模組化 OpenAPI 規範文件。

## 目錄結構

```
openapi/
├── paths/          # API 路徑定義
│   ├── health.yaml    # 健康檢查端點
│   ├── auth.yaml      # 認證相關端點（註冊、登入、登出）
│   ├── journeys.yaml  # 旅程相關端點
│   ├── missions.yaml  # 任務相關端點
│   └── users.yaml     # 用戶相關端點
└── schemas/        # 資料模型定義
    ├── common.yaml    # 共用模型（錯誤回應、健康檢查等）
    ├── auth.yaml      # 認證相關模型
    ├── journeys.yaml  # 旅程相關模型
    ├── missions.yaml  # 任務相關模型
    └── users.yaml     # 用戶相關模型
```

## 如何使用

### 1. 開發時編輯模組文件

當你需要修改 API 規範時：

- **修改端點**：編輯 `paths/` 目錄下對應的檔案
- **修改資料模型**：編輯 `schemas/` 目錄下對應的檔案

例如，要修改旅程列表 API：
```bash
# 編輯端點定義
vim openapi/paths/journeys.yaml

# 編輯回應模型
vim openapi/schemas/journeys.yaml
```

### 2. 合併成單一檔案（用於部署或分享）

使用 `@apidevtools/swagger-cli` 工具將模組化文件合併成單一檔案：

```bash
# 安裝工具（如果還沒安裝）
npm install -g @apidevtools/swagger-cli

# 合併文件
cd docs
swagger-cli bundle swagger.yaml -o swagger-bundled.yaml -t yaml

# 驗證合併後的文件
swagger-cli validate swagger-bundled.yaml
```

### 3. 預覽 API 文件

使用 Swagger UI 或 Redoc 預覽：

```bash
# 使用 Swagger UI（需要安裝 swagger-ui）
npx serve

# 或使用線上編輯器
# 1. 先合併文件
# 2. 將 swagger-bundled.yaml 上傳到 https://editor.swagger.io/
```

## 檔案參考語法

### 在主文件中參考模組

```yaml
paths:
  /journeys:
    $ref: './openapi/paths/journeys.yaml#/list'
```

### 在模組中相互參考

```yaml
# 在 paths/journeys.yaml 中參考 schema
schema:
  $ref: '../schemas/journeys.yaml#/JourneyListItem'
```

### 在 schema 中相互參考

```yaml
# 在 journeys.yaml 中參考同一檔案內的其他 schema
chapters:
  type: array
  items:
    $ref: '#/Chapter'
```

## 修改示例

### 範例 1：添加新的 API 端點

假設要添加一個新的端點 `GET /journeys/{journeyId}/reviews`：

1. 在 `paths/journeys.yaml` 添加：
```yaml
reviews:
  get:
    tags:
      - Journeys
    summary: Get journey reviews
    # ... 其他定義
```

2. 在 `schemas/journeys.yaml` 添加回應模型：
```yaml
JourneyReview:
  type: object
  properties:
    # ... 屬性定義
```

3. 在主 `swagger.yaml` 添加路徑：
```yaml
paths:
  /journeys/{journeyId}/reviews:
    $ref: './openapi/paths/journeys.yaml#/reviews'
```

### 範例 2：修改現有欄位

假設要在旅程中添加 `difficulty` 欄位：

1. 編輯 `schemas/journeys.yaml`：
```yaml
JourneyListItem:
  properties:
    # ... 現有屬性
    difficulty:
      type: string
      enum: [BEGINNER, INTERMEDIATE, ADVANCED]
```

2. 更新相關範例（在 `paths/journeys.yaml` 中）

## 優點

✅ **模組化**：每個功能模組獨立管理，易於維護
✅ **減少衝突**：團隊協作時減少 Git 衝突
✅ **精準編輯**：AI 或開發者只需關注相關的小檔案
✅ **易於導航**：清晰的檔案結構，快速找到要修改的內容
✅ **可合併**：需要時可以合併成單一檔案

## 注意事項

- 修改後建議執行 `swagger-cli validate` 驗證語法
- Git 提交時只會看到你修改的模組檔案，而非整個大檔案
- 主 `swagger.yaml` 檔案應該只包含 metadata 和參考，不包含實際定義
- 備份檔案 `swagger.yaml.backup` 保留了原始的完整版本

## 相關工具

- **swagger-cli**: https://github.com/APIDevTools/swagger-cli
- **Swagger Editor**: https://editor.swagger.io/
- **Redocly CLI**: https://redocly.com/docs/cli/
- **Stoplight Studio**: https://stoplight.io/studio
