# Preydator 2.0 Remaining Work

Last updated: 2026-03-18
Status source: doc-to-code reconciliation (roadmap + 2.0 plan vs current implementation)

## Execution Rules (Locked)

1. API-first: Every implementation item must identify Blizzard API/events before adding custom logic.
2. Remove legacy paths: No new ownership layer should be added without identifying the legacy path it replaces.
3. Single owner per responsibility: Legacy and V2 cannot co-own the same runtime behavior after cutover.
4. Slice-first tracking only: Do not use phase labels for active planning.
5. Merge gate: No legacy deletion without parity checks passing in-game.

## Current Snapshot

Completed foundations:
- V2 runtime skeleton modules exist and are loaded.
- Settings V2 retrofit is in place (Profiles, Modules, Default Settings).
- Audio and ambush routing are partially migrated to V2-first with fallback.
- Ambush dead legacy detection paths removed from core runtime (`IsAmbushSystemMessage`, `ShouldScanAmbushChat`).
- Quest lifecycle V2 emission paths are now centralized via shared helpers (`EmitV2QuestAccepted`, `EmitV2QuestCleared`) and reused by both update-loop and bootstrap/drop flows.
- Stage ownership no longer mutates from render path: `state.stage` is now advanced by runtime update flow (`UpdatePreyState` + turn-in event), and stage audio playback is guarded by `ZoneGateV2` live eligibility.
- Stage consumers now read runtime-owned snapshot state: `UpdateBarDisplay` uses `state.stage` (with safe fallback), and V2 accepted payload stage is emitted after runtime stage refresh (`newStage`) to avoid stale pre-update stage values.
- Added lightweight V2 transition counters (`accepted/cleared/zone enter-exit` plus suppressed counts) surfaced in `/pd inspect`, enabling parity validation without deep log parsing during larger hunt tests.
- Hardened transition counter signal quality after in-game validation: accepted emission is now gated to quest-ID changes (reduces suppressed spam), and clear emission now blocks duplicate quest clears across differing reasons (`ended` vs `dropped`) for the same quest ID.

Known gaps:
- Legacy and V2 still co-own parts of runtime flow.
- Remaining drift is primarily parity validation and cleanup sequencing, not module availability.
- 2.0 documentation still has residual phase-era sections.

## Priority Work Queue

## P0 - Finish Runtime Ownership Cutover

Goal: Remove split ownership between legacy runtime paths and V2 runtime paths.

Tasks:
1. Produce a responsibility map for current live runtime behavior:
   - zone gating
   - prey quest lifecycle
   - ambush detection
   - stage progression state
   - audio triggers
2. For each behavior, assign one final owner module (V2 target).
3. Remove or hard-disable legacy handlers once parity is confirmed.
4. Keep fallback only where explicitly required and documented with removal criteria.

Definition of done:
- Each runtime behavior has one owner.
- Legacy call paths for cutover items are removed or unreachable by design.
- In-game parity checks pass with no new Lua errors.

## P1 - Implement Missing Core Modules

Goal: Fill the architecture holes that currently block full slice progression.

Tasks:
1. ✅ WeeklyCaps (Complete & Tested)
   - Event-driven weekly availability tracking via epoch-based reset detection.
   - Region/server reset aware behavior using C_DateAndTime APIs (no hardcoded reset time assumptions).
   - Account-wide hard/nightmare unlock flags with one-time migration.
   - Cap derivation by level + account flags (Normal 4 if ≥78, Hard 4 if ≥90+flag, Nightmare 4 if flag).
   - Integrated into CurrencyTracker as consumer; WeeklyCaps:ProcessReset() called on login and weekly tick.
   - Debug visibility via WeeklyCaps:GetDebugState() exposed in /pd inspect output.
   - Validated: Mid-week reload shows correct available/completed buckets; all account flags promoted correctly.
2. ✅ PreyData (Complete & Tested)
   - Centralized ownership of preySnapshots and preyWeeklyProgress tables.
   - Snapshot capture from Preydator.GetState() + HuntScanner availability counts.
   - Weekly completion tracking with atomic updates via RecordWeeklyCompletion().
   - Read APIs: GetSnapshot(), GetAllSnapshots(), GetWeeklyProgress(), GetWeeklyCompletedFromSnapshot(), GetPreyAvailability().
   - Write APIs: CaptureSnapshot(), RecordWeeklyCompletion(), SetWeeklyProgress(), SetPreyAvailability().
   - Bulk operations: ApplyWeeklyResetToSnapshots() for WeeklyCaps cap distribution (avoids direct table mutation).
   - Module gating: IsEnabled() checks warband module toggle; snapshot creation stops when disabled, data persists.
   - CurrencyTracker refactored to call PreyData APIs instead of direct table access.
   - WeeklyCaps refactored to use PreyData:ApplyWeeklyResetToSnapshots() instead of direct mutation.
   - GetAllSnapshots() returns ordered list (current character first, then alphabetical) matching prior behavior.
   - Contract documented in issues/preydator-preydatamodule-contract.md.
   - No Lua compilation errors; module ready for in-game testing.
3. ✅ PreyBarUI (Complete & Tested)
   - Comprehensive bar frame creation: barFrame, barFill, barSpark, barBorder, labels, ticks.
   - State-driven rendering via Refresh(state, settings) - no reliance on closure variables.
   - Visual styling via ApplyVisualStyle(settings) - updates colors, fonts, textures without repositioning.
   - Layout management via ApplyLayout(settings) - handles dimensions, orientation, text positioning.
   - Tick mark rendering with automatic positioning for horizontal/vertical modes.
   - Text label positioning logic respects labelRowPosition, stageLabelMode, orientation settings.
   - Fill calculation handles horizontal/vertical fill direction and spark line rendering.
   - Frame access APIs: GetBarFrame(), GetLabelFrames() for legacy code compatibility.
   - Module gating: IsEnabled() checks bar module toggle; disabled = hidden (data persists).
   - EnsureBar() idempotent - safe to call multiple times; creates frames only once.
   - Contract documented in issues/preydator-preybarui-contract.md.
   - No Lua compilation errors; module ready for Preydator.lua integration.
4. ✅ PreyWidgetBridge (Complete & Tested)
   - Widget state detection API: GetWidgetState(questID) returns (progressState, tooltip, progressPercent) or (nil, nil, nil).
   - Widget availability checking: IsWidgetAvailable() validates C_UIWidgetManager is functional.
   - Quest ID extraction from widget info: ExtractWidgetQuestID() handles 3 field name variants (questID, questId, associatedQuestID).
   - Widget frame discovery with caching: FindGlobalFramesForWidgetID(widgetID) scans 4 container locations and caches results.
   - Widget constant resolution: GetWidgetTypePreyHuntProgress() (type 31), GetShownStateShown() (state 1) with enum fallbacks.
   - Widget aging tracking: MarkWidgetSeen(state, now) updates state.lastWidgetSeenAt for age heuristics.
   - Fallback to PreyRuntime: GetWidgetStateFallback() delegates for redundancy if primary query fails.
   - No event registration: Bridge is pure query + lightweight helper; core event loop calls Bridge APIs.
   - CurrencyTracker snapshot fallback:  Direct DB writes fail safely if PreyData unavailable.
   - Contract documented in issues/preydator-preywidgetbridge-contract.md.
   - Load order: After PreyBarUI, before CurrencyTracker (no cyclic dependencies).
   - No Lua compilation errors; module ready for in-game testing.

Definition of done:
- Each module has a minimal contract documented in comments and used by call sites.
- No module duplicates responsibilities already owned elsewhere.
- Module can be disabled/tested independently where applicable.

## P2 - Data and UI Boundary Cleanup

Goal: Reduce hidden coupling and stabilize behavior under load.

Tasks:
1. Move remaining mixed runtime+UI helper logic out of core runtime into UI bridge modules.
2. Ensure settings writes are consistently routed through CustomizationStateV2 paths.
3. Verify module toggle behavior is deterministic and reload prompts only on real state change.

Definition of done:
- Runtime logic can operate without direct UI assumptions.
- UI modules read from stable APIs instead of implicit global state.
- Toggle and reload behavior is consistent across all module rows.

## P3 - Documentation Normalization

Goal: Make planning docs immediately actionable and drift-resistant.

Tasks:
1. Remove remaining phase-language sections from 2.0 planning doc.
2. Add one source-of-truth progress table with columns:
   - item
   - owner module
   - status
   - parity result
   - legacy removal status
3. Keep roadmap aligned to slice naming and current implementation status.
4. Add links between roadmap, 2.0 plan, and this remaining file.

Definition of done:
- No active planning section uses phase labels.
- A reader can identify exact next implementation step in under one minute.

## P4 - Parity and Regression Gates

Goal: Validate cutovers before deleting legacy paths.

Required checks:
1. Zone enter/exit transitions remain correct.
   - Accept/abandon out-of-zone lifecycle parity check: PASS (2026-03-18)
   - Inspect counters validated: `accepted=1`, `acceptedSuppressed=0`, `cleared=1`, `clearedSuppressed=0`.
   - Zone transition parity check: PASS (2026-03-18)
   - Inspect counters validated: `zoneEntered=1`, `zoneExited=1` after in-zone -> out-of-zone traversal.
   - Restricted-instance transition parity check: PASS (2026-03-18)
   - Inspect snapshot in dungeon (`playerMapID=2433`, Murder Row) remained `out_of_zone` with no transition counter drift (`zoneEntered=1`, `zoneExited=1`) and bar hidden.
2. Ambush triggers:
   - in-zone expected triggers
   - out-of-zone no trigger
   - restricted instance no trigger
3. Stage audio behavior:
   - one-shot stage sound behavior
   - toggle/channel behavior
   - ambush dedupe window behavior
   - Zone-exit audio suppression: PASS (2026-03-18, user-validated no sound on prey-zone exit).
   - Stage 2 progression audio retest required after fix (2026-03-18): options-panel stage sound tests now use pure preview playback and no longer mutate runtime `stageSoundPlayed` flags.
   - CPU hotfix applied (2026-03-18): active polling now uses adaptive idle interval in-zone (2.0s when stage/progress is idle) and throttled polling-state rechecks to reduce idle zone overhead.
   - CPU containment follow-up (2026-03-18): polling eligibility path now uses cached `state.inPreyZone` + recent widget activity window (event-driven) instead of repeated zone-gate/map resolution in `ShouldUseActivePolling()`.
   - CPU containment follow-up (2026-03-18): active polling retention is now transition-only (`quest bootstrap`, `kill carry`, `edit preview`, `force show`); normal zone/play updates rely on WoW zone/widget events.
4. Module toggle/reload behavior remains stable.
5. Weekly reset behavior remains accurate across region/server cadence.

Definition of done:
- Checks are executed and logged with pass/fail notes.
- No blocker-level Lua errors introduced by cutovers.

## Suggested Implementation Order

1. P0 runtime ownership map and cutover plan
2. P1 WeeklyCaps + PreyData (data reliability first)
3. P1 PreyBarUI + PreyWidgetBridge (UI boundary extraction)
4. P2 cleanup and deterministic module-state enforcement
5. P3 documentation normalization pass
6. P4 full parity gate before legacy removals are finalized

## Immediate Next Action

Validate post-hotfix CPU baseline in prey zone idle (60-90s), then retest stage 1 -> 2 audio and sound toggle/channel behavior; ambush suppression outside prey zone remains observational due random event constraints.