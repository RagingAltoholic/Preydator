# Preydator 2.0 - Modular Retrofit and Growth Plan

Status: Draft (tracking document)
Owner: Preydator
Target window: 2.0 cycle

## Why this exists

Preydator is moving from a focused prey bar addon into a full Prey system companion.

To reduce break risk, 2.0 will do a modular retrofit first, then do behavior refactors in smaller, isolated passes.

This document tracks the sequence, checklists, risks, and completion criteria.

## 2.0 Goals

1. Complete a stable module-first architecture before major internals refactors.
2. Preserve current user customization and in-game UX while code is restructured.
3. Reduce maintenance risk from broad widget suppression logic.
4. Add achievement-aware hunt prioritization as a first-class feature.
5. Keep all future growth work data-driven and easy to test in isolation.

## Guiding principles

1. Preserve behavior first, then improve behavior.
2. Move code in cohesive slices, avoid large rewrites.
3. Keep SavedVariables shape stable unless explicitly versioned.
4. Prefer narrow API hooks over broad frame-tree suppression.
5. Keep settings and customization parity through each phase.

## Scope boundaries for 2.0

In scope:
- Modular retrofit of runtime, UI, scanner, and diagnostics responsibilities.
- Safer default prey widget integration path.
- Achievement Bridge and priority flagging in hunt scanner/table.
- Progress tracking and milestone validation.

Out of scope:
- Full visual redesign of existing settings UI.
- Breaking changes to user profile settings without migration.
- Non-Prey feature expansion unrelated to roadmap epics.

## Success criteria

1. Core systems are split by responsibility and loaded explicitly in toc order.
2. Existing features still work with customization preserved.
3. Default prey icon suppression is narrower by default and easier to maintain.
4. Hunt rows can flag missing-achievement opportunities.
5. Tracking doc reflects done and pending work at all times.

## Cleaner implementation playbook (post-scan)

Purpose:
Capture what we are adopting from the scan at a method level so no one needs to re-read other addons.

Important:
This is an implementation pattern list, not a source-copy list.

### Adopt these patterns

1. Narrow prey widget targeting first.
- Discover prey widget from PowerBar widget set and prey widget type.
- Apply suppression only to that targeted widget frame in normal operation.

2. Event and data driven hunt systems.
- Drive lifecycle, weekly counters, and reward context from quest, gossip, and currency APIs.
- Treat widgets as display/state hints, not primary data authority.

3. Adapter boundaries between systems.
- Runtime, widget bridge, scanner, and UI communicate through small module APIs.
- Keep UI rendering independent from business logic.

4. Data-driven achievement prioritization.
- Map missing criteria to hunt quest IDs and metadata.
- Expose relevance and reason APIs to scanner/table UI.

5. Graceful fallback strategy.
- If narrow widget path fails, use guarded fallback path with debug reporting.
- Never fail gameplay-critical flows because a UI frame changed.

### Avoid these patterns

1. Broad frame-tree suppression as the default path.
2. Name-based heuristic hiding across multiple unrelated containers unless in fallback mode.
3. Hardcoding one widget ID without verification path.
4. Burying achievement logic directly inside one UI renderer.

### Definition of done for optimization

Optimization is complete only when all are true:
- Narrow path is default and validated.
- Fallback path usage is observable in diagnostics.
- Hunt priority can explain why an item is flagged.
- Customization behavior parity is preserved.
- No external code copied, only technique-level implementation.

### Ethical guardrail (explicit)

1. We do not copy code from other addons.
2. We only adopt publicly observable engineering patterns.
3. We document every major architecture decision in this file.
4. We validate behavior in game and with our own tests before shipping.

---

## Phase plan

## Phase 0 - Baseline and safety rails

Status: Completed

Checklist:
- [x] Freeze current behavior expectations by module area.
- [x] Document known risky paths (widget suppression, map open fallback, quest hydration timing).
- [x] Record smoke test script for login, hunt flow, scanner, currency, minimap, options.
- [x] Confirm no SavedVariables migrations are needed before retrofit.

Exit criteria:
- [x] Baseline behavior list completed.
- [x] Smoke test checklist written and validated once.

### Phase 0 baseline behavior (frozen)

1. Runtime and bar behavior
- Active prey quest detection drives stage/progress bar updates.
- Force show and auto visibility continue to work.
- Out-of-zone and ambush labeling logic remains unchanged.

2. Settings and customization behavior
- Existing tabs and controls continue to read/write current settings keys.
- Visual customization parity remains intact (size, scale, orientation, labels, colors, sounds).
- No reset or migration is triggered by modular extraction.

3. Scanner and currency behavior
- Hunt scanner updates and interactions remain available.
- Currency tracker and warband windows keep current behavior and settings.
- Minimap button behavior remains unchanged.

4. Slash command behavior
- Existing slash commands remain available with same user-facing text and side effects.
- Diagnostics commands are now module-owned but behavior-parity is required.

### Phase 0 risk focus (frozen)

1. Default prey widget suppression path safety.
2. Quest-to-map fallback behavior in stage 4/open-map actions.
3. Async quest/reward hydration timing in scanner flows.
4. Module load order and hook execution order.
5. SavedVariables schema drift.

### Phase 0 smoke test script (baseline)

1. Login and load
- Verify addon loads without UI or Lua errors.
- Verify bar and options can be opened.

2. Hunt lifecycle
- Start hunt, confirm stage updates and sound behavior.
- Reach final stage, confirm map fallback behavior still works.
- Turn in/end hunt, confirm state clear and bar behavior.

3. Scanner and currency
- Open hunt source and verify scanner population/updates.
- Verify currency tracker and warband panel open/refresh.
- Verify minimap interactions and visibility toggles.

4. Customization parity
- Change scale/size/orientation and verify persistence.
- Change text/label/audio settings and verify persistence.
- Toggle default prey icon suppression and verify behavior.

5. Diagnostics
- Verify `/pd debug on|off|show|clear` behavior.
- Verify `/pd mem` output path.
- Verify `/pd inspect` behavior via module handling.

### SavedVariables migration decision (Phase 0)

Decision:
No schema migration in Phase 0. Keep existing SavedVariables structure stable during modular retrofit.

Rationale:
Architecture stabilization first, behavior and data compatibility preserved.

## Phase 1 - Modular retrofit first (no intended behavior changes)

Status: In progress

Objective:
Split monolithic responsibilities into stable modules while preserving behavior.

Proposed module boundaries:
- PreyRuntime: active quest/state evaluation and state transitions.
- PreyWidgetBridge: widget lookup, prey widget info reads, suppression adapter.
- PreyBarUI: bar rendering, fill updates, label/percent display logic.
- MapAndWaypoint: map opening and waypoint helpers.
- AchievementBridge: missing criteria mapping and hunt relevance checks.
- Diagnostics: inspect/debug/memory utilities.

Checklist:
- [ ] Extract PreyRuntime responsibilities.
- [ ] Extract PreyBarUI responsibilities.
- [x] Extract MapAndWaypoint responsibilities.
- [x] Extract Diagnostics helpers.
- [ ] Keep public API and settings calls compatible.
- [ ] Update toc load order for all new modules.

Exit criteria:
- [ ] Feature parity maintained after extraction.
- [ ] No regressions in existing customization behavior.

## Phase 2 - Safer widget integration refactor

Status: Not started

Objective:
Replace broad default suppression with narrow prey widget targeting, keep fallback path as safety net.

Checklist:
- [ ] Implement narrow PowerBar prey-widget discovery first.
- [ ] Suppress only targeted prey widget frame in normal path.
- [ ] Keep current broad suppression as guarded fallback path only.
- [ ] Add debug traces that identify path used (narrow vs fallback).

Exit criteria:
- [ ] Default path avoids broad frame-tree suppression.
- [ ] Fallback only used when targeted lookup fails.

## Phase 3 - Achievement Bridge foundation

Status: Not started

Objective:
Surface missing Prey achievement progress alongside hunt opportunities using Blizzard's native achievement APIs.

Approach:
Use `GetAchievementInfo`, `GetAchievementCriteriaInfo`, `ACHIEVEMENT_EARNED`, and `CRITERIA_UPDATE` from Blizzard — do not intercept quest events for achievement tracking. Blizzard owns completion credit.

Checklist:
- [ ] Define achievement watchlist source (Expansion Features > Prey).
- [ ] Read missing criteria state from Blizzard API at scan time and on `CRITERIA_UPDATE`.
- [ ] Add quest-to-achievement mapping table and metadata fields.
- [ ] Expose API: IsHuntAchievementRelevant(questID) and GetPriorityReason(questID).

Exit criteria:
- [ ] Hunt systems can query achievement relevance without UI coupling.
- [ ] No custom quest-completion tracking — Blizzard API is the source of truth.

## Phase 4 - Priority flagging and ranking

Status: Not started

Objective:
Surface achievement-aware hunt priorities in scanner/table UI.

Checklist:
- [ ] Add high-priority marker for hunts tied to missing achievements.
- [ ] Add sort mode that favors achievement-relevant hunts.
- [ ] Add tooltip reason text for why a hunt is prioritized.
- [ ] Keep fallback behavior when mapping data is incomplete.

Exit criteria:
- [ ] Players can quickly identify high-value hunts for progression.

## Phase 5 - Hardening and release prep

Status: Not started

Checklist:
- [ ] Full smoke test pass across all major systems.
- [ ] Verify options/customization parity (layout, display, text, audio, advanced).
- [ ] Verify minimap behavior and map fallback behavior.
- [ ] Update changelog and roadmap status sections.
- [ ] Tag 2.0 release checklist complete.

Exit criteria:
- [ ] Stable release candidate with documented known issues.

---

## Cross-phase risk register

1. Widget internals changing between builds.
Mitigation: narrow path first, guarded fallback path, debug path reporting.

2. Hidden behavior coupling in monolithic file.
Mitigation: extraction in small slices, frequent smoke checks.

3. SavedVariables drift during module extraction.
Mitigation: preserve schema first, isolate migrations if needed.

4. Achievement mapping incompleteness.
Mitigation: data-driven map with graceful fallback and clear unknown states.

5. Customization regression risk.
Mitigation: explicit parity checklist for settings and visual behaviors.

---

## Progress tracker

Use this section as the source of truth for what is done in this cycle.

### 2026-03-17 kickoff slice

1. HuntScanner snapshot queue optimization (completed)
- Added burst coalescing for snapshot pass scheduling to avoid repeated timer-batch creation during noisy widget/quest event storms.
- Removed duplicate immediate pass scheduling (`0.00` delayed pass) while keeping immediate + delayed refresh behavior intact.
- Scope: performance optimization only, no intended behavior changes.

2. PreyAudio modular extraction (completed)
- Added new `PreyAudio` module and moved stage/ambush sound playback runtime behavior behind module methods.
- Updated core runtime to delegate `TryPlaySound`, `ResolveStageSoundPath`, `TryPlayStageSound`, and `TriggerAmbushAlert` to module-owned logic with safe fallback behavior.
- Added module load entry in toc and exposed required constants/API methods to keep module boundaries explicit.

### Current sprint focus
- [x] Phase 0 baseline and smoke checklist
- [x] Phase 1 modular extraction prep
- [x] Phase 1 extraction slice: Diagnostics
- [x] Phase 1 extraction slice: MapAndWaypoint
- [ ] Phase 1 extraction slice: PreyRuntime (state helpers)

### Phase 1 readiness checkpoint (current)

Checkpoint status: Ready for incremental in-game test pass.

Completed extraction slices in this checkpoint:
- Diagnostics slash ownership (debug, mem, inspect via module handlers).
- Map and waypoint open helper delegation into MapAndWaypoint module.
- TOC wiring updated for extracted modules.

Targeted verification for this checkpoint:
1. Slash diagnostics parity
- Run `/pd debug on`, `/pd debug show`, `/pd debug clear`, `/pd mem`, `/pd inspect`.

2. Stage 4 map fallback parity
- With prey active at stage 4 and default icon suppression enabled, click bar and verify map/quest open behavior remains intact.

3. Widget click fallback parity
- With stage 4 visible from widget click path, verify map open still resolves waypoint and supertrack.

4. No-regression sanity
- Confirm no Lua/UI errors on login and during one complete prey cycle.
- Confirm hunt scanner still opens/populates immediately on hunt table interaction.

### Done log
- [x] Added 2.0 cleaner implementation playbook and ethical guardrails.
- [x] Completed Phase 0 baseline behavior, risk focus, and smoke script.
- [x] Started modular retrofit with diagnostics slash command extraction to module-owned handlers.
- [x] Fixed hunt table first-open scanner timing so interaction opens populate without quest pre-click.
- [x] Extracted map/waypoint open and resolution path to MapAndWaypoint module and delegated from core.
- [x] Added hunt-table hydration guard so temporary empty pin snapshots no longer overwrite availability counts to zero.
- [x] Started PreyRuntime extraction by moving quest/zone state helper logic into a dedicated module and delegating from core.
- [x] Continued PreyRuntime extraction by moving stage mapping and quest-active checks into module-owned helpers delegated from core.
- [x] Continued PreyRuntime extraction by delegating new-quest state reset setup into a module-owned helper with core fallback preserved.
- [x] Continued PreyRuntime extraction by delegating quest lifecycle evaluation in UpdatePreyState to module-owned helper with core fallback preserved.
- [x] Continued PreyRuntime extraction by delegating widget progress state resolution to module-owned helper with core fallback preserved.
- [x] Added runtime CPU throttling: adaptive idle update interval and no-quest widget-scan bypass to reduce background usage.
- [x] Hardened CPU guards by throttling idle noisy events, requiring active tracked prey for ambush chat scans, and deduping repeated ambush alerts.
- [x] Added 2-minute ambush scan cooldown after trigger and increased idle probe/update throttles to further reduce no-quest CPU churn.
- [x] Hardened stale-context handling so inactive/stale quest IDs cannot keep widget scans and ambush chat checks running while effectively idle.
- [x] Switched runtime to event-only idle mode by disabling OnUpdate polling outside active hunt contexts.
- [x] Gated HuntScanner noisy widget/quest event processing to active hunt contexts so idle widget event spam no longer triggers scanner work.
- [x] Added dynamic HuntScanner noisy-event subscriptions (register only during hunt context, unregister when idle) to further reduce baseline CPU.
- [x] Removed CurrencyTracker OnUpdate polling loop so currency refresh is fully event-driven (loot/currency/quest/world triggers only).
- [x] Added out-of-zone hot-context gating for Prey runtime polling/widget scans so an active quest outside prey zone no longer keeps high-frequency updates running.
- [x] Stopped resetting PreyState debug dedupe on clear so identical clear-state lines no longer flood logs.
- [x] Relaxed ambush gate from late-stage-only to in-zone active-hunt context so stage 1 ambush alerts can fire.
- [x] Added ambush message fallback matching when prey name is unresolved (early hunt stages) to avoid silent misses.
- [x] Hardened default prey icon suppression check to use live active quest API in addition to tracked state.
- [x] Fixed ambush gating when tracked quest is nil by resolving live active prey quest context for scan eligibility, prey-name matching, and in-zone checks.
- [x] Enforced runtime invariant: active prey stage >= 1 forces inPreyZone=true to prevent nil zone state from blocking alerts.
- [x] Added live-quest bootstrap handling in event/poll gates so live quest + tracked=nil cannot be throttled away from state rehydration.
- [x] Fixed `IsQuestStillActive` nil-call crash by forward-declaring and binding the helper before early ambush scan handlers invoke it.
- [x] Added direct `CHAT_MSG_SYSTEM` ambush trigger path (event-driven) so "Ambush/Ambushed" system messages can alert without polling overhead.
- [x] Updated runtime active-quest check to treat `C_QuestLog.GetActivePreyQuest()` as authoritative for prey quest activity when `IsOnQuest` lags.
- [x] Started Strangler Slice A by adding V2 skeleton modules (`HuntDataStoreV2`, `QuestLifecycleV2`, `ZoneGateV2`, `AmbushDetectorV2`, `RuntimeCoordinatorV2`, `CustomizationStateV2`) and wiring them in TOC without runtime cutover.
- [x] Added audio scaffolding for migration safety: legacy-compatible `Modules/PreyAudio.lua` shim and V2 `PreyAudioV2` skeleton module.
- [x] Started Strangler Slice B (additive): legacy runtime now emits `PREY_QUEST_ACCEPTED` and `PREY_QUEST_CLEARED` transition intents to `RuntimeCoordinatorV2`, which updates `QuestLifecycleV2` state and `HuntDataStoreV2` active-hunt cache in parallel.
- [x] Added V2 Slice B observability in inspect output: lifecycle state, last transition event/state, and V2 active-hunt quest ID are now included for in-game verification.
- [x] Tightened Slice B routing so `RuntimeCoordinatorV2` ignores raw frame events and now also observes live active prey quests during tracked=nil bootstrap, keeping V2 inspect state meaningful while legacy remains authoritative.
- [x] Removed shared generic `OnEvent` ownership from `RuntimeCoordinatorV2`; Slice B now uses an internal-only handler entrypoint so frame event broadcasting cannot contaminate V2 transition state.
- [x] Added false-clear suppression for Slice B so legacy `tracked=nil` bootstrap states cannot overwrite a V2 accepted transition with a synthetic clear before real tracked ownership exists.
- [x] Fixed Slice B nil-ID comparison bug where `nil == nil` semantics allowed a no-quest reload to emit a synthetic V2 clear transition.
- [x] Moved V2 bootstrap acceptance observation earlier in the main event path so quest accept is captured immediately even when the first relevant signal is a chat/system flow and legacy tracked state is still nil.
- [x] Added inspect mode shorthand: `/pd inspect bs` now routes inspect output to BugSack.
- [x] Fixed Slice B clear fallback by allowing clear transitions to target `state.v2LastAcceptedQuestID` when legacy tracked quest remains nil after abandon.
- [x] Added deterministic V2 clear-on-drop bridge in the main event path: when live quest disappears and no tracked quest exists, `PREY_QUEST_CLEARED` is emitted immediately (not gated by widget/idle throttle timing).
- [x] Completed Slice B.1 payload enrichment: `PREY_QUEST_ACCEPTED` now pulls metadata from HuntScanner (`difficulty`, `zoneMapID`, `zoneName`, `sourceType`) with runtime fallbacks, and inspect output now includes V2 `sourceType`.
- [x] Removed `completed`/`abandoned` terminal state split from QuestLifecycleV2 and all pending-terminal machinery from Preydator.lua. Quest clear emits a single `ended` state. Rationale: audio has no quest-end sound (stages 1-4 + ambush only); achievement tracking uses Blizzard native events (`ACHIEVEMENT_EARNED`, `CRITERIA_UPDATE`) not quest interception.
- [x] Completed Slice C.3 first lifecycle cutover: disabled legacy `RunModuleHook("OnPreyQuestEnded")` emission in `Preydator.lua` and moved HuntScanner end-of-quest cleanup to V2 clear transition handling in `RuntimeCoordinatorV2`.
- [x] Started Slice D zone-gating ownership cutover: `ZoneGateV2` now owns prey-zone map hierarchy checks and instance gate decisions used by runtime ambush scanning and HuntScanner restricted-instance checks.

### Slice B/B.1 validation (passed)

Validated in game:
1. Reload with no quest: V2 remains `idle` with nil transition and nil active quest.
2. Weekly hunt accept from table: V2 emits `PREY_QUEST_ACCEPTED` and records `sourceType=weekly`.
3. Random hunt accept from Astalor: V2 emits `PREY_QUEST_ACCEPTED` and records `sourceType=random`.
4. Abandon active quest: V2 emits `PREY_QUEST_CLEARED` and active quest cache clears.
5. Complete active quest: V2 emits terminal clear and active quest cache clears.

### Slice C start (lifecycle ownership)

Objective:
Begin moving lifecycle semantics from legacy branch logic into QuestLifecycleV2 before disabling any legacy handlers.

Scope correction (2026-03-17):
The original C.1 plan to differentiate `completed` vs `abandoned` as separate terminal states was removed as unnecessary.

Reasoning:
- Audio (Slice F): stages are 1 (in zone), 2-3 (ramp), 4 (prey ready), ambush. There is no quest-start or quest-end sound. The `completed` distinction is not needed by audio.
- Achievement (Phase 3): WoW provides `ACHIEVEMENT_EARNED` and `CRITERIA_UPDATE` events natively. Blizzard's built-in tracking owns achievement credit. We do not intercept quest completion to drive achievement logic — we read from Blizzard's APIs. No `completed` flag needed.

Result:
- `QuestLifecycleV2` uses a single `ended` terminal state for all quest clears.
- `terminalReason` field and `GetTerminalReason()` removed entirely.
- `v2PendingTerminalQuestID` and `v2PendingTerminalReason` state table fields removed from `Preydator.lua`.
- `PREY_QUEST_CLEARED` payload no longer carries a `completed` boolean. Reason field uses `"ended"` (legacy clear path) or `"dropped"` (drop-clear bridge).
- Inspect output no longer shows `terminalReason`.

Substeps:
1. C.1 ~~Differentiate terminal reason in V2 (`completed` vs `abandoned`).~~ Removed — not needed.
2. C.2 Expose V2 lifecycle snapshot in inspect for parity checks. (satisfied — inspect shows state/lastEvent/nextState/lastQuestID/activeQuestID/sourceType)
3. C.3 Identify the first legacy lifecycle branch to disable only after C.2 passes.

Acceptance checks:
1. Weekly accept still reports `PREY_QUEST_ACCEPTED` with correct source type.
2. Quest end (any reason) reports V2 terminal state `ended`.
3. No change to player-facing legacy behavior yet.

Progress:
- [x] C.2 Inspect shows full V2 lifecycle snapshot without terminal reason overhead.
- [x] C.3 Disabled first legacy lifecycle branch (`OnPreyQuestEnded` emitter) and routed cleanup from V2 clear ownership.

Validation (2026-03-17, in game):
1. Completed hunt end-to-end and ran inspect report.
2. V2 reports `state=ended`, `lastEvent=PREY_QUEST_CLEARED`, and `activeQuestID=nil` after completion.
3. Behavior matches expected post-clear runtime state with no user-facing regression observed.

Inspect/BugSack note:
The stack lines rooted at `DebugInspect.lua` `pcall` are expected when using inspect-to-BugSack mode. The report is intentionally sent through the error handler for capture and is not a runtime crash.

### Blockers
- [x] Hunt scanner availability counters briefly dropping to 0 during hunt table hydration is now corrected by hydration guard behavior (validated in retest).

### Slice D start (zone gating ownership)

Objective:
Route zone/instance gating decisions through `ZoneGateV2` and remove duplicated legacy gate logic from runtime scan paths.

Implemented in this slice:
1. `ZoneGateV2:IsInPreyZone` now matches legacy behavior by traversing map parent hierarchy (not direct map equality only).
2. `PreyRuntime:IsPlayerInPreyZone` now delegates to `ZoneGateV2` first, with safe fallback retained.
3. Runtime ambush scan gate (`ShouldScanAmbushChat`) now calls `ZoneGateV2:CanScan` as primary decision path.
4. HuntScanner restricted-instance checks now query `ZoneGateV2:IsInInstance` first.

Acceptance checks:
1. Active hunt out of prey zone: ambush scanning remains disabled.
2. Active hunt inside prey zone: ambush scanning remains enabled when not in restricted instance.
3. Enter party/raid/scenario/delve while hunt active: scan gating remains blocked.
4. No user-facing regression in bar visibility or hunt scanner behavior.

Progress:
- [x] D.1 Zone/instance gating path routed through ZoneGateV2 in runtime and scanner flows.
- [x] D.2 In-game parity validation pass (zone transition + instance transition). ✅ validated 2026-03-17

Validation note (2026-03-17):
- Fixed out-of-zone quest pickup CPU spike path by preventing `CHAT_MSG_SYSTEM` quest-accepted text from matching ambush detection via prey-name string match. System-channel ambush detection now only uses explicit ambush keyword fallback + zone gate path.
- Reduced out-of-zone CPU churn by removing `recentWidgetSignal` as a hot-context trigger for widget scans, event probes, and active polling. Out-of-zone hunts now stay cold unless kill-carry, force-show, or bootstrap conditions apply.
- Fixed active-quest clear loop where `IsQuestFlaggedCompleted` could force `shouldClear=true` while prey quest was still live, causing repeated `origin=clear` lines, `tracked=nil` persistence, and sustained bootstrap polling churn.
- Added deterministic live-quest bootstrap alignment in main event flow: when live prey quest exists and legacy `tracked` is nil/mismatched, `ResetStateForNewQuest` now runs immediately so tracked state converges without prolonged bootstrap polling.
- Fixed critical pcall return-value misalignment in `UpdatePreyState`: `EvaluateQuestLifecycle` was returning a leading `true` success flag which, when wrapped in pcall, offset all capture variables by one position. Result: `moduleShouldClear` was receiving `questStillActive` (always true with an active quest), causing `ClearPreyStateAndDisplay()` every tick → `tracked=nil` every cycle. Removed the redundant success flag from the function's return signature.
- D.2 final CPU baselines: idle `.00-.03%`, quest accepted out-of-zone stationary `.00-.07%`, mounted/moving wrong zone `.11-.18%`, dungeon `.11%`. All nominal.
- Clarification: inspect-to-BugSack stack output is intentional diagnostic routing and should be treated as expected report capture, not as an addon runtime fault.

### Decisions log
- [x] Stage 4 deep retest is intentionally deferred until later 2.0 passes after more module work, due to per-character hunt table quest limits reducing test opportunities.
- [x] Customization will be a dedicated V2 module (`CustomizationStateV2`) introduced early as an adapter, with schema-preserving writes and cutover only after runtime parity.

---

### Slice E start (ambush detection ownership)

Objective:
Route ambush detection decisions through `AmbushDetectorV2` and disable the legacy `IsAmbushSystemMessage` / `ShouldScanAmbushChat` call paths.

Implemented in this slice:
1. `AmbushDetectorV2:ShouldListen(v2State, zoneMapID)` — gates on V2 lifecycle state (`in_zone` only); when `zoneMapID` is provided (NPC chat path) also delegates instance exclusion to `ZoneGateV2:CanScan`.
2. `AmbushDetectorV2:HandleSystemMessage(msg)` — keyword match only (`"ambush"`, case-insensitive); prey-name match intentionally excluded for `CHAT_MSG_SYSTEM` to avoid false positives on quest-accepted system text.
3. `AmbushDetectorV2:HandleNpcMessage(msg, speaker, preyName)` — prey-name match in message and speaker for `CHAT_MSG_MONSTER_*` / `RAID_BOSS_EMOTE`.
4. `Preydator.lua` `CHAT_MSG_SYSTEM` handler — legacy `IsAmbushSystemMessage` call replaced with `AmbushDetectorV2:ShouldListen(v2State)` + `HandleSystemMessage`.
5. `Preydator.lua` NPC handler — legacy `ShouldScanAmbushChat` + `IsAmbushSystemMessage` calls replaced with `AmbushDetectorV2:ShouldListen(v2State, zoneMapID)` + `HandleNpcMessage`.

Legacy functions (`IsAmbushSystemMessage`, `ShouldScanAmbushChat`) remain as unreachable dead code pending Slice H removal.

Acceptance checks:
1. Out-of-zone: ambush system messages and NPC chat produce no trigger (v2State = `out_of_zone`, `ShouldListen` returns false).
2. In-zone, `CHAT_MSG_SYSTEM` containing "Ambush": triggers alert.
3. In-zone, `CHAT_MSG_SYSTEM` containing prey name only (not "ambush"): no trigger.
4. In-zone, NPC say/yell containing prey name: triggers alert.
5. In-zone but in restricted instance: no trigger (ZoneGateV2:CanScan blocks NPC path).

Progress:
- [x] E.1 AmbushDetectorV2 fully implemented.
- [x] E.2 Preydator.lua event handlers routed through V2, legacy calls disabled.
- [x] E.3 In-game validation pass (ambush trigger in prey zone confirmed). ✅ validated 2026-03-17

Validation note (2026-03-17, post-maintenance live test):
- Out-of-zone inspect showed expected parity: `inPreyZone=false` and `v2 state=out_of_zone`.
- Entering prey zone showed expected parity: `inPreyZone=true` and `v2 state=in_zone` with `lastEvent=PREY_ZONE_ENTERED`.
- Ambush detection fired from NPC chat path in-zone (`CHAT_MSG_MONSTER_SAY`) with alert sound confirmed.
- Debug log now shows explicit V2 zone reconciliation transitions (`PREY_ZONE_ENTERED` / `PREY_ZONE_EXITED`) and ambush detection source entries, improving post-test diagnostics.

### Slice F start (audio ownership)

Objective:
Route stage and ambush audio behavior through `PreyAudioV2` and keep legacy audio ownership only as fallback during validation.

Implemented in this slice:
1. `PreyAudioV2` moved from legacy pass-through skeleton to active owner implementation for:
    - `ResolveStageSoundPath`
    - `TryPlaySound`
    - `TryPlayStageSound`
    - `TriggerAmbushAlert`
2. Ambush dedupe is now owned by `PreyAudioV2` with a 30-second window (prevents repeated alert bursts from multi-line ambush chatter).
3. `Preydator.lua` audio delegation points now prefer `PreyAudioV2` and fall back to `PreyAudio` only if V2 is unavailable:
    - `TryPlaySound`
    - `ResolveStageSoundPath`
    - `TryPlayStageSound`
    - `TriggerAmbushAlert`

Acceptance checks:
1. Stage 1-4 sounds still fire once per stage with existing sound toggles/channel/enhance behavior.
2. Ambush alert sound/visual behavior remains intact.
3. Multi-line ambush NPC chatter within 30 seconds triggers one alert burst, subsequent lines are deduped.
4. No regression when sound toggles are disabled (both stage and ambush paths).

Progress:
- [x] F.1 PreyAudioV2 implemented as active owner.
- [x] F.2 Runtime audio delegation switched to V2-first with legacy fallback.
- [ ] F.3 In-game parity validation pass (stage sounds + ambush dedupe + toggle behavior).

### Slice G start (customization ownership foundation)

Objective:
Lay down migration-safe CustomizationStateV2 scaffolding and inspect-visible migration telemetry before category-by-category settings rewiring.

Implemented in this slice:
1. `CustomizationStateV2` now performs lazy one-time bootstrap of `settings.customizationV2` with:
    - `schemaVersion`
    - `initialized`
    - `migrationComplete`
    - `migratedAt`
    - `migrationSource`
2. Added foundational V2 customization data scaffolds:
    - `moduleEnabled` defaults (`bar`, `sounds`, `currency`, `warband`, `achievement`, `hunt`)
    - `sharedTheme` seed (font, scale, palette from existing settings)
    - `difficultySymbols` (`auto`, `override`, `color`)
3. `CustomizationStateV2:Get` and `Set` now support dotted paths while preserving legacy flat-key access.
4. Added `CustomizationStateV2:GetMigrationState()` and `IsModuleEnabled(moduleKey)` for cutover telemetry and module gating groundwork.
5. `DebugInspect` now prints V2 customization migration status and module-enabled flags for quick paste-based validation.

Progress:
- [x] G.0 Foundation scaffold: migration metadata + module/theme/tokens scaffolds.
- [x] G.0 Inspect visibility: customization migration and module flags now visible in inspect output.
- [ ] G.1 Category read-path cutover (bar first).

## Notes from external addon comparison (ethical pattern review)

Keep: technique-level lessons, not code copying.

1. Narrow prey widget targeting from focused prey-state addons is cleaner than broad suppression scans.
2. Quest and currency event-driven tracking is better for weekly and lifecycle systems than widget hooks.
3. Data-driven module rows and adapter-style APIs make large feature growth safer.
4. Achievement prioritization should be a bridge layer, not hardcoded inside one UI renderer.

## Phase 1 Test results
1. pd debug on - Passed
2. pd debug show - Passed 20 of 200 shown
    Note: We are actively scanning for an Ambush without a Prey Quest OR in the Zone of a Prey this could cause issues and instability
3. pd debug clear - Passed 
    Note: We reran the debug show and it then showed 20 of 26 events so clear passed
4. pd mem - Passed 
    Note: before=1126273.4 afterGC=1095763.6 reclaimed=30509.8
5. pd inspect - Passed
    Note: Used the bugsack to send it there to paste here.
    Preydator Inspect Report [1/1]
    Preydator Inspect (module)
    - time=67576.538 | zone=Silvermoon City | playerMapID=2393 | playerMap=Silvermoon City
    - quest live=nil | hasActive=false | tracked=nil
    - state stage=1 | progressState=nil | progressPercent=0
    - inPreyZone=nil | disableDefaultPreyIcon=true
    - settings size width=160 | height=30 | scale=0.9
    - settings layout | orientation=horizontal | fillDir=up | labelMode=center | labelRow=above | vTextAlign=middle | vTextSide=right | vTextOffset=10 | vPctDisplay=inside | vPctSide=center | vPctOffset=2
    - bar shown=false | mouse=true | width=144.00022888184 | height=26.99998664856 | scale=1 | effectiveScale=0.64999997615814
    - prefix | shown=true | text='Preydator' | point=BOTTOM -> PreydatorProgressBar:TOP (0,4)
    - suffix | shown=false | text='' | point=BOTTOMRIGHT -> PreydatorProgressBar:TOPRIGHT (-2,4)
    - percent | shown=false | text='0%' | point=CENTER -> PreydatorProgressBar:CENTER (0,0)
    - centerDot | enabledSetting=false | shown=false | point=CENTER -> PreydatorProgressBar:CENTER (0,0)
    [C]: in function 'pcall'
    [Preydator/Modules/DebugInspect.lua]:36: in function <Preydator/Modules/DebugInspect.lua:14>
    [Preydator/Modules/DebugInspect.lua]:180: in function <Preydator/Modules/DebugInspect.lua:152>
    [C]: in function 'pcall'
    [Preydator/Preydator.lua]:5278: in function '?'
    [Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua]:259: in function 'ParseText'
    [Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua]:284: in function 'SendText'
    [Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua]:407: in function <...s/Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua:403>
6. Stage 4 map worked from the bar
    Note: Still says Map Pin instead of just poiinting to the quest like the icon does, is it possible to just make the quest active instead of require a Waypoint pin?
7. Map and waypoint fallback - Passed
8. Lua Errors while Testing:
    LUA 1: 3x Cannot perform measurement in QuestFrameModelScene. nil, 2100.5129394531
        [Blizzard_UIPanels_Game/Mainline/QuestFrame.lua]:471: in function <...ddOns/Blizzard_UIPanels_Game/Mainline/QuestFrame.lua:466>
        [C]: in function 'SetParent'
        [Blizzard_UIPanels_Game/Mainline/QuestFrame.lua]:480: in function 'QuestFrame_ShowQuestPortrait'
        [Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua]:1010: in function <...ns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua:993>
        [C]: in function 'QuestMapFrame_ShowQuestDetails'
        [Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua]:1119: in function <...ns/Blizzard_UIPanels_Game/Mainline/QuestMapFrame.lua:1116>
        [C]: ?
        [Preydator/Modules/MapAndWaypoint.lua]:115: in function <Preydator/Modules/MapAndWaypoint.lua:99>
        [C]: in function 'pcall'
        [Preydator/Preydator.lua]:2962: in function <Preydator/Preydator.lua:2958>
        [Preydator/Preydator.lua]:1914: in function <Preydator/Preydator.lua:1895>
    
    LUA 2: 1x [ADDON_ACTION_BLOCKED] AddOn 'Preydator' tried to call the protected function 'Button:SetPassThroughButtons()'.
        [!BugGrabber/BugGrabber.lua]:532: in function '?'
        [!BugGrabber/BugGrabber.lua]:516: in function <!BugGrabber/BugGrabber.lua:516>
        [C]: in function 'SetPassThroughButtons'
        [Blizzard_MapCanvas/MapCanvas_DataProviderBase.lua]:288: in function 'CheckMouseButtonPassthrough'
        [Blizzard_MapCanvas/Blizzard_MapCanvas.lua]:302: in function 'AcquirePin'
        [Blizzard_SharedMapDataProviders/QuestDataProvider.lua]:194: in function 'AddQuest'
        [Blizzard_SharedMapDataProviders/QuestDataProvider.lua]:134: in function 'CheckAddQuest'
        [Blizzard_SharedMapDataProviders/QuestDataProvider.lua]:141: in function 'RefreshAllData'
        [Blizzard_SharedMapDataProviders/QuestDataProvider.lua]:39: in function <...lizzard_SharedMapDataProviders/QuestDataProvider.lua:39>
        [C]: ?
        [Blizzard_SharedXMLBase/CallbackRegistry.lua]:210: in function <...eBlizzard_SharedXMLBase/CallbackRegistry.lua:209>
        [C]: ?
        [Blizzard_SharedXMLBase/CallbackRegistry.lua]:213: in function 'TriggerEvent'
        [Blizzard_FrameXMLUtil/Mainline/Blizzard_QuestSuperTracking.lua]:59: in function 'CacheCurrentSuperTrackInfo'
        [Blizzard_FrameXMLUtil/Mainline/Blizzard_QuestSuperTracking.lua]:17: in function <...rameXMLUtil/Mainline/Blizzard_QuestSuperTracking.lua:15>


        Locals:
        self = <table> {
        }
        event = "ADDON_ACTION_BLOCKED"
        addonName = "Preydator"
        addonFunc = "Button:SetPassThroughButtons()"
        name = "Preydator"
        badAddons = <table> {
        Preydator = true
        BtWQuests = true
        }
        L = <table> {
        NO_DISPLAY_2 = "|cffffff00The standard display is called BugSack, and can probably be found on the same site where you found !BugGrabber.|r"
        ERROR_DETECTED = "%s |cffffff00captured, click the link for more information.|r"
        BUGGRABBER_STOPPED = "|cffffff00There are too many errors in your UI. As a result, your game experience may be degraded. Disable or update the failing addons if you don't want to see this message again.|r"
        USAGE = "|cffffff00Usage: /buggrabber <1-%d>.|r"
        STOP_NAG = "|cffffff00!BugGrabber will not nag about missing a display addon again until next patch.|r"
        NO_DISPLAY_STOP = "|cffffff00If you don't want to be reminded about this again, run /stopnag.|r"
        NO_DISPLAY_1 = "|cffffff00You seem to be running !BugGrabber with no display addon to go along with it. Although a slash command is provided for accessing error reports, a display can help you manage these errors in a more convenient way.|r"
        ERROR_UNABLE = "|cffffff00!BugGrabber is unable to retrieve errors from other players by itself. Please install BugSack or a similar display addon that might give you this functionality.|r"
        ADDON_CALL_PROTECTED = "[%s] AddOn '%s' tried to call the protected function '%s'."
        }

9. pd debug off - Passed
    Note: Had to turn it off when out testing in the world
10. the N/HNi quest count automattically dropped by 1 when accepting the quest, when completing the quest it went back up to 4, then when interacting with the table it went to zero then about 8 seconds later the quests updated and I went back to 3. We need a cleaner solve for the tracking of this per week especially as the Quest reset each week after the server rest, different in each region so cannot hard code this behavior should be something in game.

## Phase 1 Retest results (post-fix)
1. Retest 1 (LUA 1 path) - Passed
    Note: No Lua errors.
2. Retest 2 (LUA 2 / map behavior path) - Passed
    Note: No Lua errors and behavior matched expected quest tracking behavior.
3. Retest 3 (hunt table load timing) - Passed with minor delay
    Note: HT pane now loads in about 2-4 seconds without requiring a quest pre-click.
4. Retest 4 (availability stability during table hydration) - Passed
    Note: N/H/Ni counts remained stable without temporary reset-to-zero flash.
5. Retest 5 (PreyRuntime helper extraction) - Passed
    Note: No Lua on login, zone detection correct, quest progression correct, hunt table updates correct.
    Observation: first hunt table open after login may take about 6 seconds, then near-instant afterward.
6. Retest 6 (PreyRuntime reset/lifecycle extraction) - Passed
    Note: No Lua errors, quest pane loaded in about 3 seconds, quest and zone behavior unchanged, hunt table behavior unchanged.

Open follow-up from retest:
- Continue observing weekly reset behavior by region/server restart cadence to ensure availability cache remains accurate over time.

## Phase 1 Retest results (event-driven currency refresh)
1. Idle CPU baseline with no hunt/currency windows open - Passed
    Note: Baseline now sits around 0.01-0.03.
2. Loot currency immediate update behavior - Passed
    Note: Brief peak near 0.18 for a couple seconds, then returns to about 0.02-0.03.
3. Quest turn-in reward refresh behavior - Passed
    Note: Brief spike near 0.05 for a fraction of a second, then normal baseline resumes.
4. Hunt table open/close + post-close idle baseline - Pending confirmation
    Note: Waiting for one more measurement pass to confirm no lingering post-close churn.

## V2 Runtime Skeleton (multi-session anchor)

Status: Drafted and approved for incremental implementation.

Purpose:
Define a strict, lean V2 runtime shape that can be implemented over multiple sessions without re-opening architecture debates.

### Design constraints (locked)

1. HuntScanner is authoritative for hunt metadata.
2. Active prey tracking is atomic and sticky until complete or abandon.
3. No scanning outside prey zone.
4. No scanning in any instance type.
5. Legacy and V2 cannot own the same runtime responsibility at the same time.

### V2 module skeletons

Planned files:
1. Modules/V2/HuntDataStoreV2.lua
2. Modules/V2/QuestLifecycleV2.lua
3. Modules/V2/ZoneGateV2.lua
4. Modules/V2/AmbushDetectorV2.lua
5. Modules/V2/RuntimeCoordinatorV2.lua
6. Modules/V2/PreyAudioV2.lua
7. Modules/V2/CustomizationStateV2.lua

Module contracts:

1. HuntDataStoreV2
- Responsibility: canonical prey metadata cache and retrieval.
- Inputs: HuntScanner snapshots, accepted questID, weekly/random source context.
- Outputs: normalized active-hunt payload and lookup APIs.
- API skeleton:

```lua
-- Set/clear active hunt in one atomic write.
function HuntDataStoreV2:SetActiveHunt(payload) end
function HuntDataStoreV2:ClearActiveHunt(reason) end

-- Query APIs used by all other V2 modules.
function HuntDataStoreV2:GetActiveHunt() end
function HuntDataStoreV2:GetQuestMeta(questID) end
function HuntDataStoreV2:HasQuestMeta(questID) end
```

2. QuestLifecycleV2
- Responsibility: state transitions only.
- Inputs: live quest APIs, completion/abandon signals, stage data.
- Outputs: deterministic transition intents.
- API skeleton:

```lua
-- Returns transition object, no rendering side effects.
function QuestLifecycleV2:Evaluate(eventName, context) end

-- Transition states: idle, accepted, out_of_zone, in_zone, stage4, completed_or_abandoned.
function QuestLifecycleV2:GetState() end
```

3. ZoneGateV2
- Responsibility: hard gating for all scan paths.
- Inputs: player map context, prey zone mapID, instance context.
- Outputs: gate decision and reason code.
- API skeleton:

```lua
function ZoneGateV2:IsInInstance() end
function ZoneGateV2:IsInPreyZone(preyMapID) end
function ZoneGateV2:CanScan(activeHunt) end -- returns boolean, reason
```

4. AmbushDetectorV2
- Responsibility: event-only ambush detection.
- Inputs: system chat and NPC speech events.
- Outputs: ambush trigger events for runtime.
- API skeleton:

```lua
function AmbushDetectorV2:ShouldListen(activeState) end
function AmbushDetectorV2:HandleSystemMessage(msg) end
function AmbushDetectorV2:HandleNpcMessage(msg, speaker) end
```

5. RuntimeCoordinatorV2
- Responsibility: single event owner and orchestrator.
- Inputs: game events and module outputs.
- Outputs: state updates, UI update requests, and module hooks.
- API skeleton:

```lua
function RuntimeCoordinatorV2:OnEvent(eventName, ...) end
function RuntimeCoordinatorV2:ApplyTransition(transition) end
function RuntimeCoordinatorV2:SyncUiFromState() end
```

6. CustomizationStateV2
- Responsibility: central settings adapter and validation/coercion boundary.
- Inputs: existing SavedVariables keys and user option updates.
- Outputs: normalized effective settings and change notifications.
- Guardrail: preserve current SavedVariables schema through runtime cutover.
- API skeleton:

```lua
function CustomizationStateV2:Get(path, fallback) end
function CustomizationStateV2:Set(path, value) end
function CustomizationStateV2:GetEffectiveSettings() end
function CustomizationStateV2:SubscribeSettingsChanged(callback) end
```

### Slice G customization requirements (confirmed 2026-03-17)

Primary goal:
Move customization ownership into `CustomizationStateV2` without causing a painful upgrade, without losing current flexibility, and with inspect-visible validation during the transition.

Migration rules:
1. Upgrade must be painless for existing users.
2. Existing SavedVariables remain present for compatibility during the transition.
3. A one-time migration copies legacy settings into the new customization pipeline.
4. During phased rollout, inspect output is the primary mismatch-reporting surface.
5. After parity is proven, verbose migration diagnostics can move back behind debug-only paths.

Cutover strategy:
1. Move category by category, not as a single big-bang rewrite.
2. Each category keeps current user-visible behavior until its V2 owner is validated.
3. Each category should expose inspect-visible parity state while dual-read or dual-write is active.
4. Slash command cleanup/update is allowed during this phase, but only if command behavior remains understandable and migration-safe.

Initial category ownership order:
1. The bar
2. The sounds
3. Currency tracker
4. Warband tracker
5. Achievement tracker
6. Hunt tracker

UI/UX direction:
1. Preserve the current level of customization; do not reduce capability just to simplify implementation.
2. Simplify settings presentation where possible by grouping shared controls instead of duplicating nearly identical panels.
3. Horizontal and vertical bar configuration should support shared control groups where one set of sliders can intentionally drive both when the user chooses linked behavior.
4. Custom themes should support font, colors, scale, and related display settings without forcing a single static look.

Module enable/disable rules:
1. Each major module can be enabled or disabled independently.
2. If a module is disabled, its runtime behavior must be off.
3. Enabling a disabled module requires reload.
4. If a module is disabled, its module-specific settings controls should not be editable.
5. Disabling a module does not delete its saved settings; they must persist for later re-enable.

Shared theme inheritance rules:
1. Shared visual settings such as font, scale, and colors should carry across tracker modules when those modules are enabled later.
2. A user who configures hunt tracker visuals first should see those shared visual settings available to currency, warband, and achievement tracker modules when enabled.
3. Module-specific overrides may exist, but the default mental model should be shared theme first, per-module override second.

Difficulty identifier requirements:
1. Hunt tracker and warband tracker both need customization for difficulty identifiers.
2. Default identifiers should be localization-friendly and derived from the first letter of each difficulty label.
3. If multiple difficulties would collide on the same first letter/symbol, the next conflicting identifier expands to the next distinguishing character.
4. Users may override the auto-derived identifier text manually.
5. Difficulty identifier text and color customization should apply consistently anywhere the difficulty token is rendered.

Verification expectations during Slice G:
1. `inspect` should expose active customization owner, migration state, and any legacy/V2 mismatch for the category under test.
2. Settings parity checks should be easy to run and easy to paste during iterative testing.
3. When a category is still mid-cutover, inspect output is preferred over hidden debug-only reporting.

Reference artifact:
1. `issues/customization_fields_matrix.md` is the active field inventory and module-usage matrix for Slice G planning and migration tracking.

7. PreyAudioV2
- Responsibility: audio behavior boundary for stage/ambush sounds during V2 cutover.
- Inputs: sound settings, stage transitions, ambush triggers.
- Outputs: play decisions and alert audio actions.
- Guardrail: keep audible behavior parity while runtime ownership transitions.
- API skeleton:

```lua
function PreyAudioV2:ResolveStageSoundPath(stage) end
function PreyAudioV2:TryPlaySound(path, ignoreSoundToggle) end
function PreyAudioV2:TryPlayStageSound(stage, ignoreSoundToggle) end
function PreyAudioV2:TriggerAmbushAlert(message, source) end
```

### Shared active-hunt payload contract

All V2 modules use the same shape:

```lua
{
    questID = number,
    targetName = string,
    difficulty = string,
    zoneMapID = number,
    zoneName = string,
    sourceType = "weekly" or "random",
    acceptedAt = number,
    stage = number,
}
```

### Runtime invariants (must always hold)

1. If live prey quest exists, active quest tracking cannot be nil.
2. inPreyZone is always boolean, never nil.
3. Clear state only on completed or abandoned.
4. Stage 4 disables ambush scanning.
5. Out-of-zone and in-instance states disable all scanning.

### Event ownership map (V2)

1. RuntimeCoordinatorV2 owns frame event registration.
2. AmbushDetectorV2 handles only chat payload parsing.
3. HuntDataStoreV2 never registers frame events.
4. QuestLifecycleV2 never performs UI updates.
5. ZoneGateV2 is pure decision logic.

### Strangler cutover plan (hard-disable legacy per slice)

1. Slice A: Introduce V2 modules with no runtime wiring.
2. Slice B: Route quest accept/clear transitions through RuntimeCoordinatorV2.
3. Slice C: Disable equivalent legacy quest lifecycle handlers.
4. Slice D: Route zone gating through ZoneGateV2 and disable legacy gating.
5. Slice E: Route ambush detection through AmbushDetectorV2 and disable legacy ambush scan logic.
6. Slice F: Route audio behavior through PreyAudioV2 and disable equivalent legacy audio ownership.
7. Slice G: Route settings reads/writes through CustomizationStateV2 and disable equivalent legacy settings ownership.
8. Slice H: Remove unreachable legacy code after parity validation.

Rule:
At any point in time, exactly one path owns each concern.

### Data sources and reference artifacts

Use these files as canonical planning inputs during V2 implementation:
1. issues/quest_list.md (quest IDs and prey catalog)
2. issues/questrewards.md (reward mapping and verification)
3. issues/currencies.md (currency inventory and tracker expansion planning)

### Multi-session continuation notes

When resuming work in a future session:
1. Start from this V2 Runtime Skeleton section before proposing changes.
2. Choose one cutover slice and define acceptance checks before coding.
3. Record done and deviations in the Done log and Decisions log immediately.
4. Do not expand scope to UI/theme/warband enhancements until runtime slice parity is validated.

## Community Requests Intake (post-runtime parity)

Status: Approved for backlog and sequencing.

Purpose:
Track user-facing feature requests that benefit from V2 modular boundaries and customization ownership.

### Request A - Add minimap button support for addon containers

Source: doch07

Scope:
1. Add an option to place the minimap button in supported addon container systems.
2. Keep existing standalone minimap behavior as fallback.

V2 ownership:
1. CustomizationStateV2: user setting for container integration mode.
2. Minimap integration module existing/new helper: runtime registration with container provider.

Acceptance criteria:
1. User can toggle container integration on or off.
2. If container API is present, button appears in container.
3. If container API is absent, addon gracefully keeps standalone minimap button behavior.
4. No Lua errors from missing third-party container addons.

### Request B - Allow disabling warband tracking and currency tab modules

Source: Zakarie

Scope:
1. Add module-level toggles for Warband tracking and Preydator currency tab.
2. Keep prey progression bar functionality independent from those modules.

V2 ownership:
1. CustomizationStateV2: module enable/disable flags.
2. RuntimeCoordinatorV2: honors module flags and prevents disabled module startup/event registration.

Acceptance criteria:
1. User can disable Warband tracker only.
2. User can disable Currency tab only.
3. User can disable both while prey bar still works.
4. Disabled modules perform no background updates or event scans.

### Request C - Font customization for hunt tracker table

Source: omgx

Scope:
1. Add font family, size, and style controls for hunt tracker table rows/headers.
2. Keep default appearance parity for users who do not customize.

V2 ownership:
1. CustomizationStateV2: font settings and validation.
2. HuntScanner table UI renderer: applies effective font tokens from settings.

Acceptance criteria:
1. User can set table font family and size from options.
2. Settings persist between sessions.
3. If a selected font is unavailable, fallback font is applied without error.

### Sequencing note

These requests should start after runtime cutover slices B-E are stable.

Recommended order:
1. Request B (module toggles) first for immediate performance and UX control.
2. Request A (container integration) second.
3. Request C (hunt table font customization) third, coordinated with broader theming work.

## Random thoughts to Add
1. Ability to hide characters under level 78 from the Prey Warband tracker so it stays clean with only those characters that can use the system and not all the leveling characters. Might add a system to include exclude characters in a different tab or area, may need to rethink how we are segregating the settings via tabs. DEFAULT OFF, Not tracking under level 78.
2. Add an area where all the cureencies can be added to the warband tracker for the expansion, segregated from seasonal and permanet curencies for the season currencies.md for a full list, dureation column.
3. Update the /pd inspect Bugsack to pd inspect bs dfor ease of typing
4. Allow players to customize their themes so setting up a tab that has all the colors pbroken up by Primary secondary, rows for the bars and the fonts. Customize font selection. Maybe add a Font folder so people can add their own fonts like how we do sounds, same with Textures for the fill or even the Theme Rows if they want to add textures there.
5. Since we can now get the zone from the quests thanks to Hunt Tracker let's add an option that the out of zone message is instead travel to zone X
6. Ability to hide the Bar but keep the sounds.
7. There should be a native to WoW code that tells us that the prey system was been reset or part of the weekly reset so that we can always have the number of Prey available correct each week without needing to toon hop.