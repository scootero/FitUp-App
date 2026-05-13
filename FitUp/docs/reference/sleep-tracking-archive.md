# Sleep tracking (archived)

This document preserves what the removed **Apple Health sleep** feature did in FitUp. The live app no longer requests `sleepAnalysis`, fetches sleep samples, or shows sleep UI. Full Swift lived in git history (pre-removal `HealthKitService.swift` and the three card files below).

## HealthKit

- **Read type:** `HKCategoryTypeIdentifier.sleepAnalysis` (`HKObjectType.categoryType(forIdentifier: .sleepAnalysis)`).
- **Not used:** background delivery and `HKObserverQuery` never included sleep; only `stepCount` and `activeEnergyBurned` were observed.

## Behavior (historical)

- **`HealthKitService.fetchSleepSummary(nights:)`** — async, non-throwing; returned `HealthSleepSummary` or an empty-shaped summary on failure.
- **Last-night window (local):** previous calendar day **18:00** → today **12:00**. All overlapping `sleepAnalysis` samples; overlap resolution via `winningSleepCategory` / `sleepCategoryPriority` (no double-counting). Awake excluded from “time asleep” and from Sleep Ratio denominators.
- **Wake-day rollups:** nightly hours and 7-night stage mix used per–wake-day canonical metrics from the same sample set.
- **Models:** `HealthSleepSummary`, `HealthSleepStagePercentages`, `HealthSleepTimelineSegment`, `HealthSleepTimelineStage`, `SleepRatioBreakdown`. **Sleep Ratio** UI read **only** `lastNightSleepRatio` (deep / light / rem percents).
- **Hypnogram:** `lastNightTimeline` segments (deep / core / rem / awake).

## UI (removed)

- **Health tab:** “Sleep Quality” — `LastNightSleepCard`, `SleepRatioCard`, `SevenNightSleepAverageCard`.
- **Battle readiness:** moon chip with formatted last-night hours; **Component breakdown** row labeled Sleep.
- **Profile → Health Data Info:** sleep last night, per-source sleep rows, sleep sample count, last-night window debug rows.

## Readiness score

- `ReadinessCalculator.compute` accepted `sleepHrsLastNight`; when non-nil and `sleepGoalHours > 0`, sleep contributed ~35% weight (see `ReadinessCalculator.swift`). The app now passes **nil** for sleep so weights renormalize (same as “no sleep data” path).

## Storage / backend

- **No Supabase** reads/writes for sleep. Health screen optional HK loads were in-memory + logging only (`loadOptionalHK`).

## Key files (pre-removal)

| File | Role |
|------|------|
| `FitUp/FitUp/FitUp/Services/HealthKitService.swift` | `readAuthorizationTypes`, `fetchSleepSummary`, canonical overlap pipeline, DEBUG sleep logs |
| `FitUp/FitUp/FitUp/Services/HealthKitPerSourceBreakdown.swift` | Approximate asleep hours per source (last-night window) |
| `FitUp/FitUp/FitUp/ViewModels/HealthViewModel.swift` | Loaded summary, readiness input, logging snapshot |
| `FitUp/FitUp/FitUp/ViewModels/HealthDataBreakdownViewModel.swift` | Debug screen sleep headline + breakdown |
| `FitUp/FitUp/FitUp/Views/Health/HealthView.swift` | Sleep Quality section |
| `FitUp/FitUp/FitUp/Views/Health/Cards/LastNightSleepCard.swift` | Hypnogram + last night hours |
| `FitUp/FitUp/FitUp/Views/Health/Cards/SleepRatioCard.swift` | Deep / Light / REM |
| `FitUp/FitUp/FitUp/Views/Health/Cards/SevenNightSleepAverageCard.swift` | 7-night average + bars |
| `FitUp/FitUp/FitUp/Views/Health/Cards/BattleReadinessCard.swift` | Sleep chip |
| `FitUp/FitUp/FitUp/Views/Health/Cards/ComponentBreakdownCard.swift` | Sleep row |
| `FitUp/FitUp/FitUp/Design/DesignTokens.swift` | `FitUpColors.HealthSleepStage` hypnogram colors |
| `FitUp/docs/fitup-docs-pack.md` §11 | Authoritative written spec (still in repo; may describe retired behavior) |

## Caveats

- Per-source sleep in Health Data Info was a **simple sum** by source and did **not** match canonical overlap resolution in `fetchSleepSummary`.
- Unused helpers existed at various times (`fetchCategorySamples`, `timelineStage`, etc.); see git for exact state.
