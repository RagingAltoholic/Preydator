# Test Next Reset

Date created: 2026-03-18
Purpose: Validate weekly warband hunt availability auto-reset behavior after server weekly reset.

## Preconditions

1. Warband module is enabled in settings.
2. Characters being validated already exist in `PreydatorDB.currency.preySnapshots`.
3. Account unlock flags are already established:
   - `hardUnlocked = true`
   - `nightmareUnlocked = true`

## Test Steps (first login after weekly reset)

1. Log into one character after weekly reset.
2. Open Preydator Warband panel.
3. Review N/H/Ni available counts for all stored characters.
4. Toggle between Available and Completed display modes.

## Expected Results

1. Weekly availability auto-resets for all stored characters without alt login loops.
2. Level 90+ characters show `4/4/4` available.
3. Level 78-89 characters show `4/-/-` available.
4. Completed mode reflects inverse counts from available values per difficulty.
5. No characters remain on stale pre-reset values.

## Notes / Exceptions

1. Characters never logged since snapshot tracking began may not have entries yet.
2. If Warband module is disabled, reset processing is skipped by design.
3. Nightmare implies Hard; hard should never show `-` when nightmare is numeric.
