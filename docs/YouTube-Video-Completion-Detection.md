# YouTube 影片播放完畢偵測 - Next.js 實作指南

## 問題說明

在課程網站中，需要偵測 YouTube 未公開影片何時播放完畢，以便將該課程單元的狀態標記為「已完成」。

## 解決方案

使用 **YouTube IFrame Player API** + **react-youtube** 套件

### 重要資訊

- ✅ **未公開影片完全支援** - 與公開影片使用相同的 API
- ✅ **播放完畢偵測** - 透過 `onEnd` 事件處理
- ✅ **Next.js 相容** - 必須使用 `"use client"` 建立客戶端元件

---

## 快速上手

### 1. 安裝套件

```bash
npm install react-youtube
```

### 2. 建立影片播放器元件

建立檔案：`components/CourseVideoPlayer.jsx`

```javascript
'use client'

import { useState, useRef } from 'react'
import YouTube from 'react-youtube'

export default function CourseVideoPlayer({ videoId, unitId, onComplete }) {
	const [isCompleted, setIsCompleted] = useState(false)
	const completedRef = useRef(false)

	const opts = {
		height: '480',
		width: '854',
		playerVars: {
			autoplay: 0,
			controls: 1,
			modestbranding: 1,
			rel: 0 // 不顯示相關影片
		}
	}

	const handleVideoEnd = async () => {
		// 防止重複標記完成
		if (completedRef.current) return

		completedRef.current = true
		setIsCompleted(true)

		try {
			// 呼叫完成處理函式（更新後端狀態）
			await onComplete(unitId)
			console.log(`課程單元 ${unitId} 已完成`)
		} catch (error) {
			console.error('更新課程狀態失敗:', error)
		}
	}

	const handleReady = (event) => {
		console.log('影片播放器已就緒')
	}

	const handleError = (event) => {
		const errorMessages = {
			2: '無效的影片 ID',
			100: '找不到影片或影片已移除',
			101: '影片無法嵌入',
			150: '影片無法嵌入'
		}

		const message = errorMessages[event.data] || '未知錯誤'
		console.error('YouTube 播放器錯誤:', message)
	}

	return (
		<div className="video-player-wrapper">
			<YouTube
				videoId={videoId}
				opts={opts}
				onReady={handleReady}
				onEnd={handleVideoEnd}
				onError={handleError}
			/>
			{isCompleted && <div className="completion-badge">✓ 影片已完成</div>}
		</div>
	)
}
```

### 3. 在課程頁面使用

```javascript
import CourseVideoPlayer from '@/components/CourseVideoPlayer'

export default function LessonPage({ lesson }) {
	const handleComplete = async (unitId) => {
		// 更新後端課程完成狀態
		const response = await fetch('/api/course/units/complete', {
			method: 'POST',
			headers: { 'Content-Type': 'application/json' },
			body: JSON.stringify({
				unitId,
				completedAt: new Date().toISOString()
			})
		})

		if (!response.ok) {
			throw new Error('更新進度失敗')
		}

		// 可選：解鎖下一課程或導向下一頁
		// router.push('/course/next-lesson');
	}

	return (
		<div className="lesson-container">
			<h1>{lesson.title}</h1>
			<CourseVideoPlayer
				videoId={lesson.youtubeVideoId}
				unitId={lesson.id}
				onComplete={handleComplete}
			/>
		</div>
	)
}
```

---

## 關鍵重點

### 1. 必須使用 "use client"

YouTube 播放器需要瀏覽器 API，因此元件必須是客戶端元件：

```javascript
'use client'
```

### 2. 播放完畢事件

`onEnd` 事件會在影片播放完畢時自動觸發，此時執行完成邏輯。

### 3. 防止重複標記

使用 `useRef` 追蹤是否已標記完成，避免重複呼叫 API。

### 4. YouTube 影片 ID

未公開影片的 ID 可從影片 URL 取得：

- URL: `https://www.youtube.com/watch?v=VIDEO_ID_HERE`
- 只需使用 `VIDEO_ID_HERE` 部分

---

## 常見問題

### Q1: 未公開影片可以使用這個方法嗎？

**可以！** 未公開（Unlisted）影片與公開影片使用相同的 API，完全支援所有功能。只有「私人」（Private）影片需要 OAuth 認證。

### Q2: 如何處理用戶跳到影片結尾的情況？

如果需要確保用戶完整觀看，可以追蹤實際播放時間：

```javascript
const [watchedSeconds, setWatchedSeconds] = useState(0)

const handleReady = (event) => {
	const player = event.target

	// 每秒追蹤播放進度
	setInterval(() => {
		const currentTime = player.getCurrentTime()
		setWatchedSeconds(Math.floor(currentTime))
	}, 1000)
}

const handleEnd = () => {
	const duration = playerRef.current.getDuration()
	const watchPercentage = (watchedSeconds / duration) * 100

	// 只有觀看超過 90% 才標記完成
	if (watchPercentage >= 90) {
		onComplete(unitId)
	}
}
```

### Q3: 播放器在 Next.js 中無法顯示怎麼辦？

確認以下檢查項目：

1. ✅ 元件檔案開頭有 `"use client"`
2. ✅ 已安裝 `react-youtube` 套件
3. ✅ YouTube 影片 ID 正確
4. ✅ 影片允許嵌入（檢查影片設定）

---

## 進階選項

### 客製化播放器參數

```javascript
const opts = {
	height: '480',
	width: '854',
	playerVars: {
		autoplay: 1, // 自動播放
		controls: 1, // 顯示控制列
		modestbranding: 1, // 簡化 YouTube Logo
		rel: 0, // 不顯示相關影片
		cc_load_policy: 1, // 預設顯示字幕
		iv_load_policy: 3, // 隱藏影片註解
		start: 10 // 從第 10 秒開始播放
	}
}
```

### TypeScript 版本

```typescript
import YouTube, { YouTubeProps, YouTubeEvent } from 'react-youtube'

interface CourseVideoPlayerProps {
	videoId: string
	unitId: string
	onComplete: (unitId: string) => Promise<void>
}

export default function CourseVideoPlayer({ videoId, unitId, onComplete }: CourseVideoPlayerProps) {
	// ... 實作內容同上
}
```

---

## 參考資源

- [YouTube IFrame Player API 官方文件](https://developers.google.com/youtube/iframe_api_reference)
- [react-youtube 套件](https://www.npmjs.com/package/react-youtube)
- [Next.js Client Components](https://nextjs.org/docs/app/building-your-application/rendering/client-components)
