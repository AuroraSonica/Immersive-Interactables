# Immersive Interactables — working handover

Last updated: 2026-08-28. Written so another session can pick this up cold.

Mod by Aurora, with Iris. Public repo: `github.com/AuroraSonica/Immersive-Interactables`.
Local repo: `C:\Users\Krist\Immersive-Interactables`.
**The live file is the source of truth**: `D:\SteamLibrary\steamapps\common\Dragons Dogma 2\reframework\autorun\Interactables.lua`.
The repo is hand-synced from it (copy the file in, commit, push). There is no sync script.

---

## 1. What the mod is

A REFramework Lua mod that lets the player use the things the game reserves for NPCs —
chairs, workstations, beds, cook pots, loose tools — through **the game's own prompts and
animations**. Nothing is hand-animated or faked. The guiding rule (Aurora's) is
"fully native": if the engine won't do it properly, we don't ship a fake version of it.

### Ships three files
```
reframework/autorun/Interactables.lua          the mod
reframework/autorun/Interactables_PromptBar.lua  renamed copy of IrisPromptBar
reframework/data/Interactables/catalog.json    REQUIRED runtime data (prefab catalog)
```
Fluffy package is built into `packages/`. Build recipe: stage `modinfo.ini` + the
`reframework` tree in a temp folder, then .NET `ZipFile.CreateFromDirectory`.

---

## 2. How it works (architecture)

### The core trick: CharacterType unlock
Every interactable in DD2 has interact points with a `CharacterType` field. Points meant
for NPCs exclude the player. The mod **adds 1 to CharacterType** on nearby points, which
makes the game itself offer its own native prompt to the player. On exit the original
value is written back. Everything else is bookkeeping around that one idea.

- `unlocks[]` — every point we changed, with its original CharacterType and IconType.
- `_unlock_kind(key)` decides what a prefab counts as: `seat`, `bed`, `station`, `chore`.
  Order matters: `CARRY_KEYS` → `STATIONS` → chores (`^gm50_`) → beds.
- `_restore_unlocks(kind)` puts them back. Called on disable, script reset, session end.

### Main tables
| Table | Purpose |
|---|---|
| `STATIONS` | ~30 workstation prefabs → label, motion bank/path, `conjure`, `pin` |
| `BED_KEYS` | bed prefabs (gm51_092, gm51_299 double, gm51_100, gm51_115_01, …) |
| `SIT_KEYS` | bench/stool family (gm51_074 bench, gm50_070 stool) |
| `CARRY_KEYS` | props you carry, not work at (gm51_046 "Wooden beams") |
| `TOOLS` | hand tools with their own verb + clips (currently just the broom, gm50_007 → Sweep) |
| `TL.eqid` | 57 equip-item ids → `it*` names (id 46 = broom, 47 = bucket, 41 = pitchfork, 50 = hatchet) |
| `MC_POTS` | cook pots our menu appears at (town only) |

### Per-frame flow (`re.on_frame`)
`_publish` → master gate → cache player address → drain hook flags → `_tick` (seats)
→ `_unlock_tick` → `_native_session_tick` → `_st_frame` (station sessions) → `_br_tick`
(bed rest menu) → `_tl_frame` (hand tools) → `_carry_tick` → `_bed_probe_tick`
→ `_registry_tick` → `_mc_frame` (cooking) → `_pin_frame` (anvil workpiece).

`re.on_application_entry("UpdateBehavior")` handles prefab building (`_carry_build`, the
anvil `PIN` loader) — engine object work belongs on the game thread.

### Subsystems
- **`_registry_tick` (2.5s)** — walks `InteractManager.InteractiveObjectUpdaters[].InteractiveObjectList`,
  the complete engine registry. Feeds beds/seats to the patcher and detects cook pots.
  Reads are safe. **Bed/seat feeding must match RAW prefab names**, never `_norm`
  (see laws).
- **`_st_frame`** — owns a "work session": detects the native interaction, shows a Stop
  prompt, drives the close-up camera, conjures station props, releases on B/BACKSPACE.
- **`_tl_frame`** — hand tools. Mounts the motion bank, plays start/loop/finish clips
  with the FSM disabled, restores it on stop.
- **`MC` (mini cook)** — prompt at a pot → native dialog listing camp meats you own →
  `ItemManager.deleteItem` → `SpecialBuffManager.startBuff` per party member → toast +
  a short stir animation.
- **`CARRY`** — keeps a villager tool in hand after the game takes it back (see §4).
- **`PIN`** — spawns the smithing workpiece and parents it to the hand.
- **`BR`** — the bed "Rest until…" menu.

---

## 3. Hard-won laws (breaking these crashes or wastes days)

1. **⛔ Never do work inside an `sdk.hook` pre-body.** The old `cancelInteract`
   interceptor called back into `InteractManager` (the manager it was inside), plus FSM
   and file logging. Result: two null-read access violations in generated-stub space
   (`0x1449FAC23`, `0x1449FAA95`) and reports of crashes when cooking at camps. Hook
   bodies may do cheap reads and set a flag; the next frame does the real work.
2. **⛔ Do not hook the equip-item / gimmick-holder subsystem at all.** A log-only hook
   there previously crashed vanilla camp cooking. `app.GuiManager`,
   `app.EquipItemController`, `app.GimmickHolder` are all off limits. Calls are fine.
3. **⛔ A "disabled" switch that only gates `on_frame` does not disable an installed
   hook.** Hooks cannot be removed at runtime — only a full game restart clears them.
4. **⛔ `EquipItemCtrl.requestExternal` only bookkeeps outside an animation.** The slot
   reports `active/draw/created = true` while no object exists. Props are actually built
   by an animation's equip track. To put an item in the player's hand in free roam,
   spawn the prefab and parent it (see §4).
5. **⛔ Space law.** `getInteractPointPosition` returns UNIVERSAL space; transforms have
   both. Comparing the wrong pair gives phantom ~1km offsets. Same trap wrote wake
   positions in render space and dropped the player in the sea.
6. **⛔ `_norm()` returns nil for catalog-invisible prefabs** — engine-registry pipelines
   must raw-match names.
7. **⛔ Pad bit aliases are not trustworthy.** `l3 = 0x1000` reads as pressed during
   ordinary play and silently dropped every carried tool. Only `circle` is field-proven.
8. **⛔ Never open the shared dialog while a rest flow is running**, and always check
   `GuiManager:IsLoadGuiType(14)` before `reqDisp` — an unloaded GUI is a hard crash.
9. **⚠ Read the log before theorising.** Twice, "the tool didn't work" actually meant
   "it spawned correctly and something else threw it away one second later".

---

## 4. Feature status

### Working (field-confirmed)
- Sit on chairs, stools, benches (incl. NPC-only ones).
- ~30 workstations with real animations and props; B stops.
- Sleep animation in beds; instant B exit.
- Cook at town pots: menu, consumes the meat, buffs the **whole party** (fixed 2026-08-28).
- Broom: pick up, keep it in hand, sweep with it.
- Smithing workpiece (sword) parented to the hand with tuned grip.
- Close-up work camera.

### Broken / unfinished
| Thing | State |
|---|---|
| Camp cooking CTD | Cause identified (hook re-entrancy, §3.1). Hook now off by default. **Needs a full-restart retest.** |
| Beds "not interactable" for users | **Cause found**: `native_beds`/`native_chores` shipped defaulting to `false`. Now `true` + cfg_rev 6 migration. Untested. |
| Carrying bucket/hatchet/logs | Spawns correctly, then was dropped by the bad `l3` bind. Fixed to BACKSPACE-only; **untested**. |
| Carry *pose* (two-armed log carry) | Not implemented. Native pose dies with the loan. Would need driving carry locomotion clips like `_tl_play` does for sweep. |
| Bed "Rest until…" | Menu works; sleeping only fires on beds with their own `InnParam`. "Any bed" mode borrows another bed's settings — **destructive**, defaulted OFF. |
| Seat vibration | Known cosmetic issue. Colliders exonerated. Root-motion family; unhunted. |
| Hatchet vs log stand | Holding an axe does not change the stand's native verb ("gather"). Not a grip issue. |

### Deliberately not done
- **Cooking other ingredients** (fish/herbs/fruit): DD2's pot cooking is the camp-meal
  system, which is **eight item IDs hardcoded in the exe** with a compiled buff jump
  table. Fish and herbs belong to the crafting system, not cooking. Supporting them
  means inventing effects, i.e. faking gameplay.
- **Row injection into the game's own rest menu**: proven dead (RiftSpeak).

---

## 5. Key APIs discovered

```
app.GimmickHolder
  returnEquipItemOnNotInteracting(bool isDrop)   the game taking a lent tool back
  returnEquipItem(bool isDrop) / borrowEquipItem()
  Context.EquipItemID, HoldObjects, PickableObject   what is being held
app.Gm51_115            the ONLY bed gimmick class in the game (all bed prefabs)
  InnParam              nil on most beds; only real inn/house beds have one
  execSleep()           ANIMATION ONLY, does not sleep
app.FacilityManager.startInn(bool is_awake_morning, int cost, InnAwakeParam, …)
                        is_awake_morning is a BOOL - the engine models morning vs night only
app.GuiManager.Dialog (app.ui010101) + reqDisp(20 params) + getDialogState
                        RetVal: Sel0=1 Sel1=2 Sel2=3 Sel3=4 Cancel=5
app.ItemManager.getHaveNum / deleteItem(int,int,Character)
app.PawnManager.get_PartyPawnList   (index lst[i] first, get_Item(i) second)
```
Prefab spawn recipe (proven): `via.Prefab` + `.ctor()` + `set_Path("AppSystem/Equipment/eqit/<name>.pfb")`
+ `set_Standby(true)` → wait `get_Ready` → `instantiate(vec3)` → wait ~10 frames →
`setParent(playerTransform, true)` + `set_ParentJoint("R_PropA")`.

---

## 6. Next steps, in order

1. **Full game restart**, then cook at a camp. Confirms the hook was the crash.
2. Confirm beds now work on a fresh config (the `native_beds` default fix).
3. Confirm carried tools stay in hand now the drop bind is BACKSPACE-only.
4. Package and push **v1.0.2** — it carries the crash fix, the beds-off fix, the party
   buff fix, keyboard stop keys, vanilla meat names, and the beams recategorisation.
5. Then, as a feature: the **carry pose** (drive carry locomotion clips), which would
   also make per-tool grip offsets unnecessary.

## 7. Useful context files
- Live log: `reframework/data/Interactables.log` (enable via dev tools).
- Crash dumps: `reframework_crash.dmp` in the game folder — **preserve before retesting**,
  it is overwritten. Managed-code VA ceiling is `0x1449d9b90`; anything above that is
  generated/stub code and usually means a hook problem.
- Reference mods in `reframework/autorun/`: `IrisBedWake.lua` (inn params, coordinate
  space), `IrisWoodcutting.lua` (eqit prefab list), `IrisFarming.lua` (dialog recipe),
  `Brinebound.lua` (input, party enumeration).
