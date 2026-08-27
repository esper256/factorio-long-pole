# factorio-long-pole

A Factorio 2.1 experimental mod that helps speedrunners load a split plan and see what still has to happen before the next split.

Product rules for implementers: [`PRODUCT.md`](PRODUCT.md) (overrides [`ARCHITECTURE.md`](ARCHITECTURE.md) on conflict).

This tree is the **total rewrite**. There is no in-game plan editor. A plan is a blueprint book.

## Plan format

1. Put the splits in a blueprint book whose **label ends in `[LP]`**.
2. Each page is one split: a blueprint, a flat book of blueprints, or a planner. The page label is the split name.
3. Optional extra items and research go in that page's description:

```text
====== long-pole data-begin ======
# Comments and blank lines are ignored.
research automation
item coal 500
====== long-pole data-end ======
```

Put extra items on the split that **needs** them, usually the next one. While placing the current print, the factory should be making the next print plus that next split's extras. There is no separate harvesting HUD. Coal before a smelter print is `item coal 500` on the smelter split.

The first `[LP]` book in the **player** blueprint library auto-loads on a new run unless that setting is off.

Advance with **Shift+Period**, rewind with **Shift+Comma**. Navigation is never gated on predicted completion.

## Tests

Logic tests do not need Factorio. From the repo root, with Lua 5.2 or 5.4:

```bash
export LUA_PATH="./?.lua;./?/init.lua;;"
for test in tests/*.lua; do lua "$test" || exit 1; done
```

Each file under `tests/` is a standalone script.
