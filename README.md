# ForeverTools

**Quality-of-life tools for WoW: Forever — version 0.12.21.**

ForeverTools brings everyday interface adjustments and useful tools together in
one place. Customize the areas you want while keeping the Blizzard interface
where you prefer it.

Open the menu with **`/ft`** or the minimap icon. Use **`/rl`** to reload the UI.

## Features

- **Skins and dark mode:** Style supported action bars, unit frames, bags, buffs,
  micro menu, minimap, XP/reputation bars, and stance/totem bars. Apply a template
  to all supported areas or adjust each area separately.
- **Fonts and cooldowns:** Adjust supported fonts, sizes, outlines, and colors,
  including cooldown numbers. Quest text, quest objectives, and world
  damage/healing numbers are unmanaged by default.
- **Tooltips:** Customize text sizes, layout, position, and health-bar visibility.
  Show faction-colored guild names, optional faction icons, unit targets, buff
  sources when available, and optional spell IDs.
- **Macros:** Browse class, racial, and general templates; select ranks; add
  mouseover support; and create custom macros with spell and equipment actions.
  Newly learned active spells are added from your character's spellbook.
- **Personal buff reminders:** Track selected buffs, weapon enhancements, auras,
  and stances with talent-based defaults and saved choices for each talent tree.
  Customize the notice size, text color, and position.
- **Group buff reminders:** Optional notices for missing group buffs while grouped
  in supported instances. Notices dismiss after 30 seconds or with a left-click;
  right-click opens settings. Separate self and group previews help with placement.
- **Flight countdown:** Show the destination and estimated time until landing.
  Bundled Classic estimates cover known routes; completed flights teach new
  routes and replace bundled estimates with your own measurements.
- **Profiles:** Save named snapshots, switch profiles from page indicators, and
  export/import settings as text strings. Custom macro entries are included.
- **Unit-frame colors:** Class coloring for supported player, target,
  target-of-target, focus, and focus-target frames. Party colors link to Blizzard
  Edit Mode settings.
- **Movable displays:** Position loot rolls, the FPS counter, tooltip anchor,
  buff reminders, and flight timer using their movement controls or previews.
- **Group-role helper:** Optionally set your role once when joining a group,
  based on your strongest talent tree. Manual changes remain respected; tied
  trees leave the role unchanged, and Feral offers a Tank/Damage choice.
- **Other controls:** Chat styling, supported custom mouse-wheel spell bindings,
  minimap controls, and a toggle for the game's Lua error display.
- **Combat-aware menus:** Settings and previews close during combat. Requesting
  the menu in combat queues it to open afterward.

## Install and update

1. Close WoW and extract the release so the addon is located at
   `Interface/AddOns/ForeverTools/ForeverTools.toc` inside the appropriate game
   installation.
2. When updating, replace the `ForeverTools` addon folder. Keep your `WTF` folder,
   which contains the game's saved settings.
3. Start WoW, enable ForeverTools in the AddOns list, and open `/ft`.

## Settings and profiles

- Changes apply immediately. Save a named profile to keep a reusable snapshot.
- Working settings and profiles are stored through WoW's SavedVariables system,
  which normally writes to disk on logout or reload.
- Export important profiles and keep the text somewhere outside WoW. Select the
  export text and press **Ctrl+C**; import it by pasting with **Ctrl+V**.
- A secondary copy inside the saved settings cannot recover profiles if the beta
  wipes the entire SavedVariables file. An external export provides that backup.

## Macro tips

- Use **New macro** to add a custom entry to Generic or your class list.
- For a combination macro, open **Macros → Generic → 1-shot combo**. Add learned
  spells, then use Advanced for equipment-slot or other supported lines.
- Choose **General** or **Character** as the destination before adding a macro.
  The game determines whether space is available.
- Macros still require your input and obey normal casting rules. Off-global-
  cooldown abilities may work alongside another spell; global-cooldown spells
  may require separate presses.
- The external Forever spell audit covers the available level 1–20 beta reference.
  Higher-level legacy templates remain, and learned-spell discovery supplements
  the catalogue. See [spell audit details](SPELL_AUDIT.md).

## Reminder and flight details

- Buff notices hide during combat, flights, death, and other unsupported player
  states. Group reminders stay quiet when solo or grouped in the open world.
- Optional low-rank alerts use learned ranks and trainer-confirmed upgrades.
  Visit a trainer to record available upgrades; unknown ranks are not flagged.
  Disable **Low-rank alerts** or enable **Ignore rank 1** for intentional use.
- Off-hand weapon-buff choices remain saved when using a two-hander, shield, or
  empty off-hand slot, without producing an unnecessary off-hand reminder.
- An unknown flight route displays **Learning route** on its first trip.
  Completed flights are recorded; interrupted trips are not saved as full-route
  measurements. Classic timings are estimates and may differ in Forever.

## Fonts, artwork, and third-party notices

- **Inter** is bundled under the SIL Open Font License 1.1. Its notice is in
  [Media/Fonts/Inter-LICENSE.txt](Media/Fonts/Inter-LICENSE.txt).
- **Expressway** is optional and is not bundled. Supply your own licensed `.ttf`
  or `.otf` copy in `Media/Fonts` and restart WoW.
- Classic flight-duration data comes from **InFlight** under the MIT license.
  The source revision and full notice are in
  [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- The FT medallion was generated for this project. See
  [ARTWORK.md](ARTWORK.md) for its provenance and
  [DISTRIBUTION.md](DISTRIBUTION.md) for distribution notes.
- Native WoW icons are referenced from the installed game; their image files
  are not bundled. Third-party components retain their respective licenses.

## Beta limitations

- Restricted or unavailable unit data may prevent tooltip enhancements, buff
  source names, or reminder checks. Native tooltip content is preserved where
  required by the client.
- Custom wheel casting is unavailable on clients missing the secure compiler
  required for those bindings.
- Some fonts, frame skins, and protected-frame positioning depend on the client
  build and require in-game verification. Hiding Lua errors does not fix errors
  or suppress Blizzard's blocked-action warnings.
- Bank inventory browsing and bank item counts are not included.

ForeverTools is an unofficial addon and is not endorsed by Blizzard Entertainment.
Game names and referenced game assets belong to their respective owners.
