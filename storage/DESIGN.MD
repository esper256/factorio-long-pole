Each speedrun plan should encode to a blueprint book,
Inside each book is a sequence of blueprints, each blueprint represents a split.
Each blueprint label is the name of the split.
The order of the blueprints inside of the book is the order of the splits.
The contents of the blueprint are the entities that the player should place when running that split.

There's some extra data that would be good to store with each speedrun plan split, such as if you want to have 500 coal ready. Or which technologies should be researched. This extra data should be put in the description of the blueprint in some kind of ====== long-pole data-begin ====== section with a known format.

The mod owns only the text between these exact markers; all other description text remains human notes. Blank lines and lines starting with # are comments. The initial directives are:

    ====== long-pole data-begin ======
    research automation
    item iron-plate 8
    item coal 500
    ====== long-pole data-end ======

Repeated item directives add together. A description with no long-pole data block is valid and means that split has no extra metadata.

We can avoid having to write a GUI to edit the speedrun plan as late as possible and instead have just a template that you copy and paste into the description with a bunch of commented out lines that show you what the format of the different parameters are and how they are specified.

The blueprint already specifies what entities to build. So we just need what technologies to research and a list of extra items to have ready.

For storage of things such as personal bests. We can have a singleton blueprint with a fake entity inside that we set tags on. And when you finish a run you can press a quick action that updates the data, regenerates a new blueprint that the user is expected to put in their My Library book and delete the old one. This is a hack but there's not a better way.

The mod should have a setting (auto-load first speedrun plan in library on game start), it should default to true.

If the blueprint book label ends in [LP] (long pole) then it is treated as a plan. It shouldn't be hard to scan every book in Blueprint Library for each book at the top level without descending into nested hierarchies.
