# Feature Request: Achievement-Aware Hunt Prioritization

Status: Post-2.0 feature request
Last updated: 2026-03-18

## Summary

Surface missing Prey achievement progress alongside hunt opportunities in the hunt scanner and table UI so players can quickly identify high-value hunts for progression.

This feature is explicitly out of scope for the 2.0 launch. The Achievement module row in Settings remains visible but disabled until this work begins.

## Motivation

Players hunting for achievement completion cannot currently tell at a glance which outstanding hunts are relevant to missing achievements. Without this, players must cross-reference external lists manually.

## Design Principles

1. Blizzard owns achievement credit. Do not intercept quest events to track completion. Use native APIs only.
2. Bridge layer, not renderer. Achievement logic must live in a dedicated bridge module, not inside the hunt table renderer or scanner.
3. Graceful fallback. Hunt rows that have no mapped achievement data should render normally without any error state.
4. API-first. Every implementation step must name the Blizzard API or event used before writing custom logic.

## Blizzard APIs to Use

- `GetAchievementInfo(achievementID)` — read achievement name, description, completion state.
- `GetAchievementCriteriaInfo(achievementID, criteriaIndex)` — read per-criteria progress.
- `ACHIEVEMENT_EARNED` — fire when a player earns an achievement.
- `CRITERIA_UPDATE` — fire when criteria progress changes.

Do not use quest completion events for achievement tracking. Blizzard's built-in tracking is the source of truth.

## Planned Modules

### AchievementBridge (new module)

Responsibilities:
- Maintain a watchlist of Prey-relevant achievement IDs sourced from Expansion Features > Prey category.
- Read missing criteria state from Blizzard APIs at scan time and on `CRITERIA_UPDATE`.
- Expose a quest-to-achievement mapping table with metadata fields.
- Provide query API for runtime and UI:
  - `AchievementBridge:IsHuntAchievementRelevant(questID)` — returns true if this hunt maps to a missing achievement criterion.
  - `AchievementBridge:GetPriorityReason(questID)` — returns a localized reason string for display in tooltip.

Exit criteria for this module:
- Hunt systems can query achievement relevance without any UI coupling.
- No custom quest-completion tracking — Blizzard API is the source of truth.
- Module can be enabled/disabled independently from other modules.

## Feature Slices (when work begins)

### Slice A: AchievementBridge foundation

- [ ] Define achievement watchlist source (Expansion Features > Prey).
- [ ] Read missing criteria state from Blizzard API at scan time and on `CRITERIA_UPDATE`.
- [ ] Add quest-to-achievement mapping table and metadata fields.
- [ ] Expose `IsHuntAchievementRelevant` and `GetPriorityReason` API.

Exit criteria:
- [ ] Hunt systems can query achievement relevance without UI coupling.
- [ ] No custom quest-completion tracking.

### Slice B: Priority flagging in scanner/table UI

- [ ] Add high-priority marker for hunts tied to missing achievements.
- [ ] Add sort mode that favors achievement-relevant hunts.
- [ ] Add tooltip reason text for why a hunt is prioritized.
- [ ] Keep fallback behavior when mapping data is incomplete.

Exit criteria:
- [ ] Players can quickly identify high-value hunts for progression.

### Slice C: Settings integration

- [ ] Enable Achievement module toggle on Modules settings page.
- [ ] Add Achievement page in settings (mirrors module enable state, row density/compact mode).
- [ ] Ensure toggle behavior is deterministic and reload prompts on real state change only.

## Known Constraints

- Achievements UI module row in Settings is currently hard-disabled and greyed. It must stay disabled until Slice A is validated in-game.
- The `modules.achievement.enabled` SavedVariable key already exists in the CustomizationStateV2 schema as a planned field. Do not repurpose it before the bridge module is ready.
- Achievement mapping completeness is a known risk. Always provide clear unknown states and graceful fallbacks so players are never shown incorrect data.

## Risk Notes

- Achievement mapping data may be incomplete. Mitigation: data-driven map with graceful fallback and clear unknown states.
- Criteria change events can fire at high frequency. Mitigation: debounce `CRITERIA_UPDATE` handling and only re-evaluate hunts with mapped criteria.
- Do not couple achievement display to the bar or minimap. Those surfaces track active hunt stage only.
