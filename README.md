# Preydator

Minimal WoW addon that plays a custom predator clicking sound when your active Prey reaches the **Final** hunt state.

## Install custom sound

1. Create this folder:

   `Interface/AddOns/Preydator/sounds/`

2. Put your sound file here:

   `Interface/AddOns/Preydator/sounds/predator-idle.ogg`

   and

   `Interface/AddOns/Preydator/sounds/predator-alert.ogg`

3. Reload UI (`/reload`).

The sound file must exist before login/reload for `PlaySoundFile` to load it.

## Detection behavior

- Uses `C_QuestLog.GetActivePreyQuest()` to confirm you have an active Prey quest.
- Listens for `UPDATE_UI_WIDGET` / `UPDATE_ALL_UI_WIDGETS` and reads `PreyHuntProgress` widget data.
- Plays once per active Prey quest when progress transitions into `Final`.

## Progress bar + stages

The addon now shows a compact stage bar with your flow:

1. Isle
2. Alert
3. Ambush
4. Torment Warning
5. Kill

Stage mapping uses live Prey widget states and fills from `0% -> 100%`. When the active Prey quest is turned in, the bar briefly shows **Kill** at `100%`.

## Slash commands

- `/preydator test` (or `/pd test`) - plays `predator-idle.ogg`.
- `/preydator testalert` - plays `predator-alert.ogg`.
- `/preydator inspect` - prints live quest/widget/state diagnostics to chat.
- `/preydator fillmode <strict|stage>` - strict uses real percent only; stage falls back to stage fill when percent is unavailable.
- `/preydator show` - force shows the stage bar.
- `/preydator hide` - returns bar to auto mode.
- `/preydator toggle` - toggles force-show.
