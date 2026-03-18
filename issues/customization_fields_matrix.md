# Preydator Customization Fields Matrix

Purpose
- Define shared customization fields once.
- Show which modules read and write each field.
- Track migration from legacy settings ownership to CustomizationStateV2.

Status legend
- L = legacy owner today
- V2 = planned owner
- RW = read and write
- R = read only

## Module map

| Module | Runtime today | Customization owner target | Notes |
|---|---|---|---|
| Bar runtime (Preydator.lua) | Yes | CustomizationStateV2 | Main progress bar visuals and labels. |
| Settings UI (Modules/Settings.lua) | Yes | CustomizationStateV2 | Primary writer for most bar and sound fields. |
| PreyAudio (Modules/PreyAudio.lua) | Yes | PreyAudioV2 + CustomizationStateV2 | Reads sound toggles, paths, channel, enhance. |
| CurrencyTracker (Modules/CurrencyTracker.lua) | Yes | CustomizationStateV2 | Currency and warband window fields + theme. |
| HuntScanner (Modules/HuntScanner.lua) | Yes | CustomizationStateV2 | Scanner panel sizing/theme/grouping. |
| Achievement tracker (planned) | Partial/planned | CustomizationStateV2 | Use shared theme defaults + local overrides. |
| Warband tracker (in CurrencyTracker) | Yes | CustomizationStateV2 | Shares theme with currency by default. |

## Shared theme fields (common across modules)

| Field key | Type | Bar | Currency | Warband | Hunt | Achievement | Owner now | Owner target | Notes |
|---|---|---|---|---|---|---|---|---|---|
| scale | number | RW | - | - | - | - | L | V2 | Bar scale baseline. |
| titleFontKey | string | RW | R (planned) | R (planned) | R (planned) | R (planned) | L | V2 | Candidate shared font family key. |
| percentFontKey | string | RW | R (planned) | R (planned) | R (planned) | R (planned) | L | V2 | Candidate shared numeric font key. |
| fillColor | color | RW | - | - | - | - | L | V2 | Bar fill color. |
| bgColor | color | RW | - | - | - | - | L | V2 | Bar background color. |
| borderColor | color | RW | R (planned) | R (planned) | R (planned) | R (planned) | L | V2 | Candidate shared border/accent color. |
| titleColor | color | RW | R (planned) | R (planned) | R (planned) | R (planned) | L | V2 | Candidate shared text accent. |
| percentColor | color | RW | R (planned) | R (planned) | R (planned) | R (planned) | L | V2 | Candidate shared percent/value color. |

## Bar and label fields

| Field key | Type | Modules using field | Owner now | Owner target | Notes |
|---|---|---|---|---|---|
| width | number | Preydator.lua, Settings.lua, DebugInspect.lua | L | V2 | Horizontal bar width. |
| height | number | Preydator.lua, Settings.lua, DebugInspect.lua | L | V2 | Horizontal bar height. |
| orientation | enum | Preydator.lua, Settings.lua, DebugInspect.lua | L | V2 | horizontal or vertical. |
| verticalFillDirection | enum | Preydator.lua, Settings.lua, DebugInspect.lua | L | V2 | up or down style behavior. |
| stageLabelMode | enum | Preydator.lua, Settings.lua, DebugInspect.lua | L | V2 | center/split label policy. |
| labelRowPosition | enum | Preydator.lua, Settings.lua, DebugInspect.lua | L | V2 | above or below. |
| stageLabels[1..4] | string array | Preydator.lua, Settings.lua | L | V2 | Stage text labels. |
| stageSuffixLabels[1..4] | string array | Preydator.lua, Settings.lua | L | V2 | Stage suffix text. |
| outOfZoneLabel | string | Preydator.lua, Settings.lua | L | V2 | Out-of-zone prefix label. |
| ambushLabel | string | Preydator.lua, Settings.lua | L | V2 | Ambush label text. |
| percentDisplay | enum | Preydator.lua, Settings.lua | L | V2 | Percent placement. |
| verticalPercentDisplay | enum | Preydator.lua, Settings.lua, DebugInspect.lua | L | V2 | Vertical percent mode. |

## Sound fields

| Field key | Type | Modules using field | Owner now | Owner target | Notes |
|---|---|---|---|---|---|
| soundsEnabled | bool | PreyAudio.lua, Settings.lua | L | V2 | Master stage sound toggle. |
| soundChannel | enum | PreyAudio.lua, Settings.lua | L | V2 | SFX/Master/etc. |
| soundEnhance | number | PreyAudio.lua, Settings.lua | L | V2 | Extra replay count. |
| stageSounds[1..4] | string array | PreyAudio.lua, Settings.lua | L | V2 | Per-stage path mapping. |
| soundFileNames[] | string array | Preydator.lua, Settings.lua | L | V2 | Selectable local files list. |
| ambushSoundEnabled | bool | PreyAudio.lua, Settings.lua | L | V2 | Ambush sound toggle. |
| ambushVisualEnabled | bool | PreyAudio.lua, Settings.lua | L | V2 | Ambush visual toggle. |
| ambushSoundPath | string | PreyAudio.lua, Settings.lua | L | V2 | Explicit ambush sound path. |

## Currency and warband fields

| Field key | Type | Modules using field | Owner now | Owner target | Notes |
|---|---|---|---|---|---|
| currencyWindowEnabled | bool | CurrencyTracker.lua, Settings.lua | L | V2 | Currency tracker visibility toggle. |
| currencyWindowPoint | point table | CurrencyTracker.lua | L | V2 | Currency window anchor and position. |
| currencyWindowWidth/Height | number | CurrencyTracker.lua | L | V2 | Currency window size. |
| currencyWindowFontSize | number | CurrencyTracker.lua | L | V2 | Currency row font size. |
| currencyWindowScale | number | CurrencyTracker.lua | L | V2 | Currency window scale. |
| currencyTheme | string | CurrencyTracker.lua, HuntScanner.lua, Settings.lua | L | V2 | Shared base theme. |
| currencyTrackedIDs | table | CurrencyTracker.lua | L | V2 | Currency inclusion list. |
| randomHuntCosts | table | CurrencyTracker.lua | L | V2 | Cost model by difficulty. |
| currencyWarbandWindowEnabled | bool | CurrencyTracker.lua, Settings.lua | L | V2 | Warband window visibility. |
| currencyWarbandWindowPoint | point table | CurrencyTracker.lua | L | V2 | Warband window anchor and position. |
| currencyWarbandWidth/Height | number | CurrencyTracker.lua | L | V2 | Warband window size. |
| currencyWarbandFontSize | number | CurrencyTracker.lua | L | V2 | Warband row font size. |
| currencyWarbandScale | number | CurrencyTracker.lua | L | V2 | Warband window scale. |
| currencyWarbandUseCurrencyTheme | bool | CurrencyTracker.lua | L | V2 | Inherit currency theme toggle. |
| currencyWarbandTheme | string | CurrencyTracker.lua | L | V2 | Warband local override theme. |
| currencyWarbandTrackedIDs | table | CurrencyTracker.lua | L | V2 | Warband tracked currencies. |
| currencyWarbandShowPreyTrack | bool | CurrencyTracker.lua | L | V2 | Show prey progress triplet in warband. |
| currencyWarbandPreyMode | enum | CurrencyTracker.lua | L | V2 | available/completed mode. |

## Hunt tracker fields

| Field key | Type | Modules using field | Owner now | Owner target | Notes |
|---|---|---|---|---|---|
| huntScannerEnabled | bool | HuntScanner.lua, Settings.lua | L | V2 | Hunt tracker module toggle. |
| huntScannerSide | enum | HuntScanner.lua | L | V2 | left/right anchoring side. |
| huntScannerWidth/Height | number | HuntScanner.lua | L | V2 | Window sizing. |
| huntScannerFontSize | number | HuntScanner.lua | L | V2 | Text size. |
| huntScannerScale | number | HuntScanner.lua | L | V2 | Scale. |
| huntScannerGroupBy | enum | HuntScanner.lua | L | V2 | none/difficulty/zone. |
| huntScannerSortBy | enum | HuntScanner.lua | L | V2 | difficulty/zone/title. |
| huntScannerAnchorAlign | enum | HuntScanner.lua | L | V2 | top/middle/bottom. |
| huntScannerUseCurrencyTheme | bool | HuntScanner.lua | L | V2 | Shared theme use toggle. |
| huntScannerTheme | string | HuntScanner.lua | L | V2 | Local override theme. |

## New planned fields for Slice G (not implemented yet)

| Planned field | Type | Applies to | Rationale |
|---|---|---|---|
| modules.bar.enabled | bool | Bar | Hard disable module runtime when off. |
| modules.sounds.enabled | bool | Sounds | Disable sound runtime and settings edits. |
| modules.currency.enabled | bool | Currency tracker | Disable module runtime and settings edits. |
| modules.warband.enabled | bool | Warband tracker | Disable module runtime and settings edits. |
| modules.achievement.enabled | bool | Achievement tracker | Planned module enable gate. |
| modules.hunt.enabled | bool | Hunt tracker | Disable module runtime and settings edits. |
| sharedTheme.fontKey | string | All trackers | Shared typography baseline. |
| sharedTheme.scale | number | All trackers | Shared scale baseline. |
| sharedTheme.palette | table | All trackers | Shared color tokens across modules. |
| difficultySymbols.auto[diff] | string | Hunt + warband + achievement | Localized auto initials with collision expansion. |
| difficultySymbols.override[diff] | string | Hunt + warband + achievement | User override for identifier text. |
| difficultySymbols.color[diff] | color | Hunt + warband + achievement | Per-difficulty identifier color. |

## Migration checkpoints to track here

- G.0 Field inventory complete and reviewed.
- G.1 Read path moved to CustomizationStateV2 by category.
- G.2 Dual-write enabled for category with inspect parity checks.
- G.3 Legacy write path removed for category.
- G.4 Category verified and marked done.

## Open questions

- Should shared theme values be stored flat in SavedVariables or nested under sharedTheme while keeping compatibility mirrors?
- Should module enabled flags default to true for existing installs and only force reload when toggled from false to true?
- For linked horizontal/vertical controls, should link state be per-setting-group or global for all bar dimensions?

## Settings IA v1 (locked decisions)

Top strip behavior
- Keep top controls as a single row only.
- Keep top strip focused on true addon-wide toggles.

Top global controls (single row)
- Enable Addon (master runtime on/off)
- Lock Frame
- Enable Sounds (master toggle for all addon sounds)
- Hide Default Prey Icon
- Show Only In Prey Zone

Mounted behavior decision
- Do not hide while mounted when inside prey zone.
- Player should still see hunt progress context while mounted in-zone.

Edit mode behavior decision
- Edit Mode always shows addon UI and always allows moving elements.
- In Edit Mode, addon is effectively unlocked and shown regardless of normal visibility rules.
- Keep same practical behavior as current implementation, but present controls in a cleaner dedicated Edit Mode page/section.

Module toggles decision
- Move module toggles into the first tab/page (dedicated Modules page).
- Module toggles are not part of the top strip to avoid overcrowding.

Module toggles list (first tab)
- Enable Bar Module
- Enable Sounds Module
- Enable Currency Module
- Enable Warband Module
- Enable Achievement Module
- Enable Hunt Module

Notes on what should not be global
- Width, height, and scale for panes remain per-pane controls.
- Per-module data options (for example tracked currency IDs, hunt grouping, warband prey mode) stay on module pages.

Proposed page structure aligned to decisions
1. Modules (first tab, module toggles)
2. Global
3. Bar
4. Theme (target selector: All, Currency, Warband, Achievement, Hunt)
5. Sounds
6. Currency
7. Warband
8. Achievement
9. Hunt
10. Edit Mode
11. Profiles / Import Export

## Page-by-page control contract (implementation draft)

1. Modules page
- Enable Bar Module
- Enable Sounds Module
- Enable Currency Module
- Enable Warband Module
- Enable Achievement Module
- Enable Hunt Module
- Behavior: turning a module off disables runtime for that module and disables its settings controls across other pages.
- Behavior: turning a module on requires reload to activate runtime.

2. Global page
- Top strip (single row):
	- Enable Addon
	- Lock Frame
	- Enable Sounds
	- Hide Default Prey Icon
	- Show Only In Prey Zone
- Additional global controls:
	- Global alpha (optional)
	- Reset positions (bar and tracker windows)
	- Global tooltip verbosity level (optional)

3. Bar page
- Layout:
	- Orientation
	- Vertical fill direction
	- Show ticks
	- Show spark line
	- Label mode
	- Label row position
	- Percent display mode
	- Vertical percent display mode
- Sizing (per-pane, never All-linked):
	- Width
	- Height
	- Scale
- Labels:
	- Stage labels 1-4
	- Stage suffix labels 1-4
	- Out-of-zone label
	- Ambush label
- Visuals:
	- Fill color
	- Background color
	- Border color
	- Title color
	- Percent color

4. Theme page (target selector)
- Target selector values:
	- All
	- Currency
	- Warband
	- Achievement
	- Hunt
- Shared controls eligible for All:
	- Font family (title/value)
	- Font outline/style (if exposed)
	- Text colors
	- Accent/border colors
	- Row highlight/stripe colors (tracker pages)
- Not allowed on Theme page:
	- Width/height/scale controls for panes
	- Data filtering controls (those stay module-specific)

5. Sounds page
- Master:
	- Enable Sounds (mirrors global)
	- Sound channel
	- Sound enhance/repeat
- Stage sounds:
	- Stage 1 path
	- Stage 2 path
	- Stage 3 path
	- Stage 4 path
- Ambush sounds:
	- Enable Ambush Sound
	- Ambush sound path
	- Ambush visual toggle

6. Currency page
- Enable Currency Window
- Currency window position
- Currency window width/height/font size/scale
- Currency theme selector (local override only when not using shared theme)
- Tracked currency list
- Affordable hunt display toggle
- Random hunt costs (normal/hard/nightmare)

7. Warband page
- Enable Warband Window
- Warband window position
- Warband width/height/font size/scale
- Use Currency Theme toggle
- Warband theme selector (enabled only when local override is active)
- Tracked currency list (warband)
- Show prey track toggle
- Prey mode selector (available/completed)
- Show realm in warband toggle

8. Achievement page
- Enable Achievement Module (mirrors Modules page state)
- Theme source toggle (All/shared vs local override)
- Local font/color overrides (when enabled)
- Achievement row density/compact mode (planned)
- Priority display toggles (planned)

9. Hunt page
- Enable Hunt Module (mirrors Modules page state)
- Hunt tracker window side/anchor
- Hunt window width/height/font size/scale
- Group by / sort by
- Use currency/shared theme toggle
- Local theme selector
- Difficulty identifier settings:
	- Auto initials on/off
	- Manual override per difficulty
	- Color per difficulty token

10. Edit Mode page
- Always shown and unlocked behavior summary text
- Enter/Exit edit mode action
- Bar anchor reset
- Tracker window anchor reset
- Optional grid/snap controls (if enabled)

11. Profiles / Import Export page
- Profile select/create/copy/delete
- Spec-aware profile binding
- Export profile string
- Import profile string
- Reset to defaults (with confirmation)

## Global omissions check

Confirmed global controls currently in scope:
- Enable Addon
- Lock Frame
- Enable Sounds
- Hide Default Prey Icon
- Show Only In Prey Zone

Controls intentionally not in top strip:
- Module toggles (moved to Modules tab)
- Any width/height/scale controls
- Any module data filters or tracked-ID selectors
