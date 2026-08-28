# Immersive Interactables

A Dragon's Dogma 2 mod that lets you live in the world the way NPCs do. Sit on any chair, work every workstation, sleep in real beds, and cook at any pot - all through the game's own interaction prompts and animations. Nothing is faked: when you knead dough you hold real dough, when you chop fish you use the station's own knife, when you sleep you really lie down.

## Features

- **Sit anywhere** - chairs, stools and benches all over the world become sittable, including ones the game reserved for NPCs.
- **Work anywhere** - around 30 kinds of workstation open up with their real animations and props: knead dough, work the forge, sweep, weave, chop wood, chop food at the cutting board, polish blades, dye cloth, tend fires and pots, and more. Press Interact again (or your Stop key) to finish naturally.
- **Carry villager tools and scene props** - loose brooms, buckets, pitchforks, hatchets, logs and beams can stay with you when you move. Native carrying is preserved where the game provides it; hand tools use a persistent visual fallback if the original loan expires. L3 or the configured Drop key puts an object down.
- **Sleep and actually rest** - lie down in supported beds and choose Morning or Nightfall without the mod aborting the sleep animation first. Wake positions are built from the bed's current transform, so placed beds do not send you back to their prefab's original location. House and inn beds retain their native rest flow and now request the lie-down animation as it opens.
- **Cook at town cauldrons** - choose from the camp meats in your party inventory; cooking consumes one and applies its real party buff. Native campfire cooking is deliberately untouched.
- **Close-up camera** while working, using the game's own camera system.
- **Rebind-aware controls** - by default, Interact follows the player's current DD2 keyboard/controller binding, as in Brinebound. The Controls panel also lets you capture custom keyboard fallbacks for Use, Stop and Drop.

## Requirements

- [REFramework](https://www.nexusmods.com/dragonsdogma2/mods/8) installed and working.

## Install

**Fluffy Mod Manager (recommended):** install `Immersive_Interactables_v1.0.2_FluffyMod.zip` like any other mod.

**Manual:** drop the `reframework` folder from this mod into your Dragon's Dogma 2 game directory (the folder containing `DD2.exe`), merging with the existing `reframework` folder. Three files are added:

```
reframework/autorun/Interactables.lua
reframework/autorun/Interactables_PromptBar.lua
reframework/data/Interactables/catalog.json
```

## Use

Walk up to things. Prompts appear on chairs, workstations, beds, tools and town cook pots in the game's own prompt area. Your current DD2 Interact binding uses them. Interact again or the configured Stop key ends a looping action. L3 or the configured Drop key puts down a carried object.

Settings live in the REFramework menu under **Immersive Interactables**. The **Controls** section follows DD2's current Interact binding automatically and can capture custom keyboard keys. The Advanced section contains camera and seat tuning plus a per-station list.

## Compatibility

- Has no code prerequisite beyond REFramework. `Interactables_PromptBar.lua` is included in the archive; D2D and other IRIS/Brinebound Lua files are not required.
- Can share its prompt bar with IRIS-family mods when they are installed, but does not depend on them.
- Does not touch saves, items or quests, with one exception: cooking consumes the meat you choose to cook, exactly like camp cooking does.

## Known issues

- Some seats vibrate slightly while sitting. Cosmetic; being investigated.
- A few workstations animate without a visible tool in one hand - that is how the game authored them (its own NPC smiths hammer empty-handed too).
- The persistent fallback for a one-handed tool keeps the object in hand but cannot invent a locomotion pose the game did not author for that tool.

## Credits

Made by Aurora, with Iris.
