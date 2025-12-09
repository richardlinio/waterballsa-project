# API 設計面試題解答 - WaterballSA 課程平台

## Junior Level (基礎題 1-10)

### 1. [Junior] RESTful 資源設計

這種設計主要符合 RESTful 的幾個核心原則:

首先是**資源導向**,URL 用 `/journeys` 這種名詞來表達資源,而不是 `/getJourneys` 這種動詞。在 REST 的世界裡,我們操作的是「資源」本身,HTTP 方法已經說明了動作,所以 URL 不需要再重複描述動作。

第二個是**階層式結構**,`/journeys/{journeyId}` 清楚表達了「某一個特定的 journey」這種資源關係,這樣的路徑設計讓 API 的結構一看就懂。

相比之下,`/getJourneys` 的問題在於把動作寫進 URL,違反了 REST 的資源導向原則,而且擴展性很差 —— 如果未來要新增、修改、刪除課程,是不是要再加 `/createJourney`、`/updateJourney` 這些端點?這樣會讓 API 變得很亂。

至於 `/journey/detail?id=1` 雖然可以用,但 `detail` 這個詞是多餘的,而且用 query parameter 來指定唯一資源不如直接用路徑參數來得直觀。RESTful 的設計讓你一看到 `/journeys/1`,就知道這是「編號 1 的課程」,語意非常清楚。

---

### 2. [Junior] HTTP 方法選擇

這個設計的核心差異在於操作的**冪等性**和**語意**。

「更新進度」用 PUT 是因為它是一個**冪等操作** —— 不管你呼叫幾次 `PUT /users/{userId}/missions/{missionId}/progress`,傳送 `watchPositionSeconds: 150`,結果都一樣,進度就是設定在 150 秒。而且這個 API 實作了 Upsert 語意(不存在就建立,存在就更新),這跟 PUT 的「完整替換資源」語意很吻合。

「交付任務」用 POST 是因為它是一個**非冪等的動作** —— 理論上交付任務應該要改變系統狀態(發放經驗值、更改狀態為 DELIVERED),而且語意上這是「觸發一個動作」而不是「更新資源狀態」。雖然在我們的實作中有防呆機制(重複交付會回傳 409),但本質上 deliver 這個動作帶有「副作用」,用 POST 是最恰當的。

簡單來說,PUT 適合用在「設定資源為某個狀態」,POST 適合用在「執行某個動作」。

---

### 3. [Junior] HTTP 狀態碼理解

**第一個問題：為什麼註冊用 201 而登入用 200？**

註冊(`POST /auth/register`)回傳 201 是因為它**建立了新資源** —— 一個全新的使用者帳號被創建在系統中,201 Created 的語意就是「成功建立新資源」,而且通常 201 會回傳新資源的識別碼(我們的 API 回傳了 `userId`)。

登入(`POST /auth/login`)回傳 200 是因為它**沒有建立新資源**,只是驗證身份並回傳 Token。登入是「查詢+驗證」操作,你的帳號早就存在了,這次請求只是確認身份,所以用 200 OK 就夠了。

**第二個問題：為什麼建立訂單有時候回傳 200？**

正常情況下,`POST /orders` 建立新訂單當然是回傳 201。但如果使用者**已經有該課程的未付款訂單**,系統不會再建立新訂單,而是直接回傳現有訂單,這時候用 200 是因為「沒有建立新資源」,只是把既有的訂單資料給你而已。

這是一種冪等性設計 —— 避免同一個使用者對同一門課重複建立多個未付款訂單,造成訂單管理的混亂。

---

### 4. [Junior] 認證機制基礎

**1. 什麼是 JWT？它與 Session-Cookie 有什麼不同？**

JWT(JSON Web Token)是一種基於 Token 的認證方式,它把使用者資訊(像是 userId、username)編碼後簽名成一個字串,這個 Token 本身就包含了身份資訊,後端收到 Token 後只需要驗證簽名就能知道是誰,不需要去資料庫查。

傳統的 Session-Cookie 機制則是在後端儲存使用者的 Session 資料(通常在記憶體或 Redis),前端只拿到一個 Session ID,每次請求時後端要用這個 ID 去查使用者是誰。

最大的差別是 JWT 是**無狀態(stateless)**的,後端不需要儲存 Session;而 Session-Cookie 是**有狀態(stateful)**的,後端要維護 Session 資料。JWT 特別適合單一伺服器或多伺服器架構,因為不用擔心 Session 要在哪一台機器上。

**2. 為什麼前端需要在每次請求時將 Token 放在 Authorization Header 中？**

因為 HTTP 是無狀態協定,每次請求都是獨立的,後端不會記得「上一次請求是誰發的」。所以前端每次呼叫需要認證的 API 時,都要帶上 Token 來證明身份。

`Authorization: Bearer <token>` 是一種標準格式,`Bearer` 表示「持有者認證」,意思是「誰拿到這個 Token,誰就有權限」。後端收到 Header 後,會解析並驗證 Token,確認請求來自有效的使用者。

---

### 5. [Junior] 路徑參數 vs 查詢參數

路徑參數(Path Parameter)用來表達**資源的唯一識別**,像是 `/journeys/{journeyId}` 中的 `journeyId`,它描述的是「我要取得哪一個 journey」,是資源定位的一部分。

查詢參數(Query Parameter)用來表達**篩選、排序、分頁**這類輔助功能,像是 `?page=1&limit=20`,它們不影響「我要存取哪個資源」,而是影響「怎麼呈現這個資源」。

舉個例子,`GET /users/{userId}/orders` 的 `userId` 是路徑參數,因為它定義了「我要看哪個使用者的訂單」;而 `page` 和 `limit` 是查詢參數,因為無論怎麼設定,我都是在看「這個使用者的訂單」,只是看第幾頁而已。

判斷原則很簡單：

- **必填、唯一定位資源** → 用路徑參數
- **選填、過濾或調整回應** → 用查詢參數

如果把 `/journeys/{journeyId}` 改成 `/journeys?id=1`,雖然功能一樣,但語意就不夠清楚,而且這樣設計會讓人困惑：「那我不傳 id 參數的話會發生什麼？」

---

### 6. [Junior] 必填與選填欄位

**1. 如何決定哪些欄位應該必填、哪些應該選填？**

判斷原則很簡單：**業務邏輯上不能沒有的資訊就是必填**。

以建立訂單為例,`journeyId` 是必填,因為如果不知道要買哪門課,根本無法建立訂單。`items` 陣列也是必填,因為沒有項目的訂單沒有意義。

而 `quantity` 設計成選填(預設值 1)是因為在我們的 MVP 範圍內,一個訂單只能包含一門課,數量永遠是 1,使用者不太會去改這個值,所以讓它有預設值會更方便。

選填欄位通常是那些「有合理預設值」或「可以稍後補充」的資訊,像是分頁的 `page` 和 `limit` 參數,如果不傳就用預設值(page=1, limit=20),不影響 API 的基本功能。

**2. 選填欄位使用預設值有什麼好處？**

最直接的好處是**降低前端的使用成本**。想像一下,如果 `quantity` 是必填,前端每次建立訂單都要寫:

```json
{
	"items": [{ "journeyId": 17, "quantity": 1 }]
}
```

有預設值的話,前端可以簡化成:

```json
{
	"items": [{ "journeyId": 17 }]
}
```

這種設計遵循「**慣例優於配置(Convention over Configuration)**」的原則 —— 大部分情況下都用預設值就好,只有特殊需求才需要明確指定。這樣的 API 更簡潔,也更不容易出錯。

---

### 7. [Junior] 錯誤回應結構

**1. 為什麼需要統一的錯誤回應格式？**

統一的錯誤格式讓前端可以用**同一套邏輯來處理所有錯誤**,不用每個 API 都寫不同的錯誤處理。

舉例來說,如果所有錯誤都是 `{ "error": "錯誤訊息" }` 格式,前端可以寫一個統一的錯誤處理函數:

```javascript
if (!response.ok) {
	const errorData = await response.json()
	alert(errorData.error) // 顯示錯誤訊息
}
```

如果每個 API 的錯誤格式都不同(有的叫 `error`,有的叫 `message`,有的叫 `errorMessage`),前端就要針對每個 API 寫不同的處理邏輯,維護成本會非常高。

**2. 除了 error 欄位,還可以加入哪些資訊？**

實務上可以加入這些欄位讓錯誤處理更完善:

- **錯誤代碼(errorCode)**：像是 `"INVALID_CREDENTIALS"` 或 `"ORDER_EXPIRED"`,讓前端可以針對不同錯誤類型做不同處理,而不是只能解析文字訊息。

- **欄位驗證錯誤(fieldErrors)**：當使用者填寫表單有多個欄位不合法時,可以回傳像這樣的結構:

  ```json
  {
  	"error": "驗證失敗",
  	"fieldErrors": {
  		"username": "使用者名稱不可為空",
  		"password": "密碼長度至少 8 個字元"
  	}
  }
  ```

  這樣前端可以在對應的輸入框下方顯示錯誤訊息。

- **時間戳記(timestamp)** 或 **請求 ID(requestId)**：方便追蹤和除錯。

---

### 8. [Junior] 認證 vs 授權

**情境 1：使用者未提供 JWT Token → 回傳 401 Unauthorized**

這是**認證(Authentication)失敗**,後端不知道你是誰,因為你沒有提供身份證明。401 的語意就是「你需要先登入」。

**情境 2：使用者已登入,但嘗試查看其他使用者的進度 → 回傳 403 Forbidden**

這是**授權(Authorization)失敗**,後端知道你是誰(因為 JWT 有效),但你沒有權限執行這個操作。403 的語意是「我知道你是誰,但你不能做這件事」。

**簡單區分：**

- **401 (Unauthorized)**：「你是誰？我不認識你,請先登入。」(認證問題)
- **403 (Forbidden)**：「我知道你是誰,但你不能這樣做。」(授權問題)

一個常見的誤解是把 401 翻譯成「未授權」,但其實 401 的英文 Unauthorized 在 HTTP 規範中指的是「未認證(Unauthenticated)」。真正的「未授權」應該用 403。

---

### 9. [Junior] 巢狀資源路徑

**1. 這種巢狀路徑設計表達了什麼樣的資源關係？**

`GET /journeys/{journeyId}/missions/{missionId}` 這種設計清楚表達了**資源的從屬關係**：Mission 屬於 Journey,是 Journey 底下的子資源。

這個路徑在說：「我要取得某個 Journey 底下的某個 Mission」。這樣的設計讓 API 的語意非常直觀,一看到 URL 就知道資源之間的關係。

**2. 相較於 `/missions/{missionId}`,巢狀路徑有什麼優缺點？**

**優點：**

- **語意清楚**：一看就知道 Mission 是 Journey 的一部分
- **自動驗證關係**：後端可以順便檢查「這個 missionId 是否真的屬於這個 journeyId」,提供額外的安全性
- **符合業務邏輯**：很多時候使用者就是在「某門課的脈絡下」查看任務,這個路徑符合使用情境

**缺點：**

- **URL 較長**：如果資源層級很深,URL 會變很長(但我們這邊只有兩層,還好)
- **彈性較低**：如果 Mission 可以獨立存在或屬於多個 Journey,這種設計就不適合了

在我們的案例中,Mission 確實是屬於特定 Journey 的,所以巢狀路徑是合理的設計。

---

### 10. [Junior] 時間戳格式

**1. 為什麼 API 通常使用 Unix Timestamp 而不是 ISO 8601？**

主要有幾個實務上的考量:

**更簡潔**：Unix Timestamp 是一個數字(`1732420800000`),ISO 8601 是一串字串(`"2023-11-24T10:00:00Z"`),數字在 JSON 中更節省空間,傳輸效率更高。

**不用處理時區**：Unix Timestamp 是基於 UTC 的絕對時間,不會有時區混亂的問題。ISO 8601 雖然也可以包含時區資訊,但要小心處理 `+08:00`、`Z` 這些標記。

**方便計算**：數字可以直接做加減運算,計算時間差異很方便。ISO 8601 要先解析成時間物件才能計算。

**與資料庫對接容易**：很多資料庫(如 PostgreSQL 的 `BIGINT`)和後端語言都用 timestamp 儲存時間,直接回傳數字不用轉換。

不過 ISO 8601 也有優點 —— 它**人類可讀**,適合除錯和 log 記錄。實務上有些 API 會兩種都提供,或是讓客戶端選擇。

**2. 前端收到這種格式的時間資料後,通常如何處理？**

前端通常會用 JavaScript 的 `Date` 物件來處理:

```javascript
const timestamp = 1732420800000
const date = new Date(timestamp)

// 格式化顯示給使用者看
date.toLocaleString('zh-TW') // "2023/11/24 上午10:00:00"

// 或使用第三方套件如 date-fns, dayjs
format(date, 'yyyy-MM-dd HH:mm') // "2023-11-24 10:00"
```

前端拿到 timestamp 之後,可以根據使用者的時區和偏好來格式化顯示,這樣的彈性比直接給固定格式的字串好很多。

---

## Mid-level (進階題 11-30)

### 11. [Mid-level] 速率限制的錯誤訊息設計

**1. 為什麼要隱藏速率限制的真實原因？**

這是一個**安全性考量**。如果你告訴攻擊者「你已經觸發速率限制」,等於間接告訴他「你的暴力破解攻擊被偵測到了」,這會讓他調整攻擊策略 —— 比如降低嘗試頻率、換 IP、或使用分散式攻擊。

當攻擊者看到「使用者名稱或密碼無效」這個訊息時,他不知道是真的密碼錯了,還是被速率限制了,這種**不確定性**會大大提高攻擊成本。

**2. 這種設計在安全性上有什麼好處？**

主要是**防止資訊洩漏(Information Disclosure)**。如果回傳「速率限制已觸發,請 15 分鐘後再試」,攻擊者會知道:

- 系統有速率限制機制
- 限制的時間窗口是 15 分鐘
- 限制是基於 IP 的

有了這些資訊,攻擊者可以精準地規避防禦機制。隱藏這些細節可以讓攻擊者摸不透後端的防禦策略。

**3. 這種設計對使用者體驗有什麼影響？如何平衡？**

這是個兩難的問題。對於**正常使用者**來說,如果真的不小心輸錯密碼太多次,看到「密碼錯誤」會覺得困惑 —— 明明我現在輸對了,為什麼還是不能登入？

實務上可以這樣平衡:

- **第 1-5 次失敗**：正常回傳「使用者名稱或密碼無效」
- **第 6 次以上**：改回傳「登入失敗次數過多,請稍後再試」(這時候已經很明顯是異常行為了)
- **搭配前端提示**：在登入頁面加上「連續失敗 5 次將暫時鎖定 15 分鐘」的說明

或者提供「忘記密碼」的流程,讓使用者有其他解決方案,而不是一直嘗試登入。

---

### 12. [Mid-level] Token 黑名單機制

**1. 為什麼需要 Token 黑名單？JWT 不是無狀態的嗎？**

這是 JWT 的一個**經典矛盾**。理論上,JWT 是無狀態的 —— Token 本身包含所有資訊,後端不需要儲存任何狀態。但這也帶來一個問題：**一旦 Token 簽發出去,後端就無法主動讓它失效**。

如果沒有黑名單機制,使用者點「登出」之後,前端雖然刪除了 Token,但這個 Token 在過期之前仍然是有效的。如果有人在登出前複製了這個 Token,他還是可以繼續使用,直到 Token 過期(我們的專案是 1 天)。

所以我們需要黑名單來儲存「已登出的 Token」,讓後端在驗證 Token 時額外檢查「這個 Token 有沒有被登出」。這是在無狀態和安全性之間的一個取捨。

**2. 如果不實作黑名單,使用者登出後會有什麼安全性問題？**

最大的風險是 **Token 竊取攻擊**。假設:

1. 使用者在公用電腦登入
2. 有人偷偷記錄了他的 Token
3. 使用者以為點了「登出」就安全了
4. 但其實那個 Token 還有效,攻擊者可以繼續使用 23 小時

另一個情境是**帳號安全事件** —— 使用者發現帳號被盜,立刻登出並改密碼,但如果沒有黑名單,駭客手上的 Token 還是有效的,改密碼也沒用。

**3. Token 黑名單表需要建立哪些索引？**

最關鍵的是 **token 欄位的索引**,因為每次請求都要查詢「這個 token 是否在黑名單中」:

```sql
CREATE INDEX idx_access_tokens_token ON access_tokens(token);
```

另外,為了**自動清理過期 Token**,可以對 `expired_at` 建立索引:

```sql
CREATE INDEX idx_access_tokens_expired_at ON access_tokens(expired_at);
```

這樣定期執行清理任務時(比如 `DELETE FROM access_tokens WHERE expired_at < NOW()`)會更有效率。

---

### 13. [Mid-level] 登出 API 的必要性

**1. 前端登出 vs 後端登出有什麼差異？**

**前端登出**只是把 Token 從 localStorage 或 cookie 刪除,但 Token 本身還是有效的 —— 如果有人在刪除之前複製了 Token,他還是可以使用。

**後端登出**則是真正把 Token 加入黑名單,讓這個 Token 從此失效,即使有人持有這個 Token 也無法使用。

簡單來說,前端登出是「我不要這個鑰匙了」,後端登出是「把這把鑰匙作廢,讓它永遠打不開門」。

**2. 在什麼情境下,單純前端刪除 Token 是不夠安全的？**

最明顯的例子是:

- **公用電腦/共享裝置**：離開前一定要確保 Token 真的失效
- **Token 外洩**：如果懷疑 Token 被竊取,前端刪除沒有用,必須後端作廢
- **強制登出**：公司要求員工離職時立刻登出所有裝置,前端無法控制
- **帳號被盜**：使用者發現異常登入,想要立刻讓所有現存的 Token 失效

**3. 如果使用者在多個裝置登入,後端登出 API 應該如何設計？**

可以提供兩種登出選項:

**單裝置登出**：只讓「目前這個 Token」失效

```
POST /auth/logout
Authorization: Bearer <current-token>
→ 只把這個 token 加入黑名單
```

**全裝置登出**：讓「這個使用者的所有 Token」失效

```
POST /auth/logout-all
Authorization: Bearer <any-valid-token>
→ 查詢這個 userId 的所有 active tokens,全部加入黑名單
```

這需要在 `access_tokens` 表中記錄 `user_id`,這樣才能追蹤「某個使用者有哪些有效 Token」。實務上很多 App 的「帳號安全」頁面都有「登出所有裝置」的功能,就是這個概念。

---

### 14. [Mid-level] JWT 過期時間的權衡

**1. Token 有效期設定過長和過短各有什麼問題？**

**過長(如 30 天)的問題：**

- **安全風險高**：Token 被竊取後,攻擊者有 30 天的時間可以使用
- **黑名單負擔大**：登出後,黑名單要保存這個 Token 資料 30 天
- **權限變更延遲**：使用者被停權或角色改變,要 30 天後才生效(除非強制登出)

**過短(如 15 分鐘)的問題：**

- **使用者體驗差**：使用者每 15 分鐘就要重新登入一次,非常惱人
- **請求量增加**：頻繁的重新登入會增加後端負擔

**2. 你會建議什麼樣的有效期限？**

要看使用場景:

- **高安全性系統**(如銀行 App)：短一點,比如 1-2 小時
- **一般內容平台**(如學習平台)：1 天是合理的,平衡安全性和體驗
- **低敏感系統**(如新聞網站)：可以長一點,比如 7 天

我們的專案(學習平台)設定 **1 天**是合理的 —— 使用者通常不會跨日連續使用,每天重新登入一次不會太麻煩,但也不會頻繁到干擾學習。

**3. 「Access Token + Refresh Token」雙 Token 機制如何解決這個問題？**

這是目前業界最常見的解決方案:

- **Access Token**：短期有效(如 15 分鐘),用於日常 API 請求
- **Refresh Token**：長期有效(如 30 天),只用於「更新 Access Token」

流程是這樣的:

1. 使用者登入,拿到 Access Token(15 分鐘) + Refresh Token(30 天)
2. 前端用 Access Token 呼叫 API
3. Access Token 過期後,用 Refresh Token 呼叫 `/auth/refresh` 取得新的 Access Token
4. Refresh Token 不用每次請求都帶,只在需要更新時才用

這樣的好處是:

- **安全性高**：日常使用的 Access Token 很短,即使被竊取影響也小
- **體驗好**：Refresh Token 很長,使用者不用頻繁登入
- **易於控管**：登出時只要讓 Refresh Token 失效,所有 Access Token 自然無法更新

---

### 15. [Mid-level] 訂單編號生成規則

**1. 為什麼不使用單純的流水號或 UUID？**

**流水號(1, 2, 3...)**的問題:

- **資訊洩漏**：別人一看到訂單編號 1234567,就知道你的平台總共有 123 萬筆訂單,這是商業機密
- **容易猜測**：攻擊者可以遍歷所有訂單編號,嘗試存取其他人的訂單
- **分散式問題**：如果未來要多台伺服器生成訂單,流水號會衝突

**UUID** 的問題:

- **太長不好記**：`550e8400-e29b-41d4-a716-446655440000` 這種格式使用者完全記不住
- **不包含業務資訊**：看到 UUID 完全不知道這是什麼時候、誰的訂單
- **資料庫索引效率低**：UUID 是隨機的,B-tree 索引效能不好

我們的設計 `{timestamp}{userId}{randomCode}` 結合了兩者的優點:

- 包含時間資訊,方便排序和除錯
- 包含使用者 ID,方便客服快速定位
- 有隨機碼,避免被猜測

**2. 將 userId 包含在訂單編號中有什麼好處和風險？**

**好處：**

- **快速查詢**：客服看到訂單編號,不用查資料庫就知道是哪個使用者的
- **分散式友好**：不同使用者的訂單編號不會衝突
- **方便分表**：未來可以根據 userId 做訂單分表(sharding)

**風險：**

- **隱私問題**：訂單編號暴露了使用者 ID,雖然影響不大,但還是有些資訊洩漏
- **可預測性**：如果隨機碼不夠隨機,攻擊者可能猜出其他人的訂單編號

實務上這個風險是可接受的,因為:

1. 後端有權限檢查,猜到訂單編號也看不了別人的訂單
2. 隨機碼提供了足夠的熵(entropy)

**3. 這種格式能否保證訂單編號的唯一性？如何改進？**

**理論上不能 100% 保證**,因為:

- 如果兩個請求在「同一毫秒」、「同一個 userId」、且「隨機碼剛好一樣」,就會重複
- 雖然機率極低,但在高併發情境下還是可能發生

**改進方法：**

1. **資料庫層級保證**：對 `order_number` 欄位加上 `UNIQUE` 約束,如果重複就重試生成

   ```sql
   ALTER TABLE orders ADD CONSTRAINT uk_order_number UNIQUE (order_number);
   ```

2. **增加隨機碼長度**：目前是 5 位 16 進制(`17cd5`),可以增加到 8-10 位,降低碰撞機率

3. **使用 Snowflake 演算法**：業界常用的分散式 ID 生成方案,保證全域唯一且遞增

4. **加入機器 ID**：如果有多台伺服器,在編號中加入機器 ID,確保不同機器不會衝突

---

### 16. [Mid-level] 價格快照機制

**1. 為什麼需要價格快照機制？直接關聯到 journeys.price 有什麼問題？**

價格快照最重要的目的是**保持訂單的不可變性（Immutability）**。想像一個情境：

- 使用者 11/20 建立訂單，當時課程價格是 7599 元
- 11/25 平台決定漲價到 9999 元
- 使用者 11/26 回來查看自己的訂單歷史

如果訂單直接關聯到 `journeys.price`，使用者看到的價格會變成 9999 元，但他明明當初看到的是 7599 元！這會造成:

- **糾紛和客訴**：「為什麼我訂單金額變了？」
- **法律問題**：訂單是合約，價格不能事後改變
- **會計混亂**：財務報表對不上帳

所以我們在建立訂單時，把 `journeys.price` **快照（複製）** 到 `order_items.originalPrice`，從此這個價格就固定了，不受課程後續調價影響。

**2. 這種設計屬於「正規化」還是「反正規化」？**

這是典型的**反正規化（Denormalization）**設計。

正規化的原則是「不要儲存重複資料」，應該只在 `journeys` 表存價格，其他地方用外鍵關聯。但我們刻意在 `order_items` 中**重複儲存**了價格資訊。

這是一個經典的權衡：

- **犧牲：** 資料重複，儲存空間增加
- **換取：** 查詢效率（不用每次都 JOIN journeys 表）、資料一致性（訂單價格不會變）、業務正確性（符合訂單的不可變特性）

在訂單系統中，反正規化幾乎是必須的，因為訂單的「歷史準確性」比「節省空間」重要太多了。

**3. 如果未來需要支援「訂單建立後課程降價，使用者要求退差價」功能，這個設計是否足夠？**

現有設計**基本足夠**，但需要增加一些欄位來記錄退款歷史。

目前的欄位已經可以支援基本邏輯：

- `order_items.originalPrice`：當初購買時的價格（7599）
- 去查詢 `journeys.price`：目前的價格（如 6999）
- 計算差價：7599 - 6999 = 600 元

但為了完整支援這個功能，建議增加：

1. **訂單層級增加欄位：**

   - `refundAmount`：已退款金額
   - `refundReason`：退款原因（如 "價格調整補償"）
   - `refundAt`：退款時間

2. **或者建立專門的退款表：**
   ```sql
   CREATE TABLE order_refunds (
     id SERIAL PRIMARY KEY,
     order_id INT NOT NULL,
     refund_amount DECIMAL(10, 2),
     reason VARCHAR(255),
     refunded_at TIMESTAMP,
     FOREIGN KEY (order_id) REFERENCES orders(id)
   );
   ```

這樣就可以完整追蹤「哪些訂單退過差價」、「退了多少」，而且不影響原本的訂單資料。

---

### 17. [Mid-level] 訂單狀態管理

**1. 訂單狀態轉換的有限狀態機（FSM），哪些狀態之間可以轉換？**

訂單有三種狀態：`UNPAID`、`PAID`、`EXPIRED`。合法的狀態轉換如下：

```
     [建立訂單]
         ↓
     UNPAID ───────→ PAID (使用者付款)
         ↓
      EXPIRED (3 天後自動過期)
```

**允許的轉換：**

- `UNPAID → PAID`：使用者完成付款
- `UNPAID → EXPIRED`：3 天內未付款，系統自動標記過期

**不允許的轉換（都是非法操作）：**

- `PAID → UNPAID`：已付款不能退回未付款（要退款的話應該另外處理）
- `PAID → EXPIRED`：已付款的訂單永遠不會過期
- `EXPIRED → PAID`：過期訂單不能付款（使用者要重新建立新訂單）
- `EXPIRED → UNPAID`：過期不能變回未付款

這是一個**單向、不可逆**的狀態機，一旦進入 `PAID` 或 `EXPIRED` 就是最終狀態（Terminal State）。

**2. 付款 API 應該檢查哪些前置條件（Preconditions）？**

`POST /orders/{orderId}/action/pay` 在執行付款前應該檢查：

1. **訂單存在性**：orderId 對應的訂單是否存在？（不存在 → 404）
2. **權限檢查**：JWT 中的 userId 是否等於訂單的 userId？（不是 → 404，不用 403 避免資訊洩漏）
3. **訂單狀態**：
   - 如果狀態是 `PAID` → 回傳 `409 Conflict` + "訂單已付款"
   - 如果狀態是 `EXPIRED` → 回傳 `409 Conflict` + "訂單已過期"
   - 只有 `UNPAID` 才能繼續付款
4. **價格驗證**（可選但建議）：確認訂單金額 > 0

**3. 如果使用者嘗試支付已過期的訂單，API 應該回傳什麼狀態碼和錯誤訊息？**

應該回傳：

- **狀態碼：** `409 Conflict`
- **錯誤訊息：** `"訂單已過期"`

為什麼是 409 而不是 400？

- **400 Bad Request**：用於「請求格式錯誤」，比如缺少必填欄位、資料格式不對
- **409 Conflict**：用於「請求本身沒問題，但和資源的當前狀態衝突」

「訂單已過期」是資源狀態的問題，不是請求格式的問題，所以用 409 更準確。這告訴前端：「你的請求格式是對的，但這個訂單的狀態不允許付款」。

---

### 18. [Mid-level] 重複購買檢查

**1. 為什麼已購買回傳 409，而已有未付款訂單回傳 200？**

這兩種情況的**語意完全不同**：

**已購買（回傳 409）：**
這是一個**真正的衝突** —— 使用者已經擁有這門課了，再建立訂單是不合理的操作。409 告訴前端：「你的請求被拒絕了，因為使用者已經買過這門課」。前端應該顯示「你已經購買此課程」並導向課程頁面。

**已有未付款訂單（回傳 200）：**
這**不是錯誤，而是正常的業務邏輯** —— 使用者可能剛才建立了訂單但還沒付款，現在又點了一次「購買」按鈕。我們不希望為同一門課建立多個未付款訂單，所以直接回傳現有的訂單。

200 表示「請求成功」，前端拿到訂單資料後，可以直接導向付款頁面。從使用者體驗來看，他點了「購買」，系統給了他一個「可以付款的訂單」，這就是成功的結果。

**2. 「回傳現有訂單」是一種冪等性設計嗎？**

是的！這是一個非常好的**冪等性（Idempotency）設計**。

冪等性的定義是：**多次執行同一個操作，結果和執行一次一樣**。

在這個設計中：

- 第 1 次呼叫 `POST /orders`（課程 ID = 17）→ 建立新訂單，回傳訂單 A
- 第 2 次呼叫 `POST /orders`（課程 ID = 17）→ 不建立新訂單，回傳訂單 A
- 第 3 次呼叫 `POST /orders`（課程 ID = 17）→ 還是回傳訂單 A

**好處：**

- **防止重複提交**：使用者快速點擊兩次「購買」按鈕，不會建立兩個訂單
- **前端簡化**：前端不用擔心重複請求，反正拿到的都是同一個訂單
- **資料乾淨**：避免大量未付款的重複訂單

**3. 如果未來要支援「重複購買送給別人」功能，API 設計需要如何調整？**

需要在建立訂單時增加一個欄位來表達「這個訂單是給誰的」：

```json
POST /orders
{
  "items": [{ "journeyId": 17 }],
  "recipientUserId": 25  // 新增：接收者的 userId（選填）
}
```

**邏輯調整：**

1. **如果沒有提供 recipientUserId**（或等於自己的 userId）：

   - 檢查「自己是否已購買」→ 已購買則回傳 409
   - 檢查「自己是否有未付款訂單」→ 有則回傳現有訂單

2. **如果提供了 recipientUserId（送給別人）**：
   - **不檢查**接收者是否已購買（因為這是禮物，可能就是要送已經有的課程）
   - 每次都建立新訂單（因為可能要送給不同人）
   - 訂單上標記 `recipient_user_id`，付款後把課程授權給接收者而不是購買者

這樣設計可以保持向後相容，現有的「自己購買」邏輯不受影響。

---

### 19. [Mid-level] PUT 方法的 Upsert 語意

**1. 為什麼「更新進度」適合使用 PUT 搭配 Upsert 語意？**

因為**進度這個資源的特性**很適合 PUT 的語意。

PUT 的標準定義是：「把資源設定為某個狀態」。對於進度來說：

- 使用者看影片到 150 秒 → 我要把進度設定為 150 秒
- 使用者繼續看到 200 秒 → 我要把進度設定為 200 秒

注意，不是「增加 50 秒」，而是「設定為 200 秒」。這就是 PUT 的語意。

如果分開設計成 POST（建立）+ PATCH（更新），會有幾個問題：

- **前端不知道該呼叫哪個 API**：第一次呼叫 POST，後續呼叫 PATCH？那前端要怎麼判斷「是不是第一次」？
- **增加複雜度**：要維護兩個端點，邏輯其實差不多
- **容易出錯**：如果前端誤判，用 POST 建立重複記錄就麻煩了

用 PUT + Upsert，前端完全不用管「進度存不存在」，反正每次都呼叫 `PUT /users/{userId}/missions/{missionId}/progress`，後端自動處理：不存在就建立，存在就更新。

**2. Upsert 操作的冪等性是什麼？多次呼叫相同的 PUT 請求會有什麼結果？**

Upsert 是**完全冪等**的。

假設我多次呼叫：

```
PUT /users/1/missions/5/progress
{ "watchPositionSeconds": 150 }
```

結果：

- 第 1 次：進度設定為 150 秒（不存在就建立）
- 第 2 次：進度設定為 150 秒（存在就更新，但值沒變）
- 第 3 次：進度還是 150 秒

**最終狀態永遠一樣**，這就是冪等性。

這對前端非常友善，因為：

- 網路不穩時可以重試，不用擔心重複請求造成問題
- 即使使用者倒轉影片，也沒關係，PUT 會把進度改回正確的值

**3. 在資料庫層級，如何實作 Upsert？**

PostgreSQL 提供了 `INSERT ... ON CONFLICT` 語法：

```sql
INSERT INTO user_mission_progress (user_id, mission_id, watch_position_seconds, status)
VALUES (1, 5, 150, 'UNCOMPLETED')
ON CONFLICT (user_id, mission_id)  -- 如果 user_id + mission_id 已經存在
DO UPDATE SET
  watch_position_seconds = EXCLUDED.watch_position_seconds,
  status = CASE
    WHEN EXCLUDED.watch_position_seconds >= (SELECT duration_seconds FROM missions WHERE id = 5)
    THEN 'COMPLETED'
    ELSE 'UNCOMPLETED'
  END,
  updated_at = CURRENT_TIMESTAMP;
```

**關鍵：**

- `ON CONFLICT (user_id, mission_id)`：需要在這兩個欄位上建立 **UNIQUE 約束**或複合主鍵
- `EXCLUDED`：代表「你想插入的新值」
- 如果沒有衝突，執行 INSERT；如果有衝突，執行 UPDATE

Spring Data JPA 中可以用：

```java
@Transactional
public void upsertProgress(Long userId, Long missionId, Integer watchPosition) {
    Optional<UserMissionProgress> existing = repository.findByUserIdAndMissionId(userId, missionId);
    if (existing.isPresent()) {
        // 更新
        existing.get().setWatchPositionSeconds(watchPosition);
    } else {
        // 建立
        repository.save(new UserMissionProgress(userId, missionId, watchPosition));
    }
}
```

但效能最好的方式還是直接用原生 SQL 的 `ON CONFLICT`，一條語句完成，避免額外的 SELECT 查詢。

---

### 20. [Mid-level] 進度更新頻率設計

**1. 為什麼選擇 10 秒而不是即時更新（每秒）或更長間隔（每分鐘）？**

這是在**精確度、使用者體驗、後端負擔**三者之間取得平衡：

**如果每秒更新（即時）：**

- 優點：進度非常精確
- 缺點：
  - 後端負擔太重，1000 名學生同時看影片 = 每秒 1000 次資料庫寫入
  - 浪費頻寬和資源（秒級精度對學習平台來說沒必要）
  - 可能觸發資料庫鎖競爭（lock contention）

**如果每分鐘更新（太長）：**

- 優點：後端負擔輕
- 缺點：
  - 使用者關閉分頁時，最多丟失 60 秒的進度（體驗差）
  - 進度條更新延遲太高，使用者會覺得「卡住了」

**10 秒剛剛好：**

- 後端負擔可接受（1000 人同時看 = 每秒 100 次請求）
- 進度損失可接受（最多丟失 10 秒）
- 使用者體驗流暢（進度條每 10 秒更新一次，不會覺得遲鈍）

**2. 如果 1000 名學生同時觀看影片，每 10 秒更新一次會對資料庫造成什麼壓力？**

簡單計算：

- 1000 名學生同時看影片
- 每 10 秒更新一次
- **每秒 = 1000 / 10 = 100 次資料庫寫入**

這個量級對於現代資料庫來說**不算大**，但仍然有些考量：

**資料庫負擔：**

- 100 QPS（Queries Per Second）的寫入，PostgreSQL 可以輕鬆處理
- 但如果每個更新都觸發索引重建、觸發器（Trigger）、複雜的邏輯，就會慢下來

**潛在問題：**

- **寫入鎖（Write Lock）**：大量 UPDATE 可能造成資料表鎖競爭
- **硬碟 I/O**：頻繁的 WAL（Write-Ahead Log）寫入會增加硬碟負擔
- **連線池耗盡**：如果每個請求都要一個資料庫連線，連線池可能不夠用

**3. 如何優化這個設計來減輕後端負擔？**

有幾種優化策略：

**策略 1：批次處理（Batching）**
前端暫存多次進度更新，每 30 秒統一送出：

```
0s → 記錄 10s
10s → 記錄 20s
20s → 記錄 30s
30s → 一次性送出「目前在 30s」
```

這樣可以把請求量降低 3 倍。

**策略 2：非同步寫入（Async Write）**
把進度更新請求丟到訊息佇列（如 Redis Queue、RabbitMQ），後端慢慢消化：

```
前端 → API Server → Redis Queue → Background Worker → Database
```

這樣 API Server 可以立刻回應，不用等資料庫寫入完成。

**策略 3：使用 Redis 快取**
先把進度寫到 Redis（記憶體操作超快），定期（如每分鐘）批次同步到 PostgreSQL：

```
PUT /progress → 寫入 Redis（快）
每 60 秒 → 批次寫入 PostgreSQL（慢但省資源）
```

使用者下次讀取進度時，優先從 Redis 讀取。

**策略 4：只在「關鍵時刻」更新資料庫**

- 影片看完時
- 使用者離開頁面時（用 `beforeunload` 事件）
- 每 60 秒更新一次資料庫（其他時間只更新 Redis）

我會建議：**先用 10 秒更新，監控系統負載，如果真的有壓力再引入 Redis 快取或非同步處理**。過早優化（Premature Optimization）往往得不償失。

---

### 21. [Mid-level] 交付與完成的分離設計

**1. 為什麼要將「完成」和「交付」分開設計？**

這個設計背後有幾個重要的考量：

**第一，符合實際學習體驗：**
當你看完一部影片，不代表你馬上想領獎勵。也許你想先複習一下筆記、思考一下內容，或者暫時離開。如果看完就自動發經驗值，使用者會錯失「主動完成任務」的成就感。

**第二，遊戲化設計：**
「交付」是一個明確的**使用者操作**，讓學習過程更有儀式感。當使用者點擊「交付任務」按鈕，看到「恭喜！獲得 100 經驗值」的提示，這種**主動獲得獎勵的體驗**比被動自動獲得更有成就感。

**第三，防止誤觸：**
如果影片看完就自動給經驗值，萬一使用者不小心快轉到結尾、或者影片本來就很短，系統該不該給獎勵？分離設計讓使用者必須「確認完成」才能領獎，避免誤判。

**2. 這種設計對使用者體驗和遊戲化機制有什麼影響？**

**正面影響：**

- **增強參與感**：使用者需要主動操作，感覺更投入
- **清楚的進度追蹤**：可以看到「哪些任務完成了但還沒交付」，方便批次領獎
- **彈性**：使用者可以選擇什麼時候領獎勵（比如累積幾個一起領，增加升級的快感）

**潛在問題：**

- **多一步操作**：有些使用者可能覺得多此一舉，為什麼不能自動領？
- **遺忘風險**：如果使用者忘記交付，經驗值就一直領不到

實務上可以這樣優化：

- 在任務完成後顯示明顯的「交付」按鈕
- 在個人頁面提示「你有 3 個任務尚未交付」
- 提供「一鍵交付所有已完成任務」功能

**3. 如果要防止「使用者快轉影片快速刷經驗值」，應該如何改進？**

現有設計已經有基本防護（必須看到 `watchPositionSeconds == durationSeconds` 才能完成），但還有改進空間：

**策略 1：檢查觀看時長**
在後端記錄使用者「實際觀看時間」（不是進度條位置）：

```java
// 假設影片 5 分鐘，使用者必須至少觀看 4 分鐘（80%）
if (actualWatchTimeSeconds < durationSeconds * 0.8) {
    return "請完整觀看影片再交付";
}
```

**策略 2：檢查觀看行為**
記錄使用者的進度更新歷史：

- 正常觀看：0s → 10s → 20s → ... → 300s（連續）
- 作弊快轉：0s → 直接跳到 300s（可疑）

如果偵測到「一次性跳到結尾」，可以要求使用者重新觀看。

**策略 3：加入隨機驗證問題**
在影片中隨機時間點插入小測驗（如選擇題），確認使用者有在看。但這會影響體驗，要謹慎使用。

**策略 4：放寬標準**
也可以反過來思考：如果使用者真的想快轉跳過，代表內容對他來說不重要或已經懂了。我們真的要強制他看完嗎？也許**允許快轉，但交付時要求填寫心得或通過測驗**，證明他確實理解內容。

我會建議採用**策略 1（檢查觀看時長）+ 提示但不強制**的溫和做法，避免過度防禦影響正常使用者體驗。

---

### 22. [Mid-level] 防止重複交付

**1. 為什麼需要防止重複交付？**

最直接的理由是**防止經驗值被重複發放**。如果同一個任務可以交付多次，使用者只要反覆點擊「交付」按鈕，就能無限刷經驗值，完全破壞遊戲化機制。

另一個理由是**資料一致性**。經驗值、等級這些資料是使用者成長的核心指標，如果因為重複交付導致數據膨脹，會影響：

- 排行榜公平性
- 使用者之間的信任
- 系統的可信度

**2. 這個檢查應該在應用層實作還是資料庫層實作？**

最好的做法是**兩層都做**：

**應用層檢查（Controller/Service）：**

```java
if (progress.getStatus() == MissionStatus.DELIVERED) {
    throw new ConflictException("任務已經交付過了");
}
```

這是第一道防線，可以快速回應錯誤，避免不必要的資料庫操作。

**資料庫層保證（Unique Constraint）：**

```sql
-- 在 user_mission_progress 表加上約束
ALTER TABLE user_mission_progress
ADD CONSTRAINT uk_user_mission UNIQUE (user_id, mission_id);
```

等等，這個約束其實已經存在了（因為 PUT API 需要 Upsert），所以資料庫層已經保證「一個使用者對一個任務只有一筆進度記錄」。

但我們還需要加上**狀態檢查**，確保 status 不會從 DELIVERED 變回其他狀態：

```sql
-- 可以用觸發器（Trigger）或應用層邏輯來保證
-- 一旦 status = 'DELIVERED' 就不能再改變
```

**3. 在高併發情境下，如何確保經驗值不會重複發放？**

這是一個經典的**併發控制**問題。假設使用者快速點擊兩次「交付」，兩個請求幾乎同時到達後端：

**請求 A 和請求 B 都執行：**

1. 讀取進度 → 狀態是 COMPLETED（都通過檢查）
2. 發放經驗值 +100
3. 更新狀態為 DELIVERED

結果：經驗值被發放兩次！

**解決方案 1：樂觀鎖（Optimistic Lock）**
使用版本號（version）來檢測併發修改：

```java
@Entity
public class UserMissionProgress {
    @Version
    private Long version;  // JPA 會自動管理
}

// 更新時如果 version 不匹配，拋出 OptimisticLockException
```

**解決方案 2：悲觀鎖（Pessimistic Lock）**
在讀取進度時就鎖定這筆記錄：

```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
UserMissionProgress findByUserIdAndMissionId(Long userId, Long missionId);
```

這樣第二個請求會被阻塞，等第一個請求完成後才能執行，此時狀態已經是 DELIVERED，就會被拒絕。

**解決方案 3：資料庫事務隔離層級**
使用 `SERIALIZABLE` 隔離層級，但這會大幅降低併發效能，一般不建議。

**解決方案 4：唯一性約束 + 狀態轉換表**
建立一個 `mission_deliveries` 表來記錄交付事件：

```sql
CREATE TABLE mission_deliveries (
    user_id INT,
    mission_id INT,
    delivered_at TIMESTAMP,
    experience_granted INT,
    PRIMARY KEY (user_id, mission_id)  -- 保證唯一性
);
```

交付時嘗試 INSERT，如果已經存在就會違反主鍵約束，捕捉異常並回傳 409。

**我會推薦使用「樂觀鎖（方案 1）」**，它在效能和安全性之間取得良好平衡，而且 Spring Data JPA 支援很好，只需要加上 `@Version` 註解即可。

---

### 23. [Mid-level] 路徑參數中的 userId 安全性

**1. 為什麼路徑中還要包含 userId？直接設計成 /users/me/orders 不是更安全嗎？**

這是一個很好的問題！兩種設計各有優缺點：

**`/users/{userId}/orders` 的優點：**

- **RESTful 語意清楚**：URL 明確表達「使用者 ID 11 的訂單列表」，符合資源導向設計
- **易於擴展權限**：未來如果要支援「管理員查看所有使用者訂單」，只需要調整權限檢查，不用改 URL
- **API 一致性**：其他資源也用類似設計（如 `/users/{userId}/missions/{missionId}/progress`），保持一致性
- **測試和除錯方便**：看到 URL 就知道在操作哪個使用者的資料

**`/users/me/orders` 的優點：**

- **更安全**：前端永遠只能傳 `me`，不可能嘗試存取其他人的資料
- **更簡潔**：不需要前端從 JWT 解析 userId 再傳回後端
- **避免混淆**：使用者看到 URL 不會困惑「為什麼要傳 userId？後端不是已經知道我是誰了嗎？」

**為什麼我們的專案選擇前者？**

主要是為了 **RESTful 原則和可擴展性**。REST 的核心思想是「URL 代表資源」，`/users/11/orders` 比 `/users/me/orders` 更明確表達資源的身份。而且後端會嚴格檢查權限，即使路徑中有 userId，也不會有安全問題。

**2. 從 RESTful 資源設計的角度，哪個更符合 REST 原則？**

**`/users/{userId}/orders` 更符合 REST 原則**。

REST 強調資源的**可定址性（Addressability）**和**統一介面（Uniform Interface）**。每個資源都應該有一個明確的 URI，而 `me` 是一個**別名（alias）**，不是真正的資源識別碼。

舉例來說：

- `/users/11/orders` → 明確指向使用者 11 的訂單
- `/users/me/orders` → 根據不同人登入，指向不同資源（不穩定）

如果今天有一個管理員想要查看「使用者 11 的訂單」，用哪個 URL？

- 如果 API 是 `/users/{userId}/orders`，管理員直接呼叫 `/users/11/orders` 即可
- 如果 API 是 `/users/me/orders`，就必須另外設計 `/admin/users/11/orders`，增加 API 複雜度

**但實務上，很多 API 會兩者都提供：**

- `/users/me` → 快捷方式，自動解析為當前使用者
- `/users/{userId}` → 標準方式，支援管理員等進階用途

這樣可以兼顧易用性和擴展性。

**3. 如果未來要支援「管理員查看所有使用者的訂單」，哪個更容易擴展？**

**`/users/{userId}/orders` 更容易擴展**。

現有的權限檢查邏輯可能是：

```java
if (!jwtUserId.equals(pathUserId)) {
    throw new ForbiddenException();
}
```

要支援管理員，只需要調整為：

```java
if (!jwtUserId.equals(pathUserId) && !currentUser.isAdmin()) {
    throw new ForbiddenException();
}
```

**URL 完全不用改**，只要調整權限邏輯即可。

但如果用 `/users/me/orders` 設計，管理員要怎麼查看其他使用者的訂單？只能新增另一個端點：

```
GET /admin/users/{userId}/orders  // 管理員專用
GET /users/me/orders              // 一般使用者專用
```

這樣會導致 API 數量膨脹，而且兩個端點的邏輯幾乎一模一樣，造成重複程式碼。

**結論：**
在單純「使用者只能看自己資料」的場景下，`/users/me` 更簡潔安全。但如果考慮未來擴展性，`/users/{userId}` 搭配嚴格的權限檢查是更好的選擇。

---

### 24. [Mid-level] 404 vs 403 的安全性權衡

**1. 為什麼訂單 API 使用 404 而不是 403？**

這是一個**資訊洩漏（Information Disclosure）**的安全性考量。

假設有兩個使用者：

- 使用者 A（userId = 11）有一個訂單 orderId = 123
- 使用者 B（userId = 12）嘗試存取 `GET /orders/123`

**如果回傳 403 Forbidden：**
使用者 B 會知道「訂單 123 存在，但我沒有權限查看」。這洩漏了資訊：

- 這個訂單編號是有效的
- 有人擁有這個訂單
- 攻擊者可以遍歷訂單編號，找出哪些訂單存在

**如果回傳 404 Not Found：**
使用者 B 會以為「訂單 123 不存在」。這樣就隱藏了資源的存在性，讓攻擊者無法判斷：

- 這個訂單是真的不存在？
- 還是存在但我沒權限？

這種「用 404 隱藏資源存在性」的做法叫做 **Security by Obscurity（透過隱蔽提升安全性）**。

**2. 這種做法有什麼優缺點？**

**優點：**

- **防止資源探測**：攻擊者無法透過狀態碼判斷資源是否存在
- **保護隱私**：避免洩漏「誰有訂單」、「哪些訂單編號被使用」等資訊
- **降低攻擊面**：讓攻擊者更難收集系統資訊

**缺點：**

- **混淆錯誤原因**：前端和使用者無法區分「資源不存在」和「無權限存取」
- **除錯困難**：開發者在除錯時也會被誤導
- **不符合 HTTP 語意**：嚴格來說，有權限問題應該用 403，用 404 算是「說謊」

**3. 什麼情況下應該用 403，什麼情況下應該用 404？**

判斷原則：**資源的敏感程度**。

**應該用 403 的情況（資源存在性不敏感）：**

- `GET /users/11/missions/5/progress`：任務進度的存在性不是秘密，任務 ID 是公開的
- `POST /orders/123/pay`：嘗試支付別人的訂單，明確告知「無權限」更合理
- 管理後台的資源：`GET /admin/users/11`，告訴管理員「你沒有權限」而不是「使用者不存在」

**應該用 404 的情況（資源存在性敏感）：**

- `GET /orders/123`：訂單編號是敏感的，不應洩漏給其他人
- `GET /users/11/private-messages/456`：私訊的存在性應該保密
- 任何包含「個人隱私資料」的資源

**實務建議：**

- 公開資源或內部資源：用 403
- 個人隱私資源：用 404
- 在 API 文件中明確說明這個設計決策，避免前端開發者困惑

也可以在後端 log 記錄真實原因（「權限拒絕」），但回傳給客戶端的是 404，這樣開發者可以從 log 中除錯，使用者和攻擊者則看不到真實原因。

---

### 25. [Mid-level] Optional JWT 設計

**1. 為什麼要設計成「可選認證」而不是強制登入？**

這是為了**降低使用者進入門檻**和**提升轉換率**。

**如果強制登入才能看課程詳情：**

- 新訪客點進課程頁面 → 被要求登入 → 很多人會直接離開（轉換率流失）
- 使用者體驗差：「我只是想看看這門課在教什麼，為什麼要我先註冊？」
- SEO 不友善：搜尋引擎爬蟲無法索引課程內容

**可選認證的好處：**

- **降低心理門檻**：訪客可以自由瀏覽課程大綱、章節標題
- **提供個性化資訊**：如果使用者已登入，額外顯示「你已購買」、「繼續學習」等資訊
- **漸進式引導**：先讓使用者看到課程內容，覺得有興趣再引導登入購買

這是電商和內容平台的常見策略：**先展示價值，再要求註冊**。

**2. 在實作上，後端如何判斷「JWT 存在但無效」和「使用者未提供 JWT」？**

後端的認證中介層（Authentication Middleware）應該區分三種情況：

**情況 1：沒有提供 JWT（Authorization Header 不存在或為空）**

```java
if (authHeader == null || authHeader.isEmpty()) {
    // 允許繼續執行，但 currentUser 設為 null
    request.setAttribute("currentUser", null);
}
```

這種情況下，API 正常執行，只是回應中的 `userStatus` 和 `status` 欄位為 null。

**情況 2：提供了 JWT 但無效（過期、簽名錯誤、格式錯誤）**

```java
try {
    User user = jwtService.validateToken(token);
    request.setAttribute("currentUser", user);
} catch (InvalidTokenException e) {
    // 回傳 401 Unauthorized
    return Response.status(401).entity(new ErrorResponse("未授權或無效的 token")).build();
}
```

這種情況應該回傳 **401 Unauthorized** + `"未授權或無效的 token"`，讓前端知道 Token 失效了，需要重新登入。

**情況 3：提供了有效的 JWT**

```java
User user = jwtService.validateToken(token);
request.setAttribute("currentUser", user);
// 繼續執行，回應包含使用者相關資訊
```

**關鍵：**

- **沒有 Token** ≠ **無效 Token**
- 沒有 Token → 當作訪客，正常執行
- 無效 Token → 明確告知錯誤，回傳 401

**3. 前端如何根據回應內容動態顯示「繼續學習」或「立即購買」按鈕？**

前端可以根據 `userStatus` 欄位來判斷：

```javascript
const response = await fetch('/journeys/17')
const journey = await response.json()

if (journey.userStatus === null) {
	// 使用者未登入，顯示「立即購買」
	showButton('立即購買', () => redirectToLogin())
} else if (journey.userStatus.hasPurchased) {
	// 使用者已購買，顯示「繼續學習」
	showButton('繼續學習', () => goToCourse(journey.id))
} else if (journey.userStatus.hasUnpaidOrder) {
	// 使用者有未付款訂單，顯示「完成付款」
	const orderId = journey.userStatus.unpaidOrderId
	showButton('完成付款', () => goToCheckout(orderId))
} else {
	// 使用者已登入但未購買，顯示「立即購買」
	showButton('立即購買', () => createOrder(journey.id))
}
```

這種設計讓前端可以提供**高度個性化的使用者體驗**，根據使用者的狀態顯示最合適的行動呼籲（Call to Action）。

另外，`missions[].status` 欄位也可以用來顯示進度：

```javascript
missions.forEach((mission) => {
	if (mission.status === 'DELIVERED') {
		showCheckmark(mission.id) // 顯示勾勾圖示
	} else if (mission.status === 'COMPLETED') {
		showDeliverButton(mission.id) // 顯示「交付」按鈕
	} else if (mission.status === 'UNCOMPLETED') {
		// 未完成，顯示正常狀態
	} else {
		// status 為 null（使用者未登入），不顯示進度
	}
})
```

這樣的 API 設計讓前端可以用一次請求就獲得所有必要資訊，避免多次往返，提升效能和使用者體驗。

---

### 26. [Mid-level] 使用者只能查看自己資料的實作策略

**1. 在 Spring Boot 中，應該在哪一層進行權限檢查？**

這個問題沒有絕對的答案，要看專案規模和複雜度。讓我分析幾種做法：

**做法 1：在 Controller 層檢查**

```java
@GetMapping("/users/{userId}/orders")
public ResponseEntity<OrderListResponse> getUserOrders(
    @PathVariable Long userId,
    @AuthenticationPrincipal JwtUser currentUser
) {
    if (!currentUser.getId().equals(userId)) {
        throw new ForbiddenException("無法查看其他使用者的訂單");
    }
    return orderService.getUserOrders(userId);
}
```

**優點：** 邏輯清楚，容易除錯
**缺點：** 每個 Controller 方法都要寫一次，重複代碼多

**做法 2：在 Service 層檢查**

```java
public List<Order> getUserOrders(Long userId, Long currentUserId) {
    if (!currentUserId.equals(userId)) {
        throw new ForbiddenException();
    }
    return orderRepository.findByUserId(userId);
}
```

**優點：** 業務邏輯集中管理
**缺點：** Service 方法需要額外傳入 currentUserId，參數變多

**做法 3：使用 Spring Security 的 @PreAuthorize**

```java
@PreAuthorize("#userId == authentication.principal.id or hasRole('ADMIN')")
@GetMapping("/users/{userId}/orders")
public ResponseEntity<OrderListResponse> getUserOrders(@PathVariable Long userId) {
    return orderService.getUserOrders(userId);
}
```

**優點：** 宣告式，簡潔優雅，支援複雜權限表達式
**缺點：** 學習曲線較陡，除錯較難（權限錯誤不好追蹤）

**我會推薦：對於簡單的「使用者只能存取自己資料」檢查，用做法 3（@PreAuthorize）**。對於複雜的業務權限（如「只有課程作者可以編輯」），在 Service 層實作。

**2. 如何避免在每個 API 都重複寫權限檢查邏輯？**

有幾種方法可以避免重複：

**方法 1：自訂註解 + AOP（Aspect-Oriented Programming）**

```java
// 定義自訂註解
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequireOwnership {
    String userIdParam() default "userId";  // 指定哪個參數是 userId
}

// 使用註解
@RequireOwnership(userIdParam = "userId")
@GetMapping("/users/{userId}/orders")
public ResponseEntity<OrderListResponse> getUserOrders(@PathVariable Long userId) {
    return orderService.getUserOrders(userId);
}

// AOP 切面處理
@Aspect
@Component
public class OwnershipCheckAspect {
    @Before("@annotation(requireOwnership)")
    public void checkOwnership(JoinPoint joinPoint, RequireOwnership requireOwnership) {
        // 從參數中取得 userId
        // 從 SecurityContext 取得 currentUserId
        // 比較兩者是否相同
        if (!currentUserId.equals(userId)) {
            throw new ForbiddenException();
        }
    }
}
```

**方法 2：自訂 Spring Security Voter**
實作 `AccessDecisionVoter`，集中處理所有權限邏輯。

**方法 3：攔截器（Interceptor）**
在請求處理前統一檢查路徑參數中的 userId：

```java
@Component
public class OwnershipInterceptor implements HandlerInterceptor {
    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String path = request.getRequestURI();
        if (path.matches("/users/(\\d+)/.*")) {
            Long pathUserId = extractUserIdFromPath(path);
            Long currentUserId = getCurrentUserId();
            if (!pathUserId.equals(currentUserId)) {
                throw new ForbiddenException();
            }
        }
        return true;
    }
}
```

**我推薦方法 1（自訂註解 + AOP）**，它兼具靈活性和可讀性，而且可以針對不同資源定義不同的權限檢查邏輯。

**3. 如果未來要支援「家長查看子女的學習進度」功能，現有的權限檢查邏輯如何擴展？**

需要調整權限模型，從「只能看自己」變成「可以看自己 + 有關聯的人」。

**資料庫層級增加關聯表：**

```sql
CREATE TABLE user_relationships (
    parent_user_id INT NOT NULL,
    child_user_id INT NOT NULL,
    relationship_type VARCHAR(50) NOT NULL,  -- 'PARENT_CHILD', 'MENTOR_MENTEE'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (parent_user_id, child_user_id)
);
```

**權限檢查邏輯調整：**

```java
@PreAuthorize("@permissionService.canAccessUserData(#userId, authentication.principal.id)")
@GetMapping("/users/{userId}/missions/{missionId}/progress")
public ResponseEntity<UserMissionProgress> getProgress(@PathVariable Long userId, ...) {
    // ...
}

@Service
public class PermissionService {
    public boolean canAccessUserData(Long targetUserId, Long currentUserId) {
        // 1. 是自己
        if (targetUserId.equals(currentUserId)) {
            return true;
        }

        // 2. 是管理員
        if (currentUser.hasRole("ADMIN")) {
            return true;
        }

        // 3. 有家長子女關係
        if (relationshipRepository.existsByParentAndChild(currentUserId, targetUserId)) {
            return true;
        }

        return false;
    }
}
```

**前端呼叫方式：**

- 家長可以切換身份：「查看我的進度」或「查看孩子的進度」
- API 路徑保持不變：`GET /users/{userId}/missions/{missionId}/progress`
- 只是 userId 可以是自己或子女的 ID

**關鍵優勢：**
這種設計的好處是**向後相容** —— 現有的 API 結構完全不用改，只需要調整權限檢查邏輯，就能支援新功能。這就是為什麼一開始選擇 `/users/{userId}/orders` 而不是 `/users/me/orders` 的原因，它為未來的擴展留下了空間。

---

### 27. [Mid-level] 冪等性設計分析

讓我們逐一分析這四個 API 的冪等性：

**1. `POST /auth/login` - 多次登入**

**是冪等的**（但有爭議）。

如果你用相同的 username 和 password 多次呼叫登入 API：

- 每次都會生成**不同的 JWT Token**（因為 Token 包含簽發時間 `iat`）
- 但從使用者角度來看，**最終效果一樣** —— 都是「成功登入並拿到有效 Token」

嚴格來說，因為回傳值不同（Token 不同），所以不是純粹的冪等。但在業務語意上，多次登入不會造成副作用，所以可以視為「實務上的冪等」。

**2. `POST /orders` - 多次建立相同課程的訂單**

**是冪等的**（特殊設計）。

如題目 18 所討論的，這個 API 有特殊的業務邏輯：

- 第 1 次呼叫 → 建立新訂單 A，回傳訂單 A
- 第 2 次呼叫（同一門課）→ 不建立新訂單，回傳訂單 A
- 第 3 次呼叫 → 還是回傳訂單 A

**結果一樣**，所以是冪等的。這是透過業務邏輯實現的冪等性，不是 HTTP 方法本身的特性。

**3. `PUT /users/{userId}/missions/{missionId}/progress` - 多次更新進度**

**是冪等的**。

如果你多次呼叫：

```
PUT /users/1/missions/5/progress
{ "watchPositionSeconds": 150 }
```

不管呼叫幾次，進度都是 150 秒，**最終狀態一致**。這就是 PUT 的標準冪等性。

**4. `POST /users/{userId}/missions/{missionId}/progress/deliver` - 多次交付**

**不是冪等的**（但有防護）。

從語意上看，交付任務應該是**非冪等操作**：

- 第 1 次交付 → 發放 100 經驗值
- 第 2 次交付 → 理論上又發放 100 經驗值（如果沒有防護）

雖然我們的實作中有檢查「已交付則回傳 409」，但這只是**防止錯誤**，不代表它是冪等的。它的本質是「第一次成功，後續失敗」，不符合冪等的「多次執行結果相同」定義。

**總結：**

| API              | 冪等性   | 原因                         |
| ---------------- | -------- | ---------------------------- |
| POST /auth/login | 實務冪等 | 回傳值不同但效果相同         |
| POST /orders     | 是       | 業務邏輯保證（回傳現有訂單） |
| PUT /progress    | 是       | PUT 的標準冪等性             |
| POST /deliver    | 否       | 第一次成功，後續失敗（409）  |

**2. 為什麼 PUT 通常是冪等的，而 POST 通常不是？**

這源自 HTTP 規範對方法語意的定義：

**PUT 的語意：「把資源設定為某個狀態」**

- `PUT /users/1/profile { "name": "John" }` → 把使用者名稱設為 John
- 不管呼叫幾次，名稱都是 John，**結果一致**

**POST 的語意：「執行某個動作」或「建立資源」**

- `POST /orders` → 建立一個新訂單
- 每次呼叫都建立新訂單，**結果不同**

簡單區分：

- **PUT**：「我要設定資源為 X」→ 多次設定結果一樣 → 冪等
- **POST**：「我要做動作 Y」→ 多次執行可能產生不同結果 → 非冪等

**3. 如何設計 POST API 來實現冪等性？**

最常見的方法是使用 **Idempotency Key（冪等鍵）**：

**前端發送請求時帶上唯一的 key：**

```http
POST /orders
Headers:
  Idempotency-Key: a1b2c3d4-e5f6-7890-abcd-ef1234567890
Body:
  { "items": [{ "journeyId": 17 }] }
```

**後端實作：**

```java
@PostMapping("/orders")
public ResponseEntity<OrderResponse> createOrder(
    @RequestBody CreateOrderRequest request,
    @RequestHeader("Idempotency-Key") String idempotencyKey
) {
    // 1. 檢查這個 key 是否已經處理過
    Optional<IdempotencyRecord> existing = idempotencyRepository.findByKey(idempotencyKey);
    if (existing.isPresent()) {
        // 2. 如果處理過，直接回傳之前的結果
        return ResponseEntity.ok(existing.get().getResponse());
    }

    // 3. 第一次處理，建立訂單
    Order order = orderService.createOrder(request);

    // 4. 儲存 idempotency key 和結果
    idempotencyRepository.save(new IdempotencyRecord(idempotencyKey, order));

    return ResponseEntity.status(201).body(order);
}
```

**Idempotency Key 的最佳實踐：**

- Key 由前端生成（如 UUID）
- 後端儲存 key + 結果的對應關係
- Key 有過期時間（如 24 小時），過期後自動清除
- 如果前端重試請求（網路不穩），只要用同一個 key，後端會回傳相同結果

**實務應用：**

- Stripe、GitHub、Shopify 等 API 都支援 Idempotency Key
- 特別適合「支付」、「轉帳」這類不能重複執行的關鍵操作

---

### 28. [Mid-level] 分頁參數設計

**1. 為什麼選擇 page/limit 而不是 offset/limit？**

這兩種方式各有適用場景：

**page/limit（頁碼 + 每頁筆數）：**

```
GET /users/11/orders?page=1&limit=20  → 第 1 頁，每頁 20 筆
GET /users/11/orders?page=2&limit=20  → 第 2 頁
```

- 對應的 SQL：`LIMIT 20 OFFSET 0`（第 1 頁）、`LIMIT 20 OFFSET 20`（第 2 頁）
- **優點：** 符合使用者直覺（「第幾頁」的概念）、適合顯示頁碼導覽（1 2 3 ... 10）
- **缺點：** 需要計算 offset = (page - 1) \* limit

**offset/limit（偏移量 + 筆數）：**

```
GET /users/11/orders?offset=0&limit=20   → 從第 0 筆開始，取 20 筆
GET /users/11/orders?offset=20&limit=20  → 從第 20 筆開始
```

- 直接對應 SQL 的 `LIMIT` 和 `OFFSET`
- **優點：** 更靈活（可以從任意位置開始），不需要計算
- **缺點：** 對一般使用者不直覺（什麼是 offset？）

**為什麼我們的專案選擇 page/limit？**
因為這是**面向使用者的 API**，不是內部系統 API。使用者習慣說「我要看第 2 頁」，而不是「我要從 offset 20 開始」。前端開發者也覺得 page 更好理解。

**2. 分頁回應中，除了 page, limit, total，還可以提供哪些資訊？**

我們可以加入更多對前端有用的資訊：

```json
{
  "orders": [...],
  "pagination": {
    "page": 2,           // 目前頁碼
    "limit": 20,         // 每頁筆數
    "total": 85,         // 總筆數
    "totalPages": 5,     // 總頁數（方便前端顯示「共 5 頁」）
    "hasNext": true,     // 是否有下一頁（方便「下一頁」按鈕）
    "hasPrev": true,     // 是否有上一頁（方便「上一頁」按鈕）
    "nextPage": 3,       // 下一頁的頁碼（null 表示沒有）
    "prevPage": 1        // 上一頁的頁碼（null 表示沒有）
  }
}
```

**或者提供「自描述連結」（HATEOAS 風格）：**

```json
{
  "orders": [...],
  "pagination": {
    "page": 2,
    "limit": 20,
    "total": 85
  },
  "links": {
    "first": "/users/11/orders?page=1&limit=20",
    "prev": "/users/11/orders?page=1&limit=20",
    "self": "/users/11/orders?page=2&limit=20",
    "next": "/users/11/orders?page=3&limit=20",
    "last": "/users/11/orders?page=5&limit=20"
  }
}
```

這樣前端不用自己算 URL，直接用 `links.next` 就能請求下一頁。

**3. 當資料量很大時，傳統的 offset/limit 分頁會有效能問題，應該改用什麼方式？**

**問題：深分頁效能差**
當 offset 很大時（如第 1000 頁），資料庫需要：

```sql
SELECT * FROM orders ORDER BY created_at DESC LIMIT 20 OFFSET 20000;
```

資料庫要**跳過前 20000 筆**資料，這非常耗時。offset 越大，查詢越慢。

**解決方案：Cursor-based Pagination（游標分頁）**

**原理：** 用「最後一筆資料的識別碼」作為游標，查詢「在這個游標之後的資料」。

**API 設計：**

```
GET /users/11/orders?limit=20                     → 第一頁
GET /users/11/orders?limit=20&cursor=order_123   → 下一頁（從 order_123 之後開始）
```

**後端實作：**

```java
@GetMapping("/users/{userId}/orders")
public OrderListResponse getUserOrders(
    @RequestParam(required = false) String cursor,
    @RequestParam(defaultValue = "20") int limit
) {
    if (cursor == null) {
        // 第一頁：取最新的 20 筆
        List<Order> orders = repository.findTop20ByUserIdOrderByCreatedAtDesc(userId);
    } else {
        // 後續頁：取「在 cursor 之後」的 20 筆
        Order cursorOrder = repository.findByOrderNumber(cursor);
        List<Order> orders = repository.findByUserIdAndCreatedAtLessThan(
            userId,
            cursorOrder.getCreatedAt(),
            PageRequest.of(0, limit)
        );
    }

    // 回傳時附上「下一頁的 cursor」
    String nextCursor = orders.isEmpty() ? null : orders.get(orders.size() - 1).getOrderNumber();
    return new OrderListResponse(orders, nextCursor);
}
```

**SQL 查詢：**

```sql
-- 傳統 offset/limit（慢）
SELECT * FROM orders WHERE user_id = 11 ORDER BY created_at DESC LIMIT 20 OFFSET 20000;

-- Cursor-based（快）
SELECT * FROM orders
WHERE user_id = 11 AND created_at < '2023-11-20 10:00:00'
ORDER BY created_at DESC
LIMIT 20;
```

**優點：**

- 效能穩定，不會因為深分頁變慢
- 適合「無限滾動」的 UI（如 Facebook、Twitter 的動態牆）

**缺點：**

- 不能跳到「第 N 頁」（因為沒有頁碼概念）
- 不適合需要頁碼導覽的場景
- 如果資料在分頁期間被刪除或新增，可能會跳過或重複

**總結：**

- **小資料量（< 10 萬筆）**：用 page/limit，簡單好用
- **大資料量 + 需要頁碼導覽**：用 offset/limit + 快取優化
- **大資料量 + 無限滾動 UI**：用 Cursor-based Pagination

---

### 29. [Mid-level] Nullable 欄位設計原則

**1. 為什麼 paidAt 和 expiredAt 設計成 nullable？**

因為 **null 有明確的語意：「事件尚未發生」**。

**如果用預設值（如 0 或 -1）表示「尚未發生」：**

```json
{
	"paidAt": 0, // 0 代表「未付款」？還是 1970-01-01？
	"expiredAt": -1 // -1 是什麼意思？前端要特殊處理
}
```

**問題：**

- **語意不清楚**：0 或 -1 不是真正的時間戳記，需要額外文件說明
- **容易出錯**：前端要記得「0 = 未付款」，如果直接傳給 `new Date(0)` 會得到 1970 年
- **不直覺**：`if (paidAt === 0)` 不如 `if (paidAt === null)` 直觀

**用 null 的好處：**

```json
{
	"paidAt": null, // 清楚表示「未付款」
	"expiredAt": null // 清楚表示「未過期（因為已付款）」
}
```

- **語意明確**：null 就是「沒有值」，不需要額外解釋
- **符合 JSON 標準**：null 是 JSON 的原生類型
- **前端好處理**：`if (order.paidAt)` 就能判斷是否已付款

**2. 前端如何根據這些欄位的 null 狀態來判斷訂單狀態和顯示邏輯？**

前端可以用很簡潔的邏輯判斷：

```javascript
function getOrderStatus(order) {
	if (order.paidAt !== null) {
		return {
			status: 'PAID',
			message: `已於 ${formatDate(order.paidAt)} 付款`,
			action: null // 不需要任何操作
		}
	}

	const now = Date.now()
	if (order.expiredAt !== null && now > order.expiredAt) {
		return {
			status: 'EXPIRED',
			message: '訂單已過期',
			action: 'createNewOrder' // 需要重新建立訂單
		}
	}

	return {
		status: 'UNPAID',
		message: `請於 ${formatDate(order.expiredAt)} 前完成付款`,
		action: 'pay' // 顯示「立即付款」按鈕
	}
}
```

**邏輯很清楚：**

1. 有 `paidAt` → 已付款
2. 沒有 `paidAt` 但過了 `expiredAt` → 已過期
3. 沒有 `paidAt` 且未到 `expiredAt` → 未付款

**顯示邏輯：**

```javascript
const { status, message, action } = getOrderStatus(order)

if (status === 'PAID') {
	showSuccessMessage(message)
} else if (status === 'EXPIRED') {
	showWarningMessage(message)
	showButton('重新購買', () => createNewOrder())
} else {
	showInfoMessage(message)
	showButton('立即付款', () => payOrder(order.id))
}
```

**3. API 文件中應該如何清楚標註欄位的 nullable 特性？**

在 OpenAPI (Swagger) 中，應該這樣標註：

```yaml
paidAt:
  type: integer
  format: int64
  description: |
    付款完成時間戳記（自紀元以來的毫秒數）

    - 若訂單狀態為 UNPAID 或 EXPIRED，此欄位為 null
    - 若訂單狀態為 PAID，此欄位為付款完成時間
  example: 1732507200000
  nullable: true # 關鍵！標記這個欄位可以是 null

expiredAt:
  type: integer
  format: int64
  description: |
    訂單過期時間戳記（created_at + 3 天）

    - 若訂單狀態為 UNPAID，此欄位為過期時間
    - 若訂單狀態為 PAID，此欄位為 null（已付款的訂單不會過期）
    - 若訂單狀態為 EXPIRED，此欄位為過期時間
  example: 1732680000000
  nullable: true
```

**文件中應該明確說明：**

1. **什麼時候是 null**（條件）
2. **什麼時候有值**（條件）
3. **null 的業務含義**（不是「錯誤」，而是「未發生」）

**額外提示：在範例中同時展示兩種情況：**

```yaml
examples:
  unpaid:
    summary: 未付款訂單
    value:
      id: 123
      status: 'UNPAID'
      paidAt: null # 明確顯示 null
      expiredAt: 1732680000000

  paid:
    summary: 已付款訂單
    value:
      id: 123
      status: 'PAID'
      paidAt: 1732507200000
      expiredAt: null # 明確顯示 null
```

這樣前端開發者看到文件就能清楚理解 null 的語意，不會誤解或錯誤處理。

---

### 30. [Mid-level] API 演進與向後相容

**1. 這種「新增欄位」的修改是否符合向後相容原則？**

**是的，完全符合向後相容原則！**

**原因：**

- **舊版前端**：不認識 `couponCode` 和 `couponDiscount`，會直接忽略這兩個欄位，只處理 `id`、`price`、`discount`
- **新版前端**：可以讀取並顯示優惠券資訊

**關鍵：新增欄位不會破壞既有行為。**

舊版前端的程式碼：

```javascript
const { id, price, discount } = order
console.log(`訂單 ${id}，金額 ${price}，折扣 ${discount}`)
// 完全不受影響，因為它不去碰 couponCode 和 couponDiscount
```

新版前端的程式碼：

```javascript
const { id, price, discount, couponCode, couponDiscount } = order
if (couponCode) {
	console.log(`使用了優惠券：${couponCode}，折扣 ${couponDiscount}`)
}
```

**向後相容的關鍵原則：**

- ✅ **新增欄位**（additive changes）
- ✅ **欄位變成選填**（required → optional）
- ❌ **刪除欄位**（breaking change）
- ❌ **重新命名欄位**（breaking change）
- ❌ **改變欄位型別**（breaking change）
- ❌ **欄位變成必填**（optional → required，breaking change）

**2. 如果是「修改欄位結構」，應該如何處理以避免破壞現有客戶端？**

**情境：** 要把 `price` 從數字改成物件（包含金額和幣別）

**破壞性改法（❌ 不要這樣做）：**

```json
// 舊版
{ "price": 7599.0 }

// 新版（直接改結構）
{ "price": { "amount": 7599, "currency": "TWD" } }
```

**後果：** 舊版前端的 `order.price` 會拿到一個物件，而不是數字，導致程式崩潰。

**正確做法 1：保留舊欄位，新增新欄位**

```json
{
	"price": 7599.0, // 保留，供舊版前端使用
	"priceV2": {
		// 新增，供新版前端使用
		"amount": 7599,
		"currency": "TWD"
	}
}
```

- 舊版前端：繼續用 `price`
- 新版前端：使用 `priceV2`
- 經過一段過渡期（如半年），確認所有前端都升級後，才能考慮移除 `price`

**正確做法 2：API 版本控制**

```
GET /v1/orders/123  → 回傳舊格式 { "price": 7599.0 }
GET /v2/orders/123  → 回傳新格式 { "price": { "amount": 7599, "currency": "TWD" } }
```

- `/v1` 和 `/v2` 同時維護
- 舊版前端繼續呼叫 `/v1`
- 新版前端改用 `/v2`
- 經過一段時間後，停止維護 `/v1`（但要提前通知）

**正確做法 3：使用 Content Negotiation**

```http
GET /orders/123
Accept: application/vnd.myapp.v1+json  → 回傳舊格式
Accept: application/vnd.myapp.v2+json  → 回傳新格式
```

透過 HTTP Header 的 `Accept` 來決定回應格式。

**我推薦做法 1（保留舊欄位 + 新增新欄位）**，因為它：

- 不需要維護多個 API 版本
- 前端可以漸進式遷移
- 簡單直接，容易理解

**3. 在單一版本 API 維護的策略下，應該如何確保 API 演進不影響現有使用者？**

**核心原則：只做加法，不做減法。**

**允許的演進：**

- ✅ 新增選填欄位（response 中）
- ✅ 新增選填參數（request 中）
- ✅ 新增新的 API 端點
- ✅ 放寬驗證規則（如欄位長度從 50 增加到 100）
- ✅ 新增 Enum 值（如訂單狀態新增 `REFUNDED`）

**禁止的演進（或需要特殊處理）：**

- ❌ 刪除欄位 → 保留欄位但標記為 deprecated，至少維護 6 個月
- ❌ 重新命名欄位 → 同時保留新舊兩個欄位
- ❌ 改變欄位型別 → 新增新欄位（如 `priceV2`）
- ❌ 改變 API 行為 → 新增新的 API 端點
- ⚠️ 刪除 Enum 值 → 提前通知所有使用者，確認沒有在用才能移除

**實務策略：**

**1. API 欄位生命週期管理：**

```yaml
# 在 API 文件中標註欄位狀態
price:
  type: number
  description: |
    ⚠️ **已棄用（Deprecated）**：請改用 priceV2
    此欄位將於 2024-06-01 移除
  deprecated: true

priceV2:
  type: object
  description: |
    💡 **推薦使用**：包含金額和幣別的完整價格資訊
```

**2. 回應中提供警告訊息：**

```json
{
	"data": {
		"price": 7599.0,
		"priceV2": { "amount": 7599, "currency": "TWD" }
	},
	"warnings": ["欄位 'price' 已棄用，請改用 'priceV2'，此欄位將於 2024-06-01 移除"]
}
```

**3. 監控欄位使用情況：**

- 在後端記錄「哪些前端還在使用舊欄位」
- 定期檢查，確認所有前端都遷移後才移除

**4. 提供遷移指南：**
在 API 文件中清楚說明「如何從舊版遷移到新版」，包括程式碼範例。

**總結：**
單一版本 API 的演進策略是：**新增不可怕，刪除要謹慎**。只要遵守向後相容原則，就能讓 API 持續演進，同時不破壞現有使用者的體驗。

---

## 結語

恭喜你完成了 30 道 API 設計面試題！這些題目涵蓋了：

- **基礎概念**：RESTful 原則、HTTP 方法與狀態碼、認證授權
- **設計決策**：冪等性、狀態管理、分頁、錯誤處理
- **安全性**：速率限制、Token 黑名單、404 vs 403、資訊洩漏防護
- **效能優化**：進度更新頻率、深分頁問題、快取策略
- **業務邏輯**：訂單流程、進度追蹤、遊戲化機制
- **系統演進**：向後相容、API 版本控制、欄位生命週期管理

**面試技巧提醒：**

1. **理解權衡（Trade-offs）**：沒有完美方案，重點是說明為什麼選擇 A 而不是 B
2. **結合實際場景**：用 WaterballSA 平台的例子來說明，展現你對專案的理解
3. **考慮未來擴展**：好的設計要為未來留下空間（如家長查看子女進度）
4. **安全優先**：面試官很看重安全意識（如防止重複交付、資訊洩漏）
5. **使用者體驗**：技術決策要考慮對使用者的影響（如 10 秒更新頻率的平衡）

祝你面試順利！🚀
