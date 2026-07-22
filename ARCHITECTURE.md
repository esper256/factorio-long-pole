# Architecture

## Purpose

This mod is intended to help people practice speedrunning **Factorio** version 2.1.12 including compatability with Space Age.

The general use case is:

1. Design a speedrunning plan (often called a set of *splits*), e.g.
   - Mine one coal rock.
   - Place the starter burner mining drill and furnace.
   - Craft another burner mining drill and furnace and place them.
   - Mine 500+ coal from coal rocks.
   - Build a blueprint containing a boiler, steam engine, lab.
   - Research Automation (requires 10 red science packs)
2. Start a new game and load the plan.
3. The Mod adds a small HUD to the game displaying what aspect of the current split is predicted to take the longest (the “long pole”).
4. While the GUI will have to be refined iteratively. It can help to imagine a starting point. 2 progress bars and a list.
   - One progress bar represents the factory construction speed. if X entitites need to be placed for the next expansion of the factory, that progress bar could be filled up to Y with one color that represents the number of these entitites that have been produced (and are therefor eligible to be placed) and another color Z, even smaller which represents the number of entities the player has placed.
   - One progress bar represents science research. A subset of the progress bar can be colored for the science packs that need to be produced out of the whole progress bar which is how many packs have been consumed on the way to the total goal.
   - A truncated list showing the worst offenders for what the holdup is on advancing to the next split (gear wheels, copper plate etc).

Hero moment: if the mod indicates **gear wheel assembly** is the long pole, the player should prioritize feeding iron plates into gear wheel assemblers before feeding electronic circuit assemblers. The player sees the lagging item start catching up. As they build their last furnace as part of this split, the press the hotkey to advance to the next split and are delighted to see that they are 15 seconds faster than their previous personal best. Next time they try, this will be the time for them to beat.

## Mod Design

The mod source code must be well organized into the following major components

1. The root essentials runtime layer as dictated by the Factorio mod API. These files (control.lua etc) should be as small as they can be. It should be organized in such a way to allow integration tests to act as the player causing events (gui events, quick actions activated) as well as the Factorio game itself by replaying recorded game state.
2. A data component that represents a speedrun plan
   - This will include a list of splits
   - Each split includes: a set of technologies that should be researched, a list of entities (assemblers, inserters, transport belts, etc) that should be placed in the world and their quantities, and a list of extra items that should be crafted or mined.
   - Splits might also include additional data such as record times the player has sped through the split, which is not really part of the split data but metadata saved to it. Keeping this cleanly separated will be good design.
   - It is anticipated that the player will have a key that will mark a split as completed and move to the next split. It might be a feature of the mod to eventually be able to automatically determine if a split is complete and advance and that should be left open as a possible future feature, but not 1.0
3. A data component that represents an inferred game state tracking progress in the speedrun, this will be important to create mocks for tests
   - The game needs to track items and entities produced, consumed, placed and destroyed. The delta between produced and consumed+placed+destroyed should be considered loose_stock. The loose stock might be in the player's inventory, hidden as ingredients in their crafting queue, inside assembler buildings ingredient slots, on transporter belts or in chests (and other places not listed such as space platforms, etc). It's not important for the data object to track where the item is, only to do a best effort not to lose track of it. It's possible that the ground truth source may come from infrequent access to the production statistics graph which doesn't update every tick. So it's possible for there to be some kind of reckoning which overwrites some assumptions on how many items have been produced or consumed so it is possible that numbers that shouldn't be able to go down, do.
   - The data component should not denormalize Factorio game data that is available from a perfect source of truth API (likely something like elapsed game time), however if possible, in the most canonical LUA way, it should provide an indirection to that data, so that a mock data for tests has everything that the GUI needs to read and display etc.
   - It might be an idea to add a sort of scientific error bar to the data because the Factorio API might not allow our mod to have exact numbers. But let's choose specificall not to do this. The data will include our best guess, and it will update if we have a mechanism to figure out we were wrong. Consumers of the data must be able to handle all changes to the data and not make assumptions about the data monotonically increasing etc.
   - The data model should error out on negative numbers. You cannot have negative buildings destroyed, or negative items produced. In the example of handcrafting 100 stone furnaces and then cancelling after 1 is produced should be seen as 5 stone consumed, 1 stone furnace produced. Not 100 stone consumed and then -95 stone consumed. This kind of thinking can be the north star for when considering what events to listen for and when to deduct or do accounting on our game state data object.
   - The data model should be flexible to handle frequent updates as well as large batch updates. Since this data will be potentially updated every tick PERFORMANCE is absolutely critical. Nothing should be done that will cause memory churn or be not performant.
   - Crafting TIME will be important to the mod, but should be calculated as needed and probably not stored in a data layer.
   - Power, pollution and other intangibles should not be tracked, but fluids should be tracked.
   - Objects produced should be able to come from all sources, handcrafting, mining and the result of recipes being finished by assemblers (and related structures). Picking up your own loose stock on belts or chests into player inventory should not count as production, however some hack might be necessary in order to count the original 8 iron plates (and some yellow ammo)that come with the crashed spaceship.
   - Objects consumed should more or less be ingredients consumed by recipes. This includes labs consuming science packs to create research
   - Objects placed is the sum of objects placed by the player or by construction bots
   - There will need to be a lot of code trying to keep this data model in sync with the game state, but the data model object should be isolated from this code. It should be very possible to play with different strategies to snoop on the game without messing with the data model, and the rest of the mod should only touch the data model and therefor churn on the event listening code shouldn't impact further in the code than it must
4. An in-game GUI HUD that sits in the upper left corner of the screen displaying progress
   - We know for sure that what is useful to show the player will have to come iteratively as humans test the mod. So we expect this GUI to change frequently and no part of the code should rely on the exact behavior of the GUI.
   - The GUI might want to do more than just the main thesis of the mod. For example later we might want to show how many handcrafted items the player has produced in order to get the Lazy Bastard achievement. We don't want these extra items to pollute the main data component of the game tracking progress though. That is the core interface that helps separate code from becoming unwieldy.
5. A few mod settings for how the player wants the mod to work, including a few quick actions (like advance to next split) that the player might want to bind to keys. This is all pretty standard stuff for a Factorio mod and I don't think will cause any code smell or pain to the architecture
6. A plan editor GUI. This will be the main pain point of coding the app as the Factorio mod GUI widgets are limited in ability and constructing these widgets is difficult for AI coders. This is one of places in the mod where performance is not paramount and code cleanliness, readability, correctness and being able to be changed without breaking is more important.
7. A storage engine designed to help data from the mod travel from one save where it is created under no time pressure, to a new save game where the player needs the data to load effortlessly as fast as possible.
   - It should sync to the player's Steam Cloud when the player saves and quits. As far as I know blueprints and blueprint books are the only real way to do this.
   - The storage engine should be able to list the available speedrun plans to the in-game speedrun GUI as well as suggest what the first plan is that could be auto-loaded.
8. A moduler set of event listeners (maybe called snoopers) that monitor Factorio's API and keep the data component tracking items produced, consumed and destroyed in the data object up to date.
9. A recipe resolver. In Space Age especially there are many recipes to create the same entity or item. When the mod needs to ask "how many seconds will it take to craft the remaining 200 gear wheels", it needs to handle the fact that multiple recipes exist. This will be in the hot loop inside of the game tick so it must be super performant.
   - The interfance for it should consider context when resolving recipes. At the very least that should include what surface (Nauvis, Vulcanus, space platform, etc) is being considered. It should also be free to return a blend of fractional recipes by weight. For example 20% basic oil processing 80% advanced oil processing.
   - It should be possible for there to be a different implementation resolving recipes used by the plan editor as vs the in-game HUD GUI. Perhaps the in game GUI HUD figures out which recipes are active and uses them automatically in the correct ratios.
   - This might be another class that changes frequently with iteration, so making the API expressive enough to handle future fluctuations will allow us to get started without having all the answers.
10. A client of the recipe resolver that will recursively backtrack over recipe ingredients to calculate raw costs of various items in the game (including crafting times).
11. Mock data objects that prevent the need for launching factorio to test our mod, some utility functions and methods meant to construct the mock data objects from human readable and editable files.
12. A progress-analysis and projection subsystem that looks at the game data, and the current split, and recipe-ambiguity resolving and does any computation on forecasting the data needed for the GUI. The GUI should perhaps not consume the raw game state data object but instead the output of this module.

## Engineering approach

- This architecture file should not be edited in commits with other changes to the source. If a change to fix a bug, or add a feature conflicts with information in this architecture file, work should stop on that feature and a single commit editing only this file should be prepared and approved in isolation first.
- Maintain Factorio performance so that the mod doesn't cause game performance to drop below 60 UPS.
- Provide tests that validate the mod’s logic without requiring Factorio to be launched.
- Avoid junior programmer idioms (functions like ensure_variable, or tons of nil testing to hide errors instead of solving them)
- Avoid change detector tests, only test important outcomes, only some logic heavy functions (for example recipe resolving) deserve unit tests, in general we prefer larger integration tests.
- Make sure we can create mock data, mock scenarios, and mock sequences of events that are as terse and human readable as possible to use in integration tests that a human can verify.
- Versioning and migration of speedrun plans in the storage engine will be important, but not until we hit a reasonable 0.1 alpha version. Until then it will just cause unnecessary work.

## Non-goals

- Doesn't need to support multiple forces or PvP