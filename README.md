# factorio-long-pole

A small Factorio Mod to assist speedrunners in creating plans and tracking how well they are progressing towards the next split in their plan.

## Tests

Unit tests:

```bash
busted tests/split_tracker_spec.lua
```

GUI smoke test:

```bash
FACTORIO_BIN=/path/to/factorio tests/gui_smoke_test.sh
```

The GUI smoke test launches a real Factorio client against an isolated temporary user-data directory, creates a fresh save, and loads it for one tick so GUI event wiring is exercised. This is meant to catch engine-level GUI API mistakes that plain Lua tests will not see.

It requires a client-capable `factorio` binary. A dedicated headless server is not sufficient for GUI coverage because `player.gui` code does not execute there.
