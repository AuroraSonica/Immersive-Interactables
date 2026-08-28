# Changelog

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
