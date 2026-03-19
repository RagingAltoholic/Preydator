# Preydator P1 Modules - In-Game Validation Checklist

**Session**: March 18, 2026  
**Focus**: WeeklyCaps, PreyData, PreyBarUI, PreyWidgetBridge  
**Expected behavior**: No crashes, snapshot recording, bar render, weekly caps persist

---

## Test 1: Addon Load & Bar Frame Initialization

**Steps**:
1. `/reload` to fully reset addon state
2. Wait for login screen to clear
3. Check chat for any Lua errors (should see none)

**Expected**:
- ✅ Addon loads cleanly
- ✅ No "PreyBarUI not found" or frame initialization errors
- ✅ No nil reference on `Preydator:GetModule("PreyBarUI")`

**Log on success**:
```
[PASS] Addon loaded, no Lua errors
```

---

## Test 2: Bar Frame Creation & Delegation

**Steps**:
1. Open `/pd inspect` (DebugInspect module)
2. Look for `bar frame unavailable` or actual bar dimensions

**Expected output**:
```
- bar shown=false | mouse=true | width=143.99... | height=26.99... | scale=1 | effectiveScale=0.65...
- prefix shown=true | text='Preydator' | point=BOTTOM -> PreydatorProgressBar:TOP (0,4)
```

**What this proves**:
- ✅ PreyBarUI:RegisterBarFrames() was called in EnsureBar()
- ✅ Preydator.GetBarFrame() delegates to PreyBarUI
- ✅ Label frames loaded via GetLabelFrames()

**Log on success**:
```
[PASS] Bar frame initialized, delegated to PreyBarUI
```

---

## Test 3: Accept a Hunt & Verify Bar Appears

**Steps**:
1. Go to a Prey zone (e.g., Winterpelt)
2. Accept a hunt (any difficulty)
3. Check that the bar appears on screen with stage label
4. Visually verify: bar shows "Scent" (stage 1) or current stage

**Expected**:
- ✅ Bar shows immediately when quest becomes active
- ✅ Stage label displays correctly ("Scent", "Blood", etc.)
- ✅ Bar is draggable (click and drag to new position)

**Log on success**:
```
[PASS] Bar renders correctly on quest accept
```

---

## Test 4: Turn In Hunt & Verify Snapshot Recording (Fallback Path)

**Purpose**: Verify CurrencyTracker fallback — if PreyData unavailable, direct DB write works.

**Steps**:
1. While hunt is active, use `/pd inspect` to note weekly completed:
   ```
   - settings ... (should show you completed 1 normal hunt)
   ```
2. Complete the hunt (kill all 4 stages) and turn it in
3. Check chat for turn-in message
4. **Critical**: Do NOT open currency tracker window yet
5. Reload addon: `/reload`
6. Use `/pd inspect` again

**Expected after reload**:
- ✅ Weekly completed count still shows your 1 normal completed (snapshot persisted)
- ✅ No "nil" or "?" for weekly completed value
- ✅ Snapshot data survives reload

**This proves**:
- ✅ RecordPreyTurnIn() fallback worked if PreyData was unavailable
- ✅ Snapshot written to DB successfully
- ✅ Data persists across reloads

**Log on success**:
```
[PASS] Snapshot recording survives reload (fallback path validated)
```

---

## Test 5: Weekly Caps Display & Persistence

**Steps**:
1. Open CurrencyTracker window (icon on minimap or `/ct` if available)
2. Navigate to "Prey" tab or similar
3. Look for your character row with weekly completed count (e.g., "1/4" for normal)
4. Reload addon: `/reload`
5. Reopen CurrencyTracker

**Expected**:
- ✅ Your character shows weekly completed count
- ✅ Count matches what you just recorded (1 for this test)
- ✅ After reload, count still present (PreyData persisted through reload)

**Weekly caps specifics**:
- If you're level 78+: Normal cap shows `4` (available count)
- If you're level 90+ with hard unlock: Hard cap shows `4` (if applicable)
- Nightmare shows `-` unless you've unlocked it

**Log on success**:
```
[PASS] Weekly caps display and persist across reloads
```

---

## Test 6: PreyWidgetBridge Availability

**Steps**:
1. Use `/pd inspect`
2. Look at the output for any widget-related errors
3. Check that widget progress updates as you advance hunt stages

**Expected in inspect output**:
- No "widget" error messages
- Bar percent updates as you progress (0% → 25% → 50% → 75% → 100%)

**This proves**:
- ✅ PreyWidgetBridge:GetWidgetState() queries widget correctly
- ✅ Widget state flows through to bar display

**Log on success**:
```
[PASS] PreyWidgetBridge detects widget state, bar percent updates
```

---

## Test 7: Module Disable/Enable (Warband Toggle)

**Steps**:
1. Go to Settings > Gameplay > Warband
2. Toggle "Warband Module" ON
3. Do `/reload`
4. Toggle "Warband Module" OFF
5. Do `/reload`

**Expected behavior**:
- ✅ When ON: Snapshot recording works, weekly caps display
- ✅ When OFF: Snapshot recording stops (silently), weekly caps don't display but data persists
- ✅ When toggled back ON: Data reappears

**This proves**:
- ✅ MODULE:IsEnabled() checks work as designed
- ✅ Data isn't erased when disabled, just not updated

**Log on success**:
```
[PASS] Module disable/enable toggles correctly without data loss
```

---

## Failure Scenarios (If You Hit These)

### **"bar frame unavailable" in inspect**
- **Cause**: PreyBarUI:RegisterBarFrames() not called or Preydator.lua EnsureBar() didn't complete
- **Fix**: Check Preydator.lua line ~2156 for RegisterBarFrames call; verify it comes AFTER ApplyBarSettings()

### **Weekly count shows `nil` after reload**
- **Cause**: PreyData module not available during snapshot write, fallback didn't run OR fallback had a typo
- **Fix**: Check CurrencyTracker.SnapshotCurrentPreyCharacter() fallback for typos in field access

### **Bar doesn't render or shows at wrong position**
- **Cause**: EnsureBar() created frames but RegisterBarFrames() didn't receive them OR Refresh() not called
- **Fix**: Verify Preydator.lua line ~2156 RegisterBarFrames table includes all 10 frame refs

### **Widget percent doesn't update during hunt**
- **Cause**: PreyWidgetBridge:GetWidgetState() returning nil or UpdatePreyState() not calling it
- **Fix**: Check that UpdatePreyState() is being called on UPDATE_UI_WIDGET events

---

## After Validation

**If all tests pass**:
- Comment in this file: `[VALIDATION PASSED - 2026-03-18]`
- Proceed to **Option 2: P0 Runtime Ownership Analysis**

**If any tests fail**:
- Note the specific failure scenario above
- Provide the exact error message or unexpected behavior
- I'll diagnose and fix the code issue

---

## Quick Checklist (Copy/Paste to Update as You Test)

```
[  ] Test 1: Addon load, no errors
[  ] Test 2: Bar frame registered, delegation works
[  ] Test 3: Bar renders on quest accept
[  ] Test 4: Snapshot persists after reload
[  ] Test 5: Weekly caps display and persist
[  ] Test 6: PreyWidgetBridge detects widget
[  ] Test 7: Module disable/enable works
```
