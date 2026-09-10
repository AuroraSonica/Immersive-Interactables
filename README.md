# Immersive Interactables

A Dragon's Dogma 2 mod that lets you live in the world the way NPCs do. Sit on any chair, work every workstation, sleep in real beds, dye your gear, temper your weapon, change vocation at a weapon rack and cook at any pot - all through the game's own interaction prompts and animations. Nothing is faked: when you knead dough you hold real dough, when you chop fish you use the station's own knife, when you sleep you really lie down.

Built for Title Update 3.2.

## Features

- **Sit anywhere** - chairs, stools, benches and the Audience Chamber throne become sittable, including seats the game reserved for NPCs. Bar-height stools have their own lift slider.
- **Work anywhere** - around 30 kinds of workstation open up with their real animations and props: knead dough, work the forge, sweep, weave, chop wood, chop food, polish blades, tend fires and pots, and more. Press Interact again (or your Stop key) to finish naturally.
- **Work rewards** - 45 seconds of active work grants the party the matching camp-meal effect. Hauling beams, log bundles or a bucket counts while you move; standing still pauses the timer.
- **Carry villager tools and scene props** - loose brooms, buckets, pitchforks, hatchets, log bundles and wooden beams stay with you while walking and running. L3 or the configured Drop key puts an object down.
- **Use working tools** - brooms Sweep, hoes Till, pitchforks Pitch Hay, and the hatchet works the chopping block.
- **Dye equipment** - recolour worn armour and weapons at dye stations, per material group or whole garment, with a live preview on your own character and a native confirmation. Dyes persist and re-apply whenever the game rebuilds your gear. Paragliders from Aurora's Paragliders can be dyed too.
- **Temper weapons** - 45 seconds at an anvil reveals a Silver, Fulgin, Copper or Gold ore finish on a display copy of your main weapon, charged only on completion, with a 30-minute weapon damage bonus. Finishes persist.
- **Change vocation at weapon racks** - approach a town weapon rack or barrel and open the game's own Vocation Guild screen. You can register more racks from the REFramework panel.
- **Sleep and actually rest** - lie down in supported beds; A or Space gets up, B or Shift opens Rest. Home beds keep their full native rest flow; optional non-home rest uses the same native menu.
- **Cook at town cauldrons** - choose from the camp meats in your party inventory; cooking consumes one and applies its real party buff. Native campfire cooking is untouched.
- **Close-up camera** while working, using the game's own camera system.
- **Rebind-aware controls** - Interact follows your current DD2 binding; the Controls panel captures custom keyboard fallbacks for Use, Stop and Drop.

## Requirements

- [REFramework](https://www.nexusmods.com/dragonsdogma2/mods/8) installed and working.

## Install

**Fluffy Mod Manager (recommended):** install `Immersive_Interactables_v1.1.0_FluffyMod.zip` like any other mod.

**Manual:** drop the `reframework` folder from this mod into your Dragon's Dogma 2 game directory (the folder containing `DD2.exe`), merging with the existing `reframework` folder. The mod adds `Interactables.lua`, `InteractablesDye.lua`, `Interactables_PromptBar.lua`, `II.VocationWarmEntry32.lua`, the `II` module folder under `reframework/autorun`, and `reframework/data/Interactables/catalog.json`.

## Use

Walk up to things. Prompts appear on chairs, workstations, beds, tools, racks, anvils, dye stations and town cook pots in the game's own prompt area. Interact again or your Stop key ends a looping action. L3 or the configured Drop key puts down a carried object.

Settings live in the REFramework menu under **Immersive Interactables**. The Advanced section has camera and seat tuning, the tall stool lift, rest options, work-reward options and a per-station list.

## Compatibility

- Has no code prerequisite beyond REFramework. The prompt bar is bundled; IRIS and Brinebound are not required, and the mod shares its prompt bar with them when they are present.
- Does not touch saves or quests. Cooking consumes the meat you choose, dyeing consumes dye bowls, tempering consumes one ore on completion.

## Known issues

- The dye preview is your own character; there is no separate mannequin.
- A few workstations animate empty-handed - that is how the game authored them.
- Rest from a home bed's own menu can decline on some beds; get up and use the bed's native prompt.
- Bar-height stools can still clip; use the tall stool lift slider under Advanced until a tuned default ships.

## Credits

Made by Aurora, with Iris.
