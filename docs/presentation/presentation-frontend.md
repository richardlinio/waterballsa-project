# 前端程式闡述演講大綱

## 📋 演講策略

**核心理念**：展示「需求 → 挑戰 → 解法 → 程式碼」的完整思維

**時間分配**：25 分鐘

**目標**：展現系統設計能力、效能優化意識、可靠性思維，而不只是「會寫程式」

---

## 🎯 開場（2 分鐘）：專案定位

### 開場白範例

> "這是一個**線上學習平台**，實作了 Release 1（權限 + 看課）和 Release 2（購課）的核心功能。我將從三個**最具挑戰性的問題**來闡述程式設計。"

### Spec 重點展示

1. **Release 1**：權限管理 + 影片進度追蹤 + 交付經驗值
2. **Release 2**：訂單流程 + 付費內容保護 + 過期訂單處理

### 技術選型（30 秒帶過）

- **技術棧**：Next.js 15 App Router + TypeScript + SWR
- **選擇原因**：SSR、型別安全、資料同步

---

## 🔥 核心問題一：如何保護付費內容？（8 分鐘）

### 業務需求（來自 Release 2 - 3.5）

```
課程權限控制：
- 未購買課程的使用者遇到「需購買」層級的單元時：
  - 課程詳情頁面：顯示鎖定圖示
  - 點擊進入該單元：顯示「此為付費內容，請先購買課程」
```

### 技術挑戰

1. **前端如何知道使用者買了哪些課程？**
2. **如何在多個頁面（課程列表、課程詳情、任務頁面）統一檢查權限？**
3. **使用者在另一個 tab 購買後，當前 tab 如何即時解鎖？**

### 解決方案：三層 Context 協作

#### 架構圖

```
AuthContext（身份層）
    ↓ userId, token
UserPurchaseContext（權限層）
    ↓ Set<purchasedJourneyIds>
JourneyContext（內容層）
    ↓ journey structure + progress
```

#### 技術亮點 1：Set O(1) 查詢

**展示檔案**：[user-purchase-context.tsx:45-50](src/contexts/user-purchase-context.tsx#L45-L50)

```typescript
// 為什麼用 Set 而不是 Array？
const purchasedJourneyIds = new Set(userPurchases.map((p) => p.journeyId))

// O(1) vs O(n)
hasPurchased = purchasedJourneyIds.has(journeyId) // Set: O(1)
// vs
hasPurchased = purchasedArray.includes(journeyId) // Array: O(n)
```

**面試話術**：

> "因為要在列表頁、詳情頁、任務頁都頻繁檢查購買狀態，Set 的 O(1) 查詢比 Array 快很多。這是效能意識的展現。"

#### 技術亮點 2：跨 Tab 即時同步

**展示檔案**：[user-purchase-context.tsx:88-95](src/contexts/user-purchase-context.tsx#L88-L95)

```typescript
// localStorage 事件監聽（很少人知道的 API）
useEffect(() => {
	const handleStorageChange = (e: StorageEvent) => {
		if (e.key === 'purchaseUpdated') {
			loadPurchases() // 重新載入購買資料
		}
	}
	window.addEventListener('storage', handleStorageChange)
	return () => window.removeEventListener('storage', handleStorageChange)
}, [])
```

**面試話術**：

> "使用者可能同時開兩個 tab，在 A tab 購買後，B tab 應該立即解鎖內容。我用 localStorage 的 `storage` event 實現跨 tab 通訊，這是原生 Web API，不需要額外 library。"

#### 技術亮點 3：Pre-check 省 API call

**展示檔案**：[use-mission.ts:85-90](src/hooks/use-mission.ts#L85-L90)

```typescript
// useMission hook 中的權限 pre-check
if (missionSummary.accessLevel === 'PURCHASED' && !hasPurchased(journeyId)) {
	setIsPurchaseRequired(true)
	return // 🔥 不呼叫 getMissionDetail API
}
```

**面試話術**：

> "如果使用者沒買課程，就不該看到付費內容。我在 hook 層做 pre-check，避免呼叫 `getMissionDetail` API。這既節省 server 資源，又防止資料洩漏。"

#### 效果展示

- 課程列表頁：已購買顯示「繼續學習」，未購買顯示「立即加入課程」
- 課程詳情頁：未購買的單元顯示鎖定圖示
- 任務頁面：顯示「請先購買課程」提示

#### 小結（30 秒）

> "這個三層架構解決了權限控制的三個核心問題：**誰**登入了（Auth）、**誰買了哪些課程**（Purchase）、**課程內容是什麼**（Journey）。三個 Context 分工明確，易測試、易擴展。"

---

## 🔥 核心問題二：如何處理複雜的訂單流程？（7 分鐘）

### 業務需求（來自 Release 2）

```
3.2 訂單建立：
- 購買流程：建立訂單 -> 完成支付 -> 購買完成
- 錯誤處理：
  1. 已購買：顯示「你已經購買此課程」
  2. 已有未付款訂單：導向該訂單的付款頁面
  3. 只能查看自己的訂單

3.3 訂單狀態管理：
- 未付款 / 已付款 / 已過期（三天後）
```

### 技術挑戰

1. **如何防止重複購買？**（已購買 or 已有未付款訂單）
2. **如何處理訂單的多種狀態？**（未付款、已付款、已過期、404）
3. **過期訂單如何優雅地導向？**

### 解決方案：多層防護 + SWR 狀態管理

#### 防護層 1：購買前檢查（前端）

```typescript
// 檢查是否已購買
if (hasPurchased(journey.id)) {
	// 顯示「繼續學習」按鈕
} else {
	// 顯示「立即加入課程」按鈕
}

// 點擊購買時
const handlePurchase = async () => {
	// 建立訂單 API 會回傳：
	// - 409 Conflict：已購買
	// - 200 + orderId：成功建立或已有未付款訂單
}
```

#### 防護層 2：訂單頁面狀態處理（SWR）

**展示檔案**：[orders/[orderId]/page.tsx](<src/app/(app)/journeys/[journeySlug]/orders/[orderId]/page.tsx>)

```typescript
// 用 SWR 管理訂單資料
const { data: order, error } = useSWR(
	orderId ? `/orders/${orderId}` : null,
	fetcher,
	{ revalidateOnFocus: false } // 付款頁面不自動刷新，避免干擾
)

// 三個獨立的 useEffect 處理不同導向條件
useEffect(() => {
	if (error?.status === 404) {
		router.push(`/journeys/${journeySlug}`)
	}
}, [error])

useEffect(() => {
	if (order?.status === 'PAID') {
		router.push(`/journeys/${journeySlug}/orders/${orderId}/success`)
	}
}, [order?.status])

useEffect(() => {
	if (order?.status === 'EXPIRED') {
		toast.error('訂單已過期，請重新購買')
		router.push(`/journeys/${journeySlug}`)
	}
}, [order?.status])
```

**面試話術**：

> "為什麼分成三個 useEffect？因為每個 effect 只關注**一個導向條件**，這樣易讀、易測試。如果寫在一起，條件判斷會很複雜。"

#### 技術亮點：SWR 的選擇

```typescript
{
	revalidateOnFocus: false
}
```

**面試話術**：

> "付款頁面不應該自動重新驗證，因為使用者可能正在填寫資訊。但訂單列表頁則需要 `revalidateOnFocus: true`，確保切換 tab 回來時看到最新訂單狀態。"

#### 效果展示

- 已購買 → 顯示提示，不建立訂單
- 已有未付款訂單 → 導向該訂單
- 訂單過期 → Toast 提示 + 導回課程頁面
- 404 → 導回課程頁面

#### 小結（30 秒）

> "訂單流程的核心是**狀態機**設計。我用 SWR 管理狀態，用多個 useEffect 處理導向邏輯，職責分離，符合 Single Responsibility Principle。"

---

## 🔥 核心問題三：如何可靠地追蹤影片進度？（6 分鐘）

### 業務需求（來自 Release 1）

```
2.3 影片觀看與進度追蹤：
- 觀看進度達 100% 視為完成
- 影片完成度必須自動追蹤，不能手動 mark
- 系統定時記錄觀看進度（每 10 秒）
- 暫停影片、關閉頁面、觀看完成也記錄
- 下次觀看從上次位置繼續播放

2.4 交付功能：
- 觀看 100% 後才能交付
- 交付後獲得經驗值（+100）
- 每個單元只能交付一次
```

### 技術挑戰

1. **如何確保進度不會遺失？**（關閉頁面、當機）
2. **YouTube onEnd 事件會觸發多次，如何防止重複標記完成？**
3. **如何區分「已看完但未交付」vs「已交付」？**

### 解決方案：useVideoProgress Hook

#### 技術亮點 1：beforeunload 防止進度遺失

**展示檔案**：[use-video-progress.ts:120-130](src/hooks/use-video-progress.ts#L120-L130)

```typescript
useEffect(() => {
	const handleBeforeUnload = () => {
		if (currentProgress > 0) {
			saveProgress() // 同步存檔（fetch with keepalive）
		}
	}
	window.addEventListener('beforeunload', handleBeforeUnload)
	return () => window.removeEventListener('beforeunload', handleBeforeUnload)
}, [currentProgress])
```

**面試話術**：

> "使用者可能直接關閉瀏覽器，這時 React cleanup 來不及執行。我用 `beforeunload` listener 確保進度不會遺失。"

#### 技術亮點 2：Ref-based Completion Guard

**展示檔案**：[use-video-progress.ts:90-95](src/hooks/use-video-progress.ts#L90-L95)

```typescript
const hasCompletedRef = useRef(false)

const handleVideoEnd = () => {
	if (hasCompletedRef.current) return // 🔥 防止重複標記

	hasCompletedRef.current = true
	saveProgress(100) // 標記完成
	onComplete?.() // 觸發交付 UI 變化
}
```

**面試話術**：

> "我在測試時發現 YouTube 的 `onEnd` 事件會觸發多次（特別是使用者快轉到結尾時）。用 `useRef` 做 guard，因為 ref 變化**不會觸發 re-render**，非常適合這種 flag。"

#### 技術亮點 3：定時存檔 + Debounce

```typescript
// 播放時：每 10 秒存一次
useEffect(() => {
	if (isPlaying) {
		const interval = setInterval(() => {
			saveProgress(currentProgress)
		}, 10000)
		return () => clearInterval(interval)
	}
}, [isPlaying])

// 暫停時：立即存檔
const handlePause = () => {
	saveProgress(currentProgress)
}
```

**面試話術**：

> "定時 10 秒存檔是效能考量，避免過多 API call。但暫停時立即存檔，因為使用者可能暫停後就關閉頁面。這是 UX 和效能的平衡。"

#### 效果展示

- 進度條即時更新
- 關閉頁面再開啟 → 從上次位置繼續
- 看完後顯示灰色圓圈（可交付）
- 交付後變綠色 + 經驗值 +100

#### 小結（30 秒）

> "影片進度追蹤的核心是**可靠性**。用 beforeunload 防止遺失、用 ref guard 防止重複、用定時存檔平衡效能。這些都是實際測試中發現的問題，不是紙上談兵。"

---

## 🏗️ 加分環節：架構設計的思考（2 分鐘）

### 為什麼不用 Redux/Zustand？

> "這個專案的狀態不算複雜，Context API 已經足夠。如果未來有複雜的 computed state 或跨元件通訊需求，可以考慮 Zustand（比 Redux 輕量）。"

### 為什麼選 SWR 而不是 React Query？

> "SWR 更輕量，API 更簡潔。這個專案不需要 React Query 的 mutation、optimistic updates 等進階功能。夠用就好，不過度工程。"

### API Client 為什麼自己寫？

> "因為需要自訂 retry 邏輯（只重試 idempotent methods）、request/response interceptors（自動加 token、處理 401）。用 axios 也可以，但自己寫更輕量、更可控。"

**展示檔案**：[client.ts:100-102](src/lib/api/core/client.ts#L100-L102)

```typescript
// Idempotent methods 判斷
private isIdempotentMethod(method: HttpMethod): boolean {
  return ['GET', 'PUT', 'DELETE'].includes(method)
}

// 重試邏輯
private shouldRetry(
  method: HttpMethod,
  error: { message: string; status?: number }
): boolean {
  // 只重試 idempotent methods
  if (!this.isIdempotentMethod(method)) {
    return false
  }
  // 默認：只重試網路錯誤（無 status code）
  return !error.status
}
```

**面試話術**：

> "我特別注意 PUT 是 idempotent 但 POST 不是，所以重試邏輯只對 GET/PUT/DELETE 啟用。這避免了重複下單的風險。"

### 型別安全的重要性

```typescript
// Discriminated Union Pattern
type ApiResponse<T> = { success: true; data: T } | { success: false; error: ApiError }

// TypeScript 可以自動 narrow type
if (response.success) {
	console.log(response.data) // TypeScript 知道這裡有 data
} else {
	console.log(response.error) // TypeScript 知道這裡有 error
}
```

**面試話術**：

> "所有 API response 都用 `ApiResponse<T>` 包裝，這是 discriminated union，TypeScript 可以自動 narrow type。這避免了 runtime 的 `undefined` 錯誤。"

---

## 🎤 總結：我的技術價值（1 分鐘）

### 三個核心能力展示

1. **系統設計**：三層 Context 協作、訂單狀態機
2. **效能優化**：Set O(1)、平行 API、Pre-check early return
3. **可靠性**：錯誤處理三層、影片進度防遺失、重複防護

### 展現的思維

- **問題導向**：不是為了用技術而用技術，而是解決實際問題
- **Trade-offs 意識**：為什麼選這個而不是那個？
- **邊界情況處理**：beforeunload、ref guard、跨 tab 同步
- **可維護性**：型別安全、職責分離、註解清楚

### 結尾話術

> "這個專案雖然是 AI 協助開發，但每個技術決策我都深入理解並做了優化。我展示的不只是程式碼，而是**解決問題的完整思維**。"

---

## 📊 時間分配總結

| 環節                 | 時間   | 核心內容                                 |
| -------------------- | ------ | ---------------------------------------- |
| 開場                 | 2 分鐘 | 專案定位 + Spec 概覽                     |
| 問題一：付費內容保護 | 8 分鐘 | 三層 Context + Set O(1) + 跨 tab 同步    |
| 問題二：訂單流程     | 7 分鐘 | 多層防護 + SWR 狀態管理 + useEffect 分離 |
| 問題三：影片進度追蹤 | 6 分鐘 | beforeunload + ref guard + 定時存檔      |
| 架構思考             | 2 分鐘 | 技術選型 trade-offs                      |
| 總結                 | 1 分鐘 | 三個核心能力                             |

---

## 💡 面試技巧提醒

### 展示時的話術模式

1. **需求**："Spec 要求..."
2. **挑戰**："這裡的難點是..."
3. **解法**："我用...來解決，因為..."
4. **效果**："這樣做的好處是..."

### 加分點

- 多提「**為什麼**」而不只是「**是什麼**」
- 展示「**測試中發現的問題**」（ref guard、beforeunload）
- 提到「**Trade-offs**」（SWR vs React Query、Context vs Redux）
- 用「**Big O**」等 CS 術語（O(1) vs O(n)）

### 避免的陷阱

- ❌ "AI 寫的我不太懂"
- ✅ "AI 提供初版，我優化了 X、Y、Z"

- ❌ "這個功能很簡單"
- ✅ "這個功能的核心挑戰是..."

---

## 📁 關鍵檔案參考

### API 層

- [src/lib/api/core/client.ts](src/lib/api/core/client.ts) - 泛型 API Client，retry 邏輯
- [src/lib/api/core/config.ts](src/lib/api/core/config.ts) - Request/Response interceptors
- [src/lib/api/api-schema/](src/lib/api/api-schema/) - 型別定義

### 狀態管理

- [src/contexts/auth-context.tsx](src/contexts/auth-context.tsx) - 身份驗證
- [src/contexts/user-purchase-context.tsx](src/contexts/user-purchase-context.tsx) - 購買權限（Set O(1)、localStorage 同步）
- [src/contexts/journey-context.tsx](src/contexts/journey-context.tsx) - 課程內容

### 業務邏輯

- [src/hooks/use-mission.ts](src/hooks/use-mission.ts) - 任務邏輯協調（Pre-check）
- [src/hooks/use-video-progress.ts](src/hooks/use-video-progress.ts) - 影片進度追蹤（beforeunload、ref guard）
- [src/hooks/use-api.ts](src/hooks/use-api.ts) - 401 統一處理

### 頁面

- [src/app/(app)/journeys/[journeySlug]/orders/[orderId]/page.tsx](<src/app/(app)/journeys/[journeySlug]/orders/[orderId]/page.tsx>) - 訂單狀態處理
- [src/components/auth/login-form.tsx](src/components/auth/login-form.tsx) - 表單驗證（zod + react-hook-form）

### 路由

- [src/middleware.ts](src/middleware.ts) - 路由保護

---

## 🎯 預期問答準備

### Q: "為什麼不用 Redux？"

**A**: "這個專案的狀態樹不複雜，三個 Context 已經足夠。Redux 會引入額外的 boilerplate（actions、reducers、store）。我選擇 Context API 是基於**夠用就好**的原則，不過度工程。如果未來狀態管理變複雜，可以考慮 Zustand，它比 Redux 輕量但有更好的 DX。"

### Q: "如何處理 Context 的 re-render 問題？"

**A**: "我在 Context 中使用 `useMemo` 和 `useCallback` 優化。例如在 UserPurchaseContext 中，`hasPurchased` 函數用 `useCallback` 包裝，避免每次 re-render 都建立新函數。此外，三個 Context 分離也減少了不必要的 re-render 範圍。"

### Q: "API Client 的 retry 機制如何設計？"

**A**: "只對 idempotent methods（GET、PUT、DELETE）啟用 retry，因為這些操作重複執行不會改變系統狀態。POST 和 PATCH 不重試，避免重複下單或重複修改。Retry 使用指數退避（100ms、200ms、400ms），最多重試 3 次。"

### Q: "影片進度追蹤如何處理網路不穩定？"

**A**: "使用 `beforeunload` listener 確保頁面關閉前存檔。定時存檔每 10 秒一次，即使網路斷線，最多只會遺失 10 秒進度。暫停時立即存檔，因為使用者可能暫停後就關閉。此外，API Client 有 retry 機制，網路錯誤會自動重試。"

### Q: "如何測試這些 hooks？"

**A**: "可以用 React Testing Library 的 `renderHook`。例如測試 `useMission` 時，mock 三個 Context 的值，驗證不同情境下的行為（已購買、未購買、未登入）。對於 `useVideoProgress`，可以 mock YouTube API，測試 onEnd 觸發多次時的防護邏輯。"

### Q: "跨 tab 同步為什麼用 localStorage 而不是 BroadcastChannel？"

**A**: "BroadcastChannel 更現代，但瀏覽器支援度不如 localStorage events（IE11 不支援 BroadcastChannel）。對於學習平台，使用者可能用舊版瀏覽器，localStorage events 相容性更好。未來如果不需考慮舊瀏覽器，可以改用 BroadcastChannel。"

---

## 🚀 後續改進點（展現成長思維）

如果面試官問「你覺得這個專案還能怎麼改進？」，可以提：

1. **效能優化**

   - 用 React.memo 減少不必要的 re-render
   - 用 React Query 的 prefetch 預載資料
   - 用 Next.js Image 優化圖片載入

2. **可測試性**

   - 加入 unit tests（Jest + React Testing Library）
   - E2E tests（Playwright）測試完整購買流程
   - API mocking（MSW）隔離前後端測試

3. **可觀測性**

   - 加入 error tracking（Sentry）
   - 加入 analytics（追蹤使用者行為）
   - 加入 performance monitoring（Core Web Vitals）

4. **使用者體驗**

   - Optimistic UI（按下購買後立即顯示成功，背景呼叫 API）
   - Skeleton loading（載入時顯示骨架屏而不是空白）
   - 離線支援（Service Worker 快取影片進度）

5. **安全性**
   - Content Security Policy（CSP）防 XSS
   - Rate limiting（防暴力破解）
   - CSRF token（防跨站請求偽造）

**話術範例**：

> "如果有更多時間，我會加入 E2E 測試確保購買流程的可靠性，並且用 Sentry 追蹤 production 錯誤。此外，可以用 Optimistic UI 提升購買體驗，讓使用者感覺更快。"
