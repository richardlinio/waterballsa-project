# BDD 測試生成 Prompt Template

**版本**: v1.0
**最後更新**: 2025-12-12
**適用專案**: WaterBall SA Platform

---

## 📋 目錄

1. [概述](#概述)
2. [Prompt 1: Spec → DSL Feature](#prompt-1-spec--dsl-feature-業務層測試場景生成)
3. [Prompt 2: DSL → ISA Feature](#prompt-2-dsl--isa-feature-技術層測試實作生成)
4. [Prompt 3: 測試失敗分析與精煉](#prompt-3-測試失敗分析與精煉)
5. [Step Definitions Reference](#step-definitions-reference-可用步驟參考)
6. [使用流程範例](#使用流程範例)
7. [最佳實踐](#最佳實踐)

---

## 概述

本文件提供三個完整的 Prompt Template，用於自動生成 BDD 測試：

| Prompt       | 輸入                       | 輸出        | 用途                                          |
| ------------ | -------------------------- | ----------- | --------------------------------------------- |
| **Prompt 1** | Release Spec               | DSL Feature | 業務層測試場景（給人看，可包含前端+後端場景） |
| **Prompt 2** | DSL + API Spec + DB Schema | ISA Feature | **後端 API E2E 測試**（給機器跑，只測試 API） |
| **Prompt 3** | 測試失敗訊息               | 修正建議    | 迭代精煉達到 99% 精準度                       |

### 核心理念

1. **分層抽象**: DSL 使用業務語言（可包含前端+後端場景），ISA 使用技術語言（**專注後端 API E2E**）
2. **後端 E2E 聚焦**: ISA 層目標是完整測試 API 文件定義的所有端點
3. **原子化測試**: 每個步驟只做一件事，驗證分層
4. **通用步驟**: 使用可重用的 Step Definitions，不發明新步驟
5. **資料庫直接插入**: Setup 使用 `Given the database has a ...`，不透過 API

---

## Prompt 1: Spec → DSL Feature (業務層測試場景生成)

### 使用時機

當你有一個新的功能規格，需要生成業務層的測試場景。

### 輸入準備

1. 從 Release-X-Spec.md 複製具體的功能規格
2. 從 `/docs/domain-glossary.md` 複製相關的業務術語

### Prompt Template

複製以下內容到 Claude 對話中：

````markdown
你是一位專業的 QA 工程師，負責將產品經理的功能規格轉換為 BDD 測試場景。

## 你的任務

將以下功能規格轉換為 Gherkin 格式的 DSL Feature 檔案。

## 功能規格

## Domain Glossary (業務術語表)

/Users/linporu/Documents/world-of-code/waterballsa-project/docs/domain-glossary.md

## 輸出要求

### 格式要求

1. 使用 Gherkin 語法撰寫
2. 檔案開頭包含元資料註解:

   ```gherkin
   # Language: zh-TW
   # DSL Layer (L1): Business Domain Language
   # Source: Release-X-Spec.md - X.X 功能名稱
   ```

3. Feature 描述使用 User Story 格式:
   ```gherkin
   Feature: [功能名稱]
     作為一個 [角色]
     我想要 [做某事]
     以便 [達成目標]
   ```

### 內容要求

1. **只使用業務語言**

   - 使用 Domain Glossary 中的標準術語
   - 不要出現技術詞彙: HTTP, API, JSON, 資料庫, SQL 等
   - 不要出現實作細節

2. **場景設計原則**

   - 每個 Scenario 只測試一個具體情境
   - 包含正常流程 (Happy Path)
   - 包含異常流程 (Error Cases)
   - 包含邊界條件 (Edge Cases)

3. **Gherkin 步驟結構**

   - **Given**: 系統的前置條件和狀態
     - 範例: `Given 系統中存在一位用戶 "Alice" 密碼為 "Test1234!"`
   - **When**: 使用者執行的操作
     - 範例: `When "Alice" 嘗試使用 "Test1234!" 進行登入`
   - **Then**: 系統的預期行為和結果
     - 範例: `Then 登入應該成功`
   - **And**: 額外的條件或驗證
     - 範例: `And 她應該收到一組有效的存取 Token`

4. **測試資料命名**

   - 使用有意義的測試資料名稱 (如 Alice, Bob, Charlie)
   - 不同場景使用不同的測試資料
   - 密碼格式需符合系統要求 (8-72 字元，英數字加特殊符號)

## 範例輸出

/Users/linporu/Documents/world-of-code/waterballsa-project/www_root/waterballsa-backend/src/test/resources/features/dsl/auth/login.dsl.feature

## 現在開始生成

請根據上述要求，為提供的功能規格生成 DSL Feature 檔案。

檔案請至以下位置尋找資料夾：/Users/linporu/Documents/world-of-code/waterballsa-project/www_root/waterballsa-backend/src/test/resources/features/dsl

any question?
````

---

## Prompt 2: DSL → ISA Feature (後端 API E2E 測試生成)

### 使用時機

當你有 DSL Feature，需要生成可執行的後端 API E2E 測試。

### 測試範疇

**ISA 層專注於後端 API E2E 測試**：

- ✅ 測試目標：完整覆蓋 API 文件（Swagger/OpenAPI）定義的所有端點
- ✅ 測試範圍：HTTP Request → API Handler → Database → HTTP Response
- ✅ 測試方式：透過 HTTP 呼叫 API，驗證回應結果和資料庫狀態
- ❌ 不包含：前端 UI 測試、瀏覽器互動、畫面渲染等

### DSL 場景的轉換策略

如果 DSL Feature 包含前端場景：

1. **後端可測試的場景**：轉換為 ISA Feature（如：登入、註冊、購買課程）
2. **純前端場景**：標註 `@frontend` tag，暫時略過或記錄在註解中
3. **混合場景**：拆分為後端 API 測試部分，前端部分記錄在註解中

### 輸入準備

1. 複製 DSL Feature 檔案內容
2. 從 `/docs/api-docs/openapi/paths/` 複製相關的 API endpoint 定義
3. 從 `/docs/db-schema.dbml` 複製相關的資料表定義

### Prompt Template

複製以下內容到 Claude 對話中：

````markdown
你是一位專業的 Backend 工程師，負責將業務測試場景翻譯為可執行的後端 API E2E 測試。

## 你的任務

將以下 DSL Feature 翻譯為 ISA Feature 檔案，生成可透過 Cucumber + RestAssured 執行的後端 API E2E 測試。

## 測試範疇說明

**ISA 層專注於後端 API E2E 測試**：

- ✅ 測試所有 API 端點（根據 Swagger/OpenAPI 定義）
- ✅ 測試 HTTP Request/Response、狀態碼、回應結構、回應值
- ✅ 測試資料庫狀態變化（透過直接查詢或後續 API 驗證）
- ❌ 不測試前端 UI、瀏覽器互動、畫面渲染

**轉換規則**：

- 如果 DSL 場景可以透過 API 測試 → 轉換為 ISA Feature
- 如果 DSL 場景是純前端操作 → 標註 `@frontend` tag 並在註解中說明
- 如果 DSL 場景是混合場景 → 拆分後端 API 部分進行測試

## 輸入資料

### DSL Feature

### API Swagger 定義

/Users/linporu/Documents/world-of-code/waterballsa-project/docs/api-docs/swagger.yaml

### 資料庫 Schema

/Users/linporu/Documents/world-of-code/waterballsa-project/docs/db-schema.dbml

### 可用的通用步驟 (Step Definitions)

/Users/linporu/Documents/world-of-code/waterballsa-project/www_root/waterballsa-backend/src/test/java/waterballsa/bdd/steps

## 輸出要求

### 格式要求

1. 使用 `@isa` Tag 標記（後端 API E2E 測試）
2. 如果 DSL 場景是純前端，使用 `@frontend` Tag 標記並在註解中說明
3. 檔案開頭包含元資料註解:

   ```gherkin
   # ISA Layer (L2): Backend API E2E Test
   # Source: swagger.yaml - /具體/endpoint
   # Test Scope: HTTP Request → API Handler → Database → HTTP Response
   # Maps DSL scenarios to concrete API calls
   ```

### 內容要求

1. **Setup (Given) 步驟**

   - ✅ 使用 `the database has a ...` 步驟建立測試資料
   - ❌ 不要透過 API 建立測試資料 (如註冊 API)
   - 密碼欄位直接使用明文 (會自動 hash)
   - 確保測試資料獨立於其他測試

2. **Action (When) 步驟**

   - 使用 `I send "METHOD" request to "ENDPOINT" with body:` 步驟
   - Request body 必須符合 Swagger 的 schema 定義
   - JSON 格式需正確縮排 (2 空格)
   - 使用三引號 `"""` 包裹 JSON body

3. **Verification (Then/And) 步驟**

   - **第一層**: 驗證 HTTP 狀態碼
     ```gherkin
     # Verification: HTTP layer
     Then the response status code should be 200
     ```
   - **第二層**: 驗證回應欄位存在
     ```gherkin
     # Verification: Response structure
     And the response body should contain field "accessToken"
     And the response body should contain field "user.username"
     ```
   - **第三層**: 驗證回應欄位值
     ```gherkin
     # Verification: Response values
     And the response body field "user.username" should equal "Alice"
     And the response body field "user.experience" should equal "0"
     ```
   - 每個驗證步驟只檢查一件事 (原子化)
   - 加入註解說明驗證的層級

4. **錯誤處理測試**

   - 驗證正確的 HTTP 錯誤碼 (如 401, 404, 409)
   - 驗證錯誤訊息內容
   - 考慮各種錯誤情境

5. **前端場景處理**

   - 如果 DSL 場景包含純前端操作（如：點擊按鈕、填寫表單、檢查畫面顯示）
   - 在 ISA Feature 中使用 `@frontend` tag 標記
   - 在註解中說明這是前端場景，暫不實作自動化測試
   - 範例:
     ```gherkin
     @frontend
     Scenario: 使用者在首頁瀏覽課程列表
       # 前端場景：此場景涉及 UI 渲染和使用者互動
       # 暫不納入後端 API E2E 測試範圍
       # 可考慮使用 Playwright/Cypress 等前端測試工具
     ```

6. **注意事項**
   - ❌ 不要使用未在 Step Definitions 列表中的步驟
   - ❌ 不要發明新的步驟語法
   - ✅ 專注於測試 API 端點，確保涵蓋 Swagger 定義的所有 endpoints
   - 如果需要新步驟，請和我討論，討論後再執行

## 範例輸出

/Users/linporu/Documents/world-of-code/waterballsa-project/www_root/waterballsa-backend/src/test/resources/features/isa/auth/login.isa.feature

## 現在開始生成

請根據上述要求，為提供的 DSL Feature 生成可執行的 ISA Feature 檔案。

檔案請至以下位置尋找資料夾：/Users/linporu/Documents/world-of-code/waterballsa-project/www_root/waterballsa-backend/src/test/resources/features/isa

完成後禁止自行測試，我會幫你執行測試

any question?
````

---

## Prompt 3: 測試失敗分析與精煉

### 使用時機

當測試執行失敗，需要分析原因並修正。

### 輸入準備

1. 複製失敗的 Scenario
2. 複製完整的錯誤訊息和 stack trace
3. 複製相關的 API endpoint 定義

### Prompt Template

複製以下內容到 Claude 對話中：

````markdown
你是一位專業的測試架構師，負責分析測試失敗原因並提供修正建議。

## 你的任務

分析以下測試失敗的原因，並提供修正方案。

## 失敗的測試

### ISA Feature

### 錯誤訊息

### API Swagger 定義

/Users/linporu/Documents/world-of-code/waterballsa-project/docs/api-docs/swagger.yaml

## 分析重點

請按照以下順序分析問題:

### 1. API 實作與 Swagger 定義的一致性

- Response 的欄位名稱是否與 Swagger 一致?
- Response 的資料類型是否與 Swagger 一致?
- HTTP 狀態碼是否與 Swagger 定義相符?
- 錯誤訊息格式是否與 Swagger 定義相符?

### 2. 測試資料的正確性

- 測試資料是否符合 API 的驗證規則?
- 密碼格式是否符合要求?
- 必填欄位是否都有提供?
- 資料庫中的資料是否正確建立?

### 3. 測試步驟的邏輯

- Setup 步驟是否正確建立了所需的資料?
- Action 步驟是否正確呼叫了 API?
- Verification 步驟是否檢查了正確的欄位?

### 4. 步驟定義的可用性

- 是否使用了不存在的步驟?
- 步驟的參數格式是否正確?
- JSON 格式是否有誤?
- DataTable 格式是否正確?

### 5. 是否需要新的通用步驟

- 這個測試場景是否需要新的 Step Definition?
- 如果需要，新步驟的設計應該如何?
- 新步驟是否可重用於其他測試?

## 輸出要求

請提供以下內容:

### 1. 問題診斷

```
問題類型: [API實作問題 / 測試設計問題 / 步驟定義問題 / 資料問題]
根本原因: [詳細說明問題的根本原因]
```

### 2. 修正方案

#### 如果是測試設計問題

提供修正後的 ISA Feature:

```gherkin
[修正後的 Scenario]
```

#### 如果是 API 實作問題

指出 API 與 Swagger 的差異:

```
預期 (根據 Swagger):
  - HTTP Status: 200
  - Response Body: { "accessToken": "...", "user": { ... } }

實際 (根據錯誤訊息):
  - HTTP Status: 401
  - Response Body: { "error": "..." }

建議修正:
  - [具體的修正建議]
```

#### 如果需要新的 Step Definition

提供 Java 實作建議:

```java
@Given("the database has a user with ID {int}:")
public void databaseHasUserWithId(int userId, DataTable dataTable) {
  // Implementation
}
```

### 3. 預防措施

提供建議避免類似問題:

```
- [建議 1: 例如加強密碼驗證測試]
- [建議 2: 例如新增 API 回應格式檢查]
- [建議 3: 例如確保資料庫 Setup 的正確性]
```

## 現在開始分析

請根據上述框架，分析提供的測試失敗案例。
````

---

## Step Definitions Reference (可用步驟參考)

以下是所有可用的通用步驟定義，這些步驟已實作並可直接使用：

### 資料庫操作步驟

```gherkin
# 建立測試用戶
Given the database has a user:
  | username   | Alice       |  # 必填: 用戶名 (3-50 字元，英數字和底線)
  | password   | Test1234!   |  # 必填: 密碼 (明文，會自動 BCrypt hash)
  | experience | 0           |  # 選填: 經驗值 (預設 0)

# 建立測試旅程
Given the database has a journey:
  | title       | Java 基礎課程           |  # 必填: 旅程標題
  | slug        | java-basics            |  # 必填: URL slug
  | description | 學習 Java 程式設計基礎  |  # 選填: 描述
  | teacher     | 水球老師                |  # 必填: 老師名稱
  | price       | 1999.00                |  # 必填: 價格 (數字格式)

# 建立測試訂單
Given the database has an order:
  | user_id    | 1           |  # 必填: 使用者 ID (整數)
  | journey_id | 1           |  # 必填: 旅程 ID (整數)
  | status     | UNPAID      |  # 必填: UNPAID / PAID / EXPIRED
```

### HTTP 請求步驟

```gherkin
# 發送帶 JSON body 的請求
When I send "POST" request to "/auth/login" with body:
  """
  {
    "username": "Alice",
    "password": "Test1234!"
  }
  """

# 發送帶 headers 的請求（用於需要認證的 API）
When I send "GET" request to "/users/me" with headers:
  | Authorization | Bearer {{token}} |

# 參數說明:
# - Method: GET, POST, PUT, DELETE, PATCH (大寫)
# - Endpoint: API 路徑，必須以 / 開頭
# - Body: JSON 格式，使用三引號 """ 包裹，縮排 2 空格
# - Headers: 表格格式 (DataTable)
# - 變數替換: 使用 {{變數名}} 格式
```

### HTTP 回應驗證步驟

```gherkin
# 驗證 HTTP 狀態碼
Then the response status code should be 200

# 驗證回應欄位存在
And the response body should contain field "accessToken"
And the response body should contain field "user.username"

# 驗證回應欄位值 (支援字串和數字自動轉換)
And the response body field "user.username" should equal "Alice"
And the response body field "user.experience" should equal "0"

# 儲存回應值到變數（用於後續步驟）
And I store the response field "accessToken" as "token"
And I store the response field "user.id" as "userId"

# 參數說明:
# - Field path: 使用點號 . 表示巢狀結構
#   例如: "user.username" 對應 { "user": { "username": "..." } }
# - 數字值: 自動轉換類型進行比較
#   "0" 會被轉換成整數 0
# - 變數: 儲存後可在後續步驟使用 {{變數名}}
```

### 使用範例

```gherkin
Scenario: 完整的認證流程
  # Setup: 建立測試資料
  Given the database has a user:
    | username   | Alice     |
    | password   | Test1234! |
    | experience | 0         |

  # Action: 登入並取得 Token
  When I send "POST" request to "/auth/login" with body:
    """
    {
      "username": "Alice",
      "password": "Test1234!"
    }
    """

  # Verification: 檢查登入回應
  Then the response status code should be 200
  And the response body should contain field "accessToken"
  And I store the response field "accessToken" as "token"

  # Action: 使用 Token 存取需認證的 API
  When I send "GET" request to "/users/me" with headers:
    | Authorization | Bearer {{token}} |

  # Verification: 檢查使用者資訊
  Then the response status code should be 200
  And the response body field "username" should equal "Alice"
  And the response body field "experience" should equal "0"
```

---

## 使用流程範例

### 完整工作流程

#### 步驟 1: 生成 DSL Feature

1. 從 `/docs/Release-1-Spec.md` 複製 "1.2 使用者登入" 的規格
2. 從 `/docs/domain-glossary.md` 複製相關術語
3. 使用 **Prompt 1** 生成 DSL Feature
4. 儲存為 `src/test/resources/features/dsl/auth/login.dsl.feature`

#### 步驟 2: 生成 ISA Feature

1. 複製步驟 1 生成的 DSL Feature
2. 從 `/docs/api-docs/openapi/paths/auth.yaml` 複製 login endpoint 定義
3. 從 `/docs/db-schema.dbml` 複製 users table 定義
4. 使用 **Prompt 2** 生成 ISA Feature
5. 儲存為 `src/test/resources/features/isa/auth/login.isa.feature`

#### 步驟 3: 執行測試

```bash
# 執行所有 BDD 測試
make test-bdd

# 只執行 ISA 層測試
make test-bdd-isa

# 執行特定 tag 的測試
make test-bdd-tag TAG=@auth
```

#### 步驟 4: 如果測試失敗

1. 複製失敗的 Scenario
2. 複製完整的錯誤訊息和 stack trace
3. 從 `/docs/api-docs/` 複製相關的 API 定義
4. 使用 **Prompt 3** 進行分析
5. 根據建議修正測試或 API 實作

#### 步驟 5: 迭代直到成功

重複步驟 3-4，直到所有測試通過，達到 99% 精準度。

---

## 最佳實踐

### DSL Feature 撰寫

#### ✅ 應該做的

1. 使用 Domain Glossary 的標準術語
2. 一個 Scenario 只測試一個具體情境
3. 包含正常流程 (Happy Path)
4. 包含異常流程 (Error Cases)
5. 包含邊界條件 (Edge Cases)
6. 使用有意義的測試資料名稱 (Alice, Bob, Charlie)

#### ❌ 不應該做的

1. 不要出現技術詞彙 (HTTP, API, JSON, SQL 等)
2. 不要出現實作細節 (資料庫、快取、佇列等)
3. 不要使用 test1, test2 等無意義名稱
4. 不要在一個 Scenario 中測試多個情境

### ISA Feature 撰寫

#### ✅ 應該做的

1. **專注後端 API E2E 測試**：目標是完整覆蓋 API 文件定義的所有端點
2. Setup 使用 `the database has a ...` 步驟
3. 驗證分層且原子化 (HTTP → 結構 → 值)
4. 加入清楚的註解說明驗證層級
5. JSON 格式正確縮排 (2 空格)
6. 只使用已有的 Step Definitions
7. 確保測試資料獨立於其他測試
8. 測試範圍：HTTP Request → API Handler → Database → HTTP Response

#### ❌ 不應該做的

1. 不要透過 API 建立測試資料 (如先呼叫註冊 API)
2. 不要發明新的步驟語法
3. 不要在一個步驟中檢查多個欄位
4. 不要依賴其他 API 的正確性
5. 不要使用全域變數或共享狀態
6. **不要測試前端 UI**：如瀏覽器互動、畫面渲染、DOM 操作等

#### 🔄 前端場景的處理

當 DSL Feature 包含前端場景時：

```gherkin
# DSL Feature 可能包含前端場景
Feature: 課程瀏覽
  Scenario: 使用者在首頁看到推薦課程
    Given 系統中有 5 門熱門課程
    When 使用者打開首頁
    Then 她應該看到推薦課程列表
    And 每門課程都顯示標題、老師和價格

# ISA Feature 處理方式 1: 標註為前端場景
@frontend
Scenario: 使用者在首頁看到推薦課程
  # 前端場景：涉及 UI 渲染和畫面顯示
  # 建議使用 Playwright/Cypress 等前端測試工具
  # 暫不納入後端 API E2E 測試範圍

# ISA Feature 處理方式 2: 轉換為對應的 API 測試
@isa
Scenario: 取得推薦課程列表 API
  # 後端 API 測試：測試 GET /journeys/recommended 端點
  Given the database has a journey:
    | title   | Java 基礎 |
    | teacher | 水球      |
    | price   | 1999      |
  When I send "GET" request to "/journeys/recommended"
  Then the response status code should be 200
  And the response body should contain field "journeys[0].title"
  And the response body should contain field "journeys[0].teacher"
  And the response body should contain field "journeys[0].price"
```

### 原子化驗證原則

#### 驗證分層順序

1. **第一層**: 驗證 HTTP 狀態碼

   ```gherkin
   # Verification: HTTP layer
   Then the response status code should be 200
   ```

2. **第二層**: 驗證回應欄位存在

   ```gherkin
   # Verification: Response structure
   And the response body should contain field "accessToken"
   And the response body should contain field "user.id"
   And the response body should contain field "user.username"
   ```

3. **第三層**: 驗證回應欄位值
   ```gherkin
   # Verification: Response values
   And the response body field "user.username" should equal "Alice"
   And the response body field "user.experience" should equal "0"
   ```

#### 為什麼要分層?

- **快速定位問題**: 如果第一層失敗,知道是 HTTP 狀態碼問題
- **原子化**: 每個步驟只檢查一件事
- **可重用**: 每個驗證步驟都可以在其他測試中重用
- **可讀性**: 清楚知道每個步驟在驗證什麼

### 測試資料命名

#### ✅ 好的命名

```gherkin
Given the database has a user:
  | username   | Alice       |  # 有意義的名字
  | password   | Test1234!   |

Given the database has a journey:
  | title   | Java 基礎課程  |  # 描述性的標題
  | teacher | 水球老師       |  # 真實的名稱
```

#### ❌ 不好的命名

```gherkin
Given the database has a user:
  | username   | test1       |  # 無意義
  | password   | test1       |  # 不符合格式要求

Given the database has a journey:
  | title   | course1     |  # 太抽象
  | teacher | teacher1    |  # 無意義
```

### 錯誤處理測試

#### 應該測試的錯誤情境

1. **認證錯誤**:

   - 錯誤的密碼
   - 不存在的帳號
   - 過期的 Token
   - 無效的 Token

2. **權限錯誤**:

   - 未登入存取需登入的 API
   - 存取其他使用者的資源
   - 存取未購買的付費內容

3. **資料驗證錯誤**:

   - 必填欄位缺失
   - 格式不正確
   - 資料範圍超出限制

4. **業務邏輯錯誤**:
   - 重複購買同一課程
   - 交付未完成的任務
   - 對已過期訂單付款

---

## 常見問題 (FAQ)

### Q1: ISA 層的測試範圍是什麼？

**A**: ISA 層專注於**後端 API E2E 測試**：

**✅ 測試範圍**：

- 所有 API 端點（根據 Swagger/OpenAPI 定義）
- HTTP Request/Response 的完整流程
- 資料庫狀態變化
- 業務邏輯正確性
- 錯誤處理和異常情境

**❌ 不包含**：

- 前端 UI 測試（瀏覽器互動、畫面渲染）
- 前端狀態管理
- 前端路由導航
- CSS 樣式和視覺效果

**測試目標**: 完整覆蓋 API 文件定義的所有端點，確保後端 API 功能正確。

### Q2: DSL 包含前端場景時如何處理？

**A**: 根據場景類型採取不同策略：

**策略 1: 純後端場景** → 轉換為 ISA Feature

```gherkin
# DSL
Scenario: 使用者登入系統
  When Alice 使用正確密碼登入
  Then 登入應該成功

# ISA (轉換為 API 測試)
@isa
Scenario: 登入 API 測試
  Given the database has a user:
    | username | Alice     |
    | password | Test1234! |
  When I send "POST" request to "/auth/login" with body:
    """
    {"username": "Alice", "password": "Test1234!"}
    """
  Then the response status code should be 200
```

**策略 2: 純前端場景** → 標註 `@frontend` tag

```gherkin
# DSL
Scenario: 使用者在首頁看到歡迎訊息
  When Alice 打開首頁
  Then 她應該看到 "歡迎來到水球軟體學院"

# ISA (標註為前端場景)
@frontend
Scenario: 使用者在首頁看到歡迎訊息
  # 前端場景：涉及 UI 渲染
  # 建議使用 Playwright/Cypress 測試
  # 暫不納入後端 API E2E 測試範圍
```

**策略 3: 混合場景** → 拆分後端部分

```gherkin
# DSL
Scenario: 使用者購買課程後在畫面看到購買成功訊息
  When Alice 購買 "Java 課程"
  Then 系統應該顯示 "購買成功" 訊息
  And 她的課程列表中應該出現 "Java 課程"

# ISA (只測試後端 API 部分)
@isa
Scenario: 購買課程 API 測試
  # 後端部分：測試購買 API
  Given the database has a user:
    | username | Alice |
  And the database has a journey:
    | title | Java 課程 |
  When I send "POST" request to "/orders" with body:
    """
    {"journeyId": 1}
    """
  Then the response status code should be 201

  # 驗證資料庫狀態
  When I send "GET" request to "/users/me/journeys"
  Then the response body should contain field "journeys[0].title"
  And the response body field "journeys[0].title" should equal "Java 課程"

# 前端部分可以在註解中記錄
# 前端測試：驗證畫面顯示 "購買成功" 訊息（需使用前端測試工具）
```

### Q3: 如果需要新的 Step Definition 怎麼辦?

**A**: 在 ISA Feature 中用註解說明需要什麼步驟,然後使用 Prompt 3 分析,它會提供 Java 實作建議。

範例:

```gherkin
# TODO: Need new step definition
# Given the database has a chapter:
#   | journey_id | 1             |
#   | title      | 第一章         |
#   | order      | 1             |
```

### Q2: 如何處理需要多個前置資料的測試?

**A**: 使用多個 `Given the database has a ...` 步驟:

```gherkin
Scenario: 購買課程後交付任務
  Given the database has a user:
    | username | Alice     |
    | password | Test1234! |
  And the database has a journey:
    | title   | Java 課程 |
    | price   | 1999     |
  And the database has an order:
    | user_id    | 1    |
    | journey_id | 1    |
    | status     | PAID |
  When I send "POST" request to "/missions/1/deliver" with headers:
    | Authorization | Bearer {{token}} |
  Then the response status code should be 200
```

### Q3: 如何測試需要認證的 API?

**A**: 先登入取得 Token,儲存為變數,然後在後續步驟中使用:

```gherkin
Scenario: 存取需認證的個人資料 API
  Given the database has a user:
    | username | Alice     |
    | password | Test1234! |

  # 先登入取得 Token
  When I send "POST" request to "/auth/login" with body:
    """
    {
      "username": "Alice",
      "password": "Test1234!"
    }
    """
  Then the response status code should be 200
  And I store the response field "accessToken" as "token"

  # 使用 Token 存取 API
  When I send "GET" request to "/users/me" with headers:
    | Authorization | Bearer {{token}} |
  Then the response status code should be 200
```

### Q4: 測試失敗時如何快速定位問題?

**A**: 根據驗證分層快速判斷:

- **HTTP 狀態碼失敗**: API 實作問題或請求格式錯誤
- **欄位存在驗證失敗**: API 回應結構與 Swagger 不一致
- **欄位值驗證失敗**: 業務邏輯問題或測試資料問題

### Q5: 如何確保測試之間完全隔離?

**A**:

1. 每個 Scenario 前都會執行 `@Before` Hook 清理資料庫
2. 使用 `the database has a ...` 建立獨立的測試資料
3. 不要依賴其他測試的執行結果
4. 不要使用全域變數或共享狀態

---

## 附錄: 檔案結構範例

```
waterballsa-backend/
├── docs/
│   ├── domain-glossary.md      # 業務術語表
│   ├── bdd-prompt.md           # 本文件
│   ├── Release-1-Spec.md       # Release 1 規格
│   ├── Release-2-Spec.md       # Release 2 規格
│   ├── db-schema.dbml          # 資料庫 Schema
│   └── api-docs/
│       ├── swagger.yaml        # API 總覽
│       └── openapi/
│           ├── paths/
│           │   ├── auth.yaml   # 認證 API
│           │   ├── journeys.yaml
│           │   └── orders.yaml
│           └── schemas/
│               ├── auth.yaml
│               ├── journeys.yaml
│               └── orders.yaml
│
├── src/test/
│   ├── java/waterballsa/bdd/
│   │   ├── CucumberSpringConfiguration.java
│   │   ├── RunCucumberTest.java
│   │   ├── steps/
│   │   │   ├── DatabaseStepDefinitions.java  # 資料庫操作步驟
│   │   │   └── IsaStepDefinitions.java       # HTTP 請求/驗證步驟
│   │   └── support/
│   │       ├── RestAssuredConfig.java
│   │       └── World.java
│   │
│   └── resources/features/
│       ├── dsl/            # 業務層測試場景
│       │   ├── auth/
│       │   │   ├── login.dsl.feature
│       │   │   ├── register.dsl.feature
│       │   │   └── logout.dsl.feature
│       │   ├── journeys/
│       │   └── orders/
│       │
│       └── isa/            # 技術層可執行測試
│           ├── auth/
│           │   ├── login.isa.feature
│           │   ├── register.isa.feature
│           │   └── logout.isa.feature
│           ├── journeys/
│           └── orders/
│
└── Makefile
```

---

## 版本歷史

- **v1.0 (2025-12-12)**: 初始版本
  - 建立三個完整的 Prompt Template
  - 包含 Step Definitions Reference
  - 包含使用流程範例和最佳實踐

---

## 聯絡與支援

如有任何問題或建議,請透過以下方式聯絡:

- GitHub Issues: [waterballsa-project/issues](https://github.com/waterballsa/waterballsa-project/issues)
- 團隊 Discord: #bdd-testing 頻道

---

**Happy Testing! 🧪**
