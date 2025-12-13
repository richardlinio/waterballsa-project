# WaterBall SA 業務術語表 (Domain Glossary)

**版本**: v1.0
**最後更新**: 2025-12-12
**來源**: Release-1-Spec.md, Release-2-Spec.md, db-schema.dbml

---

## 使用說明

本文件定義 WaterBall SA 平台的核心業務術語，用於：

1. **BDD 測試撰寫**: 確保 DSL Feature 使用統一的業務語言
2. **跨團隊溝通**: PM、QA、工程師使用一致的詞彙
3. **AI 生成測試**: 提供給 AI Prompt 使用，確保生成的測試術語正確

---

## 核心業務概念

### 1. 使用者管理 (User Management)

#### 使用者 (User)

- **定義**: 平台的學習者
- **資料庫**: `users` table
- **關鍵屬性**:
  - `username`: 帳號（英數字，3-50 字元）
  - `password`: 密碼（英數字加特殊符號，8-72 字元）
  - `experience_points`: 經驗值（預設 0）
  - `level`: 等級（預設 1）
  - `role`: 角色（STUDENT, TEACHER, ADMIN）
- **相關操作**:
  - 註冊 (Register)
  - 登入 (Login)
  - 登出 (Logout)
- **業務規則**:
  - 帳號不可重複
  - 起始經驗值為 0
  - 起始等級為 1

#### 帳號 (Username / Account)

- **定義**: 使用者的唯一識別名稱
- **格式要求**: 英數字和底線，3-50 字元
- **範例**: `alice_chen`, `john_doe123`

#### 密碼 (Password)

- **定義**: 使用者的登入憑證
- **格式要求**: 英數字和特殊符號 (@$!%\*?&#)，8-72 字元
- **儲存方式**: BCrypt hash
- **範例**: `Test1234!`, `SecurePass123!`

#### 經驗值 (Experience Points / Experience)

- **定義**: 使用者的成長指標
- **資料庫**: `users.experience_points`
- **獲得方式**: 交付任務
- **用途**: 排行榜、升級計算
- **初始值**: 0

#### 等級 (Level)

- **定義**: 使用者的等級
- **資料庫**: `users.level`
- **初始值**: 1
- **升級方式**: 累積經驗值達標準後自動升級（延後執行）

#### 存取 Token (Access Token)

- **定義**: 使用者登入後獲得的 JWT 權杖
- **有效期限**: 1 天
- **用途**: 存取需要登入的 API
- **格式**: Bearer Token

---

### 2. 學習內容 (Learning Content)

#### 旅程 (Journey)

- **定義**: 學習課程的統稱
- **同義詞**: 課程 (Course)
- **資料庫**: `journeys` table
- **關鍵屬性**:
  - `title`: 旅程標題
  - `slug`: URL 友好識別符
  - `description`: 旅程描述
  - `cover_image_url`: 封面圖 URL
  - `teacher_name`: 老師名稱
  - `price`: 旅程價格
- **結構**: 一個旅程包含多個章節

#### 章節 (Chapter)

- **定義**: 旅程的組成單位
- **資料庫**: `chapters` table
- **關鍵屬性**:
  - `title`: 章節標題
  - `order_index`: 章節順序
- **結構**: 一個章節包含多個任務
- **從屬關係**: 屬於一個旅程

#### 任務 (Mission)

- **定義**: 最小的學習單元
- **同義詞**: 單元 (Unit)
- **資料庫**: `missions` table
- **任務類型** (Mission Type):
  - `VIDEO`: 影片任務
  - `ARTICLE`: 文章任務
  - `QUESTIONNAIRE`: 問卷任務
- **關鍵屬性**:
  - `title`: 任務標題
  - `description`: 任務詳細描述
  - `type`: 任務類型
  - `access_level`: 存取權限層級
  - `order_index`: 任務順序
- **從屬關係**: 屬於一個章節

#### 任務資源 (Mission Resource)

- **定義**: 任務的內容資源
- **資料庫**: `mission_resources` table
- **資源類型** (Resource Type):
  - `VIDEO`: 影片內容
  - `ARTICLE`: 文章內容
  - `FORM`: 表單
- **關鍵屬性**:
  - `resource_url`: 資源 URL
  - `resource_content`: 資源內容（文字）
  - `duration_seconds`: 影片長度（秒）
- **用途**: 一個任務可以有多個資源（如多段影片）

---

### 3. 學習進度 (Learning Progress)

#### 任務進度 (Mission Progress / User Mission Progress)

- **定義**: 使用者對任務的完成狀態
- **資料庫**: `user_mission_progress` table
- **進度狀態** (Progress Status):
  - `UNCOMPLETED`: 未完成（任務進行中或尚未開始）
  - `COMPLETED`: 已完成（任務已達成完成條件但尚未交付）
  - `DELIVERED`: 已交付（任務已交付並獲得獎勵）
- **關鍵屬性**:
  - `watch_position_seconds`: 影片觀看位置（秒）
  - `status`: 進度狀態

#### 完成 (Complete / Completion)

- **定義**: 任務達到 100% 完成度
- **影片任務**: 觀看進度達 100%
- **文章任務**: 使用者標記為完成
- **狀態變更**: UNCOMPLETED → COMPLETED
- **業務規則**:
  - 影片必須自動追蹤，不能手動標記
  - 每 10 秒記錄一次進度
  - 暫停、關閉頁面、觀看完成時也記錄

#### 交付 (Deliver / Delivery)

- **定義**: 完成任務後領取獎勵的動作
- **前置條件**: 任務狀態為 COMPLETED
- **效果**:
  - 狀態變更: COMPLETED → DELIVERED
  - 獲得任務的經驗值獎勵
- **業務規則**:
  - 每個任務只能交付一次
  - 交付後經驗值立即增加

#### 觀看進度 (Watch Progress / Watch Position)

- **定義**: 影片任務的觀看位置
- **資料庫**: `user_mission_progress.watch_position_seconds`
- **單位**: 秒
- **記錄時機**:
  - 每 10 秒自動記錄
  - 暫停影片時記錄
  - 關閉頁面時記錄
  - 觀看完成時記錄
- **用途**: 下次觀看時從上次位置繼續播放

---

### 4. 獎勵系統 (Reward System)

#### 獎勵 (Reward)

- **定義**: 交付任務後獲得的回報
- **資料庫**: `rewards` table
- **獎勵類型** (Reward Type):
  - `EXPERIENCE`: 經驗值獎勵
- **關鍵屬性**:
  - `reward_type`: 獎勵類型
  - `reward_value`: 獎勵數值
- **業務規則**:
  - 單一任務可設定多種獎勵
  - MVP 階段每個單元固定 100 經驗值

---

### 5. 權限控制 (Access Control)

#### 存取權限層級 (Mission Access Level)

- **定義**: 任務的可見性和可存取性
- **資料庫**: `missions.access_level`
- **權限層級**:
  - `PUBLIC`: 公開任務，未登入即可觀看
  - `AUTHENTICATED`: 需登入任務，登入後可觀看
  - `PURCHASED`: 需購買任務，購買旅程後可觀看
- **顯示規則**:
  - 未購買時顯示鎖定圖示
  - 點擊進入時顯示「此為付費內容，請先購買課程」

#### 登入狀態 (Login Status / Authentication Status)

- **定義**: 使用者是否已通過身份驗證
- **狀態**:
  - 已登入: 持有有效的 Access Token
  - 未登入: 沒有 Token 或 Token 已過期
- **業務規則**:
  - 重新整理頁面後仍保持登入
  - 關閉瀏覽器後再開啟仍保持登入
  - Token 過期時間為 1 天

---

### 6. 購課模組 (Purchase Module)

#### 訂單 (Order)

- **定義**: 購買課程的交易記錄
- **資料庫**: `orders` table
- **訂單狀態** (Order Status):
  - `UNPAID`: 未付款（訂單已建立但尚未付款）
  - `PAID`: 已付款（付款完成）
  - `EXPIRED`: 已過期（三天後未付款自動過期）
- **關鍵屬性**:
  - `order_number`: 訂單編號
  - `original_price`: 原始總價
  - `discount`: 折扣金額
  - `price`: 實際應付金額
  - `created_at`: 訂單建立時間
  - `expired_at`: 訂單過期時間（建立時間 + 3 天）
  - `paid_at`: 付款完成時間

#### 訂單編號 (Order Number)

- **定義**: 訂單的唯一識別碼
- **格式**: `{timestamp}{userId}{randomCode}`
- **範例**: `20251121011117cd5`
  - `2025112101`: 時間戳（年月日時）
  - `11`: 使用者 ID
  - `cd5`: 隨機碼

#### 訂單明細 (Order Item)

- **定義**: 訂單中的每個課程項目
- **資料庫**: `order_items` table
- **關鍵屬性**:
  - `journey_id`: 購買的課程
  - `quantity`: 購買數量（目前固定為 1）
  - `original_price`: 課程原價（建立時鎖定）
  - `discount`: 此課程的折扣金額
  - `price`: 此課程的實付金額
- **業務規則**:
  - MVP 階段每個訂單只能包含一門課程
  - 同一訂單不能包含重複的課程

#### 購買 (Purchase)

- **定義**: 使用者取得課程存取權的過程
- **流程**: 建立訂單 → 完成支付 → 購買完成
- **業務規則**:
  - 必須先登入才能購買
  - 已購買該課程時不可重複購買
  - 已有未付款訂單時導向付款頁面

#### 付款 (Payment / Pay)

- **定義**: 完成訂單支付的動作
- **效果**:
  - 訂單狀態: UNPAID → PAID
  - 記錄付款時間 (`paid_at`)
  - 建立使用者課程擁有權 (`user_journeys`)
- **業務規則**:
  - 過期訂單無法付款
  - 同一訂單不可重複付款

#### 課程擁有權 (User Journey / Purchased Journey)

- **定義**: 使用者已購買的課程
- **資料庫**: `user_journeys` table
- **關鍵屬性**:
  - `user_id`: 使用者 ID
  - `journey_id`: 課程 ID
  - `order_id`: 來源訂單 ID
  - `purchased_at`: 購買時間（付款完成時間）
- **業務規則**:
  - 使用者不可重複擁有同一課程
  - 購買後該課程的所有單元全部解鎖
  - 沒有觀看期限限制

#### 訂單過期 (Order Expiration)

- **定義**: 訂單超過付款期限的狀態
- **過期期限**: 訂單建立後 3 天
- **效果**:
  - 訂單狀態: UNPAID → EXPIRED
  - 無法再進行付款
- **業務規則**:
  - 系統自動標記過期
  - 使用者仍可查看過期訂單
  - 需重新建立新訂單（以新價格）

#### 價格鎖定 (Price Lock)

- **定義**: 訂單建立時鎖定當下的課程價格
- **用途**: 避免課程調價影響未付款訂單
- **業務規則**:
  - 訂單建立時記錄當下價格
  - 後續課程漲價不影響已建立的訂單
  - 過期後需重新建立訂單（以新價格）

---

## 業務流程術語

### 註冊流程 (Registration Flow)

1. 使用者填寫帳號和密碼
2. 系統驗證格式和重複性
3. 建立使用者（初始經驗值 0，等級 1）
4. 導向登入頁面

### 登入流程 (Login Flow)

1. 使用者輸入帳號和密碼
2. 系統驗證憑證
3. 成功：發放 Access Token，顯示課程列表
4. 失敗：顯示「帳號或密碼錯誤」

### 登出流程 (Logout Flow)

1. 使用者點擊登出按鈕
2. 系統將 Token 加入黑名單
3. 清除前端 Token
4. 無法再存取需登入的頁面

### 課程購買流程 (Purchase Flow)

1. **建立訂單階段**:

   - 點擊「立即加入課程」
   - 檢查是否已購買或有未付款訂單
   - 建立訂單，鎖定當下價格
   - 顯示訂單資訊

2. **完成支付階段**:

   - 顯示訂單詳情
   - 點擊「立即支付」
   - 訂單狀態變更為已付款
   - 建立課程擁有權

3. **購買完成階段**:
   - 顯示更新的訂單資訊
   - 顯示「立即上課」按鈕
   - 課程所有單元解鎖

### 觀看影片流程 (Video Watching Flow)

1. 使用者點擊影片單元
2. 檢查存取權限（PUBLIC / AUTHENTICATED / PURCHASED）
3. 載入上次觀看位置
4. 播放影片，每 10 秒記錄進度
5. 達到 100% 時狀態變更為 COMPLETED

### 交付任務流程 (Mission Delivery Flow)

1. 檢查任務狀態為 COMPLETED
2. 使用者點擊交付按鈕
3. 狀態變更為 DELIVERED
4. 增加經驗值
5. UI 顯示為綠色（已交付）

---

## 錯誤訊息標準

### 認證錯誤

- **帳號或密碼錯誤**: 登入失敗（帳號不存在或密碼錯誤）
- **使用者名稱已存在**: 註冊時帳號重複
- **使用者名稱或密碼格式無效**: 格式不符合要求
- **未授權或權杖無效**: Token 無效或過期

### 購課錯誤

- **你已經購買此課程**: 重複購買同一課程
- **此為付費內容，請先購買課程**: 未購買嘗試存取付費內容

---

## 資料庫對應表

| 業務術語     | 資料庫表格            | 關鍵欄位                                          |
| ------------ | --------------------- | ------------------------------------------------- |
| 使用者       | users                 | username, password_hash, experience_points, level |
| 帳號         | users                 | username                                          |
| 經驗值       | users                 | experience_points                                 |
| 等級         | users                 | level                                             |
| 旅程         | journeys              | title, slug, description, price, teacher_name     |
| 章節         | chapters              | title, order_index, journey_id                    |
| 任務         | missions              | title, type, access_level, chapter_id             |
| 任務資源     | mission_resources     | resource_type, resource_url, duration_seconds     |
| 任務進度     | user_mission_progress | status, watch_position_seconds                    |
| 獎勵         | rewards               | reward_type, reward_value, mission_id             |
| 訂單         | orders                | order_number, status, price, expired_at           |
| 訂單明細     | order_items           | journey_id, price, order_id                       |
| 課程擁有權   | user_journeys         | user_id, journey_id, purchased_at                 |
| Token 黑名單 | access_tokens         | token_jti, invalidated_at                         |

---

## 同義詞對照表

| 主要術語                    | 同義詞                                 |
| --------------------------- | -------------------------------------- |
| 旅程 (Journey)              | 課程 (Course)                          |
| 任務 (Mission)              | 單元 (Unit)                            |
| 經驗值 (Experience Points)  | 經驗 (Experience)                      |
| 存取 Token (Access Token)   | 權杖 (Token)、JWT                      |
| 任務進度 (Mission Progress) | 使用者任務進度 (User Mission Progress) |
| 課程擁有權 (User Journey)   | 已購買課程 (Purchased Journey)         |
| 帳號 (Username)             | 使用者名稱 (Account)                   |

---

## 使用範例

### 在 DSL Feature 中使用

```gherkin
Scenario: 使用者購買旅程後交付影片任務
  Given 系統中存在一個旅程 "Java 基礎課程"
  And 旅程包含一個章節 "第一章：變數與型別"
  And 章節包含一個影片任務 "認識變數"
  And 使用者 "Alice" 已購買該旅程
  When "Alice" 觀看影片任務達 100%
  Then 任務狀態應變更為 "已完成"
  When "Alice" 點擊交付任務
  Then 任務狀態應變更為 "已交付"
  And "Alice" 的經驗值應增加 100
```

### 在 ISA Feature 中使用

```gherkin
Scenario: Create order for a journey
  Given the database has a user:
    | username   | Alice     |
    | password   | Test1234! |
    | experience | 0         |
  And the database has a journey:
    | title   | Java 基礎課程 |
    | slug    | java-basics  |
    | teacher | 水球老師      |
    | price   | 1999.00      |
  When I send "POST" request to "/orders" with body:
    """
    {
      "journeyId": 1
    }
    """
  Then the response status code should be 201
  And the response body field "status" should equal "UNPAID"
```

---

## 版本歷史

- **v1.0 (2025-12-12)**: 初始版本
  - 涵蓋 Release 1 所有功能（認證、看課、經驗值）
  - 涵蓋 Release 2 購課模組
  - 建立資料庫對應表和同義詞對照表
