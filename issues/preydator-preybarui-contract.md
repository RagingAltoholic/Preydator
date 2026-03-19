# PreyBarUI Module Contract

## Ownership & Scope

**PreyBarUI owns:**
- Bar frame creation and all child elements (frame, fill, spark, border, labels, ticks)
- All visual styling and layout (colors, fonts, textures, positioning)
- Tick mark rendering and labeling
- Text display positioning and layering
- Bar visibility and state-driven rendering logic
- Spark line and kill stage visual feedback

**PreyBarUI does NOT own:**
- State management (Preydator.lua owns activeQuestID, progressPercent, stage, etc.)
- Settings persistence (Settings module stores configuration)
- Event handling (Preydator.lua handles QUEST_TURNED_IN, UPDATE_UI_WIDGET, etc.)
- Audio/ambush effects (PreyAudio module owns sound triggers)
- Edit mode behavior (Preydator manages edit mode state)

**Why this split:**
- Rendering is visually complex and benefits from isolated module ownership
- State and settings are policy; rendering is implementation
- PreyBarUI can be disabled independently to hide bar visuals while keeping state intact
- Settings can change without PreyBarUI knowing about event stream

## Frame Hierarchy

```
barFrame (main container, movable, user-positioned)
├── barBackgroundTexture (black semi-transparent fill)
├── barFill (progress bar texture, color-based)
├── barSpark (progress edge indicator)
├── barBorder (backdrop frame with border edges)
├── stageText (FontString, above bar for stage label)
├── stageSuffixText (FontString, above bar for suffix)
├── barText (FontString, centered for percent display)
├── barAlignmentDot (Texture, center alignment indicator, debug only)
├── barTickMark[1..N] (Textures for tick mark lines)
└── barTickLabel[1..N] (FontStrings for tick mark percentages)
```

## Module API

### Initialization

```lua
-- Initialize bar frame and all child elements (call once on ADDON_LOADED).
-- Creates frame, textures, fonts, and applies initial settings.
-- Required before any other PreyBarUI calls.
function PreyBarUI:EnsureBar()
  -> Creates barFrame and all child elements
  -> Applies default styling
  -> Returns nothing (frames stored internally)
end

-- Check if bar rendering is enabled (gated by module toggle).
-- Called: By Preydator before rendering operations.
-- Returns: true if bar is enabled, false if disabled or error.
function PreyBarUI:IsEnabled()
  -> Checks CustomizationStateV2:IsModuleEnabled("bar")
  -> Returns boolean
end
```

### Display Refresh

```lua
-- Update bar display based on current state and settings.
-- Called: When state changes (quest, stage, percent, zone), when user moves bar, etc.
-- state input: {activeQuestID, progressPercent, stage, inPreyZone, killStageUntil, ambushAlertUntil, forceShowBar}
-- settings input: Full settings table (colors, fonts, dimensions, text, layout, etc.)
-- Behavior: Determines visibility, updates fill width, positions text/labels, applies styling.
function PreyBarUI:Refresh(state, settings)
  -> Determines if bar should be visible based on state
  -> Calculates fill width/height based on percent and orientation
  -> Updates all text labels (stage, suffix, percent)
  -> Positions ticks and labels based on layout mode
  -> Updates visual styling (colors, fonts) from settings
  -> Shows/hides elements based on mode (e.g., hide barText if percentDisplay=off)
end

-- Apply visual style changes (colors, fonts, textures, sizing).
-- Called: When user adjusts bar appearance settings.
-- Behavior: Updates textures, colors, fonts WITHOUT recalculating layout.
-- Optimization: Faster than full Refresh when only appearance changes.
function PreyBarUI:ApplyVisualStyle(settings)
  -> Updates barFill color, texture from settings.fillColor, settings.textureKey
  -> Updates barBorder color from settings.borderColor
  -> Updates all FontString colors (stageText, barText, etc.) from settings
  -> Updates font faces from settings.titleFontKey, settings.textFontKey
  -> Does not change element visibility or position
end

-- Apply layout/dimension changes (width, height, scale, orientation).
-- Called: When user adjusts bar size or changes horizontal/vertical mode.
-- Behavior: Resizes frame, recalculates tick positions, reflows text.
function PreyBarUI:ApplyLayout(settings)
  -> Resizes barFrame to settings.width / settings.height
  -> Sets barFrame:SetScale(settings.scale)
  -> Reflows tick marks based on orientation (horizontal vs vertical)
  -> Repositions text elements based on labelRowPosition, stageLabelMode, etc.
  -> Updates vertical-only layout (fillDirection, verticalTextSide, etc.)
end
```

### Frame Access (Legacy Compatibility)

```lua
-- Get main bar frame for positioning/event handling.
-- Called: By external code that needs to interact with frame directly.
-- Returns: barFrame (WoW Frame object).
function PreyBarUI:GetBarFrame()
  -> Returns barFrame or nil if not initialized
end

-- Get text label frames for external updates.
-- Called: By Settings module to expose label FontStrings for editing.
-- Returns: {prefix=stageText, suffix=stageSuffixText, percent=barText, centerDot=barAlignmentDot}.
function PreyBarUI:GetLabelFrames()
  -> Returns table with frame references
  -> prefix: stageText (above bar, stage number/label)
  -> suffix: stageSuffixText (above bar, difficulty suffix)
  -> percent: barText (centered in or below bar)
  -> centerDot: barAlignmentDot (debug alignment indicator)
end
```

### Debug

```lua
-- Expose bar rendering state for /pd inspect.
-- Called: By DebugInspect for diagnostic output.
-- Returns: {isVisible, displayPercent, stage, fillWidth, orientation, ...}.
function PreyBarUI:GetDebugState()
  -> Returns table with current frame state and display metrics
end
```

## Event Flow & Triggers

### On ADDON_LOADED
```
Preydator (core loader) detects addon load
  -> calls PreyBarUI:EnsureBar()
     (creates all frame elements)
  -> reads current state/settings
  -> calls PreyBarUI:Refresh(state, settings)
     (initial bar render)
```

### On PLAYER_LOGIN
```
Preydator.OnEvent(PLAYER_LOGIN) fires
  -> reads saved bar position from settings
  -> calls barFrame:SetPoint(...) via GetBarFrame()
  -> calls PreyBarUI:Refresh(state, settings)
     (render bar in saved position)
```

### On quest change (QUEST_ACCEPTED, QUEST_TURNED_IN, UPDATE_UI_WIDGET)
```
Preydator.UpdatePreyState() updates state.activeQuestID / state.progressPercent / state.stage
  -> calls PreyBarUI:Refresh(state, settings)
     (update fill width, stage label, visibility)
```

### On settings change (user clicks color picker, slider, dropdown)
```
Settings module detects change (e.g., fillColor, width, orientation)
  -> calls Preydator.ApplyBarSettings() or Preydator.UpdateBarDisplay()
  -> calls PreyBarUI:ApplyVisualStyle()  [for color/font/texture changes]
  -> calls PreyBarUI:ApplyLayout()       [for dimension/orientation changes]
  -> calls PreyBarUI:Refresh()           [for comprehensive re-render]
```

### On bar reposition (user drags bar)
```
barFrame OnDragStop event fires
  -> saves position to settings.point.{anchor, relativePoint, x, y}
  -> no visual change needed; bar already moved by WoW drag
```

### On zone change (ZONE_CHANGED, ZONE_CHANGED_INDOORS, etc.)
```
Preydator updates state.inPreyZone
  -> calls PreyBarUI:Refresh(state, settings)
     (update visibility based on onlyShowInPreyZone setting)
```

### On module toggle (warband enabled/disabled)
```
CustomizationStateV2 detects "bar" module toggle
  -> calls PreyBarUI:OnDisable() or OnEnable()
  -> PreyBarUI:OnDisable() hides bar frame
  -> PreyBarUI:OnEnable() shows bar frame (if state allows)
```

## State Contract

**State object input to Refresh() (read-only, provided by caller):**
```lua
state = {
  activeQuestID = number or nil,           -- Current prey quest, nil if none
  progressPercent = number (0..100),       -- Calculated progress 0-100%
  stage = number (1..4),                   -- Current stage, 1 if no active quest
  inPreyZone = boolean or nil,             -- true if player in prey zone
  forceShowBar = boolean,                  -- Force bar visible (edit mode preview, etc.)
  killStageUntil = number (unix epoch),    -- Now < this = show stage 4 visual
  ambushAlertUntil = number (unix epoch),  -- Now < this = show ambush alert
  lastDisplayPct = number,                 -- Previous refresh percent (for spark position)
}
```

**Settings object input to Refresh()/ApplyStyle()/ApplyLayout() (read-only):**
```lua
settings = {
  -- Visibility/behavior
  onlyShowInPreyZone = boolean,            -- Only show when in prey zone
  showInEditMode = boolean,                -- Show bar in edit mode preview
  -- Dimensions
  width = number (160..500),               -- Bar frame width
  height = number (10..40),                -- Bar frame height
  scale = number (0.7..1.4),               -- Frame scale multiplier
  -- Layout
  orientation = "horizontal" | "vertical", -- Bar direction
  labelRowPosition = "above" | "below",    -- Stage label position (horizontal)
  stageLabelMode = "center" | "left" | "left_combined" | etc., -- Label alignment
  labelRowPosition = "above" | "below",    -- Text row position (hor)
  verticalTextSide = "left" | "right",     -- Text side (vert)
  verticalPercentSide = "left" | "right" | "center", -- Percent side (vert)
  verticalTextOffset = number (2..60),     -- Text offset from bar (vert)
  verticalPercentOffset = number (2..60),  -- Percent offset from bar (vert)
  verticalTextAlign = "separate" | "combined", -- Text layout (vert)
  verticalFillDirection = "up" | "down",   -- Fill direction (vert)
  -- Visual styling
  fillColor = {r, g, b, a},                -- Progress bar color
  backgroundColor = {r, g, b, a},          -- Bar background color
  titleColor = {r, g, b, a},               -- Stage label text color
  percentColor = {r, g, b, a},             -- Percent display text color
  tickColor = {r, g, b, a},                -- Tick mark color
  borderColor = {r, g, b, a},              -- Border color
  borderColorLinked = boolean,             -- Link border to fillColor
  -- Fonts
  titleFontKey = "frizqt" | "arialn" | etc., -- Stage label font
  textFontKey = "frizqt" | "arialn" | etc.,  -- Text display font
  fontSize = number (8..24),               -- Text font size
  -- Textures
  textureKey = "smooth" | "gradient" | etc., -- Fill texture preset
  -- Percent display
  percentDisplay = "inside" | "inside_below" | "above_bar" | "below_bar" | "off", -- Percent placement
  verticalPercentDisplay = "inside" | "above_bar" | etc., -- Percent (vert)
  -- Advanced
  showTicks = boolean,                     -- Show tick marks
  showSparkLine = boolean,                 -- Show progress spark line
  tickLayerMode = "above" | "below",       -- Tick layer vs fill
  progressSegments = "thirds" | "quarters", -- 33/66 or 25/50/75
  showAlignmentDot = boolean,              -- Debug center dot
  -- Labels (per-stage and special)
  stageLabels = {[1]=..., [2]=..., [3]=..., [4]=...}, -- Custom stage names
  stageSuffixLabels = {...},               -- Suffix after stage
  outOfZoneLabel = string,                 -- When out of zone
  ambushCustomText = string,               -- Custom ambush text
}
```

## Interaction with Other Modules

**Preydator (core runtime):**
- Calls: `PreyBarUI:EnsureBar()` on ADDON_LOADED
- Calls: `PreyBarUI:Refresh(state, settings)` on state changes
- Calls: `PreyBarUI:GetBarFrame()` to get frame for positioning/events
- Scenario: Preydator owns event handling and state mutations; PreyBarUI owns rendering

**Settings:**
- Calls: `PreyBarUI:GetLabelFrames()` to expose text elements for user editing
- Calls: `PreyBarUI:ApplyVisualStyle()` / `PreyBarUI:ApplyLayout()` on setting changes
- Scenario: Settings controls the UI for customization; PreyBarUI applies visual changes

**PreyAudio:**
- Calls: `Preydator.API.UpdateBarDisplay()` (which triggers `PreyBarUI:Refresh()`)
- Scenario: Sound effects don't directly control rendering, but may trigger state that leads to render

**CustomizationStateV2:**
- Calls: `PreyBarUI:OnDisable()` when bar module toggled off
- Calls: `PreyBarUI:OnEnable()` when bar module toggled on
- Scenario: Module gating hides/shows bar visuals without destroying state

## Rollout Plan

1. Create Modules/PreyBarUI.lua with full contract
2. Extract EnsureBar() from Preydator.lua
3. Extract ApplyBarSettings() from Preydator.lua (split into ApplyVisualStyle + ApplyLayout)
4. Extract UpdateBarDisplay() from Preydator.lua (becomes PreyBarUI:Refresh)
5. Update Preydator.lua to call PreyBarUI APIs instead of direct manipulation
6. Update Settings to call PreyBarUI APIs for style/layout changes
7. Ensure frame references via GetBarFrame() / GetLabelFrames() work for legacy code
8. Verify no Lua errors and bar visuals in-game

## Implementation Notes

- **Frame closure:** Store all frames (barFrame, barFill, etc.) as private module state, not in Preydator closure
- **Initialization guard:** EnsureBar() should be idempotent; calling twice should not recreate frames
- **State-driven rendering:** Refresh() should calculate all visibility/position based on inputs, not internal state
- **Backward compat:** GetBarFrame() and GetLabelFrames() must work for existing code that fetches frame references
- **Module gating:** IsEnabled() check on refresh operations; if disabled, skip rendering but preserve stored frames
