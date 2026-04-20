# Architecture

## Purpose

This mod is intended to help people practice speedrunning **Factorio**.

The general use case is:

1. Design a speedrunning plan (often called a set of *splits*), e.g.
   - Mine one coal rock.
   - Place the starter burner mining drill and furnace.
   - Craft another burner mining drill and furnace and place them.
   - Mine 500+ coal from coal rocks.
   - Build a blueprint containing a boiler, steam engine, lab, and 10 red science packs.
2. Run the plan in-game.
3. Use the mod to identify which part of the current split is predicted to take the longest (the “long pole”).

Example: if the mod indicates **gear wheel assembly** is the long pole, the player should prioritize feeding iron plates into gear wheel assemblers before feeding electronic circuit assemblers.

## Core design philosophy

The mod maintains an internal tally of what the player has access to by registering for Factorio events that indicate items are:

- created
- consumed
- destroyed

This tally must account for items located across multiple places, including:

- the player’s inventory
- chests (e.g., buffer chests, logistics chests)
- items on transport belts
- machine inventories (e.g., assembling machines)

The internal tally is compared against the current split’s requirements to determine what is still missing. Combined with recent production rates, the mod estimates which requirement is most likely to be the long pole.

## Major mod components

The mod is split into two primary parts:

### 1) Split viewer (in-game display)

An in-game display in the **upper-left** corner showing a vertical stack of rows representing splits the player cares about.

Default behavior (configurable via settings):

- Previous split at the top
- Current in-progress split directly below
- A configurable number of upcoming splits below the current split

Each split should have the following columns:
- The name of the split (Power plant, On-patch burners, etc)
- The elapsed time compared to previous best timing on the split -3:02 would mean 3 minutes 2 seconds faster than previous record, +1:06 would mean one minute and six seconds slower than fastest attempt at the split
- A truncated list of items that need to be produced for the split to be complete sorted by how long they are predicted to take before completing. This list should include two virtual items (lab research production as well as entities placed as a heuristic for player bluprint build speed)
- On the current split only an extra column that is a button for completing the split and advancing to the next one. This one should turn green once the mod predicts all intended production, build and research objectives have been completed.

### 2) Plan editor (speedrun plan editor)

A large popup window (nearly full screen) for editing the list of splits.

Each split includes:

- a name
- a list of blueprints the player intends to build
- a list of additional items (beyond what the blueprints include)
- a list of technologies to research before proceeding to the next split

The editor also surfaces supporting information to help with planning decisions, such as:

- the raw resource cost of every entity combined in each blueprint
- the total entity count of each blueprint

Undecided: Many blueprints are staged in that they include items from the previous blueprint in addition to the new entities. There needs to be some way to not double count the old entitities that were already build in a previous blueprint.

## Engineering approach

- Ensure the mod works as designed and the GUI is intuitive.
- Maintain Factorio performance for bases typical of speedrunning (not megabases).
- Provide tests that validate the mod’s logic without requiring Factorio to be launched.