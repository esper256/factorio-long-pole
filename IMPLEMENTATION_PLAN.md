# Step 1 - Finalize the big design choices for components in ARCHITECTURE.md
# Step 2 - Finalize a layout of the project structure and component names.
    - Names are important, factorio_entity_util.lua would become a dumping ground of bad code, guaranteed.
# Step 3 - Create barebones skeleton files according to the layout from step 2, with just enough code to launch Factorio and have the mod load (but do nothing)
# Step 4 - Create the data objects, and basic mock data, a way to display the data textually during tests without having to launch the game
# Step 5 - Add a debug setting for the mod that when turned on, shows an extra panel displaying the tracked game state data directly (and not just the analysis of the split completion projection). Currently this will be mock data but it should show entities produced, consumed, placed, destroyed counts.
# Step 6 - Implement event listeners in an attempt to as accurately as possible track real data instead of mock data.
# Step 7 - Create a way to export real data from an actual factorio as loadable mock data for integration tests
