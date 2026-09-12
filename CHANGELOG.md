# Changelog

## 1.1.3

Note on numbering: the 1.1.1 fix was uploaded to Nexus as 1.1.2, so this build is 1.1.3 everywhere.

- **Dyeing now costs gold, not dye bowls.** A user pointed out that the game only ever gives you one of each dye bowl, so the bowl cost meant you could dye about once per playthrough. Station dyeing now charges a flat 1000 gold per equipment piece, however many colours or regions you change on it. The Confirm line shows pieces and total, and the confirmation dialogue repeats it. Settings: "station dyeing cost" (gold, dye bowls, or free) and "gold per equipment piece". Existing configs move to gold automatically.
- **Cooking can be cancelled.** Every page of the cookpot dialogue ends with a Cancel button. The native back button does nothing under that dialogue, so this is the way out. Cancel consumes nothing.
- **Performance.** The prompt-bar text hook sat on the game's message lookup, which the HUD calls for every string it draws, and allocated a managed string on each call whether or not a prompt was showing. It now does nothing unless a world prompt was requested in the last two seconds, and matches by raw memory compare. Thanks to Jarol for the per-mod idle-load measurements that pointed at it.
- **Fixed on 3.2:** the native world prompt (the game's own interact label at beds and stations) was silently disabled for every shipped user because the Guid parse returns nothing on Title Update 3.2. The build now mints the Guid directly.

## 1.1.1

- Removed three global hooks that 1.1.0 installed on the game's input queries and hold-interaction chain. They were left over from the keyboard bed-exit investigation and had no feature behind them once the real exit route was found. If 1.1.0 interfered with talking to NPCs or pawns on your setup, this is the build to try first.
- The mod never requires REFramework's Content Editor; it is safe to disable that if another mod installed it.

## 1.1.0

Title Update 3.2 release. Everything below is relative to 1.0.6.

### Compatibility

- Rebuilt every native call for Title Update 3.2: the removed Human.Fsm field, the new InnAwakeParam constructor, the reshaped interact registry, the 20-argument dialogue request, the GmInteractPickableBase tool hand-off and the prompt-panel paths.
- Fixed the in-bed spacebar hang and the post-teleport ghosting that 3.2 introduced.
- Player and prop transforms are only ever written from the engine's LateUpdate phase.

### New

- **Dye equipment.** Recolour worn armour and weapons at dye stations, per material group or by whole garment and whole weapon, with a live preview on a mannequin copy of your character, native confirmation dialogue, Wash Out, and a bowl cost per final colour. Dye profiles are saved and re-applied whenever the game rebuilds your equipment. Paragliders from Aurora's Paragliders can be dyed too when that mod is installed.
- **Temper weapons at anvils.** Forty-five seconds of work reveals a coordinated finish (Silver, Fulgin, Copper or Gold ore treatments) on a display copy of your main weapon, with a compare view, an ore cost charged only on completion and a 30-minute +5% weapon damage effect. Finishes persist. Works with every weapon family, including bows and staves.
- **Change vocation at weapon racks.** Approach a weapon rack or barrel in a town and open the game's own Vocation Guild screen. Sixty-one rack locations across fourteen areas are mapped; you can register more from the REFramework panel.
- **Throne.** The Audience Chamber throne can be sat on with the native seat.
- **Work rewards.** Forty-five seconds of active work grants the party the matching native camp-meal effect (food preparation, household, outdoors or trades), with a shared 60-second cooldown and no downgrade of an active meal. Progress and results show on a movable HUD. Carrying beams, log bundles or a bucket while moving counts as work, and standing still with the load pauses the timer instead of cancelling it.
- **Ending-animation notice.** An optional top-left note while an interaction winds down.
- **Tall stool lift.** A slider under Advanced lifts you onto bar-height stools through the game's own sit IK.

### Fixed

- Wooden beams and log bundles stay in your hands while you walk, run, strafe and sprint. The game's NPC carry chain no longer drops or returns them on stick input; L3 or your Drop key still puts them down.
- Keyboard Space gets you out of bed the same way pad A does, and Shift opens Rest.
- Non-home bed rest works again on 3.2.
- Town-cauldron cooking opens the native dialogue again.
- The chopping block at wood piles runs its full animation with the hatchet in hand.
- Held tools stay visible through the game's fade; the beam fade is cleared while carried.
- The tool keeper stands down during station sessions, which restores the anvil hammer and stops the dagger sticking to your hand.
- Sweep start order corrected for 3.2.
- Bow and staff users no longer see "No owned weapon mesh" on their first anvil visit; the display copy waits for its equipment instead of failing.
- First anvil visit no longer stalls on "Preparing weapon" for staff users; the dagger tool resources are preloaded.
- Performance: registry classification cached, seat lookups normalised once per scan, player and menu lookups and keyboard and pad reads memoised per frame, binding strings parsed once, carry-name resolution cached, dye lists snapshotted twice a second, world prompts throttled.
- A long-standing scene cache leak that polled destroyed animals every frame until the game crashed.

### Changed

- Prompts: the mod's own prompt bar stands down automatically when the IRIS prompt bar is present.
- Discovery uses a 16 m spatial grid with cached neighbours, 5 Hz proximity checks, movement-triggered rescans and cooperative one-millisecond batches, and pauses while loading, in native menus or while the dye UI owns input.
- Tool actions validate the exact live clip names before offering a prompt.
- The bucket is a haul prop: carrying it counts as household work. The game has no bucket-use animation, so the old "Use bucket" prompt is gone.
- Anvil upgrades through the native enhancement menu are disabled after native crashes; use the blacksmith. Tempering replaces the anvil's old generic meal reward.
- Dyeing grants no work reward.
- The gong was removed.

### Known issues

- A few workstations animate empty-handed by design.
- Rest from a home bed's own menu can decline on some beds; get up and use the bed's native prompt.
- Bar-height stools can still clip; use the tall stool lift slider under Advanced until a tuned default ships.

## 1.0.3 to 1.0.6

- Fixed the crash caused by using native campfire cooking while the mod was installed.
- Native keyboard binding detection; controller and keyboard prompts follow the player's current bindings, with optional fallback bindings for Use, Stop and Drop.
- Carried tools and scene props no longer drop when walking or running; explicit drop with L3 or the configured key.
- Native Sweep, Till and Pitch Hay actions for supported tools.
- Full lie-down and native rest for home beds; Morning and Nightfall choices for supported non-home beds; wake placement aligned to the bed.
- World-object discovery reworked into cached, bounded update slices.
- Fixed the frame-rate collapse in dense areas caused by per-frame scene sweeps.
- Fixed the missing anvil hammer and the dagger stuck to the hand after smithing.
- Fixed the workpiece flashing in mid-air on spawn.

## 1.0.2

- Fixed the camp-cooking CTD. Removed the global `InteractManager.cancelInteract` hook and excluded every native camp stew pot from the town-cauldron system.
- Removed unsafe manual retain/release calls on scene-owned GameObjects.
- Made disabled mode inert before any engine polling or drawing occurs.
- Added Brinebound-style DD2 action binding support and a Controls panel for keyboard fallbacks.
- Added L3 and configurable-key drop handling for both one-handed borrowed tools and native two-handed `ObjectCarry` props.
- Kept borrowed hand tools visible after their native loan expires, without disabling locomotion.
- Rest now hands off to `FacilityManager` while the lie-down remains active and uses a private wake parameter aimed at the current bed.
- House and inn beds retain their native rest UI and request the sleep animation when their interaction begins.
- Removed D2D usage. The only requirement is REFramework; the prompt-bar Lua is bundled.
