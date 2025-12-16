這份計畫以 「登入功能 (Release-1-Spec 1.2)」 作為 Tracer Bullet（曳光彈/先行驗證指標），並結合你提供的 swagger.yaml 進行具體規劃。請將此文件交給負責實作的工程團隊。

# 規格驅動開發 (Spec-Driven Development) 實作計畫：Phase 1

**目標**：建立從「功能規格 (Problem Domain)」到「自動化測試 (Solution Domain)」的決定性翻譯鏈。
**核心策略**：透過分層架構 (DSL -> ISA -> Execution) 消除 LLM 開發中的不確定性。
**驗證案例**：會員登入功能 (Release 1 - 1.2)

---

## 1. 架構總覽 (Architecture Overview)

我們將測試代碼分為三個抽象層級，每一層都承擔不同的職責：

| 層級   | 名稱                | 職責 (Responsibility)                                            | 來源 (Source of Truth) | 關鍵字範例                                       |
| :----- | :------------------ | :--------------------------------------------------------------- | :--------------------- | :----------------------------------------------- |
| **L1** | **DSL Layer**       | **定義業務行為** (Why & What)<br>不包含任何 HTTP/JSON 技術細節。 | PM Spec / User Story   | `Given 用戶 "Alice" 已註冊`<br>`When 她嘗試登入` |
| **L2** | **ISA Layer**       | **定義介面互動** (How)<br>將業務行為翻譯為具體的 API 請求。      | Swagger / OpenAPI      | `POST /auth/login`<br>`Response 200 OK`          |
| **L3** | **Execution Layer** | **執行** (Action)<br>Java 代碼，負責發送請求與驗證。             | Java Framework         | `RestAssured.given()...`                         |

---

## 2. 實作環境準備 (Prerequisites)

### 2.1 技術堆疊

- **Language**: Java 17+
- **Test Runner**: Cucumber-JVM 7.x
- **HTTP Client**: RestAssured 5.x
- **JSON Processing**: Jackson or Gson
- **DI Container**: Cucumber-PicoContainer (用於在 Step 之間共享 State)

### 2.2 專案結構建議

```text
src/test/
├── resources/
│   ├── features/
│   │   ├── dsl/          # L1: 業務場景 (Human Readable)
│   │   │   └── auth/
│   │   │       └── login.feature
│   │   └── isa/          # L2: 技術場景 (Machine Executable)
│   │       └── auth/
│   │           └── login_implementation.feature
├── java/
│   └── com/waterballsa/
│       ├── steps/
│       │   ├── DslDefinitions.java   # (Optional) 若需直接跑 DSL
│   │   │   └── IsaDefinitions.java   # 核心：通用 API 測試步
│   │   ├── support/
│   │   │   ├── World.java            # 存放 context (response, token)
│   │   │   └── ApiClient.java        # 封裝 RestAssured 設定
```

---

## 3. 實作步驟詳解 (Step-by-Step Guide)

### Step 1: 定義標準化 DSL (The Business Contract)

根據 Release-1-Spec.md 中的「1.2 使用者登入」，撰寫第一個 Feature File。

File: src/test/resources/features/dsl/auth/login.feature

```gherkin
Feature: 使用者登入 (Release 1.2)

  Scenario: 使用者使用正確的帳密登入成功
    # 這裡的詞彙應對應 Domain Glossary
    Given 系統中存在一位用戶 "Alice" 密碼為 "password123"
    When "Alice" 嘗試使用 "password123" 進行登入
    Then 登入應成功
    And 她應該收到一組有效的存取 Token
```

### Step 2: 定義 ISA 映射 (The Implementation Contract)

這是最關鍵的一步。工程師需參考 swagger.yaml 中的 /auth/login 路徑，將上述 DSL 翻譯為技術細節。

Mapping 邏輯 (人工或 AI 輔助):

- DSL When ... 登入 -> Swagger POST /auth/login

- DSL Then ... 成功 -> Swagger 200 OK

File: src/test/resources/features/isa/auth/login_implementation.feature

```gherkin
Feature: 使用者登入_實作層

  Scenario: 使用者使用正確的帳密登入成功_Impl
    # 預置資料 (通常透過直接操作 DB 或 Admin API)
    Given Database has user:
      | username | password    |
      | Alice    | password123 |

    # 對應 swagger: /auth/login
    When Client sends "POST" request to "/auth/login" with body:
      """
      {
        "username": "Alice",
        "password": "password123"
      }
      """

    # 驗證 Response
    Then The response status code should be 200
    And The response body should contain field "token"
    And The response body field "id" should not be null
```

### Step 3: 撰寫 Java 通用執行層 (The Execution Engine)

我們不需要為每個功能寫 Java Code，而是寫一套通用的 API 驅動程式。

File: src/test/java/.../steps/IsaDefinitions.java

```java
public class IsaDefinitions {

    @Autowired
    private World world; // 用於儲存 Response

    @When("Client sends {string} request to {string} with body:")
    public void sendRequest(String method, String endpoint, String body) {
        // 1. 變數替換 (Optional: 處理 {{token}} 等動態變數)
        String finalBody = world.replaceVariables(body);

        // 2. 發送請求
        Response response = RestAssured.given()
                .contentType(ContentType.JSON)
                .body(finalBody)
                .request(method, endpoint);

        // 3. 儲存結果到 Context
        world.setLastResponse(response);
    }

    @Then("The response status code should be {int}")
    public void verifyStatusCode(int expectedCode) {
        world.getLastResponse().then().statusCode(expectedCode);
    }

    @Then("The response body should contain field {string}")
    public void verifyFieldExists(String fieldPath) {
        world.getLastResponse().then().body(fieldPath, notNullValue());
    }
}
```

## 4. 驗收標準 (Definition of Done)

DSL 審閱：PM 或 QA 確認 dsl/login.feature 準確描述了業務需求。

ISA 驗證：工程師確認 isa/login_implementation.feature 的 Payload 符合 swagger.yaml 定義。

測試通過：執行 Cucumber 測試，綠燈通過。

無特定代碼：Java 層中不應該出現 login() 這樣的方法，只應該出現 sendRequest()。這證明了我們建立的是通用的 DSL 執行引擎。

## 5. 未來展望 (Next Phase: Automation)

完成此 Case 後，我們將導入 AI Agent：

Input: Release-Spec.md + Domain Glossary -> AI Agent -> Output: DSL Gherkin.

Input: DSL Gherkin + swagger.yaml -> AI Agent -> Output: ISA Gherkin.

現在，請依照此計畫手動實作 User Login，以打通整條路徑。
