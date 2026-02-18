# AtlasLoot Source Map (Sirus)

Primary upstream source:
- `https://github.com/Mr-Dan/AtlasLoot-Sirus`

Local installation root:
- `c:\Games\World of Warcraft Sirus\Interface\AddOns`

## Load order and module model

Core addon:
- `AtlasLoot\AtlasLoot.toc`
  - Loads core XML/Lua (Locales, TableRegister, AtlasLayout, Menus, Core, DefaultFrame)
  - Declares `X-Sirus-Update` to GitHub upstream

Load-on-demand content modules:
- `AtlasLoot_OriginalWoW\AtlasLoot_OriginalWoW.toc`
- `AtlasLoot_BurningCrusade\AtlasLoot_BurningCrusade.toc`
- `AtlasLoot_WrathoftheLichKing\AtlasLoot_WrathoftheLichKing.toc`
- `AtlasLoot_Sirus\AtlasLoot_Sirus.toc`
- `AtlasLoot_PVP\AtlasLoot_PVP.toc`
- `AtlasLoot_Crafting\AtlasLoot_Crafting.toc`
- `AtlasLoot_WorldEvents\AtlasLoot_WorldEvents.toc`

Each `AtlasLoot_*` module is `LoadOnDemand: 1` and contributes data tables into shared globals used by AtlasLoot runtime.

## Boss names, loot tables, menu hierarchy

Boss/table display names:
- `AtlasLoot\TableRegister\loottables.en.lua`
- Runtime table: `AtlasLoot_TableNames`

Loot table bodies (item rows):
- `AtlasLoot_BurningCrusade\burningcrusade.lua`
- `AtlasLoot_WrathoftheLichKing\wrathofthelichking.lua`
- `AtlasLoot_Sirus\sirus.lua`
- Additional modules listed above can also contain `AtlasLoot_Data[...]`
- Runtime table: `AtlasLoot_Data`

Instance/raid hierarchy (layout):
- `AtlasLoot\AtlasLayout\instances.en.lua`
- `AtlasLoot\AtlasLayout\worldbosses.en.lua`
- Runtime helpers/tables used by AtlasLoot layout navigation

Localization/constants:
- `AtlasLoot\Locales\constants.en.lua` and locale variants

## Data schema summary used for BisEquip extraction

Loot table row format (typical):
- `{ index, itemId, icon, qualityName, slotDescriptor, sourceText, dropRate }`

Key fields for BisEquip:
- `itemId` (numeric)
- `slotDescriptor` string containing markers:
  - `#s1#..#s16#`, `#h1#..#h4#`, `#w#`, `#a#`
- table key name (`AtlasLoot_Data["TableId"]`) used as `source`

## Runtime stats in AtlasLoot vs BisEquip

AtlasLoot:
- Focuses on loot browsing and presentation.
- Uses item APIs for display data (name/icon/link), but does not maintain BisEquip-ready aggregated stat DB.

BisEquip:
- Calculates/reads item stats through `GetItemStats` and tooltip fallback at runtime.

## Extraction strategy used by BisEquip

1. Parse all selected `AtlasLoot_*` module Lua files for `AtlasLoot_Data`.
2. Map AtlasLoot slot markers to BisEquip slot IDs.
3. Normalize difficulty from table IDs/suffixes.
4. Write static snapshot:
   - `Data/ItemsFull.lua` (`BisEquip_ItemDB`, `BisEquip_ItemSources`)
5. Keep generation repeatable for upstream updates.

