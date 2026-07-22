# Lessons Learned

## Context

This project moved fast in April 2026 and reached a useful prototype, but it also accumulated a lot of structural debt very quickly. Looking at the commit history, the biggest churn clustered around:

- `gui/plan_editor.lua`
- `plan_storage.lua`
- `split_tracker.lua`
- `progress_tracker_store.lua`
- `control.lua`

That is a strong sign that too many responsibilities were still being discovered while the code was already being written.

## Greatest Challenges And Time Wasted

### 1. Too many hard problems were attacked at once

The mod is really three separate products glued together:

- a dense plan editor
- a blueprint import/export/linking system
- a runtime progress tracker / predictor

Those are all legitimate features, but they have very different failure modes. A lot of time appears to have been spent bouncing between them instead of finishing one stable vertical slice at a time.

What would have been better:

- First ship a minimal plan format with manual item goals only.
- Then add blueprint-backed requirements.
- Only then add predictive runtime tracking and "long pole" estimation.

### 2. The UI and domain model evolved together instead of one driving the other

`gui/plan_editor.lua` saw the heaviest churn by far. That usually means the editor was acting as both:

- presentation layer
- domain workflow discovery layer

That creates back-and-forth because every domain change forces GUI rewrites, and every GUI experiment leaks into storage and tracker decisions.

What would have been better:

- Freeze a plain-Lua domain model first.
- Define plan editing operations as functions on that model.
- Make the GUI a thin adapter over those operations.

### 3. Blueprint linkage is a product of its own, not a side feature

The blueprint symlink / refresh problem is inherently tricky in Factorio because there is no perfect permanent identity for arbitrary player library blueprints. The architecture document already recognizes this, but the code still had to absorb a lot of change while discovering the exact boundary between:

- stored plan snapshot data
- live blueprint library lookup
- portable import/export representation

What would have been better:

- Treat blueprint linking as a separate bounded context from day one.
- Give it one explicit API:
  - `capture`
  - `refresh`
  - `export`
  - `import`
  - `diagnose`
- Keep the plan editor unaware of the raw blueprint-library mechanics.

### 4. Progress tracking is an accounting problem, not just an event-listening problem

The architecture correctly calls out uncertainty, destroyed inventories, and the difference between placed entities vs loose stock. That is the right direction. The difficulty is that once the tracker is framed as "listen to some events and infer the rest", the implementation tends to sprawl.

The hard part is not just collecting events. The hard part is preserving invariants:

- loose stock must not silently drift upward
- placed entities must stay distinct from stock
- uncertainty must be explicit, not hidden
- recovery behavior must be deterministic

What would have been better:

- Define the tracker first as a ledger with invariant checks.
- Treat every event handler as just a translator into ledger operations.
- Make "uncertain" a first-class state rather than an edge case.

### 5. `control.lua` became too important

`control.lua` is currently orchestrating initialization, GUI refresh behavior, auto-import, smoke-test flags, and event routing. None of those are individually unreasonable, but together they make the runtime entrypoint too central.

What would have been better:

- Keep `control.lua` as wiring only.
- Move each event family behind a named controller module:
  - `runtime/bootstrap.lua`
  - `runtime/gui_events.lua`
  - `runtime/plan_import.lua`
  - `runtime/progress_events.lua`

### 6. Performance fixes arrived after the structure had already hardened

Several commits were spent stopping unnecessary GUI rebuilds. That is normal in Factorio GUI work, but it also suggests the original refresh model was not constrained early enough.

What would have been better:

- Decide early which views are:
  - fully rebuildable
  - incrementally patchable
  - refresh-on-demand only
- For this project specifically:
  - split viewer should be cheap and frequent
  - plan editor should be explicit and mostly local-update

### 7. The architecture document was useful, but too much was still undecided while coding

`ARCHITECTURE.md` is directionally good, especially around semantics like `Constructed Blueprints`, `Extra Stock`, and `Completed Research`. The problem is that many critical operational details were still open while implementation was already underway.

What would have been better:

- Lock down a smaller "v1 contract" before broad implementation.
- Push speculative features into a later document section instead of into current code paths.

## A Better Rewrite Shape

If this project is restarted, the cleanest structure would probably be:

### 1. `domain/plan`

Owns:

- split definitions
- normalization
- migration
- plan editing operations
- import/export schema

This layer should know nothing about GUI widgets or Factorio events.

### 2. `domain/blueprint_links`

Owns:

- blueprint capture
- fingerprints / summaries
- refresh matching
- unresolved / ambiguous states

This layer should be the only place that touches blueprint-library lookup details.

### 3. `domain/progress`

Owns:

- the ledger
- stock vs placed accounting
- uncertainty state
- claim / reserve calculations for current and next split

This layer should expose pure operations and snapshots.

### 4. `runtime/`

Owns:

- event subscriptions
- turning Factorio events into domain operations
- save initialization
- migration hooks

### 5. `ui/`

Owns:

- split viewer
- plan editor
- dialogs

UI should consume domain snapshots and call domain operations. It should not own the business rules.

## Factorio 2.1 Experimental Status

As of **Wednesday, July 22, 2026**:

- the initial 2.1 experimental announcement was published on **June 26, 2026**
- the Factorio download page lists **2.1.12** as the latest experimental build
- the latest release thread is **2.1.12**, posted on **July 21, 2026**

Important practical note from the 2.1 experimental announcement:

- 2.0 saves load in 2.1, but designs can break
- save games and blueprints cannot be downgraded back to 2.0
- 2.1 is still being tuned before stable

## 2.1 API / Engine Changes Worth Using In The Next Version

### 1. Recipe-crafted prototype events are the most important new hook here

The single most relevant new hook for this project arrived in **2.1.12**:

- `RecipePrototype.raise_on_crafted`
- `LuaRecipePrototype.on_crafted_event`
- `ScriptTriggerEffectItem.custom_event`

This is not a generic built-in global `on_recipe_finished` event. It is an opt-in recipe-prototype event. For this mod, that matters because it opens a cleaner path for "recipe completion happened" style logic without relying entirely on polling or indirect statistics for every special case.

Potential uses in Long Pole:

- mark special crafted milestones directly
- detect completion of custom helper recipes if the rewrite introduces them
- reduce bespoke per-tick observation for recipe-specific triggers

Important caution:

- This helps when *you control the recipe prototypes involved*.
- It does not magically solve general stock accounting for every vanilla crafting machine outcome.

Related 2.1.12 scripting additions that may help tooling and diagnostics:

- `LuaBootstrap.get_event_name()`
- `LuaQualityPrototype.roll_quality()`
- `LuaPlayer.editor_settings`

### 2. Recipe categories changed materially in 2.1

In 2.1.7, Factorio reworked recipe categories and moved away from several combined categories in favor of multiple explicit categories per recipe.

Why this matters here:

- any recipe-resolution logic that assumes old category names can go stale
- planner logic should rely on current recipe prototype data, not hard-coded category assumptions

This especially matters for `util/recipe_resolver.lua` and any future "what can craft this?" logic.

### 3. Recipe and product API surface is richer

The 2.1 docs show several useful recipe-side additions, including:

- `LuaRecipePrototype.categories`
- `LuaRecipePrototype.get_product_amount(...)`
- `LuaRecipePrototype.get_product_quality(...)`
- `LuaRecipePrototype.get_ingredient_quality(...)`
- `RecipePrototype.can_set_quality`

Why this matters here:

- better quality-aware planning if the mod ever wants to support non-normal-quality runs or Space Age-specific planning
- cleaner recipe introspection instead of special-casing old assumptions

### 4. Fluid APIs changed heavily in 2.1.7

2.1.7 removed the old `LuaEntity::fluidbox` / `LuaFluidBox` path in favor of direct `LuaEntity` fluid methods and fluid-segment operations.

This matters if the tracker ever expands into:

- fluid-backed split requirements
- stronger accounting around machine / pipe / segment state

Even if that is not a near-term goal, any restart should avoid designing around the pre-2.1 fluid API shape.

### 5. 2.1.10 fixed a recipe-selection edge case involving product quality

2.1.10 fixed an assembler `set recipe` issue where item-signal selection could fail for recipes with product quality control.

That is probably not central to the current mod, but it is relevant if the rewrite ever leans harder on blueprint parametrization or circuit-driven helper flows during testing.

### 6. 2.1.11 changed passthrough-fluid crafting behavior

2.1.11 changed assembling machines with passthrough ports so they consider the entire fluid segment available for crafting.

That is more engine behavior than scripting API, but it can affect assumptions if any future progress heuristics start modeling machine readiness from fluid state.

## Recommended Direction For The Next Version

1. Keep the current repo as a reference implementation, not the foundation to endlessly reshape.
2. Start a rewrite only if you first freeze the boundaries between `plan`, `blueprint_links`, `progress`, `runtime`, and `ui`.
3. Build the next version in this order:
   - plan schema and migrations
   - minimal editor over that schema
   - blueprint linking
   - stock / placed ledger
   - prediction and long-pole ranking
4. Use newer coding models to accelerate implementation, but do not let the model invent architecture in the middle of coding. The module boundaries should be decided up front.
5. Explicitly target Factorio 2.1.x from the start rather than trying to preserve a 2.0 mental model.

## Sources

- Factorio Friday Facts #444 - 2.1 Experimental release: https://www.factorio.com/blog/post/fff-444
- Factorio experimental download page: https://www.factorio.com/download/experimental
- Factorio 2.1.7 release thread: https://forums.factorio.com/viewtopic.php?t=134095
- Factorio 2.1.9 release thread: https://forums.factorio.com/viewtopic.php?t=134604
- Factorio 2.1.10 release thread: https://forums.factorio.com/viewtopic.php?t=135008
- Factorio 2.1.11 release thread: https://forums.factorio.com/viewtopic.php?t=135041
- Factorio 2.1.12 release thread: https://forums.factorio.com/viewtopic.php?t=135201
- Latest prototype docs index: https://lua-api.factorio.com/latest/index-prototype.html
- `RecipePrototype` docs: https://lua-api.factorio.com/latest/prototypes/RecipePrototype.html
- `LuaRecipePrototype` docs: https://lua-api.factorio.com/latest/classes/LuaRecipePrototype.html
- Runtime events docs: https://lua-api.factorio.com/latest/events.html
