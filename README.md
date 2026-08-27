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

The first `[LP]` book in the **player** blueprint library auto-loads on a new run unless that setting is off.

## Tests

Logic tests do not need Factorio. From the repo root, with Lua 5.2 or 5.4:

```bash
lua tests/blueprint_book_plan_loader.lua
lua tests/construction_progress.lua
lua tests/split_completion.lua
```

Each file under `tests/` is a standalone script.
