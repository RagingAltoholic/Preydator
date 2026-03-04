# Preydator

Preydator is a focused Prey Hunt companion addon for World of Warcraft.

It gives you a clear, customizable progress bar for your active prey stages and optional stage-based audio cues so you always know how close you are to the kill.

## What Preydator does

- Tracks your active prey quest and stage progression.
- Shows a compact progress bar with stage naming support.
- Displays out-of-zone messaging when you are not in the prey zone.
- Locks the final stage to 100% for consistent finish-state feedback.
- Plays per-stage audio cues with configurable sound channel support.

## Stage flow

1. Scent in the Wind
2. Blood in the Shadows
3. Echoes of the Kill
4. Feast of the Fang

## Customization features

- Move and lock/unlock bar position
- Scale, width, height, and font size controls
- Texture preset selection
- Custom colors for:
  - Bar texture/border
  - Stage title text
  - Percent text
- Editable stage labels and out-of-zone label
- Tick marks and percent display modes
- Sound settings (enable/disable, channel, enhancement)
- In-settings stage sound test buttons
- Reset all settings to defaults

## Slash commands

- `/pd options` - Open Preydator settings
- `/pd inspect` - Print live diagnostics to chat
- `/pd show` - Force show bar
- `/pd hide` - Return to auto visibility
- `/pd toggle` - Toggle force show
- `/pd mem` - Print memory usage snapshot
- `/pd debug <on|off|show|clear>` - Debug logging tools

## Optional custom audio

You can replace the included stage sounds by placing your own `.ogg` files in:

- `Interface/AddOns/Preydator/sounds/predator-alert.ogg`
- `Interface/AddOns/Preydator/sounds/predator-ambush.ogg`
- `Interface/AddOns/Preydator/sounds/predator-torment.ogg`
- `Interface/AddOns/Preydator/sounds/predator-kill.ogg`

Then run `/reload`.

## Notes

- Retail-focused addon.
- Uses Blizzard quest/widget APIs for live prey state tracking.
