# Product rules

Canonical product decisions for agents. If this file conflicts with `ARCHITECTURE.md` or comments, **this file wins**. Numbers match the 2026-08-27 clarification round.

Target **Factorio 2.1 experimental** (API 2.1.17 as of 2026-08-26). Keep the data model able to grow into Space Age, but do not build SA-only surfaces, quality, spoilage, or platforms as first-class split features yet. Cheap 2.1 compatibility (library `LuaRecord`, quality-summed production stats, space-platform build events) is fine.

This is a **single-player** practice mod. Do not design around multiplayer. Harmless MP survival is fine if it is cheap.

**Plan authoring is a blueprint book, not a custom editor.** Label the book so it ends in `[LP]`. Each page is a split (a blueprint, a flat book of blueprints, or a planner). Extra items and research go in the page description between `====== long-pole data-begin ======` / `====== long-pole data-end ======`. Do not add a plan-editor GUI.

## In scope

**1. Long pole.** The long pole is not a single named station. It is the **ordering** of everything that still has to happen before the run can advance. Sort by **anticipated arrival time**. The item predicted to arrive last *is* the long pole.

**2. ETA.** Every craft counts (hand and machine). Prefer recent crafting/production rates. To keep zero-rate items sortable, each item’s finish time assumes the player is also **handcrafting that item nonstop** on top of the observed factory rate. That avoids a pile of equal infinities. On the HUD: if the factory (or labs) has a known rate, show that ETA; if the rate is zero, show remaining count. Sort by ETA either way, longest pole first.

**3. What to show (starting rule; still tunable).** Prefer the **limiting ingredient**, not the unfinished finished good, when an intermediate is the real blocker. That applies to current-split construction shortfalls and next-split production.

Loose stock is spent **once** across every requirement on the split. Extra `copper-ore`, a lab, and 10 red packs cannot each claim the same 15 ore.

Example: next split needs 1000 belts. Plates exist, gears do not. Show **gears**, not belts. Placing gear assemblers produces more. Placing belt assemblers with no gears produces nothing. If plates are also missing, show plates. Walk the chain toward root ingredients and surface the ones that are actually blocking.

**4. Which recipe.** Recipe choice will stay contentious. The **selection heuristic must be a replaceable module** with a stable input/output API so approaches can change without thrashing callers. First playthrough stab: blend **observed recipe ratios** when several recipes make the same product (e.g. 50% basic oil + 50% advanced oil). The Factorio API may not expose this cleanly; that is a known risk, not a reason to hard-code one recipe tree into `progress_analysis`.

**5. Research.** The last item in a research goal is **labs consuming packs into science**, not packs sitting in chests and not “tech researched” as an invisible flag. The HUD should make **lab throughput** visible so the player can tell they are lab-limited (more labs, lab research speed).

**6. Split navigation.** The player may go **forward or back at any time**, including after a mistake and including when the current split is not “ready.” Bind this to shortcut keys. Do not gate advance on predicted completion.

**8. HUD rows.** Show **one previous split**, the **current** split, and upcoming splits. Older than previous is clutter. The previous row is the yardstick (“am I a minute ahead of where I usually am at this point?”). The current split cannot be that yardstick because this attempt has no finish time yet.

**10. Placement matching.** Assume the player is building the linked blueprint. Count by item/entity type. Do not attempt layout, ghost, tile, module, or recipe-on-entity matching.

**11. Production vs placement.** During a split the player **places** the current blueprint. The factory (and handcrafting) should be **making** the next split’s placement items. Production and loose stock are the real signal for that next-split work. Placed entities on the current print are a bonus / confirmation signal. If placement claims drift, the player advances or rewinds manually.

**12. Extra Stock.** Put extras on the split that will **need** them, usually the next one. They add to that split’s production demand alongside its blueprint (`10` belts in the print + `10` extra = `20` belts to have). They cover map-seed-dependent bits that cannot be blueprinted exactly. There is **no** separate harvesting goal or extra-item HUD bar. Coal to mine before the smelter split is `item coal 500` on the smelter split, not a harvest mini-game on the current one.

**14. Loose stock.** Heuristic is acceptable. Loose stock is everything **produced, mined, harvested, or started with** that has not been **placed, consumed, spoiled, or destroyed**. Do not chase a perfect world inventory census.

Ore from patches (hand-mined or by mining drills) is **only** whatever Factorio puts on the production graph. Do not snoop `on_player_mined_item` / resource-entity mining for those items — that double-counts against the graph. Trees, rocks, and wreck loot are not on that graph; those stay harvested from entity events.

**17. Starting items.** Chest withdrawal is not production. Crash-site wreck loot (the player grabbing starter iron plates, etc.) must be **special-cased** so those items enter loose stock once. Detecting the actual starter set from the API is desirable if it is possible; a vanilla table is an acceptable v1 if detection is not.

**18. Import.** Importing a plan **always replaces** the save’s active plan. No confirm, no merge.

**20. Auto-import.** Search the **player blueprint library** only. Game/shared blueprint libraries are a multiplayer feature; speedruns almost never use them.

## Deferred — do not implement until revived

**7. Personal-best split deltas** (`−3:02` / `+1:06` vs a stored record). Blocked on Factorio Mod API / where to persist PBs. Current attempt elapsed time on the stopwatch is enough for now.

**9. Staged / overlapping blueprints** (later prints that include earlier entities). Assume **non-overlapping** prints. Do not subtract previous splits’ entities.

**13. `Refresh Linked Blueprints` matching pipeline** (exact / unique-name / fuzzy, resolution badges). Unclear product. The plan *is* the `[LP]` book; do not add a second link-refresh workflow.

**15–16. Space Age play.** Quality, spoilage, platforms, other planets as first-class split surfaces. Keep the per-surface ledger so this can land later. Ship vanilla first.

**19. `visibility=` / copied vs reference plan export.** Unexplained. The `[LP]` library book is the plan. Do not add a second export mode.

**21. HUD polish.** The gameplay HUD is a **tight left-side flow** (about 192px, 8px icons, no frame padding). Do not add a framed panel, split-row clocks, or 20px icon chrome — that hides map and fits fewer shortfalls. Still open: how many upcoming splits, and whether Complete is a separate green button vs the stopwatch. Do not add extra chrome beyond previous / current / next.

## Non-goals for architecture

- Co-op / per-player plans / per-force UX beyond “don’t crash if a second player exists.”
- Perfect loose-stock reconciliation scans.
- A separate harvesting / extra-item HUD bar.
- Treating Extra Stock as demand on the *current* print. Extras belong on the split that needs the items (typically the next one).
- Snooping hand-mined ore patches. Production statistics already include hand mining and mining drills.
- Baking a single oil/recycling/Kovarex recipe policy into requirement expansion.
