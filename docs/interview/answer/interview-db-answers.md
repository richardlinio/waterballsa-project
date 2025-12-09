# 資料庫設計面試題解答 - WaterballSA 課程平台

## Junior Level (基礎題 1-10)

### 1. [Junior] Schema 基礎理解

請說明 `users` 表中為什麼要為 `username` 欄位建立 unique 索引？這個索引在註冊和登入流程中分別扮演什麼角色？

**解答：**

為 `username` 建立 unique 索引主要有兩個原因。

首先是**資料完整性**。我們必須確保每個使用者的帳號是獨一無二的，不能有兩個人使用同樣的帳號註冊，這是最基本的業務邏輯。如果沒有這個約束，系統就會出現帳號重複的問題，到時候登入時就不知道要讓誰進來了。

第二個原因是**查詢效能**。在註冊流程中，系統需要檢查「這個帳號是不是已經被人用了」，如果沒有索引，資料庫就要掃描整張表才能確認。當使用者數量一多，這個檢查就會變得很慢。有了 unique 索引之後，資料庫可以用 B-tree 結構快速查找，時間複雜度從 O(n) 降到 O(log n)。

在登入流程中，這個索引的角色更重要。每次使用者登入，系統都要用 `WHERE username = ?` 來找到對應的使用者資料，然後驗證密碼。因為有索引，這個查詢可以瞬間完成。如果沒有索引，每次登入都要全表掃描，那使用者體驗就會很差。

所以簡單來說，這個 unique 索引在註冊時扮演「守門員」的角色，防止重複帳號；在登入時則扮演「快速通道」的角色，讓使用者能迅速進入系統。

---

### 2. [Junior] 軟刪除設計

在這個專案中,所有資料表都有 `deleted_at` 欄位實作軟刪除。請解釋什麼是軟刪除？相較於直接刪除資料（硬刪除），軟刪除有哪些優缺點？

**解答：**

軟刪除就是「假裝刪除」，資料其實還在資料庫裡面，只是標記一個時間戳記說「這筆資料在什麼時候被刪除了」。查詢的時候我們就加上 `WHERE deleted_at IS NULL` 的條件，把那些「已刪除」的資料過濾掉。

軟刪除最大的**優點**有幾個：

第一是**資料可以救回來**。使用者可能會誤刪，或是刪了之後又後悔。如果是硬刪除，資料就真的不見了；但軟刪除的話，我們只要把 `deleted_at` 改回 `NULL`，資料就復活了。

第二是**可以保留歷史記錄**。像訂單資料，即使使用者刪除了帳號，我們可能還是需要保留訂單記錄做財務稽核或是分析。軟刪除可以讓我們在「對使用者來說資料已經刪除」跟「系統內部還保有記錄」之間取得平衡。

第三是**資料關聯不會斷掉**。假設一個課程被刪除了，如果是硬刪除，所有訂單明細裡面的 `journey_id` 就會變成孤兒。但軟刪除的話，外鍵關聯還在，只是我們不顯示而已。

但軟刪除也有**缺點**：

第一個是**查詢效能**。每個查詢都要加 `WHERE deleted_at IS NULL`，這會讓查詢變複雜。而且索引策略也要重新思考，因為被刪除的資料會一直佔用索引空間。

第二個是**唯一性約束的問題**。比如說 `username` 必須唯一，但如果使用者刪除帳號後又想用同樣的帳號重新註冊，軟刪除的資料會讓這個約束失效。我們可能需要額外的邏輯來處理這種情況。

第三個是**儲存空間**。被刪除的資料永遠不會真正消失，長期下來會佔用很多空間。我們可能需要定期清理真的不需要的舊資料。

---

### 3. [Junior] Primary Key 選擇

專案中所有資料表的主鍵都使用 `bigserial` 類型。請說明為什麼選擇 `bigserial` 而不是 `serial` 或 `UUID`？在什麼情況下應該考慮使用 UUID？

**解答：**

這個專案選擇 `bigserial` 是一個很務實的決定。

先說為什麼不用 `serial`。`serial` 是 32-bit 整數，最大值大約 21 億。聽起來很多，但對於一個課程平台來說，如果考慮到使用者、訂單、任務進度這些資料，累積下來很容易就會突破這個上限。尤其是像 `user_mission_progress` 這種會快速增長的表，用 `serial` 可能幾年就用完了。而 `bigserial` 是 64-bit，上限是 9 quintillion（9 後面 18 個零），基本上可以視為用不完。

至於為什麼不用 UUID，主要是考量**效能和儲存空間**。

UUID 是 128-bit 的隨機字串，優點是全域唯一、不需要依賴資料庫序列、可以在應用層先產生 ID。但缺點是它**佔 16 bytes**，相比 `bigserial` 的 8 bytes 大了一倍。而且 UUID 是隨機的，插入時會導致 B-tree 索引頻繁分裂，寫入效能會比自增 ID 差。

`bigserial` 的優勢在於它是**循序遞增**的，這對 B-tree 索引非常友善。新資料永遠插在索引的最右邊，不會造成頁面分裂。而且它只需要 8 bytes，對於有大量外鍵關聯的表來說，可以省下不少空間。

那什麼時候應該用 UUID 呢？

第一個情境是**分散式系統**。如果我們的資料庫要做水平分片（sharding），每個分片都有自己的資料庫，這時候自增 ID 會衝突。用 UUID 就可以避免這個問題。

第二個情境是**安全性考量**。自增 ID 是可以預測的，別人可以從訂單編號 12345 猜到下一個訂單是 12346。如果我們不希望外部知道資料量或是順序，UUID 就是個好選擇。

但對於這個專案來說，單一資料庫架構、沒有特別的安全考量，`bigserial` 絕對是最簡單高效的選擇。

---

### 4. [Junior] 外鍵關聯

`chapters` 表透過 `journey_id` 關聯到 `journeys` 表。請說明這個外鍵關聯的目的是什麼？如果刪除一個 journey（軟刪除），應該如何處理其關聯的 chapters？

**解答：**

這個外鍵關聯的目的很明確，就是要維護**資料完整性**。

每個章節一定要屬於某個旅程，不能憑空存在。外鍵約束可以確保 `journey_id` 必須對應到 `journeys` 表裡面真實存在的一筆資料。這樣我們就不會出現「孤兒章節」的情況——比如說某個章節指向了一個根本不存在的旅程 ID。

在資料庫層級加上這個約束，就不用完全依賴應用程式邏輯。就算程式有 bug，資料庫也會擋下不合理的操作。

至於軟刪除的處理，這就有點微妙了。

因為這個專案用的是**軟刪除**，所以當我們刪除一個旅程時，只是把 `journeys.deleted_at` 設成現在的時間戳記，資料本身還在。從外鍵約束的角度來看，`chapters.journey_id` 還是指向一筆存在的資料，所以不會違反約束。

但從業務邏輯來看，我們應該**同時軟刪除所有相關的章節**。因為一個旅程被刪除了，它底下的章節也應該一起消失。不然會出現很奇怪的狀況：旅程看不到了，但章節還在。

具體的處理方式可以是：

1. 在應用層實作「級聯軟刪除」——刪除旅程時，同時找出所有 `journey_id = ?` 的章節，把它們的 `deleted_at` 也設定好。
2. 或者寫一個觸發器（trigger），當 `journeys.deleted_at` 被更新時，自動更新相關章節。

但要注意，這個邏輯要放在一個**交易（transaction）**裡面，確保旅程和章節的刪除是原子性的。如果中間任何一步失敗，整個操作都要回滾。

如果未來要「恢復」一個被刪除的旅程，也要記得把相關章節一起恢復，保持資料的一致性。

---

### 5. [Junior] Enum 類型使用

`user_role` 使用 PostgreSQL 的 Enum 類型定義了三種角色：STUDENT、TEACHER、ADMIN。相較於使用 varchar 或 integer 儲存角色，使用 Enum 有什麼優勢和限制？

**解答：**

用 Enum 來定義角色是一個蠻聰明的做法，它在這個場景下有幾個明顯的**優勢**。

第一是**資料完整性**。Enum 在資料庫層級就限制了只能插入這三個值：STUDENT、TEACHER、ADMIN。如果有人試圖插入 `SUPER_USER` 或是打錯字寫成 `STUDNET`，資料庫會直接拒絕。這比用 `varchar` 好太多了，因為 varchar 什麼都能塞，要靠應用層去驗證，但應用層可能會有疏漏。

第二是**儲存空間**。Enum 在 PostgreSQL 內部是用整數編號儲存的，所以實際上只佔 4 bytes。相比之下，`varchar` 要存 "TEACHER" 這 7 個字元可能需要更多空間。當 `users` 表有幾十萬筆資料時，這個差異就很明顯了。

第三是**可讀性**。在資料庫裡直接看到 `STUDENT` 比看到 `1` 或是 `S` 清楚多了。用整數的話，每次都要去對照表才知道 1 是什麼意思；用單字縮寫的話，也容易搞混。Enum 讓資料本身就有語意。

但 Enum 也有一些**限制**：

最大的問題是**修改不方便**。如果哪天要新增一個角色，比如說 `MODERATOR`，就必須用 `ALTER TYPE` 指令去修改 Enum 定義。這個操作可能需要鎖表，在生產環境會比較麻煩。相比之下，如果用 varchar，就只是在應用層的驗證邏輯裡多加一個值而已。

第二個問題是**跨資料庫相容性**。Enum 是 PostgreSQL 的特性，如果未來要遷移到 MySQL 或其他資料庫，就要改設計。不過這個專案明確用 PostgreSQL，所以問題不大。

第三是**排序邏輯**。Enum 的排序是按定義順序，所以 `STUDENT < TEACHER < ADMIN`。這可能符合需求（照權限等級），也可能不符合（照字母順序）。要注意這個隱含的行為。

整體來說，對於**值域固定且不常變動**的欄位（像角色、訂單狀態、任務類型），Enum 是個很好的選擇。它在效能、安全性、可讀性上都有優勢。但如果是那種經常需要新增選項的欄位，可能用 varchar + 應用層驗證會比較靈活。

---

### 6. [Junior] 時間戳欄位

每個資料表都有 `created_at` 和 `updated_at` 欄位。請說明這兩個欄位的用途，以及為什麼 `updated_at` 需要在每次更新時自動更新？

**解答：**

這兩個時間戳欄位是標準的**稽核欄位（audit fields）**，幾乎每個正式專案都會加。

`created_at` 的用途很直觀，就是記錄「這筆資料是什麼時候建立的」。這在很多場景都很有用：

- 查詢「最近一週新註冊的使用者」
- 顯示「訂單建立時間」
- 資料分析時看「每月新增的課程數量」

一旦建立就不會再改變，所以設定 `default: now()` 就好，不需要應用層特別處理。

`updated_at` 則是記錄「這筆資料最後一次被修改的時間」。這個欄位非常重要，有幾個用途：

第一是**追蹤變更**。比如使用者更新了個人資料，我們可以知道是什麼時候改的。訂單狀態從未付款變成已付款，也能看到確切的時間點。

第二是**快取失效**。假設前端快取了課程資料，可以用 `updated_at` 來判斷資料是否過期。如果資料庫的 `updated_at` 比快取時間還新，就知道要重新抓取。

第三是**樂觀鎖定（Optimistic Locking）**。更新資料時可以用 `WHERE id = ? AND updated_at = ?` 來確保中間沒有其他人修改過。如果 `updated_at` 對不上，就表示有併發更新，需要重新處理。

至於為什麼需要「自動更新」，主要是因為**人為更新很容易忘記**。

如果要靠應用層每次更新資料時都記得設 `updated_at = now()`，一定會有疏漏。也許某個 API 忘記寫，或是直接用 SQL 修改資料時沒注意。時間一久，`updated_at` 就不可信了。

PostgreSQL 可以用**觸發器（trigger）**來自動處理。每次執行 `UPDATE` 語句時，觸發器會自動把 `updated_at` 設成當前時間。這樣不管是從應用層還是直接用 SQL 修改，都能確保 `updated_at` 永遠是正確的。

不過要注意一點：如果只是查詢資料，或是更新了但內容沒變（比如 `username` 本來就是 'john'，又設成 'john'），到底要不要更新 `updated_at` 呢？這要看業務需求。通常我們會選擇「只要執行了 UPDATE 就更新時間戳」，因為實作簡單，而且能反映「有人嘗試修改」這個事實。

---

### 7. [Junior] 唯一約束

`orders` 表中的 `order_number` 有 unique 約束。請說明為什麼訂單編號需要唯一性？如果沒有這個約束會發生什麼問題？

**解答：**

訂單編號必須唯一，這是非常基本但很重要的需求。

從**業務邏輯**來看，訂單編號就像是訂單的「身分證字號」。使用者查詢訂單、客服處理問題、金流對帳，都是靠這個編號來找到對應的訂單。如果有兩筆訂單用同樣的編號，整個系統就亂了：

- 使用者查詢時會看到錯誤的訂單資料
- 客服可能會處理到別人的訂單
- 金流回調時不知道要更新哪一筆訂單

從**技術層面**來看，訂單編號通常是對外顯示的識別碼。它的格式可能是 `{timestamp}{userId}{randomCode}`，設計上就是要確保唯一性。但光靠應用層的邏輯產生「理論上不重複」的編號是不夠的，因為：

第一，**可能有 bug**。也許亂數產生器有問題，或是時間戳精度不夠，導致高併發時產生重複的編號。

第二，**併發場景下的競爭條件（race condition）**。假設兩個請求同時建立訂單，都先查詢「這個編號是否存在」，都得到「不存在」的結果，然後都插入同樣的編號。

如果在資料庫加上 unique 約束，這些問題都能被擋下來。就算應用層有 bug，資料庫也會拒絕插入重複的編號，並回傳錯誤。應用層收到錯誤後可以重新產生編號再試一次。

如果**沒有這個約束**會怎樣？

最直接的問題是**資料完整性受損**。訂單編號重複後，所有依賴這個編號的功能都會出錯。更糟的是，這種錯誤可能不會馬上被發現，而是在幾天甚至幾週後才爆發——比如月底對帳時發現金額對不上，追查原因才發現有重複訂單編號。

另外，`order_number` 上的 unique 約束也會自動建立一個索引，這讓我們可以快速用訂單編號查詢訂單。如果沒有這個約束和索引，每次查詢都要全表掃描，效能會很差。

所以這個 unique 約束不只是防範錯誤，也是效能優化的一部分。這種「業務邏輯上必須唯一」的欄位，一定要在資料庫層級加上約束，而不是只靠應用層控制。

---

### 8. [Junior] 複合索引基礎

`chapters` 表中有一個複合唯一索引 `(journey_id, order_index)`。請說明這個索引的目的是什麼？它能防止什麼樣的資料錯誤？

**解答：**

這個複合唯一索引的目的是確保「在同一個旅程裡面，章節的順序不能重複」。

每個章節都有一個 `order_index` 來決定它的排列順序，比如第 1 章、第 2 章、第 3 章。如果同一個旅程裡有兩個章節都是「第 2 章」，那學生看課程的時候就不知道該看哪一個了。

這個索引防止的資料錯誤具體來說是：

**第一種情況：插入重複的順序**
假設旅程 A 已經有一個章節的 `order_index = 2`，如果又要插入另一個章節，`journey_id = A` 且 `order_index = 2`，資料庫會拒絕這個操作。應用層就會知道「這個位置已經有章節了」，要嘛換一個順序，要嘛先調整既有章節的順序。

**第二種情況：併發更新導致的衝突**
假設有兩個管理員同時在編輯同一個旅程的章節順序。A 管理員想把「物件導向」這章移到第 2 位，B 管理員也想把「資料結構」這章移到第 2 位。如果沒有這個約束，可能兩個章節都會成功更新，結果兩個都變成第 2 章。有了這個約束，第二個更新會失敗，應用層可以提示使用者「順序已被其他人修改，請重新整理後再試」。

這裡有個重點：為什麼是**複合索引** `(journey_id, order_index)` 而不是只有 `order_index`？

因為 `order_index` 是在「每個旅程內部」才需要唯一，而不是全域唯一。旅程 A 可以有第 1 章，旅程 B 也可以有第 1 章，這是合理的。但旅程 A 不能有兩個第 1 章。

所以這個複合索引的語意是：「`(journey_id, order_index)` 這個組合必須唯一」。

另外，這個索引除了保證資料完整性，還能**加速查詢**。當我們要顯示某個旅程的所有章節並按順序排列時，可以下這樣的 SQL：

```sql
SELECT * FROM chapters
WHERE journey_id = ? AND deleted_at IS NULL
ORDER BY order_index
```

因為有 `(journey_id, order_index)` 的索引，資料庫可以非常高效地執行這個查詢，不需要額外的排序操作。

---

### 9. [Junior] Decimal 精度

`journeys` 表的 `price` 欄位使用 `decimal(10,2)` 類型。請說明為什麼儲存金額要用 `decimal` 而不是 `float` 或 `double`？`(10,2)` 分別代表什麼意思？

**解答：**

用 `decimal` 來存金額是處理財務資料的**黃金法則**，原因很簡單：**浮點數會有精度誤差**。

`float` 和 `double` 是浮點數類型，它們用科學記號的方式儲存數字，可以表示很大或很小的數值，但代價是**無法精確表示某些小數**。

舉個例子，0.1 用二進位浮點數表示時，會變成一個無限循環小數，必須截斷。所以如果你用 `float` 存 0.1，實際儲存的可能是 0.10000000149。看起來差很小，但如果是金額計算，這個誤差就很致命。

想像一下：

- 課程價格 99.9 元
- 使用者購買了 3 門課程
- 你預期總價是 299.7 元
- 但用 `float` 計算可能得到 299.70001 或 299.69998

這種誤差會導致對帳對不上、使用者看到奇怪的金額（299.70001 元？）、甚至法律問題（多收或少收錢）。

而 `decimal` 是**定點數**類型，它用十進位的方式精確儲存每一位數字。0.1 就是 0.1，不會有誤差。加減乘除的結果也都是精確的。

`decimal(10,2)` 這個定義具體來說：

- **10** 是「精度（precision）」，代表總共可以存 10 位數字（包含小數點前後）
- **2** 是「標度（scale）」，代表小數點後固定 2 位

所以這個欄位可以存的範圍是 `-99999999.99` 到 `99999999.99`。

對一個課程平台來說，最貴的課程可能是幾千元到幾萬元，decimal(10,2) 可以存到 9999 萬多，綽綽有餘。而小數點後 2 位剛好對應「元、角、分」，符合新台幣或美金的計價方式。

如果未來要支援其他幣別（比如日圓不用小數，或是比特幣要 8 位小數），可能要調整這個定義。但對於一般的法幣來說，`(10,2)` 是很標準的選擇。

重點是：**任何涉及金錢的欄位，一律用 `decimal`，絕對不要用 `float` 或 `double`**。這不是效能問題，而是正確性問題。

---

### 10. [Junior] 預設值設計

`user_mission_progress` 表中 `watch_position_seconds` 預設值為 0。請說明為什麼需要設定預設值？在什麼情況下應該使用 NOT NULL + DEFAULT，而不是允許 NULL？

**解答：**

設定預設值主要是為了**簡化應用層邏輯**和**確保資料一致性**。

對於 `watch_position_seconds` 這個欄位，它的語意是「使用者看影片看到第幾秒」。當使用者第一次開始看一個影片任務時，他還沒開始看，所以觀看位置應該是 0 秒。如果沒有設定預設值，應用層在插入進度記錄時就必須明確寫：

```sql
INSERT INTO user_mission_progress (user_id, mission_id, watch_position_seconds)
VALUES (?, ?, 0)
```

但如果設了預設值，就可以省略這個欄位：

```sql
INSERT INTO user_mission_progress (user_id, mission_id)
VALUES (?, ?)
```

資料庫會自動把 `watch_position_seconds` 設成 0。這讓程式碼更簡潔，也減少出錯的機會（比如忘記設定或設成 NULL）。

至於什麼時候應該用 **NOT NULL + DEFAULT**，而不是允許 NULL？

**應該用 NOT NULL + DEFAULT 的情況：**

第一，欄位有**明確的初始狀態**。像 `watch_position_seconds` 的初始值就是 0，`experience_points` 的初始值也是 0，`level` 的初始值是 1。這些欄位不應該是「未知」（NULL），而是有一個合理的起始值。

第二，欄位在**業務邏輯上不能缺少**。比如 `orders.status`，每個訂單一定要有狀態，預設是 UNPAID。如果允許 NULL，程式在處理時就要一直判斷「如果 status 是 NULL 怎麼辦」，這很麻煩也容易出 bug。

第三，要**避免三值邏輯（Three-Valued Logic）**的複雜性。SQL 裡面 NULL 不等於任何值，包括它自己。`NULL = NULL` 是 false，`NULL != 0` 也是 false，而是「未知（unknown）」。這會讓查詢和計算變得很複雜。如果欄位設成 NOT NULL + DEFAULT，就只有「有值」這一種狀態，邏輯簡單得多。

**應該允許 NULL 的情況：**

第一，欄位**真的可能不存在**。像 `journeys.description` 或 `journeys.cover_image_url`，有些課程可能還沒寫描述或上傳封面，這時候 NULL 是合理的語意，表示「目前沒有這個資訊」。

第二，欄位代表**某個時間點的事件**。像 `orders.paid_at` 或 `deleted_at`，訂單剛建立時還沒付款，所以 `paid_at` 就是 NULL。等到付款完成，才會設定時間戳。這種情況不適合用預設值，因為「尚未發生」跟「在某個時間點發生」是兩個不同的狀態。

總結來說：如果欄位在語意上是「有初始值且必須存在」，就用 NOT NULL + DEFAULT；如果是「可能不存在」或「代表事件發生的時間點」，就允許 NULL。這樣設計可以讓資料庫層級就能保證資料的合理性，減少應用層的負擔。

---

## Mid-level (進階題 11-30)

### 11. [Mid-level] 索引效能分析

`users` 表中為 `experience_points` 建立了索引 `idx_users_experience`，註解說明是「用於排行榜查詢」。請分析：

1. 這個索引對排行榜查詢（依經驗值排序）有什麼幫助？
2. 如果排行榜需要同時顯示等級和經驗值排序，是否應該改為複合索引 `(level, experience_points)`？為什麼？
3. 這個索引對使用者經驗值更新操作的效能有什麼影響？

**解答：**

**1. 索引對排行榜查詢的幫助**

排行榜通常要顯示「經驗值最高的前 100 名使用者」，SQL 會是這樣：

```sql
SELECT username, experience_points, level
FROM users
WHERE deleted_at IS NULL
ORDER BY experience_points DESC
LIMIT 100
```

如果沒有索引，資料庫要做全表掃描，把所有使用者都讀出來，然後在記憶體裡排序。假設有 10 萬個使用者，就要處理 10 萬筆資料。

有了 `idx_users_experience` 這個索引，資料庫可以直接從索引的「最右邊」（經驗值最高的）開始往回讀，讀 100 筆就停。不需要掃描全表，也不需要額外排序。查詢速度從秒級降到毫秒級。

**2. 是否需要改成複合索引 (level, experience_points)？**

這要看排行榜的**實際需求**。

如果排行榜是「先按等級、再按經驗值」排序（比如等級 10 的人都排在等級 9 的前面，同等級內再比經驗值），那複合索引 `(level, experience_points)` 就很有用。

但通常排行榜是**只按經驗值排序**，因為經驗值已經包含了等級的資訊。等級 10 的人經驗值一定比等級 9 的人高，所以不需要特別按等級排。

如果改成 `(level, experience_points)`，反而會有問題：

- 查詢只按 `experience_points` 排序時，這個索引的前導欄位是 `level`，就無法有效利用
- 必須改成 `ORDER BY level DESC, experience_points DESC` 才能用到索引

所以除非業務需求真的要「先按等級再按經驗值」，否則單一欄位的 `experience_points` 索引就夠了。

另一個考量是：如果要同時支援「經驗值排行榜」和「等級排行榜」，可以考慮建立兩個索引。但要小心索引太多會影響寫入效能。

**3. 索引對更新操作的影響**

每次使用者完成任務、獲得經驗值時，都要執行：

```sql
UPDATE users
SET experience_points = experience_points + ?, level = ?, updated_at = now()
WHERE id = ?
```

因為 `experience_points` 有索引，更新這個欄位時，資料庫不只要修改表中的資料，還要**維護索引**。

索引是 B-tree 結構，按經驗值排序。當經驗值從 1000 變成 1050，索引中這筆資料的位置可能要改變（從「1000 那一頁」移到「1050 那一頁」）。這需要額外的 I/O 操作。

不過實際上，這個影響不會太大：

- 更新經驗值不是高頻操作（使用者完成任務才會觸發，不是每秒幾千次）
- B-tree 索引的更新效率很高，時間複雜度是 O(log n)
- 排行榜查詢是「讀多寫少」的場景，索引帶來的查詢加速遠大於寫入的成本

如果真的遇到效能瓶頸（比如有活動導致短時間內大量使用者獲得經驗值），可以考慮：

- 把經驗值更新改成批次處理或非同步處理
- 使用 Redis 等快取來儲存排行榜，定期從資料庫同步

---

### 12. [Mid-level] Token 黑名單設計

`access_tokens` 表用於實作 JWT Token 黑名單機制。請分析：

1. 為什麼需要 `expires_at` 和 `invalidated_at` 兩個時間欄位？
2. 如何設計定期清理已過期 token 的機制？
3. 在高併發場景下，這個表可能成為效能瓶頸嗎？如何優化？

**解答：**

**1. 為什麼需要兩個時間欄位？**

這兩個欄位的用途不同：

`expires_at` 是「token 本身的過期時間」，這是 JWT 簽發時就決定的。比如說 token 在 2025-01-01 12:00:00 簽發，有效期 7 天，那 `expires_at` 就是 2025-01-08 12:00:00。這個時間是固定的，不會改變。

`invalidated_at` 是「token 被主動撤銷的時間」，也就是使用者登出的時間。比如使用者在 2025-01-03 14:30:00 按了登出按鈕，這時候我們就把這個 token 的 `token_jti` 和 `invalidated_at` 寫進黑名單表。

這兩個欄位結合起來，可以處理不同的場景：

- **正常登出**：token 還沒到期就被使用者主動登出，`invalidated_at` < `expires_at`
- **自然過期**：token 一直用到過期都沒登出，這種 token 可能不會進入黑名單（看實作方式）
- **清理依據**：我們可以用 `expires_at` 來判斷「這個 token 已經過期了，就算有人拿來用也不會通過驗證，可以從黑名單刪掉了」

**2. 定期清理機制**

已過期的 token 不需要繼續留在黑名單裡，因為驗證時會先檢查過期時間。所以可以定期清理：

```sql
DELETE FROM access_tokens
WHERE expires_at < now() - INTERVAL '7 days'
```

我會多保留 7 天的緩衝，避免時區或時鐘偏移的問題。

具體實作可以用：

- **排程任務（Cron Job）**：每天凌晨 3 點執行一次清理
- **Spring 的 @Scheduled**：在應用層定時執行
- **PostgreSQL 的 pg_cron 擴充套件**：直接在資料庫層執行

另外，schema 裡有 `idx_invalid_tokens_expires` 這個索引，就是為了加速這個清理查詢。

要注意的是，如果黑名單累積了很多資料，一次刪除可能會鎖表。可以改成分批刪除：

```sql
DELETE FROM access_tokens
WHERE id IN (
  SELECT id FROM access_tokens
  WHERE expires_at < now() - INTERVAL '7 days'
  LIMIT 1000
)
```

每次刪 1000 筆，多執行幾次，降低對資料庫的衝擊。

**3. 高併發場景的效能瓶頸與優化**

這個表確實可能成為瓶頸，因為**每次 API 請求都要查詢黑名單**：

```sql
SELECT * FROM access_tokens
WHERE token_jti = ? AND deleted_at IS NULL
```

如果網站有 1000 個同時在線使用者，每秒可能有幾千次查詢。雖然有 `idx_invalid_tokens_jti` 索引，但還是會對資料庫造成壓力。

**優化方案：**

**方案一：使用 Redis 快取**
把黑名單放到 Redis 的 Set 結構裡：

- 登出時：`SADD token_blacklist {jti}`，並設定過期時間
- 驗證時：先查 Redis，如果在黑名單就直接拒絕
- 優點：記憶體操作，速度極快
- 缺點：要處理 Redis 和資料庫的同步問題

**方案二：改用「白名單」而非黑名單**
不記錄「哪些 token 被撤銷了」，而是記錄「哪些 token 是有效的」。但這樣每個 token 都要存，儲存成本更高。

**方案三：縮短 token 有效期**
如果 token 有效期從 7 天改成 1 小時，即使有人偷到 token，損害也有限。這樣就可以不用黑名單，依靠自然過期即可。但使用者體驗會變差（常常需要重新登入）。

**方案四：Refresh Token 機制**
Access Token 有效期短（15 分鐘），Refresh Token 有效期長（7 天）。只有 Refresh Token 需要黑名單，Access Token 不用。因為 Refresh Token 使用頻率低，黑名單查詢壓力就小很多。

我個人會選**方案一（Redis）+ 方案四（Refresh Token）**的組合，這是業界最常見的做法。

---

### 13. [Mid-level] 進度追蹤併發問題

`user_mission_progress` 表記錄影片觀看進度，規格要求每 10 秒更新一次。請思考：

1. 如果使用者在多個裝置同時觀看同一影片，可能會發生什麼資料競爭問題？
2. 應該使用什麼等級的交易隔離層級（Transaction Isolation Level）來處理這種情況？
3. 如何設計更新邏輯，確保進度不會倒退？

**解答：**

**1. 多裝置同時觀看的資料競爭問題**

假設使用者在電腦和手機同時打開同一個影片：

- 電腦上看到第 100 秒，每 10 秒更新一次進度
- 手機上看到第 50 秒，也是每 10 秒更新一次

如果沒有妥善處理，可能發生：

**問題一：進度倒退**

- 電腦在 12:00:00 更新進度為 100 秒
- 手機在 12:00:05 更新進度為 50 秒
- 結果使用者下次打開影片，發現進度退回 50 秒

**問題二：Lost Update（更新遺失）**

- 電腦和手機「同時」讀取進度（假設都是 100 秒）
- 電腦更新為 110 秒
- 手機更新為 60 秒（覆蓋了電腦的更新）
- 最後進度變成 60 秒，電腦的更新遺失了

**問題三：狀態混亂**
如果進度接近完成，電腦標記為 COMPLETED，但手機還在看前半段，可能會互相衝突。

**2. 應該使用什麼交易隔離層級？**

PostgreSQL 預設的交易隔離層級是 **Read Committed**，對這個場景來說其實就夠用了。

但重點不是交易隔離層級，而是要用**樂觀鎖定（Optimistic Locking）**或**比較後更新（Compare-and-Set）**。

如果想用資料庫層級的鎖，可以用 **SELECT ... FOR UPDATE**（悲觀鎖）：

```sql
BEGIN;
SELECT * FROM user_mission_progress
WHERE user_id = ? AND mission_id = ?
FOR UPDATE;

-- 在這裡做業務邏輯判斷

UPDATE user_mission_progress
SET watch_position_seconds = ?, updated_at = now()
WHERE user_id = ? AND mission_id = ?;

COMMIT;
```

這樣第二個裝置的更新會等待第一個完成，避免衝突。但這會降低併發效能。

更好的做法是用**應用層邏輯**，不依賴交易隔離層級。

**3. 確保進度不會倒退的設計**

**方案一：取最大值**
更新時只接受「比現有進度更大」的值：

```sql
UPDATE user_mission_progress
SET watch_position_seconds = GREATEST(watch_position_seconds, ?),
    updated_at = now()
WHERE user_id = ? AND mission_id = ?
```

這樣不管哪個裝置先更新，進度永遠往前走。但可能有個問題：如果使用者想「重看」某個段落，進度會卡住。

**方案二：帶時間戳的比較**
除了記錄進度，還記錄「最後更新時間」和「客戶端時間戳」：

```sql
UPDATE user_mission_progress
SET watch_position_seconds = ?,
    updated_at = now()
WHERE user_id = ? AND mission_id = ?
  AND (updated_at < ? OR watch_position_seconds < ?)
```

只有當「更新時間更晚」或「進度更大」時才接受更新。

**方案三：以最後更新的裝置為準**
前端每次更新時帶一個「客戶端序號」或「會話 ID」，後端記錄「最後更新是來自哪個裝置」。如果切換裝置，就以新裝置的進度為準。

這樣使用者在電腦看到 100 秒，切到手機時會從 100 秒繼續；如果又切回電腦，就從手機的進度繼續。

**我的建議：**

- 用「取最大值」的方式避免進度倒退
- 前端在讀取進度時，如果發現本地播放位置 > 伺服器進度，就以本地為準（可能是同步延遲）
- 如果使用者真的想重看，可以提供「重設進度」的按鈕

這樣既簡單又實用，不需要複雜的鎖機制。

---

### 14. [Mid-level] 複合索引順序

`orders` 表有一個複合索引 `(user_id, status)`，註解說明用於「查詢使用者的訂單狀態」。請分析：

1. 索引欄位的順序 `(user_id, status)` 是否合理？如果改成 `(status, user_id)` 會有什麼差異？
2. 這個索引能否支援「查詢特定使用者的所有訂單」？
3. 這個索引能否支援「查詢所有未付款訂單」？

**解答：**

**1. 索引順序 (user_id, status) 是否合理？**

這個順序是**合理的**，而且是最佳選擇。

複合索引的原則是：**選擇性高的欄位放前面，查詢條件常用的欄位放前面**。

`user_id` 的選擇性非常高，假設有 10 萬個使用者，`user_id` 就有 10 萬個不同的值。而 `status` 只有 3 個值（UNPAID、PAID、EXPIRED），選擇性很低。

最常見的查詢場景是「查詢某個使用者的某個狀態的訂單」：

```sql
SELECT * FROM orders
WHERE user_id = 123 AND status = 'UNPAID'
```

用 `(user_id, status)` 索引：

1. 先用 `user_id = 123` 快速定位到這個使用者的所有訂單（可能 10 筆）
2. 再在這 10 筆裡找 `status = 'UNPAID'` 的（可能 2 筆）

如果改成 `(status, user_id)`：

1. 先找 `status = 'UNPAID'` 的所有訂單（可能有 5 萬筆）
2. 再在這 5 萬筆裡找 `user_id = 123` 的（最後還是 2 筆）

顯然前者效率高得多。

另一個考量是**索引的「前綴查詢」規則**。複合索引 `(user_id, status)` 可以支援：

- `WHERE user_id = ?`（用到索引的第一個欄位）
- `WHERE user_id = ? AND status = ?`（用到兩個欄位）

但不能支援：

- `WHERE status = ?`（跳過了第一個欄位）

所以 `(user_id, status)` 的順序讓索引的適用性更廣。

**2. 能否支援「查詢特定使用者的所有訂單」？**

可以！

```sql
SELECT * FROM orders
WHERE user_id = 123 AND deleted_at IS NULL
```

這個查詢只用到 `user_id` 條件，而 `(user_id, status)` 索引的第一個欄位就是 `user_id`，所以可以有效利用索引的前綴。

資料庫會用索引快速找到 `user_id = 123` 的所有訂單，然後再過濾 `deleted_at IS NULL`。

**3. 能否支援「查詢所有未付款訂單」？**

**不能有效利用這個索引。**

```sql
SELECT * FROM orders
WHERE status = 'UNPAID' AND deleted_at IS NULL
```

這個查詢只有 `status` 條件，但索引的第一個欄位是 `user_id`。根據複合索引的前綴規則，如果查詢條件不包含第一個欄位，索引就無法使用（或只能做全索引掃描，效率低）。

好在 schema 裡還有一個**單獨的** `idx_orders_status` 索引，專門用來處理這種查詢。所以這個場景還是有優化的。

**總結：**

- `(user_id, status)` 索引：支援「特定使用者 + 特定狀態」和「特定使用者的所有訂單」
- `status` 索引：支援「所有特定狀態的訂單」
- 兩個索引互補，覆蓋了常見的查詢場景

這就是為什麼 schema 裡同時有這兩個索引。每個索引都有自己的用途，不是重複的。

---

### 15. [Mid-level] 訂單過期機制

`orders` 表中 `expired_at` 欄位用於標記訂單過期時間（建立後 3 天）。請設計：

1. 如何實作定期檢查並更新過期訂單的機制？
2. 這個定期任務應該多久執行一次？考量點是什麼？
3. 如果過期訂單數量很大，如何避免單次更新造成資料庫負擔？

**解答：**

**1. 定期檢查並更新過期訂單的機制**

首先，訂單建立時就要設定 `expired_at`：

```sql
INSERT INTO orders (order_number, user_id, status, expired_at, ...)
VALUES (?, ?, 'UNPAID', now() + INTERVAL '3 days', ...)
```

然後用排程任務定期執行這個更新：

```sql
UPDATE orders
SET status = 'EXPIRED', updated_at = now()
WHERE status = 'UNPAID'
  AND expired_at < now()
  AND deleted_at IS NULL
```

這個 SQL 會找出所有「未付款」且「已超過過期時間」的訂單，把狀態改成 EXPIRED。

實作方式可以用：

- **Spring 的 @Scheduled**：

  ```java
  @Scheduled(cron = "0 */10 * * * *") // 每 10 分鐘執行一次
  public void expireOrders() {
      orderRepository.expireUnpaidOrders();
  }
  ```

- **獨立的排程服務**（如 Quartz、Jenkins、Linux Cron）

Schema 裡的 `idx_orders_expired_at` 索引就是為了加速這個查詢。

**2. 任務應該多久執行一次？**

這要看**業務需求的時效性**。

如果訂單過期後「立刻」就不能付款了，那任務要頻繁執行（比如每 1 分鐘）。但這會增加資料庫負擔。

如果可以容忍一定的延遲（比如過期後 10 分鐘內還能付款），就可以每 10 分鐘執行一次。

我的建議是 **每 10 分鐘或每 30 分鐘執行一次**，原因：

- 訂單有效期是 3 天（72 小時），幾分鐘的誤差不會有太大影響
- 降低資料庫負擔，避免頻繁的寫入操作
- 使用者通常不會「剛好在過期那一秒」去付款

另一個重點是**避開高峰時段**。如果發現每天晚上 8-10 點是下單高峰，就不要在這時候跑過期任務，改在凌晨或白天流量低的時候執行。

**3. 避免大量更新造成負擔**

如果系統累積了幾萬筆未付款訂單，一次全部更新可能會：

- 長時間鎖住表或索引
- 產生大量的 WAL（Write-Ahead Log），影響資料庫效能
- 導致其他查詢變慢

**優化方案：**

**方案一：分批更新**

```sql
UPDATE orders
SET status = 'EXPIRED', updated_at = now()
WHERE id IN (
  SELECT id FROM orders
  WHERE status = 'UNPAID'
    AND expired_at < now()
    AND deleted_at IS NULL
  LIMIT 500
)
```

每次只更新 500 筆，執行多次。兩次執行之間可以 sleep 一小段時間（比如 100ms），讓資料庫有喘息空間。

**方案二：只更新「快要被查詢到的」訂單**
如果使用者不查詢，訂單狀態是 UNPAID 還是 EXPIRED 其實沒差。可以改成「Lazy Update」：

- 排程任務只更新「最近 7 天內的過期訂單」
- 更舊的訂單在使用者查詢時才更新（或直接在應用層判斷）

**方案三：加上時間範圍限制**

```sql
UPDATE orders
SET status = 'EXPIRED', updated_at = now()
WHERE status = 'UNPAID'
  AND expired_at BETWEEN now() - INTERVAL '1 day' AND now()
  AND deleted_at IS NULL
```

只更新「過去 24 小時內過期的訂單」，避免每次都掃描所有歷史訂單。

**方案四：使用 PostgreSQL 的 SKIP LOCKED**
如果有多個 worker 同時執行過期任務（分散式部署），可以用 SKIP LOCKED 避免鎖等待：

```sql
UPDATE orders
SET status = 'EXPIRED', updated_at = now()
WHERE id IN (
  SELECT id FROM orders
  WHERE status = 'UNPAID' AND expired_at < now()
  LIMIT 500
  FOR UPDATE SKIP LOCKED
)
```

**我的建議：**
結合方案一和方案三，每次更新「過去 24 小時內過期的訂單，最多 1000 筆」。這樣既能及時處理，又不會對資料庫造成太大壓力。

---

### 16. [Mid-level] 價格快照設計

`order_items` 表中同時儲存了 `original_price`、`discount` 和 `price`。請分析：

1. 為什麼需要在訂單中「快照」課程價格，而不是關聯到 `journeys.price`？
2. 這種設計屬於正規化還是反正規化？有什麼取捨？
3. 如果未來需要支援「價格歷史查詢」功能，應該如何設計？

**解答：**

**1. 為什麼需要價格快照？**

這是一個非常重要的業務邏輯問題。

假設今天某個課程原價 1000 元，使用者下單時享有 9 折優惠，實付 900 元。訂單建立了，但使用者還沒付款。

過了兩天，課程漲價到 1500 元。如果訂單不儲存價格快照，而是每次都去查 `journeys.price`，會發生什麼？

- 使用者看到自己的訂單變成 1500 元，覺得被詐騙
- 或者更糟：他付了 900 元，但系統顯示課程現在 1500 元，對帳會亂掉
- 財務報表也會不準確，因為歷史訂單的金額一直在變

**價格快照的核心原則是：訂單建立時的價格就是合約價格**。

不管後來課程怎麼調價、打折、促銷，都不影響已經建立的訂單。這是**業務穩定性**和**法律義務**的要求。

另外，還有一些實務考量：

- **課程可能會被刪除**（軟刪除）。如果沒有快照，歷史訂單就找不到價格資料了
- **折扣邏輯可能很複雜**。比如「雙 11 全站 8 折」、「會員專屬優惠」、「早鳥價」等等。這些規則會隨時間改變，如果不快照，就無法還原「當時是怎麼算出這個價格的」
- **對帳和退款**。如果使用者要退款，要退多少錢？必須以訂單的快照價格為準

**2. 這是正規化還是反正規化？**

這是**反正規化（Denormalization）**的設計。

在完全正規化的設計裡，價格資訊應該只存在 `journeys.price` 一個地方，訂單透過 `journey_id` 關聯去查詢。但這裡我們刻意「重複儲存」價格，造成資料冗餘。

**取捨分析：**

**優點：**

- **資料穩定性**：歷史訂單不受課程調價影響
- **查詢效能**：顯示訂單明細時不需要 JOIN `journeys` 表
- **業務正確性**：符合商業邏輯和法律要求
- **解耦**：訂單系統不依賴課程系統的即時資料

**缺點：**

- **資料冗餘**：同一個課程在不同訂單中可能有不同價格（雖然這正是我們想要的）
- **儲存空間**：每筆訂單明細都要存三個價格欄位（original_price、discount、price）
- **維護成本**：要確保訂單建立時正確複製價格

但在這個場景下，**優點遠大於缺點**。這是「該反正規化的時候就要反正規化」的典型案例。

**3. 如果需要支援價格歷史查詢**

如果要記錄「課程的價格變化歷史」（比如管理員想看「這門課在過去一年的定價變化」），可以這樣設計：

**方案一：建立價格歷史表**

```sql
Table journey_price_history {
  id bigserial [primary key]
  journey_id bigint [not null, ref: > journeys.id]
  price decimal(10,2) [not null]
  effective_from timestamp [not null, note: '生效起始時間']
  effective_to timestamp [null, note: '生效結束時間，NULL 表示目前有效']
  created_at timestamp [not null]
}
```

每次課程調價時：

1. 把目前價格記錄的 `effective_to` 設成現在時間
2. 插入新的價格記錄，`effective_from` 設為現在，`effective_to` 設為 NULL

查詢「某個時間點的課程價格」：

```sql
SELECT price FROM journey_price_history
WHERE journey_id = ?
  AND effective_from <= ?
  AND (effective_to IS NULL OR effective_to > ?)
```

**方案二：使用 PostgreSQL 的時態表（Temporal Tables）**

利用 `tstzrange` 類型記錄價格的有效期間，可以更優雅地處理時間範圍查詢。

**方案三：結合訂單資料反推**

如果不想建新表，也可以從 `order_items` 反推價格歷史：

```sql
SELECT DISTINCT original_price, created_at
FROM order_items
WHERE journey_id = ?
ORDER BY created_at
```

雖然不夠精確（只有「有人下單的時間點」的價格），但對於簡單的分析可能夠用。

**我的建議：**
如果真的需要完整的價格歷史追蹤，建議用方案一（價格歷史表）。但要注意，`order_items` 的價格快照還是必須保留，兩者用途不同：

- 價格歷史表：記錄課程定價的「官方變更」
- 訂單快照：記錄「某筆交易的實際價格」（可能有折扣、優惠券等）

---

### 17. [Mid-level] 資料完整性保證

當使用者付款完成訂單時，需要同時：

1. 更新 `orders.status` 為 PAID
2. 設定 `orders.paid_at`
3. 在 `user_journeys` 中建立擁有權記錄

請說明應該使用什麼策略來確保這些操作的原子性？如果中間某個步驟失敗，應該如何處理？

**解答：**

這是一個經典的**資料一致性問題**，必須確保「付款成功」這個業務操作在資料庫層面是原子性的。

**策略：使用資料庫交易（Transaction）**

所有操作必須包在一個交易裡：

```java
@Transactional
public void completePayment(Long orderId) {
    // 1. 更新訂單狀態
    orderRepository.updateOrderStatus(orderId, OrderStatus.PAID, Instant.now());

    // 2. 查詢訂單明細
    List<OrderItem> items = orderItemRepository.findByOrderId(orderId);

    // 3. 為每個課程建立擁有權記錄
    for (OrderItem item : items) {
        userJourneyRepository.create(
            order.getUserId(),
            item.getJourneyId(),
            orderId,
            Instant.now()
        );
    }
}
```

在 Spring Boot 中，`@Transactional` 註解會確保：

- 所有操作在同一個交易內執行
- 全部成功才提交（COMMIT）
- 任何一步失敗就全部回滾（ROLLBACK）

**具體的 SQL 執行流程：**

```sql
BEGIN;

-- 步驟 1: 更新訂單狀態
UPDATE orders
SET status = 'PAID', paid_at = now(), updated_at = now()
WHERE id = ? AND status = 'UNPAID';

-- 檢查影響行數，確保訂單存在且狀態正確
-- 如果影響 0 行，表示訂單不存在或已付款，拋出異常

-- 步驟 2: 查詢訂單明細
SELECT journey_id, user_id FROM order_items
WHERE order_id = ?;

-- 步驟 3: 建立課程擁有權（可能有多筆）
INSERT INTO user_journeys (user_id, journey_id, order_id, purchased_at, created_at)
VALUES (?, ?, ?, now(), now());

-- 如果一切順利
COMMIT;

-- 如果任何步驟失敗
ROLLBACK;
```

**可能的失敗情況與處理：**

**失敗情況 1：訂單狀態已經是 PAID**

- 原因：重複的付款通知（支付網關可能重試）
- 處理：在 UPDATE 時加上 `WHERE status = 'UNPAID'`，如果影響 0 行，檢查訂單是否已付款。如果已付款就回傳成功（冪等性），否則拋出異常
- 結果：交易回滾，但不影響資料

**失敗情況 2：user_journeys 唯一約束衝突**

- 原因：使用者已經擁有這門課程（可能之前買過）
- 處理：這應該在建立訂單時就檢查，但如果真的發生，可以：
  - 跳過已擁有的課程（只新增其他課程）
  - 或回滾整個交易，要求使用者處理
- 結果：取決於業務邏輯

**失敗情況 3：資料庫連線中斷**

- 原因：網路問題、資料庫重啟等
- 處理：交易會自動回滾，應用層捕獲異常後可以重試
- 結果：資料保持一致，沒有「付了錢但沒拿到課程」的情況

**額外的保護措施：**

**1. 樂觀鎖（Optimistic Locking）**
使用 `updated_at` 作為版本號：

```sql
UPDATE orders
SET status = 'PAID', paid_at = now(), updated_at = now()
WHERE id = ? AND status = 'UNPAID' AND updated_at = ?
```

如果在查詢和更新之間有其他操作修改了訂單，`updated_at` 會對不上，更新失敗。

**2. 悲觀鎖（Pessimistic Locking）**
在交易開始時鎖住訂單：

```sql
BEGIN;
SELECT * FROM orders WHERE id = ? FOR UPDATE;
-- 其他操作...
COMMIT;
```

這樣同一時間只有一個交易能處理這筆訂單，避免併發問題。

**3. 冪等性設計**
支付網關的回調可能會重複發送，所以要確保「多次呼叫 completePayment 不會造成重複扣款或重複建立擁有權」：

- 用訂單編號作為冪等鍵
- 如果訂單已經是 PAID 狀態，直接回傳成功
- 如果 user_journeys 已存在，視為正常（用 INSERT ... ON CONFLICT DO NOTHING）

**我的建議：**

- 使用 `@Transactional` 包裹整個付款流程
- 加上訂單狀態檢查（`WHERE status = 'UNPAID'`）
- 實作冪等性邏輯，應對重複通知
- 記錄詳細日誌，方便追蹤問題

這樣就能確保「要嘛全部成功，要嘛全部失敗」，不會出現資料不一致的情況。

---

### 18. [Mid-level] 查詢優化

請為以下查詢場景設計最佳索引策略：「查詢使用者 A 在課程 B 中所有已完成但尚未交付的任務」

涉及的表：`user_mission_progress`, `missions`, `chapters`

請說明：

1. 需要哪些索引？
2. 索引欄位的順序應該如何安排？
3. 是否需要考慮覆蓋索引（Covering Index）？

**解答：**

先來理解這個查詢的需求。「使用者 A 在課程 B 中所有已完成但尚未交付的任務」，意思是：

- 找出課程 B 的所有任務
- 篩選出使用者 A 的進度記錄
- 狀態是 COMPLETED（已完成但尚未交付）

**完整的 SQL 查詢：**

```sql
SELECT m.id, m.title, m.type, ump.watch_position_seconds
FROM missions m
JOIN chapters c ON m.chapter_id = c.id
JOIN user_mission_progress ump ON ump.mission_id = m.id
WHERE c.journey_id = ?  -- 課程 B
  AND ump.user_id = ?   -- 使用者 A
  AND ump.status = 'COMPLETED'
  AND c.deleted_at IS NULL
  AND m.deleted_at IS NULL
  AND ump.deleted_at IS NULL
ORDER BY c.order_index, m.order_index
```

**1. 需要哪些索引？**

目前 schema 裡已經有的索引：

- `user_mission_progress` 表：

  - `(user_id, mission_id)` 唯一索引
  - `user_id` 索引
  - `mission_id` 索引
  - `status` 索引

- `missions` 表：

  - `(chapter_id, order_index)` 唯一索引

- `chapters` 表：
  - `(journey_id, order_index)` 唯一索引

**需要新增或優化的索引：**

**關鍵索引：`user_mission_progress (user_id, status)`**

```sql
CREATE INDEX idx_progress_user_status
ON user_mission_progress (user_id, status)
WHERE deleted_at IS NULL;
```

這個索引可以快速找到「某使用者的某狀態的所有進度記錄」。用 Partial Index 只索引未刪除的資料，節省空間。

**2. 索引欄位順序**

對於 `user_mission_progress`，應該用 **(user_id, status)** 而不是 (status, user_id)，理由是：

- `user_id` 的選擇性遠高於 `status`（假設 10 萬使用者 vs 3 種狀態）
- 先用 `user_id` 篩選出這個使用者的所有進度（可能幾百筆）
- 再從中找 `status = 'COMPLETED'` 的（可能幾十筆）

這比「先找所有 COMPLETED 的進度（可能幾萬筆），再找特定使用者的」高效得多。

**查詢執行計畫分析：**

```sql
-- 執行流程：
1. 使用 chapters 的 (journey_id, order_index) 索引
   找出課程 B 的所有章節（假設 10 個章節）

2. 使用 missions 的 (chapter_id, order_index) 索引
   找出這些章節的所有任務（假設 200 個任務）

3. 使用 user_mission_progress 的 (user_id, status) 索引
   找出使用者 A 狀態為 COMPLETED 的進度記錄（假設 50 筆）

4. JOIN 這些結果，找出交集（假設 5 筆）
```

**3. 是否需要覆蓋索引（Covering Index）？**

**覆蓋索引**是指索引包含了查詢所需的所有欄位，這樣資料庫可以「只掃描索引，不需要回表」。

對於這個查詢，可以考慮：

**選項 1：為 user_mission_progress 建立覆蓋索引**

```sql
CREATE INDEX idx_progress_covering
ON user_mission_progress (user_id, status, mission_id, watch_position_seconds)
WHERE deleted_at IS NULL;
```

這樣查詢 `user_mission_progress` 時完全不需要回表。

**但要評估成本：**

- 索引會變大（多了 `watch_position_seconds` 欄位）
- 每次更新進度都要維護這個索引
- 如果查詢頻率不高，可能不划算

**選項 2：局部覆蓋索引**
只在主要的篩選條件上建索引：

```sql
CREATE INDEX idx_progress_user_status_mission
ON user_mission_progress (user_id, status, mission_id)
WHERE deleted_at IS NULL;
```

這樣 `mission_id` 也在索引裡，JOIN 時更高效，但 `watch_position_seconds` 還是要回表查。

**我的建議：**

**基本配置（必要）：**

```sql
-- 如果 schema 裡沒有，就新增這個
CREATE INDEX idx_progress_user_status
ON user_mission_progress (user_id, status)
WHERE deleted_at IS NULL;
```

**進階優化（如果這個查詢很頻繁）：**

```sql
CREATE INDEX idx_progress_covering
ON user_mission_progress (user_id, status, mission_id, watch_position_seconds)
WHERE deleted_at IS NULL;
```

**查詢改寫建議：**
如果發現效能還不夠，可以考慮改成兩步查詢：

```sql
-- 步驟 1：先找出課程 B 的所有任務 ID（可以快取）
WITH course_missions AS (
  SELECT m.id
  FROM missions m
  JOIN chapters c ON m.chapter_id = c.id
  WHERE c.journey_id = ? AND c.deleted_at IS NULL AND m.deleted_at IS NULL
)

-- 步驟 2：找出使用者的 COMPLETED 進度
SELECT ump.*, m.title, m.type
FROM user_mission_progress ump
JOIN course_missions cm ON cm.id = ump.mission_id
JOIN missions m ON m.id = ump.mission_id
WHERE ump.user_id = ?
  AND ump.status = 'COMPLETED'
  AND ump.deleted_at IS NULL
```

這樣可以充分利用 `(user_id, status)` 索引。

---

### 19. [Mid-level] 軟刪除索引策略

所有資料表都有 `deleted_at` 欄位進行軟刪除。請思考：

1. 查詢時需要加上 `WHERE deleted_at IS NULL` 條件，這對索引使用有什麼影響？
2. 是否應該為 `deleted_at` 欄位建立索引？
3. 如何設計局部索引（Partial Index）來優化軟刪除場景的查詢效能？

**解答：**

軟刪除是個實用的設計，但確實會給查詢和索引帶來額外複雜度。

**1. `WHERE deleted_at IS NULL` 對索引使用的影響**

假設我們有個查詢：

```sql
SELECT * FROM users WHERE username = 'john' AND deleted_at IS NULL;
```

如果只有 `username` 的索引，資料庫會：

1. 用索引找到所有 `username = 'john'` 的記錄
2. 然後逐一檢查 `deleted_at IS NULL`（回表查詢）

這有兩個問題：

**問題 1：索引包含已刪除的資料**
假設使用者 'john' 刪除帳號又重新註冊了 3 次，`users` 表裡有 4 筆 `username = 'john'` 的記錄（1 筆有效、3 筆已刪除）。索引會找出全部 4 筆，然後再過濾出那 1 筆有效的。

**問題 2：無法充分利用索引**
如果查詢是：

```sql
SELECT * FROM users WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 10;
```

即使 `created_at` 有索引，資料庫可能還是要全表掃描，因為它不知道「未刪除的資料」在索引中的位置。

**2. 是否應該為 deleted_at 建立索引？**

**單獨的 `deleted_at` 索引通常不是好主意**，理由如下：

**原因 1：選擇性極低**
大部分資料都是 `deleted_at IS NULL`（未刪除），只有少數是已刪除。這個欄位的選擇性非常低，單獨建索引效果不好。

**原因 2：NULL 值的索引特性**
在 PostgreSQL 中，B-tree 索引會包含 NULL 值，但 `deleted_at IS NULL` 這種查詢可能無法有效利用索引（取決於統計資訊和查詢計畫）。

**原因 3：佔用空間**
如果大部分資料都是未刪除的，索引會包含大量的 NULL 值，浪費空間。

**更好的做法是用「複合索引 + Partial Index」。**

**3. 局部索引（Partial Index）優化策略**

PostgreSQL 支援 **Partial Index（局部索引）**，可以只對符合條件的資料建立索引。

**策略 1：在現有索引上加 WHERE 條件**

與其建立：

```sql
CREATE INDEX idx_users_username ON users (username);
```

不如建立：

```sql
CREATE INDEX idx_users_username_active
ON users (username)
WHERE deleted_at IS NULL;
```

這個索引**只包含未刪除的使用者**，有幾個優點：

- 索引更小（不包含已刪除的資料）
- 查詢更快（不需要過濾已刪除的記錄）
- 維護成本更低（刪除資料時不需要更新索引）

**策略 2：為常用查詢建立特定的 Partial Index**

例如，查詢「經驗值排行榜」時：

```sql
CREATE INDEX idx_users_experience_active
ON users (experience_points DESC)
WHERE deleted_at IS NULL;
```

這樣排行榜查詢可以直接用這個索引，不需要額外的過濾。

**策略 3：複合索引 + Partial Index**

對於 `orders` 表，與其：

```sql
CREATE INDEX idx_orders_user_status ON orders (user_id, status);
```

可以改成：

```sql
CREATE INDEX idx_orders_user_status_active
ON orders (user_id, status)
WHERE deleted_at IS NULL;
```

**實務建議：**

**1. 檢視現有 schema 的索引**
看看 `db-schema.dbml` 裡的索引，幾乎所有查詢都會加 `deleted_at IS NULL`。應該把現有索引都改成 Partial Index。

例如：

```sql
-- 原本
indexes {
  username [unique]
  experience_points [name: 'idx_users_experience']
}

-- 改成
indexes {
  username [unique, where: 'deleted_at IS NULL']
  experience_points [name: 'idx_users_experience', where: 'deleted_at IS NULL']
}
```

**2. 只在「查詢已刪除資料」時才需要完整索引**
如果有管理後台要「查看所有已刪除的訂單」，可以另外建立：

```sql
CREATE INDEX idx_orders_deleted
ON orders (deleted_at)
WHERE deleted_at IS NOT NULL;
```

這個索引只包含已刪除的資料，很小而且高效。

**3. 應用層的最佳實踐**
在 JPA/Hibernate 中，可以用 `@Where` 註解自動加上軟刪除條件：

```java
@Entity
@Where(clause = "deleted_at IS NULL")
public class User {
    // ...
}
```

這樣所有查詢都會自動加上這個條件，不會遺漏。

**總結：**

- 不要為 `deleted_at` 單獨建索引
- 把所有常用索引改成 Partial Index（WHERE deleted_at IS NULL）
- 索引會更小、更快、維護成本更低
- 這是 PostgreSQL 的強大功能，一定要善用

---

### 20. [Mid-level] 任務資源多型設計

`mission_resources` 表使用 `resource_type` 區分影片、文章、表單等不同資源類型，並且 `resource_url` 和 `resource_content` 都是可選的。請評估：

1. 這種「單表多型」設計的優缺點是什麼？
2. 相較於為每種資源類型建立獨立的表（如 `video_resources`, `article_resources`），哪種設計更合適？
3. 如何確保資料的完整性約束（例如影片必須有 URL 和 duration_seconds）？

**解答：**

這是一個經典的「多型資料建模」問題。

**1. 單表多型設計的優缺點**

**優點：**

**第一：Schema 簡單、擴展容易**
如果未來要新增新的資源類型（比如 PDF、音訊、互動式程式碼編輯器），只需要：

- 在 Enum 裡加一個新值
- 應用層加對應的處理邏輯
- 不需要建新表、不需要資料庫遷移

**第二：查詢方便**
要找「某個任務的所有資源」很簡單：

```sql
SELECT * FROM mission_resources
WHERE mission_id = ? AND deleted_at IS NULL
ORDER BY content_order
```

不需要 UNION 多個表。

**第三：統一的介面**
應用層可以用同一個 Repository 處理所有資源類型，程式碼更乾淨：

```java
List<MissionResource> resources = missionResourceRepository.findByMissionId(missionId);
for (MissionResource resource : resources) {
    switch (resource.getResourceType()) {
        case VIDEO -> renderVideo(resource);
        case ARTICLE -> renderArticle(resource);
        case FORM -> renderForm(resource);
    }
}
```

**缺點：**

**第一：欄位語意模糊**
`resource_url` 和 `resource_content` 都是可選的，但實際上：

- 影片必須有 `resource_url` 和 `duration_seconds`
- 文章可以有 `resource_content`（Markdown 內容）或 `resource_url`（外部連結）
- 表單必須有 `resource_url`（Google Form 連結）

這些規則無法在資料庫層級強制執行，只能靠應用層驗證。

**第二：空間浪費**
每筆資料都有 `resource_url`、`resource_content`、`duration_seconds` 三個欄位，但同時最多只用到兩個。如果資料量很大，會有一定的空間浪費。

**第三：查詢效率可能較低**
如果要「找出所有時長超過 10 分鐘的影片資源」：

```sql
SELECT * FROM mission_resources
WHERE resource_type = 'VIDEO'
  AND duration_seconds > 600
  AND deleted_at IS NULL
```

需要先掃描整個表（或用 `resource_type` 索引），然後再過濾 `duration_seconds`。

**2. 單表 vs 多表設計，哪種更合適？**

**多表設計**會是這樣：

```sql
Table video_resources {
  id bigserial [primary key]
  mission_id bigint [not null, ref: > missions.id]
  resource_url varchar(1000) [not null]
  duration_seconds integer [not null]
  content_order integer [not null]
  ...
}

Table article_resources {
  id bigserial [primary key]
  mission_id bigint [not null, ref: > missions.id]
  resource_content text [null]
  resource_url varchar(1000) [null]
  content_order integer [not null]
  ...
}

Table form_resources {
  id bigserial [primary key]
  mission_id bigint [not null, ref: > missions.id]
  resource_url varchar(1000) [not null]
  content_order integer [not null]
  ...
}
```

**比較：**

| 考量點        | 單表多型       | 多表設計            |
| ------------- | -------------- | ------------------- |
| Schema 複雜度 | 簡單           | 複雜                |
| 新增資源類型  | 容易           | 需要建新表          |
| 查詢所有資源  | 一個查詢       | 需要 UNION          |
| 資料完整性    | 弱（靠應用層） | 強（NOT NULL 約束） |
| 空間效率      | 有浪費         | 高效                |
| 應用層程式碼  | 統一介面       | 多個 Repository     |

**我的建議：對這個專案來說，單表多型更合適**

理由：

1. 資源類型不會很多（VIDEO、ARTICLE、FORM，未來可能再加 2-3 種）
2. 資源之間的差異不大（主要是 URL vs Content 的差別）
3. 查詢模式以「取得某任務的所有資源」為主，不太會單獨查「所有影片」
4. 擴展性需求高（平台可能常常實驗新的任務形式）

如果是其他場景（比如每種資源有 10 幾個特殊欄位、資料量上億、需要針對不同資源類型做複雜查詢），多表設計會更好。

**3. 如何確保資料完整性約束？**

既然選擇單表多型，但又想要某程度的資料完整性，可以這樣做：

**方案一：應用層驗證（最常見）**

在 Entity 或 Service 層加驗證邏輯：

```java
@Entity
public class MissionResource {
    // ...

    @PrePersist
    @PreUpdate
    private void validate() {
        switch (resourceType) {
            case VIDEO:
                if (resourceUrl == null || resourceUrl.isBlank()) {
                    throw new IllegalStateException("Video resource must have URL");
                }
                if (durationSeconds == null || durationSeconds <= 0) {
                    throw new IllegalStateException("Video resource must have duration");
                }
                break;

            case ARTICLE:
                if (resourceUrl == null && resourceContent == null) {
                    throw new IllegalStateException("Article must have URL or content");
                }
                break;

            case FORM:
                if (resourceUrl == null || resourceUrl.isBlank()) {
                    throw new IllegalStateException("Form resource must have URL");
                }
                break;
        }
    }
}
```

**方案二：資料庫層級的 CHECK 約束**

PostgreSQL 支援 CHECK 約束，可以加在表定義裡：

```sql
ALTER TABLE mission_resources
ADD CONSTRAINT check_video_resources
CHECK (
  resource_type != 'VIDEO' OR
  (resource_url IS NOT NULL AND duration_seconds IS NOT NULL AND duration_seconds > 0)
);

ALTER TABLE mission_resources
ADD CONSTRAINT check_article_resources
CHECK (
  resource_type != 'ARTICLE' OR
  (resource_url IS NOT NULL OR resource_content IS NOT NULL)
);

ALTER TABLE mission_resources
ADD CONSTRAINT check_form_resources
CHECK (
  resource_type != 'FORM' OR
  resource_url IS NOT NULL
);
```

這樣資料庫就會拒絕不符合規則的資料，即使應用層有 bug 也擋得住。

**方案三：PostgreSQL 的觸發器**

如果約束邏輯很複雜，可以寫觸發器在 INSERT/UPDATE 時檢查：

```sql
CREATE OR REPLACE FUNCTION validate_mission_resource()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.resource_type = 'VIDEO' THEN
    IF NEW.resource_url IS NULL OR NEW.duration_seconds IS NULL THEN
      RAISE EXCEPTION 'Video resource must have URL and duration';
    END IF;
  ELSIF NEW.resource_type = 'ARTICLE' THEN
    IF NEW.resource_url IS NULL AND NEW.resource_content IS NULL THEN
      RAISE EXCEPTION 'Article must have URL or content';
    END IF;
  ELSIF NEW.resource_type = 'FORM' THEN
    IF NEW.resource_url IS NULL THEN
      RAISE EXCEPTION 'Form resource must have URL';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_validate_resource
BEFORE INSERT OR UPDATE ON mission_resources
FOR EACH ROW EXECUTE FUNCTION validate_mission_resource();
```

**我的建議：**
結合方案一和方案二：

- 應用層驗證提供即時回饋，用戶體驗好
- CHECK 約束作為最後一道防線，確保資料庫的完整性

這樣既有彈性，又有安全保障。

---

### 21. [Mid-level] 排行榜查詢優化

系統需要顯示經驗值排行榜（前 100 名）。當使用者數量增長到 10 萬人時，查詢開始變慢。請分析：

1. 目前的 `idx_users_experience` 索引是否足夠？查詢時應該如何撰寫 SQL？
2. 是否應該引入 Redis 等快取來儲存排行榜？更新策略為何？
3. 如果要顯示「我的排名」，應該如何設計查詢？

**解答：**

**1. 索引是否足夠？**

目前的 `idx_users_experience` 索引基本上是夠的，但有個小地方要注意。

這個索引建在 `experience_points` 欄位上，查詢排行榜時只要寫「按經驗值降冪排序，取前 100 筆」，資料庫就能直接從索引的尾端往前讀 100 筆，非常快。

但要記得加上軟刪除條件。如果查詢沒有過濾 `deleted_at IS NULL`，就可能把已刪除的帳號也算進去。這時候索引還是能用，但效率會打折扣，因為要多掃描一些已刪除的記錄。

所以最好把索引改成 Partial Index，只對未刪除的使用者建索引。這樣查詢時不用擔心已刪除的資料，索引也更小更快。

另外，如果排行榜還要顯示使用者名稱、等級等資訊，每次都要回表查詢。如果想極致優化，可以考慮覆蓋索引，把 `username` 和 `level` 也加進去。但這會讓索引變大，更新成本也變高，要看查詢頻率來決定是否值得。

**2. 是否需要 Redis 快取？**

當使用者到 10 萬人時，**建議用 Redis 快取排行榜**。

原因是排行榜的特性很適合快取：資料更新頻率不高（使用者完成任務才會加經驗值），但查詢頻率很高（大家都想看自己排第幾）。每次都查資料庫太浪費，而且排行榜對即時性要求沒那麼高，延遲個幾分鐘其實沒差。

Redis 有個很適合的資料結構叫 **Sorted Set（有序集合）**。你可以把所有使用者的經驗值存進去，Redis 會自動按分數排序。查詢前 100 名只要一個指令，速度超快。

**更新策略：**

有兩種做法：

第一種是**定期全量更新**。比如每 5 分鐘從資料庫重新抓一次所有使用者的經驗值，整個刷新到 Redis。優點是實作簡單，缺點是如果使用者很多（10 萬人），全量更新成本有點高。

第二種是**即時增量更新**。當使用者交付任務、獲得經驗值時，同步更新 Redis 裡的分數。這樣排行榜幾乎是即時的，但要小心 Redis 和資料庫的一致性問題。如果 Redis 掛了或資料遺失，要有機制能從資料庫重建。

我個人會選第二種，因為經驗值更新的頻率其實不算高，每次更新時順便改 Redis 不會有太大負擔。然後再加上一個每天凌晨的全量同步任務，確保資料是對的。

**3. 如何查詢「我的排名」？**

這個就比較麻煩了。

如果用資料庫，要算「比我經驗值高的人有幾個」，這基本上要掃描整張表或整個索引。10 萬人的話，雖然有索引但還是有點慢。

如果用 Redis Sorted Set，就很簡單了。Redis 有個指令可以直接查「某個成員在集合中的排名」，時間複雜度是 O(log n)，非常快。

所以答案是：排行榜查詢最好搭配 Redis。前 100 名用 Redis 查，我的排名也用 Redis 查。資料庫作為主要儲存，Redis 作為查詢加速層。

這樣不管使用者數量成長到多少，排行榜查詢都能維持毫秒級的回應時間。

---

### 22. [Mid-level] 批次資料初始化

系統需要匯入 1000 門課程的初始資料，每門課程包含 10 個章節，每章節 20 個任務。請思考：

1. 如何設計高效的批次插入策略？
2. 應該使用交易嗎？如果使用，整批資料放在一個交易還是分批？
3. 如何處理部分資料匯入失敗的情況？

**解答：**

**1. 高效的批次插入策略**

先算一下資料量：1000 門課程 × 10 章節 × 20 任務，總共要插入 20 萬筆任務，再加上 1 萬筆章節和 1000 筆課程，合計超過 21 萬筆資料。如果一筆一筆插，會非常慢。

最有效的方式是**批次插入**。PostgreSQL 支援一次插入多筆資料，比如一個 INSERT 語句插入 500 筆。這樣可以大幅減少網路往返和交易開銷。

具體做法是把資料分批，每批比如 500 或 1000 筆，然後用一個 INSERT 語句搞定。這在大部分的 ORM 框架都有支援，比如 JPA 的 `saveAll` 配合適當的 batch size 設定。

另一個技巧是**暫時關閉某些約束檢查**。如果確定資料是正確的，可以在匯入前暫時停用觸發器或外鍵檢查，匯入完再打開。但這要很小心，萬一資料有錯，清理起來很麻煩。

還有一個進階做法是用 PostgreSQL 的 **COPY** 指令，這是專門為大量資料匯入設計的，速度比 INSERT 快很多。但 COPY 比較底層，要直接操作 CSV 檔案或資料流，應用層的整合會複雜一點。

**2. 交易策略**

**不建議把所有資料放在一個交易**，原因有幾個。

第一，21 萬筆資料在一個交易裡，交易時間會很長。這段時間內，相關的表可能會被鎖住，影響其他操作。而且萬一中間出錯，整個交易回滾，前面花的時間就白費了。

第二，長交易會產生大量的 WAL 日誌，佔用磁碟空間，也可能拖慢資料庫效能。

比較好的做法是**分批提交**。比如每 10 門課程一個交易，或者每 1000 筆資料一個交易。這樣每個交易的規模可控，即使失敗也只影響一小部分，不用全部重來。

具體的分批策略可以是：

- 以課程為單位：每門課程（包含它的章節和任務）一個交易。這樣邏輯清楚，一門課要嘛全部成功，要嘛全部失敗，不會出現「只有課程沒有章節」的狀況。
- 以數量為單位：每 1000 筆一個交易。這樣比較平均，不會因為某門課特別大就讓交易變很大。

我個人會選第一種，因為資料的完整性比較好掌握。

**3. 處理部分失敗**

分批匯入一定會遇到「部分成功、部分失敗」的情況。

首先要**記錄哪些批次成功、哪些失敗**。可以在匯入腳本裡加日誌，記下每批的起始位置和結果。失敗的批次要記錄錯誤訊息，方便事後檢查。

然後要提供**重試機制**。失敗的批次可以單獨重新匯入，不用整個從頭來過。這時候要注意冪等性：如果某筆資料已經存在（比如課程的 slug 重複），要能優雅地處理，不是直接噴錯。

另一個做法是**驗證後再匯入**。在真正插入資料庫之前，先跑一遍驗證邏輯，檢查資料格式、必填欄位、唯一性約束等等。把問題資料挑出來，只匯入乾淨的資料。這樣可以大幅降低匯入失敗的機率。

最後，如果是生產環境的匯入，最好先在測試環境完整跑一遍，確認沒問題再上正式環境。大規模資料匯入失敗的話，要回復是很頭痛的。

---

### 23. [Mid-level] 熱門課程效能問題

假設某門熱門課程有 5000 名學生同時在線上觀看影片，每 10 秒更新一次 `user_mission_progress`。請分析：

1. 這會對資料庫造成什麼樣的寫入壓力？每秒約多少次更新？
2. 可以採用什麼策略來減輕資料庫負擔？（例如：批次更新、非同步寫入）
3. 如何確保使用者關閉瀏覽器時，進度不會遺失？

**解答：**

**1. 寫入壓力計算**

5000 個學生，每 10 秒更新一次，那每秒的更新次數就是 5000 ÷ 10 = **500 次寫入**。

這個數字乍看不算太誇張，但要考慮幾個因素。

第一，這只是一門課程。如果同時有多門熱門課程，或者平台整體有更多使用者在線，寫入量會疊加上去。

第二，每次更新不只改 `watch_position_seconds`，還會更新 `updated_at`。而且 `user_mission_progress` 表上有好幾個索引（user_id、mission_id、status），每次更新都要維護這些索引，實際的資料庫寫入成本比單純改一個欄位高。

第三，如果這 5000 個使用者的更新請求剛好集中在某幾秒（比如大家都在整點開始看課），可能會有瞬間的寫入尖峰，對資料庫造成突發壓力。

所以 500 QPS 的寫入，對於單一資料庫來說，不算輕鬆但也不至於撐不住。問題在於如果流量再成長，或是有其他寫入操作，就可能成為瓶頸。

**2. 減輕負擔的策略**

有幾個方向可以優化：

**策略一：延長更新間隔**
真的需要每 10 秒更新一次嗎？如果改成 30 秒或 1 分鐘，寫入壓力就直接降到原本的 1/3 或 1/6。使用者體驗不會差太多，因為進度記錄本來就有一點延遲是可以接受的。

**策略二：前端合併更新**
前端不要每 10 秒就發一次請求，而是先在本地記錄，等使用者暫停影片、跳轉進度、或關閉頁面時再一次性更新。這樣可以大幅減少請求數量。

**策略三：後端批次處理**
把進度更新請求先放到佇列（比如 Redis Queue 或 RabbitMQ），然後用 worker 批次處理。比如每秒從佇列裡撈 100 筆，用一個批次更新搞定。這樣可以平滑寫入尖峰，避免突發流量打垮資料庫。

**策略四：用 Redis 做緩衝**
進度先寫到 Redis，然後定期（比如每分鐘）同步到 PostgreSQL。Redis 的寫入效能遠高於關聯式資料庫，可以輕鬆應付這個流量。但要注意 Redis 和資料庫的一致性，以及 Redis 掛掉時的資料恢復。

我個人會選策略三和策略四的組合。進度更新不需要強一致性，稍微延遲個幾秒甚至幾十秒都沒關係，重點是不能遺失。

**3. 確保進度不遺失**

這是個很實務的問題。如果使用者直接關瀏覽器或網路斷線，怎麼保證最後的進度有存到？

**做法一：前端在離開前強制同步**
監聽瀏覽器的 `beforeunload` 事件，在使用者關閉頁面前發送最後一次進度更新。但這個事件不是 100% 可靠，有些情況（比如瀏覽器崩潰）不會觸發。

**做法二：用 Beacon API**
這是瀏覽器提供的專門用於「頁面關閉時發送資料」的 API，比一般的 AJAX 請求更可靠。即使頁面已經開始關閉，Beacon 請求也有更高機率送達。

**做法三：前端週期性同步 + 後端容忍遺失**
接受「最後 10 秒的進度可能遺失」這個現實。畢竟影片只是回退 10 秒，使用者重新看一次也不會太困擾。重點是大部分的進度都有正確記錄就好。

**做法四：後端冪等性處理**
如果使用策略二（前端合併更新），那在頁面關閉時可能會有「連續幾次更新」同時送達。後端要能處理這種情況，用「取最大值」的方式更新，確保進度不會倒退。

實務上我會用做法二搭配做法四，在正常情況下定期更新，離開時用 Beacon API 做最後一次同步。雖然不能 100% 保證，但已經能涵蓋絕大部分場景了。

---

### 24. [Mid-level] 訂單併發控制

兩個使用者可能同時對同一課程建立訂單。請思考：

1. `user_journeys` 表有 `(user_id, journey_id)` 的唯一約束，如何防止重複購買？
2. 如果使用者 A 已有未付款訂單，使用者 A 再次點擊購買，應該如何處理？
3. 應該在資料庫層級還是應用層級處理這些邏輯？各有什麼優缺點？

**解答：**

**1. 防止重複購買**

`user_journeys` 的唯一約束是最後一道防線，但不能只靠它。

正常的流程應該是：使用者點擊購買時，先檢查 `user_journeys` 裡有沒有這筆記錄。如果已經擁有這門課，就直接提示「你已經購買過了」，不讓他建立訂單。

但有個邊界情況：使用者已經有一筆未付款訂單（訂單已建立，但還沒進入 `user_journeys`），這時候唯一約束擋不住。他可以再建一筆新訂單，結果兩筆訂單都指向同一門課。

如果兩筆訂單都付款成功，系統會試圖插入兩筆相同的 `(user_id, journey_id)` 到 `user_journeys`。這時候第二筆會因為唯一約束失敗。

所以要在**建立訂單時就檢查**：不只看 `user_journeys`，也要看有沒有未付款或已付款的訂單包含這門課。如果有，就不讓他重複下單。

**2. 已有未付款訂單的處理**

這要看產品需求。有幾種做法：

**做法一：直接導向原訂單**
提示使用者「你已經有一筆未付款的訂單，請先完成付款」，然後導向原訂單的付款頁面。這樣可以避免重複訂單，使用者體驗也還可以。

**做法二：取消舊訂單，建立新訂單**
把舊的未付款訂單標記為「已取消」（或軟刪除），然後建立新訂單。這樣使用者想重新下單就能重新下單，比較彈性。

**做法三：合併訂單**
如果舊訂單還包含其他課程，就把新課程加進去。但這會讓訂單邏輯變複雜，而且要考慮價格計算、折扣等等。

我個人傾向做法一。未付款訂單通常是使用者還在考慮或暫時離開，讓他回去完成原訂單比較合理。如果他真的不想要舊訂單，可以提供「取消訂單」的功能。

**3. 邏輯放在哪一層？**

這個問題沒有絕對答案，要看團隊的技術棧和架構。

**在應用層處理：**

優點：

- 彈性高，可以根據不同情境做複雜的業務判斷
- 容易寫測試，邏輯都在程式碼裡
- 可以給使用者友善的錯誤提示

缺點：

- 如果有多個應用實例，要小心併發問題（兩個請求同時通過檢查，都建立訂單）
- 依賴應用層邏輯的正確性，萬一有 bug 就可能出錯

**在資料庫層處理：**

優點：

- 資料完整性由資料庫保證，不管應用層怎麼寫都擋得住
- 唯一約束、外鍵、CHECK 約束等都能強制執行
- 即使直接用 SQL 操作資料庫，規則也不會被繞過

缺點：

- 彈性較低，複雜的業務邏輯很難用 SQL 或觸發器表達
- 錯誤訊息比較陽春（比如 "unique constraint violation"），要在應用層再包裝

**我的建議：**

**兩層都要做**。

應用層負責主要的業務邏輯檢查，提供好的使用者體驗。資料庫層用唯一約束、外鍵等機制當作最後防線，確保即使應用層有 bug，資料完整性也不會受損。

比如這個場景：

- 應用層：建立訂單前，查詢 `user_journeys` 和 `orders`，檢查是否重複
- 資料庫層：`user_journeys` 的唯一約束確保最終不會重複擁有課程

這樣既有彈性又有保障，是最穩健的做法。

---

### 25. [Mid-level] 長交易問題

付款流程需要呼叫第三方支付 API（可能需要 5-10 秒），並在成功後更新訂單狀態。請分析：

1. 如果在資料庫交易中呼叫外部 API，會有什麼問題？
2. 應該如何設計交易邊界？哪些操作應該在交易內，哪些應該在交易外？
3. 如果支付成功但資料庫更新失敗，應該如何處理？

**解答：**

**1. 在交易中呼叫外部 API 的問題**

這是個經典的錯誤，千萬不要這樣做。

資料庫交易的目的是確保一系列操作的原子性，但它有個隱含的假設：**交易時間要短**。如果交易開啟了 5-10 秒，會發生什麼？

第一，**長時間鎖住資料**。交易通常會對相關的資料列或資料表上鎖，防止其他操作干擾。如果這期間外部 API 很慢，鎖就會一直佔著，導致其他請求被阻塞。比如使用者想查看自己的訂單，結果因為付款交易還沒結束，查詢一直等。

第二，**連線佔用**。資料庫連線池的連線數量有限，假設連線池只有 20 個連線，如果有 10 個付款請求都卡在等 API 回應，就佔掉一半的連線。其他功能可能因為拿不到連線而失敗。

第三，**交易可能超時**。大部分資料庫或應用框架都有交易超時設定，5-10 秒可能就超過限制了。超時後交易會自動回滾，但這時候你可能已經呼叫了支付 API，錢已經扣了，結果資料庫回滾了。這就亂套了。

第四，**外部 API 失敗會回滾交易**。如果 API 呼叫失敗，整個交易回滾。但外部 API 可能已經做了某些不可逆的操作（比如扣款），回滾資料庫解決不了這個問題。

**2. 正確的交易邊界設計**

核心原則是：**外部 API 呼叫要在交易外**。

正確的流程應該是：

1. **交易外**：呼叫支付 API，等待回應
2. **交易內**：根據 API 回應，更新訂單狀態、建立擁有權記錄

具體來說：

第一階段（交易外）：

- 驗證訂單是否有效（未付款、未過期）
- 組裝支付請求參數
- 呼叫第三方支付 API
- 等待 API 回應

第二階段（交易內）：

- 再次檢查訂單狀態（防止這期間訂單被修改）
- 更新 `orders.status` 為 PAID
- 設定 `orders.paid_at`
- 在 `user_journeys` 建立擁有權記錄
- 提交交易

這樣交易時間可能只需要幾十毫秒，不會因為外部 API 拖慢整個流程。

**3. 支付成功但資料庫更新失敗的處理**

這是分散式系統裡的經典問題：**兩階段操作的一致性**。

外部 API 成功了（錢扣了），但資料庫更新失敗了（訂單狀態還是未付款），這時候使用者付了錢但沒拿到課程，非常嚴重。

有幾個處理方式：

**方式一：重試機制**
資料庫更新失敗時，記錄錯誤日誌，然後重試。比如重試 3 次，每次間隔幾秒。大部分情況下（網路抖動、暫時性錯誤）重試就能成功。

**方式二：人工介入**
如果重試也失敗，把這筆訂單標記為「異常狀態」，通知管理員處理。管理員可以查看支付記錄，手動更新訂單狀態。

**方式三：對帳機制**
定期（比如每小時或每天）從支付平台拉取付款記錄，跟資料庫的訂單狀態比對。如果發現「支付平台顯示已付款，但資料庫顯示未付款」的訂單，自動或人工補正。

**方式四：冪等性設計**
支付平台的回調可能會重複發送，所以更新訂單的邏輯要做成冪等的。用訂單編號或支付流水號當作冪等鍵，確保同一筆付款不會被重複處理。

實務上會**結合多種方式**：

- 正常情況下，資料庫更新應該很快就成功
- 失敗時先自動重試
- 重試也失敗的話，記錄到異常訂單表，觸發告警
- 定期對帳機制作為最後保障

這樣可以在絕大部分情況下自動處理，少數異常需要人工介入。雖然不完美，但已經是分散式系統中比較實際的做法了。

---

### 26. [Mid-level] 課程存取權限查詢

查詢「使用者是否有權限觀看某個任務」需要檢查：

1. 任務的 `access_level`（PUBLIC/AUTHENTICATED/PURCHASED）
2. 如果是 PURCHASED，需要查詢 `user_journeys` 確認使用者是否擁有該課程

請設計：

1. 這個查詢的最佳 SQL 語句
2. 需要建立哪些索引來支援這個查詢？
3. 如何避免 N+1 查詢問題（例如課程列表頁一次查詢多個課程的權限）？

**解答：**

**1. 最佳查詢設計**

這個查詢的邏輯有點複雜，因為權限檢查分三種情況。

如果任務是 PUBLIC，那誰都能看，不用檢查擁有權。如果是 AUTHENTICATED，只要使用者有登入就行。只有 PURCHASED 才需要去查 `user_journeys`。

所以查詢的思路是：先抓任務資料，JOIN 到章節和旅程，然後根據 `access_level` 決定是否需要檢查擁有權。

可以用一個 LEFT JOIN 來做。如果任務是 PURCHASED，就 JOIN `user_journeys` 看有沒有記錄。如果有記錄或者 `access_level` 不是 PURCHASED，就表示有權限。

這樣一個查詢就能搞定，不用在應用層分別處理三種情況。

**2. 需要的索引**

這個查詢會用到幾個表的 JOIN，索引很重要。

首先，`missions` 的 `access_level` 索引已經有了，這個能加速篩選。

然後，`missions` 到 `chapters` 的 JOIN 用 `chapter_id`，這個有外鍵和索引，沒問題。

`chapters` 到 `journeys` 的 JOIN 用 `journey_id`，也有索引。

關鍵是 `user_journeys` 的查詢。我們需要找「某個使用者擁有某個旅程」，所以 `(user_id, journey_id)` 的唯一索引正好能用上，效能很好。

不過要注意軟刪除。所有查詢都要加 `deleted_at IS NULL`，如果索引是 Partial Index（只包含未刪除的資料），效能會更好。

所以基本上現有的索引就夠用了，不需要額外建立新索引。

**3. 避免 N+1 查詢**

這是個很實務的問題。假設課程列表頁要顯示 20 門課程，每門課都要判斷使用者有沒有權限，如果分別查詢就是 20 次，太慢了。

**做法一：一次查出所有擁有權**

在顯示課程列表前，先一次性查出「這個使用者擁有哪些課程」，放到一個 Set 裡。然後在顯示每門課時，直接檢查 Set 裡有沒有這個課程 ID。

這樣只需要兩個查詢：一次查課程列表，一次查擁有權列表。時間複雜度從 O(n) 降到 O(1)。

**做法二：用 IN 查詢批次檢查**

如果要更精確，可以用一個 IN 查詢，一次檢查「這 20 門課程中，使用者擁有哪幾門」。

這樣也是兩個查詢，而且邏輯更清楚。資料庫優化器通常能很好地處理 IN 查詢，尤其是有索引的情況下。

**做法三：應用層快取**

如果使用者的課程擁有權不常變動（付款後才會改變），可以把擁有權清單快取起來。比如放到 Redis，或是在使用者的 Session 裡。

這樣整個 Session 期間都不用查資料庫，直接從快取拿。但要小心快取失效的問題，付款後要記得清除快取。

**實務建議：**

我會用做法一。在課程列表的 API 裡，先查出使用者的所有擁有權，然後在組裝回應時一起判斷。這樣程式碼簡單，效能也好。

如果平台成長到使用者可能擁有幾百門課，做法一可能會拿到一個很大的 Set。這時候可以改用做法二，只查「當前頁面這 20 門課」的擁有權。

做法三適合用在「我的課程」這種頁面，因為使用者會反覆瀏覽自己的課程列表，快取效益高。

---

### 27. [Mid-level] 資料一致性檢查

系統運行一段時間後，需要定期檢查資料完整性。請設計 SQL 查詢來找出以下異常：

1. 存在於 `order_items` 但對應訂單不存在或已刪除
2. 訂單狀態為 PAID，但 `paid_at` 為 NULL
3. `user_journeys` 中的使用者擁有課程，但找不到對應的已付款訂單

**解答：**

這種資料一致性檢查很重要，可以發現系統的潛在 bug 或資料異常。

**1. 找出孤兒訂單明細**

訂單明細應該永遠有對應的訂單。如果訂單被刪除了但明細還在，或是外鍵關聯有問題，就會出現這種情況。

查詢的邏輯是：找出「`order_items` 裡的 `order_id` 在 `orders` 表裡不存在或已被軟刪除」的記錄。

可以用 LEFT JOIN，如果 JOIN 不到訂單，或是訂單的 `deleted_at` 不是 NULL，就表示有問題。

這種異常如果出現，通常表示資料庫操作有 bug，或是有人直接用 SQL 刪除了訂單但沒清理明細。

**2. 找出付款狀態不一致的訂單**

訂單標記為 PAID，就應該有付款時間。如果沒有，可能是付款流程的程式碼忘記設定 `paid_at`，或是有人手動改了狀態。

查詢很簡單：WHERE `status = 'PAID' AND paid_at IS NULL`。

這種異常要馬上修正，因為會影響財務報表和對帳。可以根據 `updated_at` 推測付款時間，或是查支付平台的記錄來補正。

**3. 找出沒有付款記錄的課程擁有權**

使用者擁有課程，應該是因為他付款買了。如果 `user_journeys` 裡有記錄，但對應的訂單找不到或不是已付款狀態，就有問題。

查詢的邏輯是：從 `user_journeys` 出發，JOIN `orders` 和 `order_items`，檢查訂單是否存在且為 PAID 狀態。

如果 JOIN 不到，或是訂單狀態不對，就表示資料有異常。

這種情況可能是：

- 訂單被誤刪了
- 訂單狀態被改成非 PAID
- 有人手動插入 `user_journeys` 記錄（比如測試或贈送課程）但沒有對應訂單

如果是正常的贈送課程，可以建立一筆「系統贈送」的特殊訂單來對應。如果是資料錯誤，就要調查原因並修正。

**定期檢查的實務建議：**

這些檢查可以寫成腳本或排程任務，比如每天凌晨執行一次。如果發現異常，記錄到日誌或發送告警通知。

輕微的異常（比如少數幾筆）可能只是歷史遺留問題，記錄下來就好。但如果突然出現大量異常，就表示系統可能有 bug，要馬上調查。

另外，這些檢查也可以在部署新版本前執行，確保資料庫遷移或程式碼變更沒有破壞資料完整性。

---

### 28. [Mid-level] 經驗值與等級同步

當使用者交付任務獲得經驗值時，需要同時更新 `users` 表的 `experience_points` 和 `level`。請思考：

1. 等級計算邏輯應該在應用層還是資料庫層（例如使用觸發器或函式）？
2. 如何確保經驗值和等級的更新是原子性的？
3. 如果有多個任務同時交付，如何避免經驗值計算錯誤？

**解答：**

**1. 等級計算邏輯放在哪一層？**

這個沒有絕對的對錯，但我個人傾向**放在應用層**。

原因有幾個：

第一，等級計算的邏輯可能會變。比如一開始是「每 100 經驗值升一級」，後來改成「等級越高需要的經驗值越多，1 級到 2 級要 100，2 級到 3 級要 150」。如果邏輯在應用層，改起來很簡單，改程式碼、測試、部署就好。但如果在資料庫層（觸發器或函式），要改資料庫的 SQL 程式碼，風險比較高，也不容易做版本控制。

第二，測試方便。應用層的邏輯可以寫單元測試，輸入經驗值、預期得到的等級，測試覆蓋率很容易達到。但資料庫層的觸發器或函式要測試就麻煩多了，通常要整合測試才測得到。

第三，可讀性。等級計算可能涉及一些業務規則（比如「完成新手任務額外升一級」之類的），這些邏輯用 Java 或其他程式語言寫，比用 PL/pgSQL 清楚易懂。

當然資料庫層也有優點：不管從哪裡更新經驗值（應用層、直接 SQL、其他系統），觸發器都會自動算等級，保證一致性。但在單一應用的架構下，這個優點不太重要。

**2. 確保原子性**

這個一定要用**交易**。

更新經驗值和等級要放在同一個交易裡，確保要嘛都成功、要嘛都失敗。不能出現「經驗值加了但等級沒升」或「等級升了但經驗值沒加」的情況。

具體流程是：

1. 開啟交易
2. 計算使用者應該獲得的經驗值
3. 更新 `experience_points`
4. 根據新的經驗值計算等級
5. 更新 `level`
6. 提交交易

如果中間任何步驟失敗，整個交易回滾，使用者的狀態不會改變。

要注意的是，計算邏輯（步驟 2 和 4）不應該有外部 API 呼叫或長時間運算，保持交易時間短。

**3. 併發交付的問題**

這是個很實際的問題。假設使用者在兩個分頁同時交付兩個任務，或是前端連點兩次交付按鈕，可能會有併發更新的問題。

比如：

- 交易 A：讀取經驗值 1000，加 50，寫回 1050
- 交易 B：也讀取經驗值 1000（因為交易 A 還沒提交），加 30，寫回 1030
- 結果：最後經驗值是 1030，但應該是 1080（1000 + 50 + 30）

這就是經典的 **Lost Update（更新遺失）**問題。

**解決方式：**

**方式一：樂觀鎖**
在更新時檢查 `updated_at` 或 `experience_points` 是否被改過。如果被改了，拒絕更新並要求重試。

具體是：讀取使用者資料時記下 `experience_points` 的值，更新時用 WHERE 條件檢查這個值是否還一樣。如果不一樣，表示有其他交易修改過，更新會失敗（影響 0 行）。

這時候應用層重新讀取、重新計算、重新更新。

**方式二：悲觀鎖**
在讀取使用者資料時就鎖住這筆記錄，用 SELECT ... FOR UPDATE。這樣其他交易想讀取同一筆資料時會被阻塞，直到第一個交易提交。

這樣可以完全避免併發問題，但缺點是會降低併發效能。如果很多人同時交付任務，可能會有排隊等待的情況。

**方式三：原子性加法**
不要「讀取 → 計算 → 寫回」，而是直接用 UPDATE 語句做加法。比如 `SET experience_points = experience_points + ?`。

這樣資料庫會原子性地執行加法，不會有 Lost Update 的問題。

但要注意等級計算。如果用這個方式更新經驗值，要在 UPDATE 之後重新讀取經驗值來計算等級。

**我的建議：**

用方式三（原子性加法）搭配方式一（樂觀鎖）。

大部分情況下，使用者不會真的併發交付任務，所以樂觀鎖的重試機制幾乎不會觸發。但萬一真的併發了，樂觀鎖能保證資料正確性。

原子性加法則確保經驗值累加不會出錯。等級計算可以在加完經驗值後重新讀取，反正整個流程在一個交易裡，資料是一致的。

---

### 29. [Mid-level] 反正規化權衡

為了提升查詢效能，團隊考慮在 `missions` 表中加入冗餘欄位 `journey_id`（目前需要透過 `chapters` 表才能關聯到 `journeys`）。請評估：

1. 這個反正規化設計能帶來什麼效能提升？哪些查詢會受益？
2. 會引入什麼資料一致性風險？
3. 如何維護這個冗餘欄位的正確性？應該用觸發器還是應用層邏輯？

**解答：**

**1. 效能提升分析**

這個反正規化主要是省掉一次 JOIN。

目前要從任務查到課程，必須 `missions → chapters → journeys`，兩次 JOIN。如果在 `missions` 加上 `journey_id`，就可以直接 `missions → journeys`，一次 JOIN 搞定。

**受益的查詢：**

第一個是「查詢某課程的所有任務」。目前要先從課程找章節，再從章節找任務。如果有 `journey_id`，直接 WHERE `journey_id = ?` 就行了。

第二個是「檢查使用者是否有權限觀看某任務」。這需要知道任務屬於哪個課程，然後查 `user_journeys`。有了 `journey_id` 就少一次 JOIN。

第三個是統計類查詢，比如「某課程有多少任務」、「某課程的平均完成率」。這些查詢如果能直接從 `missions` 表拿到課程 ID，會簡單很多。

**效能提升的量化：**

假設一門課程有 10 個章節、200 個任務。查詢「某課程的所有任務」：

- 原本：先查 10 個章節（一次查詢），再查這 10 個章節的任務（可能要 JOIN 或 IN 查詢）
- 反正規化後：直接 WHERE `journey_id = ?`，一次搞定

對於頻繁執行的查詢（比如課程詳情頁），這個提升還是有感的。

**2. 資料一致性風險**

最大的風險是 **`journey_id` 和實際的歸屬關係不一致**。

比如說：

- 某章節本來屬於課程 A，後來被移到課程 B（雖然這在業務上可能不常見）
- 如果只更新了 `chapters.journey_id`，但忘記更新 `missions.journey_id`，任務就還指向課程 A，資料就亂了

另一個風險是**新增資料時忘記設定**。建立任務時，除了設定 `chapter_id`，還要記得設定 `journey_id`。如果應用層有 bug 或是有人直接用 SQL 插入資料，可能會漏掉。

還有一個細節：如果章節被軟刪除或移到其他課程，任務的 `journey_id` 要不要跟著改？這要看業務邏輯，但總之又多了一層要維護的關係。

**3. 維護冗餘欄位的方式**

有兩個主要選擇：

**選擇一：應用層維護**

建立任務時，從 `chapter` 查出 `journey_id`，然後一起設定到任務裡。更新章節的課程歸屬時（如果有這種操作），同步更新相關任務的 `journey_id`。

優點：

- 邏輯清楚，都在程式碼裡
- 容易測試和除錯
- 可以加入業務判斷（比如「某些特殊任務不跟隨章節變動」）

缺點：

- 依賴應用層的正確性
- 如果有多個系統或服務操作資料庫，要確保都有實作這個邏輯
- 直接用 SQL 操作資料庫會繞過這個邏輯

**選擇二：資料庫觸發器**

寫一個觸發器，當 `missions` 插入或 `chapters` 更新時，自動設定或更新 `missions.journey_id`。

優點：

- 不管從哪裡操作資料庫，觸發器都會執行，保證一致性
- 應用層不用特別處理，減少出錯機會

缺點：

- 觸發器邏輯隱藏在資料庫裡，不容易發現和理解
- 除錯比較麻煩（觸發器的錯誤訊息通常不太友善）
- 可能影響寫入效能（每次插入或更新都要執行觸發器）

**我的建議：**

如果這個專案是**單一應用架構**，所有資料庫操作都透過應用層，我會選應用層維護。邏輯透明，容易掌控。

但要加上**資料完整性檢查**（就像前面第 27 題提到的），定期掃描是否有 `journey_id` 不一致的任務，及時發現問題。

如果未來有多個系統或服務會操作資料庫，或是會直接用 SQL 做資料維護，那觸發器會是比較保險的選擇。

**另一個思考：真的需要反正規化嗎？**

在決定反正規化之前，先確認：

1. 效能真的是瓶頸嗎？兩次 JOIN 在有索引的情況下其實很快
2. 有沒有其他優化方式？比如查詢結果快取、複合索引等
3. 資料變動頻率高嗎？如果任務和章節很少變動，快取可能更有效

反正規化是「用空間和維護成本換查詢效能」，要確認這個交換是划算的。

---

### 30. [Mid-level] 資料庫連線池設計

應用使用連線池（Connection Pool）連接 PostgreSQL。請思考：

1. 連線池大小應該如何設定？設太大或太小各有什麼問題？
2. 如果發生長時間執行的查詢佔用連線，會對系統造成什麼影響？
3. 如何監控連線池的使用狀況，並設定告警閾值？

**解答：**

**1. 連線池大小的設定**

這是個很實務的問題，沒有標準答案，要根據實際情況調整。

**設太小的問題：**

如果連線池只有 5 個連線，但同時有 20 個請求需要查資料庫，就會有 15 個請求在排隊等連線。使用者會感覺網站很慢，回應時間拉長。

更糟的是，如果等待時間超過連線池的超時設定（比如 30 秒），請求會直接失敗，使用者看到錯誤訊息。

**設太大的問題：**

PostgreSQL 對每個連線都有成本：記憶體佔用、上下文切換、鎖競爭等等。如果連線池有 200 個連線，全部同時在跑查詢，資料庫可能會因為資源耗盡而變慢，甚至比連線少的時候還慢。

而且大部分時候那麼多連線根本用不到，白白佔用資源。

**推薦的設定方式：**

有個經驗公式：**連線池大小 = CPU 核心數 × 2 + 磁碟數量**

假設資料庫伺服器有 8 核 CPU、1 個磁碟陣列，連線池大小可以設 8 × 2 + 1 = 17。

但這只是起點，要根據實際負載調整。可以從小開始（比如 10），然後監控連線使用率。如果經常「所有連線都在用，還有請求在等」，就加大一點。如果大部分時候只用到一半連線，就維持現狀或甚至減少。

另一個考量是**應用伺服器的數量**。如果有 3 台應用伺服器，每台連線池 20，總共就是 60 個連線打到同一個資料庫。要確保資料庫撐得住。

PostgreSQL 預設最大連線數是 100，但建議不要設那麼高。實務上 20-50 個活躍連線通常就夠了。

**2. 長查詢佔用連線的影響**

這是個嚴重的問題。

假設連線池有 20 個連線，突然有個查詢跑了 5 分鐘（可能是慢查詢、死鎖、或是忘記加索引）。這個查詢佔用一個連線，5 分鐘都不釋放。

如果同時有很多這種查詢，可能 10 個連線都被卡住了。剩下 10 個連線要應付所有正常請求，系統就開始變慢。如果慢查詢繼續增加，可能連線池被耗盡，新請求完全無法執行。

更糟的情況是**雪崩效應**：因為連線不夠，請求開始堆積。堆積的請求讓系統負載變高，導致更多查詢變慢，佔用更多連線，形成惡性循環。

**預防和處理：**

第一，設定**查詢超時**。應用層和資料庫層都要設。如果查詢超過一定時間（比如 30 秒），強制中斷，釋放連線。這樣可以避免一個慢查詢佔用連線太久。

第二，**監控慢查詢**。定期檢查資料庫的慢查詢日誌，找出有問題的 SQL 並優化。

第三，**連線池的候補機制**。有些連線池支援「最小連線數 + 最大連線數」的設定。平常維持少量連線，高峰時可以臨時開啟更多，但不超過最大值。這樣可以應對突發流量。

**3. 監控和告警**

連線池是系統的關鍵資源，一定要監控。

**要監控的指標：**

第一，**活躍連線數**。目前有多少連線正在執行查詢。如果長時間接近或等於連線池大小，表示可能不夠用。

第二，**等待連線的請求數**。有多少請求在排隊等連線。如果這個數字不是 0，表示連線池確實不夠。

第三，**連線等待時間**。請求平均要等多久才能拿到連線。如果超過幾百毫秒，使用者體驗就會受影響。

第四，**連線獲取失敗次數**。有多少請求因為拿不到連線而失敗。這個一旦不是 0 就很嚴重。

第五，**連線的平均使用時間**。每個連線平均被佔用多久。如果突然變長，可能有慢查詢出現。

**告警閾值建議：**

- 活躍連線數超過連線池大小的 80%，發出警告
- 有請求在等待連線，發出警告
- 連線等待時間超過 500ms，發出告警
- 連線獲取失敗，立即發出嚴重告警
- 連線平均使用時間超過平常的 3 倍，發出警告（可能有慢查詢）

**實作方式：**

大部分連線池函式庫（如 HikariCP、C3P0）都有內建的 metrics 輸出，可以整合到監控系統（如 Prometheus、Grafana）。

設定好監控後，建立 Dashboard 可以即時看到連線池狀況。設定告警規則，連線池有問題時自動發送通知（Email、Slack、簡訊等）。

定期檢視這些監控數據，可以提前發現問題。比如發現每天晚上 8 點連線使用率都很高，就可以考慮加大連線池或優化查詢，避免真的出問題。

---

## 結語

以上 30 題資料庫設計與優化問題，涵蓋了從基礎的索引和約束，到進階的效能調校、併發控制、分散式系統一致性等議題。

在實務工作中，資料庫設計沒有「完美解法」，重要的是：

1. **理解權衡**：每個設計決策都有優缺點，要根據業務需求、流量規模、團隊能力來選擇
2. **數據驅動**：不要憑感覺優化，用監控數據找出真正的瓶頸
3. **持續演進**：架構會隨著業務成長而調整，今天的最佳方案明天可能就不適用了
4. **防禦性設計**：應用層和資料庫層都要有保護機制，避免單點故障導致資料損壞

希望這些解答對你的面試準備有幫助！
