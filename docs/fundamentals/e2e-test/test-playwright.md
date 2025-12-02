# Playwright E2E 測試基本語法指南

## 目錄

1. [測試結構基礎](#測試結構基礎)
2. [頁面導航](#頁面導航)
3. [元素定位器 (Locators)](#元素定位器-locators)
4. [互動操作](#互動操作)
5. [斷言 (Assertions)](#斷言-assertions)
6. [等待機制](#等待機制)
7. [測試步驟組織](#測試步驟組織)
8. [API 測試](#api-測試)
9. [Context 與 Cookie 管理](#context-與-cookie-管理)
10. [測試隔離與共享狀態](#測試隔離與共享狀態)

---

## 測試結構基礎

### 基本測試框架

```typescript
import { test, expect } from '@playwright/test'

// 描述測試群組
test.describe('測試群組名稱', () => {
	// 單個測試案例
	test('測試案例描述', async ({ page }) => {
		// 測試邏輯
	})
})
```

### 測試的核心參數

- **`page`**: 瀏覽器頁面物件，用於互動與導航
- **`context`**: 瀏覽器上下文，管理 cookies 和隔離狀態
- **`request`**: API 請求物件，用於呼叫後端 API

```typescript
test('完整參數範例', async ({ page, context, request }) => {
	// page: 操作瀏覽器頁面
	// context: 管理 cookies、權限等
	// request: 執行 HTTP 請求
})
```

---

## 頁面導航

### 基本導航

```typescript
// 前往指定 URL
await page.goto('/')
await page.goto('/login')
await page.goto('https://example.com')

// 等待頁面載入完成
await page.waitForLoadState('networkidle') // 等待網路閒置
await page.waitForLoadState('domcontentloaded') // 等待 DOM 載入
await page.waitForLoadState('load') // 等待 load 事件
```

### 驗證 URL

```typescript
// 驗證當前 URL
await expect(page).toHaveURL('/login')

// 使用正則表達式驗證 URL
await expect(page).toHaveURL(/\/journeys\/[^/]+\/chapters\/\d+/)

// 使用正則表達式並設定 timeout
await expect(page).toHaveURL(new RegExp(`/orders/[^/]+$`), { timeout: 10000 })
```

### 頁面重新載入

```typescript
// 重新載入當前頁面
await page.reload()

// 取得當前 URL
const currentUrl = page.url()
```

---

## 元素定位器 (Locators)

### 常用定位方法

#### 1. 透過 Role 定位（推薦）

```typescript
// 按鈕
await page.getByRole('button', { name: '登入' })

// 連結
await page.getByRole('link', { name: '註冊' })

// 文字輸入框
await page.getByRole('textbox', { name: '使用者名稱' })
```

#### 2. 透過 Placeholder 定位

```typescript
await page.getByPlaceholder('請輸入使用者名稱')
await page.getByPlaceholder('請輸入密碼')
```

#### 3. 透過文字內容定位

```typescript
// 精確文字
await page.getByText('註冊成功！')

// 正則表達式
await page.getByText(/大章節/i)
await page.getByText(/完成任務並領取.*XP/i)
```

#### 4. CSS Selector

```typescript
// 一般 selector
await page.locator('header')
await page.locator('form')
await page.locator('h1')

// class selector
await page.locator('.text-green-500')
await page.locator('svg.lucide-circle')

// attribute selector
await page.locator('[data-sidebar="content"]')
await page.locator('svg[stroke-dasharray="3 3"]')
```

#### 5. 階層式定位

```typescript
// 從父元素定位子元素
const header = page.locator('header')
await header.locator('button')

// 表單中的特定按鈕
await page.locator('form').getByRole('button', { name: '登入' })

// 側邊欄中的特定連結
const sidebar = page.locator('[data-sidebar="content"]')
const missionLink = sidebar.locator(`a[href="${MISSION_URL}"]`)
```

#### 6. 連結 (href) 定位

```typescript
// 透過 href 屬性定位
await sidebar.locator(`a[href="/missions/1"]`)
```

### Locator 方法

```typescript
// 第一個匹配的元素
await page.locator('button').first()

// 最後一個匹配的元素
await page.locator('button').last()

// 第 n 個元素 (從 0 開始)
await page.locator('button').nth(2)

// 計數
const count = await page.locator('button').count()
```

---

## 互動操作

### 點擊

```typescript
// 基本點擊
await page.getByRole('button', { name: '登入' }).click()

// 雙擊
await element.dblclick()

// 右鍵點擊
await element.click({ button: 'right' })
```

### 填寫表單

```typescript
// 填入文字
await page.getByPlaceholder('請輸入使用者名稱').fill('testuser')

// 清空後填入
await page.getByPlaceholder('密碼').clear()
await page.getByPlaceholder('密碼').fill('newpassword')
```

### 鍵盤操作

```typescript
// 按下 Enter 鍵
await page.keyboard.press('Enter')

// 按下多個鍵
await page.keyboard.press('Control+A')
await page.keyboard.press('Shift+Tab')

// 輸入文字
await page.keyboard.type('Hello World')
```

---

## 斷言 (Assertions)

### 可見性斷言

```typescript
// 元素可見
await expect(page.getByRole('button', { name: '登入' })).toBeVisible()

// 元素不可見
await expect(page.getByRole('button', { name: '登入' })).not.toBeVisible()

// 帶 timeout 的可見性檢查
await expect(deliverButton).toBeVisible({ timeout: 10000 })
```

### 文字內容斷言

```typescript
// 包含文字
await expect(page.locator('h1')).toContainText('購買完成！')

// 正則表達式匹配
await expect(page.locator('h1')).toContainText(/AI x BDD/)

// 精確文字
await expect(page.locator('h1')).toHaveText('登入')
```

### URL 斷言

```typescript
// 精確 URL
await expect(page).toHaveURL('/login')

// 正則表達式
await expect(page).toHaveURL(/\/chapters\/\d+/)

// 帶 timeout
await expect(page).toHaveURL('/success', { timeout: 5000 })
```

### 數值斷言

```typescript
// 標準 Jest 斷言
expect(credentials.userId).toBeGreaterThan(0)
expect(authToken).toBeTruthy()
expect(progress.status).toBe('COMPLETED')
expect(response.status()).toBe(409)
expect(match).toBeTruthy()
```

### 否定斷言

```typescript
// 使用 .not 進行否定
await expect(header).not.toContainText(username)
await expect(purchaseButton).not.toBeVisible()
await expect(dashedCircleIcon).not.toBeVisible()
```

---

## 等待機制

### 等待頁面載入

```typescript
// 等待網路閒置（沒有網路請求）
await page.waitForLoadState('networkidle')

// 等待 DOM 完全載入
await page.waitForLoadState('domcontentloaded')
```

### 等待 URL 改變

```typescript
// 等待特定 URL
await page.waitForURL('/login')

// 等待 URL 符合正則表達式
await page.waitForURL(new RegExp(`/journeys/${JOURNEY_SLUG}/orders/[^/]+$`), { timeout: 10000 })
```

### 等待特定文字出現

```typescript
// 等待元素可見
await page.waitForSelector('button[name="登入"]')

// 等待文字出現（透過斷言的 timeout）
await expect(page.getByText('註冊成功！')).toBeVisible({ timeout: 10000 })
```

### 等待 API 回應

```typescript
// 等待特定的網路請求
const response = await page.waitForResponse(
	(response) => response.url().includes('/api/users') && response.status() === 200
)
```

---

## 測試步驟組織

### 使用 test.step 組織測試

```typescript
test('完整流程測試', async ({ page }) => {
	await test.step('步驟 1: 前往登入頁', async () => {
		await page.goto('/login')
		await expect(page).toHaveURL('/login')
	})

	await test.step('步驟 2: 填寫登入表單', async () => {
		await page.getByPlaceholder('使用者名稱').fill('testuser')
		await page.getByPlaceholder('密碼').fill('password')
	})

	await test.step('步驟 3: 提交表單', async () => {
		await page.getByRole('button', { name: '登入' }).click()
		await expect(page.getByText('登入成功！')).toBeVisible()
	})
})
```

---

## API 測試

### 發送 HTTP 請求

```typescript
// POST 請求
const response = await request.post('http://localhost:8080/auth/register', {
	data: { username, password }
})

// GET 請求
const response = await request.get('http://localhost:8080/users/1', {
	headers: { Authorization: `Bearer ${token}` }
})

// PUT 請求
await request.put('http://localhost:8080/users/1/progress', {
	headers: { Authorization: `Bearer ${token}` },
	data: { watchPositionSeconds: 100 }
})

// 取得回應資料
const data = await response.json()
const status = response.status()
```

### 混合 API 與 UI 測試

```typescript
test('混合測試', async ({ page, request }) => {
	// 使用 API 建立測試資料
	await test.step('透過 API 註冊使用者', async () => {
		await request.post(`${API_BASE_URL}/auth/register`, {
			data: { username: 'testuser', password: 'pass123' }
		})
	})

	// 使用 UI 進行登入
	await test.step('透過 UI 登入', async () => {
		await page.goto('/login')
		await page.getByPlaceholder('使用者名稱').fill('testuser')
		await page.getByPlaceholder('密碼').fill('pass123')
		await page.getByRole('button', { name: '登入' }).click()
	})
})
```

---

## Context 與 Cookie 管理

### 清除 Cookies

```typescript
// 清除所有 cookies
await context.clearCookies()
```

### 設定 Cookies

```typescript
await context.addCookies([
	{
		name: 'auth_token',
		value: 'your-token-here',
		domain: 'localhost',
		path: '/'
	},
	{
		name: 'user_info',
		value: encodeURIComponent(JSON.stringify({ id: 1, username: 'test' })),
		domain: 'localhost',
		path: '/'
	}
])
```

### 讀取 Cookies

```typescript
// 取得所有 cookies
const cookies = await context.cookies()

// 尋找特定 cookie
const authToken = cookies.find((cookie) => cookie.name === 'auth_token')

// 驗證 cookie 存在
expect(authToken).toBeTruthy()
expect(authToken?.value).toBeTruthy()
```

---

## 測試隔離與共享狀態

### 獨立測試（預設）

每個測試都是獨立的，不共享狀態：

```typescript
test.describe('獨立測試群組', () => {
	test('測試 1', async ({ page }) => {
		// 這個測試的狀態不會影響測試 2
	})

	test('測試 2', async ({ page }) => {
		// 全新的獨立狀態
	})
})
```

### 序列測試（共享狀態）

使用 `test.describe.serial` 讓測試按順序執行並共享狀態：

```typescript
test.describe.serial('序列測試群組', () => {
	let sharedData: any

	test('測試 1: 初始化', async ({ page }) => {
		sharedData = { userId: 123 }
		// 設定共享狀態
	})

	test('測試 2: 使用共享狀態', async ({ page }) => {
		// 可以存取 sharedData
		console.log(sharedData.userId)
	})

	test('測試 3: 繼續使用', async ({ page }) => {
		// 仍然可以存取
	})
})
```

---

## 實戰範例

### 範例 1：完整註冊登入流程

```typescript
test('註冊到登入完整流程', async ({ page, context }) => {
	// 清除 cookies 確保乾淨狀態
	await context.clearCookies()

	// 前往首頁
	await page.goto('/')
	await page.waitForLoadState('networkidle')

	// 點擊登入按鈕
	await page.getByRole('link', { name: '登入' }).click()
	await expect(page).toHaveURL('/login')

	// 前往註冊頁
	await page.getByRole('link', { name: '立即註冊' }).click()
	await expect(page).toHaveURL('/register')

	// 填寫註冊表單
	const username = `user_${Date.now()}`
	await page.getByPlaceholder('請輸入使用者名稱').fill(username)
	await page.getByPlaceholder('請輸入密碼').fill('TestPass123!')
	await page.getByPlaceholder('請再次輸入密碼').fill('TestPass123!')

	// 提交註冊
	await page.getByRole('button', { name: '註冊' }).click()
	await expect(page.getByText('註冊成功！')).toBeVisible({ timeout: 10000 })

	// 驗證跳轉到登入頁
	await expect(page).toHaveURL('/login', { timeout: 3000 })
})
```

### 範例 2：API + UI 混合測試

```typescript
test('使用 API 建立使用者後透過 UI 登入', async ({ page, request, context }) => {
	// API: 註冊使用者
	const username = `api_user_${Date.now()}`
	await request.post('http://localhost:8080/auth/register', {
		data: { username, password: 'TestPass123!' }
	})

	// API: 登入取得 token
	const loginResponse = await request.post('http://localhost:8080/auth/login', {
		data: { username, password: 'TestPass123!' }
	})
	const { accessToken, user } = await loginResponse.json()

	// 設定 cookies
	await context.addCookies([
		{
			name: 'auth_token',
			value: accessToken,
			domain: 'localhost',
			path: '/'
		},
		{
			name: 'user_info',
			value: encodeURIComponent(JSON.stringify({ id: user.id, username })),
			domain: 'localhost',
			path: '/'
		}
	])

	// UI: 驗證已登入狀態
	await page.goto('/')
	await expect(page.locator('header')).toContainText(username)
	await expect(page.getByRole('button', { name: '登出' })).toBeVisible()
})
```

### 範例 3：表單驗證測試

```typescript
test('表單驗證錯誤處理', async ({ page }) => {
	await page.goto('/register')

	// 不填寫任何欄位直接提交
	await page.getByRole('button', { name: '註冊' }).click()

	// 驗證錯誤訊息
	await expect(page.getByText('使用者名稱為必填')).toBeVisible()
	await expect(page.getByText('密碼為必填')).toBeVisible()

	// 只填寫使用者名稱
	await page.getByPlaceholder('請輸入使用者名稱').fill('test')
	await page.getByRole('button', { name: '註冊' }).click()

	// 驗證密碼錯誤訊息仍存在
	await expect(page.getByText('密碼為必填')).toBeVisible()
})
```

---

## 常見模式與最佳實踐

### 1. 產生唯一測試資料

```typescript
const timestamp = Date.now()
const username = `testuser_${timestamp}`
```

### 2. 封裝可重用的輔助函數

```typescript
async function loginUser(
	request: APIRequestContext,
	username: string,
	password: string
): Promise<string> {
	const response = await request.post('http://localhost:8080/auth/login', {
		data: { username, password }
	})
	const data = await response.json()
	return data.accessToken
}
```

### 3. 使用適當的 timeout

```typescript
// 對於可能較慢的操作，增加 timeout
await expect(element).toBeVisible({ timeout: 10000 })

// URL 跳轉
await expect(page).toHaveURL('/success', { timeout: 5000 })
```

### 4. 先驗證元素可見再操作

```typescript
const loginButton = page.getByRole('button', { name: '登入' })
await expect(loginButton).toBeVisible() // 先驗證
await loginButton.click() // 再點擊
```

### 5. 使用描述性的 test.step

```typescript
await test.step('驗證註冊成功並跳轉', async () => {
	await expect(page.getByText('註冊成功！')).toBeVisible()
	await expect(page).toHaveURL('/login')
})
```

---

## 總結

這份指南涵蓋了 Playwright E2E 測試的核心語法：

1. **測試結構**：`test.describe` 和 `test` 組織測試
2. **頁面操作**：導航、重新載入、URL 驗證
3. **元素定位**：Role、Placeholder、Text、CSS Selector
4. **互動**：點擊、填寫、鍵盤操作
5. **斷言**：可見性、文字內容、URL、數值檢查
6. **等待**：頁面載入、URL 變化、元素出現
7. **API 測試**：HTTP 請求與 UI 混合測試
8. **狀態管理**：Cookies 操作、測試隔離與共享

掌握這些語法，你將能夠：

- 撰寫清晰且可維護的 E2E 測試
- 有效地定位和操作 DOM 元素
- 整合 API 與 UI 測試
- 管理測試狀態和資料
- 回答面試中關於 Playwright 的技術問題
