# Java E2E 測試基本語法指南

## 目錄

1. [測試結構基礎](#測試結構基礎)
2. [JUnit 5 核心 Annotations](#junit-5-核心-annotations)
3. [REST Assured - Given-When-Then](#rest-assured---given-when-then)
4. [Request 設定](#request-設定)
5. [Response 驗證](#response-驗證)
6. [資料提取 (Extract)](#資料提取-extract)
7. [Hamcrest Matchers](#hamcrest-matchers)
8. [Testcontainers 設定](#testcontainers-設定)
9. [Spring Boot Test](#spring-boot-test)
10. [測試組織與 Helper Methods](#測試組織與-helper-methods)
11. [JdbcTemplate 資料庫驗證](#jdbctemplate-資料庫驗證)
12. [常見測試模式](#常見測試模式)

---

## 測試結構基礎

### 基本測試類別

```java
import org.junit.jupiter.api.Test;
import static io.restassured.RestAssured.given;

class AuthE2ETest extends BaseE2ETest {

  @Test
  void shouldRegisterNewUser() {
    // 測試邏輯
  }
}
```

### 必要 import 語句

```java
// JUnit 5
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;

// REST Assured
import static io.restassured.RestAssured.given;
import io.restassured.http.ContentType;

// Hamcrest Matchers
import static org.hamcrest.Matchers.*;
```

---

## JUnit 5 核心 Annotations

### @Test - 標記測試方法

```java
@Test
void shouldLoginSuccessfully() {
  // 測試邏輯
}
```

### @DisplayName - 測試描述

```java
@Test
@DisplayName("Should successfully register a new user")
void shouldRegisterNewUser() {
  // 中文描述更易讀
}
```

### @BeforeEach - 每個測試前執行

```java
@BeforeEach
void setUp() {
  username = "testuser_" + System.currentTimeMillis();
  userId = registerUser(username, password);
  userToken = loginAndGetToken(username, password);
}
```

### @AfterEach - 每個測試後執行

```java
@AfterEach
void cleanUp() {
  RestAssured.reset();
}
```

### @Nested - 巢狀測試組織

```java
@Nested
@DisplayName("POST /orders")
class CreateOrderTests {

  @Test
  void shouldCreateOrderSuccessfully() {
    // 測試建立訂單
  }

  @Test
  void shouldFailWithInvalidData() {
    // 測試錯誤情境
  }
}
```

---

## REST Assured - Given-When-Then

### 基本結構

```java
given()
    .contentType(ContentType.JSON)  // Given: 設定前置條件
    .body(requestBody)
.when()
    .post("/auth/register")         // When: 執行操作
.then()
    .statusCode(201)                // Then: 驗證結果
    .body("message", equalTo("Registration successful"));
```

### 三個階段說明

- **Given**: 設定請求的前置條件（headers, body, parameters）
- **When**: 執行 HTTP 操作（GET, POST, PUT, DELETE）
- **Then**: 驗證回應結果（status code, body, headers）

---

## Request 設定

### ContentType 設定

```java
given()
    .contentType(ContentType.JSON)  // 設定 Content-Type: application/json
    .body(requestBody)
```

### Request Body - Text Blocks (Java 15+)

```java
String requestBody = """
    {
        "username": "%s",
        "password": "%s"
    }
    """;

given()
    .contentType(ContentType.JSON)
    .body(String.format(requestBody, username, password))
```

### Authorization Header

```java
given()
    .header("Authorization", "Bearer " + token)
    .when()
    .post("/orders")
```

### Path Parameters

```java
given()
    .header("Authorization", bearerToken(token))
    .when()
    .get("/orders/{orderId}", orderId)  // {orderId} 會被替換
```

### Query Parameters

```java
given()
    .header("Authorization", bearerToken(token))
    .queryParam("page", 1)
    .queryParam("size", 10)
    .when()
    .get("/users/{userId}/orders", userId)
```

---

## Response 驗證

### Status Code 驗證

```java
.then()
    .statusCode(201)  // 驗證 HTTP 狀態碼
```

常見狀態碼：

- `200` - OK（成功）
- `201` - Created（建立成功）
- `400` - Bad Request（請求錯誤）
- `401` - Unauthorized（未授權）
- `404` - Not Found（找不到資源）
- `409` - Conflict（衝突，例如重複註冊）

### Body 驗證 - JSONPath

```java
.then()
    .body("message", equalTo("Registration successful"))
    .body("userId", greaterThan(0))
    .body("user.username", equalTo("testuser"))
    .body("items", hasSize(1))
    .body("items[0].price", equalTo(1999.00f))
```

#### JSONPath 語法

- `"message"` - 取得根層級的 message 欄位
- `"user.username"` - 取得巢狀物件的欄位
- `"items[0].price"` - 取得陣列第一個元素的 price 欄位
- `"items"` - 取得整個陣列

---

## 資料提取 (Extract)

### 提取完整 Response

```java
Response response = given()
    .contentType(ContentType.JSON)
    .body(requestBody)
.when()
    .post("/orders")
.then()
    .statusCode(201)
    .extract()
    .response();
```

### 提取特定欄位

```java
// 提取 Long 型別
Long userId = given()
    .contentType(ContentType.JSON)
    .body(requestBody)
.when()
    .post("/auth/register")
.then()
    .statusCode(201)
    .extract()
    .jsonPath()
    .getLong("userId");

// 提取 String 型別
String token = response.jsonPath().getString("accessToken");

// 提取 Integer 型別
Integer orderId = response.jsonPath().getInt("id");
```

### 從 Response 讀取資料

```java
Response response = given().when().get("/orders/{orderId}", orderId)
    .then().statusCode(200).extract().response();

Long createdAt = response.jsonPath().getLong("createdAt");
String orderNumber = response.jsonPath().getString("orderNumber");
```

---

## Hamcrest Matchers

### 基本匹配器

```java
import static org.hamcrest.Matchers.*;

.body("id", notNullValue())              // 不是 null
.body("paidAt", nullValue())             // 是 null
.body("userId", equalTo(1))              // 等於
.body("status", not(equalTo("PAID")))    // 不等於
```

### 數值匹配器

```java
.body("price", greaterThan(0.0f))                 // 大於
.body("price", lessThan(10000.0f))                // 小於
.body("price", greaterThanOrEqualTo(1999.00f))    // 大於等於
.body("price", lessThanOrEqualTo(2999.00f))       // 小於等於
```

### 字串匹配器

```java
.body("error", containsString("已存在"))          // 包含子字串
.body("orderNumber", matchesPattern("\\d{10}"))   // 符合正則表達式
```

### 集合匹配器

```java
.body("items", hasSize(1))                // 陣列大小
.body("items", hasSize(greaterThan(0)))   // 組合使用
.body("status", anyOf(                    // 符合任一條件
    equalTo("UNPAID"),
    equalTo("PAID"),
    equalTo("EXPIRED")
))
```

### 組合使用

```java
assertThat(orderNumber, containsString(userIdStr));
assertThat(orderNumber.length(), greaterThanOrEqualTo(15));
```

---

## Testcontainers 設定

### PostgreSQL Container - Singleton Pattern

```java
import org.testcontainers.containers.PostgreSQLContainer;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public abstract class BaseE2ETest {

  static final PostgreSQLContainer<?> postgres;

  // 使用 static 區塊確保容器只啟動一次
  static {
    @SuppressWarnings("resource")
    PostgreSQLContainer<?> container =
        new PostgreSQLContainer<>("postgres:15-alpine")
            .withDatabaseName("e2e_test")
            .withUsername("test")
            .withPassword("test");
    container.start();
    postgres = container;
  }
}
```

### @SuppressWarnings("resource")

- 作用：抑制「resource 未關閉」的警告
- 原因：Testcontainers 的 Ryuk 機制會自動清理容器，無需手動關閉

### @DynamicPropertySource - 動態配置

```java
@DynamicPropertySource
static void configureProperties(DynamicPropertyRegistry registry) {
  registry.add("spring.datasource.url", postgres::getJdbcUrl);
  registry.add("spring.datasource.username", postgres::getUsername);
  registry.add("spring.datasource.password", postgres::getPassword);
  registry.add("spring.jpa.hibernate.ddl-auto", () -> "validate");
  registry.add("spring.liquibase.enabled", () -> "true");
}
```

**為什麼需要 @DynamicPropertySource？**

- Testcontainers 的 port 是動態分配的（每次啟動不同）
- 無法在 `application.properties` 中寫死連線資訊
- 需要在容器啟動後動態注入配置

---

## Spring Boot Test

### @SpringBootTest - 啟動測試環境

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class OrderE2ETest extends BaseE2ETest {
  // RANDOM_PORT: 使用隨機 port 避免衝突
}
```

### @LocalServerPort - 注入 Port

```java
@LocalServerPort
protected int port;

@BeforeEach
void setUpRestAssured() {
  RestAssured.port = port;
  RestAssured.baseURI = "http://localhost";
}
```

### @Sql - 測試資料管理

```java
@Sql(
    scripts = {"/test-data/cleanup.sql", "/test-data/orders.sql"},
    executionPhase = Sql.ExecutionPhase.BEFORE_TEST_METHOD)
@Sql(
    scripts = "/test-data/cleanup.sql",
    executionPhase = Sql.ExecutionPhase.AFTER_TEST_METHOD)
class OrderE2ETest extends BaseE2ETest {
  // 測試前：清理 + 插入測試資料
  // 測試後：清理
}
```

### @Autowired - 依賴注入

```java
@Autowired
private JdbcTemplate jdbcTemplate;

@Test
void shouldGrantJourneyAccessAfterPayment() {
  Integer count = jdbcTemplate.queryForObject(
      "SELECT COUNT(*) FROM user_journeys WHERE user_id = ?",
      Integer.class,
      userId
  );
}
```

---

## 測試組織與 Helper Methods

### BaseE2ETest 基底類別

```java
public abstract class BaseE2ETest {

  @LocalServerPort
  protected int port;

  @BeforeEach
  void setUpRestAssured() {
    RestAssured.port = port;
    RestAssured.baseURI = "http://localhost";
    RestAssured.enableLoggingOfRequestAndResponseIfValidationFails();
  }

  // Helper methods
  protected String loginAndGetToken(String username, String password) {
    return given()
        .contentType(ContentType.JSON)
        .body(String.format("""
            {"username": "%s", "password": "%s"}
            """, username, password))
        .when().post("/auth/login")
        .then().statusCode(200)
        .extract().jsonPath().getString("accessToken");
  }
}
```

### 測試隔離 - 唯一測試資料

```java
@BeforeEach
void setUp() {
  // 使用時間戳記確保每次測試的使用者名稱唯一
  username = "testuser_" + System.currentTimeMillis();
  userId = registerUser(username, "Test1234!");
  userToken = loginAndGetToken(username, "Test1234!");
}
```

### Helper Method 設計原則

```java
// 1. 使用 protected 讓子類別可存取
protected Long registerUser(String username, String password) {
  return given()
      .contentType(ContentType.JSON)
      .body(String.format("""
          {"username": "%s", "password": "%s"}
          """, username, password))
      .when().post("/auth/register")
      .then().statusCode(201)
      .extract().jsonPath().getLong("userId");
}

// 2. 語意化的方法名稱
protected String bearerToken(String token) {
  return "Bearer " + token;
}
```

---

## JdbcTemplate 資料庫驗證

### queryForObject - 查詢單一結果

```java
@Autowired
private JdbcTemplate jdbcTemplate;

// 查詢數量
Integer count = jdbcTemplate.queryForObject(
    "SELECT COUNT(*) FROM user_journeys WHERE user_id = ? AND journey_id = ?",
    Integer.class,
    userId,
    journeyId
);

assertThat(count, equalTo(1));
```

### update - 修改資料

```java
// 直接修改資料庫（模擬特定狀態）
jdbcTemplate.update(
    "UPDATE orders SET status = 'EXPIRED' WHERE id = ?",
    orderId
);
```

### 參數化查詢

```java
// 使用 ? 作為參數佔位符
jdbcTemplate.queryForObject(
    "SELECT COUNT(*) FROM orders WHERE user_id = ? AND status = ?",
    Integer.class,
    userId,        // 第一個 ?
    "PAID"         // 第二個 ?
);
```

### 何時使用資料庫驗證？

- ✅ 驗證中介表記錄（如 `user_journeys`）
- ✅ 測試需要直接修改資料庫狀態（如模擬訂單過期）
- ❌ 一般業務邏輯應透過 API 驗證

---

## 常見測試模式

### 模式 1: 註冊登入流程

```java
@Test
void shouldLoginAfterRegistration() {
  String username = "testuser_" + System.currentTimeMillis();
  String password = "Test1234!";

  // 1. 註冊
  Long userId = given()
      .contentType(ContentType.JSON)
      .body(String.format("""
          {"username": "%s", "password": "%s"}
          """, username, password))
      .when().post("/auth/register")
      .then().statusCode(201)
      .extract().jsonPath().getLong("userId");

  // 2. 登入
  String token = given()
      .contentType(ContentType.JSON)
      .body(String.format("""
          {"username": "%s", "password": "%s"}
          """, username, password))
      .when().post("/auth/login")
      .then().statusCode(200)
      .extract().jsonPath().getString("accessToken");

  // 3. 使用 token 存取受保護資源
  given()
      .header("Authorization", "Bearer " + token)
      .when().get("/users/{userId}", userId)
      .then().statusCode(200);
}
```

### 模式 2: Bearer Token 認證

```java
// Helper method
protected String bearerToken(String token) {
  return "Bearer " + token;
}

// 使用方式
@Test
void shouldAccessProtectedResource() {
  String token = loginAndGetToken(username, password);

  given()
      .header("Authorization", bearerToken(token))
      .when().post("/orders")
      .then().statusCode(201);
}
```

### 模式 3: 完整流程測試

```java
@Test
@DisplayName("Should complete full purchase flow")
void shouldCompleteFullPurchaseFlow() {
  String requestBody = """{"items": [{"journeyId": 1, "quantity": 1}]}""";

  // Step 1: 建立訂單
  Long orderId = given()
      .header("Authorization", bearerToken(userToken))
      .contentType(ContentType.JSON)
      .body(requestBody)
      .when().post("/orders")
      .then().statusCode(201)
      .body("status", equalTo("UNPAID"))
      .extract().jsonPath().getLong("id");

  // Step 2: 查詢訂單
  given()
      .header("Authorization", bearerToken(userToken))
      .when().get("/orders/{orderId}", orderId)
      .then().statusCode(200)
      .body("status", equalTo("UNPAID"));

  // Step 3: 付款
  given()
      .header("Authorization", bearerToken(userToken))
      .when().post("/orders/{orderId}/action/pay", orderId)
      .then().statusCode(200)
      .body("status", equalTo("PAID"));

  // Step 4: 驗證資料庫
  Integer count = jdbcTemplate.queryForObject(
      "SELECT COUNT(*) FROM user_journeys WHERE user_id = ? AND order_id = ?",
      Integer.class,
      userId,
      orderId
  );
  assertThat(count, equalTo(1));
}
```

### 模式 4: 多使用者測試

```java
@Test
void shouldFailWhenAccessingOthersOrder() {
  // User 1: 建立訂單
  Long orderId = given()
      .header("Authorization", bearerToken(user1Token))
      .contentType(ContentType.JSON)
      .body(requestBody)
      .when().post("/orders")
      .then().statusCode(201)
      .extract().jsonPath().getLong("id");

  // User 2: 嘗試存取 User 1 的訂單
  String user2Username = "testuser2_" + System.currentTimeMillis();
  registerUser(user2Username, "Test1234!");
  String user2Token = loginAndGetToken(user2Username, "Test1234!");

  given()
      .header("Authorization", bearerToken(user2Token))
      .when().get("/orders/{orderId}", orderId)
      .then().statusCode(404);  // 404 而非 403，避免洩漏資源存在性
}
```

### 模式 5: 錯誤情境測試

```java
@Test
@DisplayName("Should fail to register with duplicate username")
void shouldFailToRegisterWithDuplicateUsername() {
  String username = "testuser_" + System.currentTimeMillis();

  // 第一次註冊成功
  registerUser(username, "Test1234!");

  // 第二次註冊應失敗
  given()
      .contentType(ContentType.JSON)
      .body(String.format("""
          {"username": "%s", "password": "%s"}
          """, username, "Test1234!"))
      .when().post("/auth/register")
      .then()
      .statusCode(409)
      .body("error", equalTo("使用者名稱已存在"));
}
```

---

## 最佳實踐總結

### 1. 測試隔離

```java
// ✅ 好：每次測試使用唯一資料
username = "testuser_" + System.currentTimeMillis();

// ❌ 壞：使用固定資料（測試間會互相影響）
username = "testuser";
```

### 2. Helper Methods

```java
// ✅ 好：語意清楚的 helper method
String token = loginAndGetToken(username, password);

// ❌ 壞：重複的測試程式碼
String token = given().contentType(ContentType.JSON)...
```

### 3. 測試組織

```java
// ✅ 好：使用 @Nested 組織相關測試
@Nested
@DisplayName("POST /orders")
class CreateOrderTests {
  // 所有建立訂單的測試
}

@Nested
@DisplayName("GET /orders/{orderId}")
class GetOrderDetailTests {
  // 所有查詢訂單的測試
}
```

### 4. 錯誤訊息驗證

```java
// ✅ 好：驗證錯誤訊息
.then()
    .statusCode(409)
    .body("error", containsString("已存在"));

// ❌ 壞：只驗證狀態碼
.then()
    .statusCode(409);
```

### 5. 資料庫驗證時機

```java
// ✅ 好：驗證中介表或無 API 的資料
Integer count = jdbcTemplate.queryForObject(
    "SELECT COUNT(*) FROM user_journeys WHERE user_id = ?",
    Integer.class, userId
);

// ❌ 壞：應該透過 API 驗證的資料
Integer orderCount = jdbcTemplate.queryForObject(
    "SELECT COUNT(*) FROM orders WHERE user_id = ?",  // 應該用 GET /users/{id}/orders
    Integer.class, userId
);
```

---

## 延伸學習資源

- **REST Assured 官方文件**: https://rest-assured.io/
- **JUnit 5 使用指南**: https://junit.org/junit5/docs/current/user-guide/
- **Hamcrest Matchers**: http://hamcrest.org/JavaHamcrest/
- **Testcontainers**: https://www.testcontainers.org/
- **Spring Boot Testing**: https://docs.spring.io/spring-boot/reference/testing/index.html
