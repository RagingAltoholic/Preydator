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
