# Immersive Interactables

A Dragon's Dogma 2 mod that lets you live in the world the way NPCs do. Sit on any chair, work every workstation, sleep in real beds, and cook at any pot - all through the game's own interaction prompts and animations. Nothing is faked: when you knead dough you hold real dough, when you chop fish you use the station's own knife, when you sleep you really lie down.

## Features

- **Sit anywhere** - chairs, stools and benches all over the world become sittable, including ones the game reserved for NPCs.
- **Work anywhere** - around 30 kinds of workstation open up with their real animations and props: knead dough, work the forge, sweep, weave, chop wood, chop food at the cutting board, polish blades, dye cloth, tend fires and pots, and more. Press B again (or BACKSPACE) to stop; work animations finish their motion naturally.
- **Villager tools** - pick up loose brooms and pitchforks and actually use them. Carry a pitchfork to a haystack and pitch hay with it.
- **Sleep in beds** - real lie-down sleeping in inn and house beds. B gets you back up.
- **Cook at any pot** - town cauldrons and campfire pots serve a native cooking menu with the game's real camp meats. Cooking consumes the meat and grants the real party buffs.
- **Close-up camera** while working, using the game's own camera system.

## Requirements

- [REFramework](https://www.nexusmods.com/dragonsdogma2/mods/8) installed and working.

## Install

Drop the `reframework` folder from this mod into your Dragon's Dogma 2 game directory (the folder containing `DD2.exe`), merging with the existing `reframework` folder. Three files are added:

```
reframework/autorun/Interactables.lua
reframework/autorun/Interactables_PromptBar.lua
reframework/data/Interactables/catalog.json
```

## Use

Walk up to things. Prompts appear on chairs, workstations, beds, tools and cook pots the same way the game's own prompts do. B interacts; B again (or BACKSPACE) stops a looping work animation; BACKSPACE is also the emergency exit if anything ever feels stuck.

Settings live in the REFramework menu under **Immersive Interactables**. The Advanced section has camera and seat tuning plus a per-station list if you want to turn any single station off.

## Compatibility

- Plays nicely alongside the IRIS and Brinebound mod families - the prompt bar is shared, and their menus take priority where they overlap (for example the IRIS cook menu at cook pots).
- Does not touch saves, items or quests, with one exception: cooking consumes the meat you choose to cook, exactly like camp cooking does.

## Known issues

- Some seats vibrate slightly while sitting. Cosmetic; being investigated.
- A few workstations animate without a visible tool in one hand - that is how the game authored them (its own NPC smiths hammer empty-handed too).

## Credits

Made by Aurora, with Iris.
