# BisEquip Smoke Test Checklist

## Data generation checks (offline)

1. Regenerate snapshot:
   - `python scripts/extract_atlasloot.py --addons-path "c:\Games\World of Warcraft Sirus\Interface\AddOns"`
2. Validate snapshot:
   - `python scripts/validate_snapshot.py`
3. Confirm report exists:
   - `Data/AtlasLootExtractReport.txt`

## In-game UI checks

1. Open BisEquip and click any slot once:
   - picker must open on first click.
2. Open source dropdown immediately:
   - categories must be visible; list must not be empty.
3. Select a boss in BC and WotLK:
   - item list must refresh without repeated clicks.
4. Change difficulty:
   - item list must filter consistently.
5. Click item in picker:
   - item equips into target slot and source label updates.
6. Reopen same slot:
   - picker remains responsive, no empty placeholder-only state.
7. Open/close with Escape:
   - main and picker frames should close via `UISpecialFrames`.

## Regression checks

1. `Load`/`Delete` set dropdowns are clickable and visible above frames.
2. Slot clicks work across left/right/bottom slot groups.
3. Source labels do not overlap critical controls.
4. Stats block remains visible and updates after item change.

