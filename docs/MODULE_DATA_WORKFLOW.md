# Module Data Workflow

BisEquip now uses static section modules as the primary data source.

## Files

- Registry: `Data/Modules/ModuleRegistry.lua`
- Runtime API: `Core/ModuleData.lua`
- Generated module data: `Data/Modules/*.lua`
- Rule config: `scripts/module_rules.py`
- Generator: `scripts/extract_atlasloot.py`

## Regeneration

```powershell
python "c:\Games\World of Warcraft Sirus\Interface\AddOns\BisEquip\scripts\extract_atlasloot.py" --addons-path "c:\Games\World of Warcraft Sirus\Interface\AddOns" --output-root "c:\Games\World of Warcraft Sirus\Interface\AddOns\BisEquip"
```

## Validation checklist

1. `Data/AtlasLootExtractReport.txt` has non-zero rows for key modules (`PVP`, `WotLKRaid`, `Sets`).
2. `PVP.lua` contains A5-A13 groups and Wintergrasp section.
3. In game:
   - opening source menu has no heavy lag spikes;
   - A7 exists for armor slots;
   - OLO appears as a separate section;
   - class grouping in PvP shows classes only.

## Fallback mode

- Keep `fallbackToLegacy = true` only for emergency compatibility.
- Preferred production mode for static data: `fallbackToLegacy = false`.

