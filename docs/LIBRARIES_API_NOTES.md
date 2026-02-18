# Libraries API Notes for BisEquip

This file summarizes practical APIs from `BisEquip/Libraries` that are useful for UI stability and business logic.

## High-priority (recommended for BisEquip core)

### Ace3
- `AceAddon-3.0`
  - addon lifecycle, module bootstrap (`OnInitialize`, `OnEnable`)
- `AceEvent-3.0`
  - event registration/unregistration patterns for reactive UI refresh
- `AceTimer-3.0`
  - delayed refresh/retry (e.g. item cache re-check after first render)
- `AceHook-3.0`
  - safe function hooks instead of replacing globals

### LibSharedMedia-3.0
- unified fonts/textures/statusbars
- useful for consistent styling of slot buttons and stat panes

### LibActionButton-1.0 (optional)
- if migrating slot rendering closer to action-button behavior
- not required for current picker flow

## Useful for search/filter logic

### LibItemSearch-1.2 + CustomSearch + Unfit
- richer text filters for item list search
- can replace ad-hoc `string.find` matching in picker search

## Useful for communication / future sync

### AceComm-3.0 + AceSerializer-3.0 + LibCompress / LibDeflate / LibBase64
- only needed if sets/source presets are shared between players
- not required for standalone static loot DB mode

## oUF / unitframe stack (not required now)

Folders:
- `oUF`
- `oUF_Plugins/*`
- `Compat/*`

These are heavy unitframe systems and not needed for BisEquip equipment planner.
Recommendation: keep in repository only if you explicitly build unitframe-like features; otherwise do not couple core logic to them.

## Integration policy in BisEquip

1. Keep hard dependencies minimal (`Ace3` + optional media/search libs).
2. Wrap library usage in adapter helpers:
   - `Libraries/UICompat.lua`
3. Avoid direct dynamic reads from external addons.
4. Continue static data ownership in `Data/*` generated files.

