# Prey Zone State Fix Plan

## Goal

Keep the prey bar driven by the live Blizzard quest-log answer for `isOnMap` while a hunting quest is active, and stop stale state from overriding the live value.

## Current working conclusion

The bug is not that the quest-log API is missing. The bug is that `state.inPreyZone` is being overwritten or cleared after the live answer is read, so the UI final gate is acting on stale state instead of the current quest-log result.

This is the pattern we have repeatedly observed:

- live prey quest is active
- `GetInfo(...).isOnMap = true`
- runtime still reports `state.inPreyZone = false`
- `activeQuestTransitionWindow` remains stuck true
- bar remains hidden despite the live quest-log saying the player is in-zone

## Root cause being tracked

The most likely root cause is a stale write after the live answer is read. The bar finally decides visibility from `state.inPreyZone`, so any later write to that variable can hide the bar even when Blizzard is telling us the quest is on map.

The relevant runtime paths are:

- `Preydator.lua`
- `Core/PreyContextRuntime.lua`
- `Core/BarRuntime.lua`
- `Core/EventRuntime.lua`
- `Modules/DebugInspect.lua`

## Decision rule

The live quest-log answer is the only authority for this feature while an active prey quest is present.

- `isOnMap == true` => in-zone state is true
- `isOnMap == false` => out-of-zone state is false
- no stale `false` or `nil` override may survive after a fresh live read
- map/zone fallback logic must not override the live quest-log answer

## Non-goals

- No new mapID / zoneID fallback logic
- No quest-to-zone cache
- No broader redesign of the prey runtime
- No extra polling beyond the live `isOnMap` check while the quest is active

## Work plan for the next session

1. Reproduce in-game with a single active prey quest in the correct zone.
2. Capture the exact order of events for one pass:
   - live prey quest ID
   - `GetInfo(...).isOnMap`
   - `state.inPreyZone`
   - `PollingGate` output
   - final bar `shouldShowBar` / visibility reason
3. Identify the exact write that flips `state.inPreyZone` back to `false` or `nil` after a live true answer.
4. Patch only that stale write path.
5. Keep the fix minimal and local to the state ownership path.
6. Re-run validation and confirm the bar behaves correctly while flying around and entering the zone.

## Success criteria

- When `GetInfo(...).isOnMap == true`, the prey bar stays visible while the active quest remains in-zone.
- When `GetInfo(...).isOnMap == false`, the prey bar hides and does not remain stuck in a stale state.
- The `activeQuestTransitionWindow` must not stay stuck while the live answer is already true.
- The bar should not require a world quest trigger or instance event to recover once the live quest-log answer is available.

## Current status

The logic is narrowed to the real issue: stale state writes are overriding the live quest-log answer.
The remaining work is to isolate the exact overwrite and remove it without changing the rest of the prey flow.
