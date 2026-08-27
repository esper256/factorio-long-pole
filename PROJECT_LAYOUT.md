# Project Layout

This file records the current layout plan of record from implementation step 2.
It exists so the agreed naming does not live only in chat context.

## Top level

```text
factorio-long-pole/
├── ARCHITECTURE.md
├── IMPLEMENTATION_PLAN.md
├── PROJECT_LAYOUT.md
├── info.json
├── changelog.txt
├── settings.lua
├── data.lua
├── control.lua
├── thumbnail.png
├── locale/
├── runtime/
├── speedrun_plan/
├── game_state/
├── progress_analysis/
├── recipe_resolution/
├── recipe_analysis/
├── storage/
├── snoopers/
├── hud/
├── plan_editor/
├── data_definitions/
├── runtime_state/
├── test_support/
├── test_data/
└── tests/
```

## Naming notes

- `runtime/` is the Factorio-facing layer.
- `speedrun_plan/` is the domain model for the plan itself, not persistence.
- `storage/` is specifically cross-save transport and library access.
- `runtime_state/` owns save-local state held in Factorio's `storage` table.
- `snoopers/` contains one adapter per Factorio event source; `snooper_master.lua`
  selects the active adapters and combines their event handlers.
- `progress_analysis/` is the forecasting layer between tracked game state and the HUD.
- Avoid generic directories such as `util/`, `helpers/`, `common/`, or `misc/`.
- Create files in these directories only when the current implementation step needs them.
