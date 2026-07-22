# Step 1 - Finalize the big design choices for components in ARCHITECTURE.md
# Step 2 - Finalize a layout of the project structure and component names.
    - Names are important, factorio_entity_util.lua would become a dumping ground of bad code, guaranteed.
# Step 3 - Create barebones skeleton files according to the layout from step 2, with just enough code to launch Factorio and have the mod load (but do nothing)
# Step 4 - Create the structure of the game_state data object, and a sample mock data of it, a way to display the data textually during tests without having to launch the game.
# Step 5 - Create a custom input that toggles a HUD debug panel displaying the first 8 rows of game_state (which is mock data for now)
# Step 6 - Implement event listeners in an attempt to as accurately as possible track real data instead of mock data.
# Step 7 - Create a design document that decides how persistent storage will be done and implement plan from book decoding.
# Step 8 - Create a basic game HUD showing previous split (if any) the game time when that split was marked done. The current split and the running gametime as it ticks forwards and the name of the next split (with no time yet until we implement personal best memory). If no speedrun is loaded this UI should not display. There should be a next button that scans forward in the library book to find the next [LP] book and replace the current plan with that one resetting the split to #1. UI should be a small as possible to remain beautiful and useable because Factorio screenspace is already limited with in game UI.
# Step 9 - Add a setting to auto-load the first eligible speedrun blueprint plan when starting a run.
# Step 10 - Show progress bars for entities produced and placed, and research packs produced and research completed. These progress bars should be Tri color, Grey - not done at all, Yellow produced but not consumed or placed, Green consumed or placed (and obviously produced.)