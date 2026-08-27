Each speedrun plan should encode to a blueprint book,
Inside each book is a sequence of split entries. Each entry is either a blueprint or a flat blueprint book, and its label is the name of the split. The order of the entries inside of the plan book is the order of the splits. A blueprint entry contains the entities that the player should place for that split. On import, each entity is normalized to its placement item and item count, so entity variants such as curved and straight rails become one `rail` requirement. A split-book sums those placement-item requirements in each of its direct child blueprints; nested books are not allowed.

There's some extra data that would be good to store with each speedrun plan split, such as if you want to have 500 coal ready. Or which technologies should be researched. This extra data should be put in the description of the split entry (the outer book when the split is a book) in some kind of ====== long-pole data-begin ====== section with a known format.

The mod owns only the text between these exact markers; all other description text remains human notes. Blank lines and lines starting with # are comments. The initial directives are:

    ====== long-pole data-begin ======
    research automation
    item iron-plate 8
    item coal 500
    ====== long-pole data-end ======

Repeated item directives add together. A description with no long-pole data block is valid and means that split has no extra metadata.

We can avoid having to write a GUI to edit the speedrun plan as late as possible and instead have just a template that you copy and paste into the description with a bunch of commented out lines that show you what the format of the different parameters are and how they are specified.

The blueprint already specifies what placement items are needed to build it. Extra `item` lines are more items to **have** for that split (map-seed belts, coal before smelting, etc.). Put them on the split that needs them, typically the one you are producing toward while placing the previous print. They are not a separate harvesting HUD. Patch ore (hand or miners) is read from production statistics, not from mining events. `research` names technologies whose lab consumption belongs to that split.

For storage of things such as personal bests. We can have a singleton blueprint with a fake entity inside that we set tags on. And when you finish a run you can press a quick action that updates the data, regenerates a new blueprint that the user is expected to put in their My Library book and delete the old one. This is a hack but there's not a better way.

The mod should have a setting (auto-load first speedrun plan in library on game start), it should default to true.

If the blueprint book label ends in [LP] (long pole) then it is treated as a plan. It shouldn't be hard to scan every book in Blueprint Library for each book at the top level without descending into nested hierarchies.
