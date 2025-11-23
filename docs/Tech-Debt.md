# 技術債清單

## TD-001: Journey Mission Progress N+1 查詢問題

**檔案位置**: `src/contexts/journey-context.tsx:43-62`

**問題描述**:
目前在取得 journey 資料後，會針對每個 mission 個別呼叫 `missionApi.getUserMissionProgress()` API，造成 N+1 查詢問題。若一個 journey 有 20 個 missions，就會發出 20 個 API 請求。

**現行程式碼**:
```typescript
const allMissionIds = journeyData.chapters.flatMap(chapter =>
  chapter.missions.map(mission => mission.id)
)

// Fetch progress for all missions in parallel
const progressResults = await Promise.all(
  allMissionIds.map(missionId =>
    missionApi.getUserMissionProgress(parseInt(userId), missionId)
  )
)
```

**影響**:
- 大量 HTTP 請求增加網路負擔
- 增加後端伺服器負載
- 前端等待時間較長
- 在 mission 數量多時效能問題更明顯

**建議解決方案**:
後端新增批次查詢 API，例如：
```
GET /api/users/{userId}/journeys/{journeyId}/mission-progress
```

回傳該使用者在指定 journey 中所有 mission 的 progress status，讓前端只需一次請求即可取得所有資料。

**優先級**: 中

**建立日期**: 2025-01-23
