# AtlasLoot Update Workflow for BisEquip

This workflow keeps BisEquip fully static (no runtime data download) while staying synchronized with AtlasLoot-Sirus updates.

Primary upstream:
- https://github.com/Mr-Dan/AtlasLoot-Sirus

## 1) Update data source

1. Update local `AtlasLoot*` folders in:
   - `c:\Games\World of Warcraft Sirus\Interface\AddOns`
2. Verify required modules exist:
   - `AtlasLoot`
   - `AtlasLoot_BurningCrusade`
   - `AtlasLoot_WrathoftheLichKing`
   - `AtlasLoot_Sirus`
   - and other `AtlasLoot_*` modules.

## 2) Regenerate BisEquip snapshot

From any shell:

```powershell
python "c:\Games\World of Warcraft Sirus\Interface\AddOns\BisEquip\scripts\extract_atlasloot.py" --addons-path "c:\Games\World of Warcraft Sirus\Interface\AddOns"

# or use dedicated Desktop source snapshot
python "c:\Games\World of Warcraft Sirus\Interface\AddOns\BisEquip\scripts\extract_atlasloot.py" --addons-path "$env:USERPROFILE\Desktop\AtlasLoot" --output-root "c:\Games\World of Warcraft Sirus\Interface\AddOns\BisEquip"
```

Generated outputs:
- `Data/ItemsFull.lua` (legacy fallback snapshot)
- `Data/Modules/*.lua` (static per-section modules)
- `Data/AtlasLootExtractReport.txt` (includes per-module row counts)

## 3) Validate generated data

```powershell
python "c:\Games\World of Warcraft Sirus\Interface\AddOns\BisEquip\scripts\validate_snapshot.py"
```

Expected result:
- `OK: snapshot looks consistent`

## 4) In-game smoke checks

Use:
- `docs/SMOKE_TEST_CHECKLIST.md`

Minimum required checks:
1. Picker opens on first click for multiple slots.
2. Source dropdown is populated immediately.
3. Boss selection returns items in BC/WotLK/Sirus.
4. Difficulty filter updates results.

## 5) If AtlasLoot table IDs changed

Symptoms:
- Boss visible, but 0 items for that source.

Actions:
1. Re-run extractor (step 2) first.
2. Re-test with smoke checklist.
3. If mismatch persists, adjust module rules first:
   - `scripts/module_rules.py`
4. Regenerate and retest.
5. Keep legacy fixes in sync only when fallback path is enabled:
   - `Core/ItemData.lua`

## 6) Module runtime mode

Main data path is now module-based (`Core/ModuleData.lua`), with compatibility fallback.

Config:
- `Data/Modules/ModuleRegistry.lua`
  - `enabled = true`: use module data API
  - `fallbackToLegacy = true`: emergency fallback to legacy `Core/ItemData.lua` path

To hard-disable legacy runtime classification for covered sections, set:
- `enabled = true`
- `fallbackToLegacy = false`

## 7) Optional UI/library alignment refresh

Reference for UI patterns:
- https://github.com/accidev/ElvUI-for-Sirus

When needed:
1. Re-check click/strata/dropdown behavior in `Libraries/UICompat.lua`.
2. Validate slot/button interaction paths in `UI/Frame.lua` and `UI/ItemPicker.lua`.

