# ForeverTools

**Quality-of-life tools for WoW: Forever — version 0.13.6.**

ForeverTools brings everyday interface adjustments and useful tools together in
one place. Everything starts **off**, so the game looks like Blizzard's until you
choose otherwise. A short first-time setup offers Minimal, Dark mode and Full
presets, and new characters reuse your profile automatically.

Open the menu with **`/ft`** or the minimap button, and search any setting from
the home window. Use **`/rl`** to reload the UI.

## Features

- **Skins and dark mode:** Style action bars, buffs and debuffs, bags, micro
  menu, minimap, XP/reputation bars, stance and totem bars, gryphons and unit
  frames. Choose a preset for all areas or adjust each area separately, with
  border, fill and transparency controls and separate rare/elite switches.
- **Fonts and cooldowns:** Adjust supported fonts, sizes, outlines and colors,
  including cooldown numbers.
- **Unit-frame colors:** Class-colored health bars for player, target,
  target-of-target, focus and focus-target frames. Party colors link to
  Blizzard's Edit Mode settings.
- **Tooltips:** Text sizes, layout, position and health-bar visibility; guild
  names with optional faction icons, unit targets, buff sources and tooltip IDs.
- **Chat:** Show, hide or mouseover-reveal chat controls, change the chat font,
  and optional clickable links that open a copy box.
- **Macros:** Browse class, racial and general templates; select ranks; add
  mouseover support; and build custom macros with spell and equipment actions.
- **Buff reminders:** Self and group buff notices with talent-based choices,
  weapon enchants, low-rank alerts and an optional low-rank marker on action
  bars, with per-spell exceptions.
- **Leveling stats:** XP per hour, time to level, kills to level, XP progress and
  rested XP. Pick which to show and their order, one per line or on a single
  line; movable, and also added to the XP bar tooltip.
- **Flight countdown:** Destination and estimated time until landing. Completed
  flights teach new routes and replace bundled estimates.
- **Merchant helpers:** Optional auto-sell of grey items and auto-repair, with
  guild funds if allowed, and a one-line summary.
- **Minimap:** ForeverTools button, coordinates, and an optional launcher that
  groups other addons' minimap buttons into one menu.
- **Profiles:** Save named snapshots, switch from any page, export/import as text,
  and pick which profile new characters use.
- **More:** FPS counter, movable loot rolls, group-role helper, custom
  mouse-wheel casting on mouseover, a Lua-error toggle and a copyable bug report.
- **Combat-aware menus:** Settings close during combat; requesting the menu in
  combat opens it afterward.

## Install and update

1. Close WoW and extract the release so the addon is located at
   `Interface/AddOns/ForeverTools/ForeverTools.toc` inside the appropriate game
   installation.
2. When updating, replace the `ForeverTools` addon folder. Keep your `WTF` folder,
   which contains the game's saved settings.
3. Start WoW, enable ForeverTools in the AddOns list, and open `/ft`.

## Settings and profiles

- Changes apply immediately. Save a named profile to keep a reusable snapshot.
  **Create** starts a new profile from default settings and switches to it.
  **Default settings** resets the selected profile and returns everything
  ForeverTools changes to Blizzard's defaults, as if the addon was just installed.
- New characters automatically load the profile chosen under **Profiles → New
  characters** (by default, the last profile you used), without any setup.
- **System → General → Reset all settings** returns everything to the defaults
  (all off) and reloads. Saved profiles, custom macros and flight times are kept.
- Working settings and profiles are stored through WoW's SavedVariables system,
  which normally writes to disk on logout or reload.
- Export important profiles and keep the text somewhere outside WoW. Select the
  export text and press **Ctrl+C**; import it by pasting with **Ctrl+V**.
- A secondary copy inside the saved settings cannot recover profiles if the
  SavedVariables file itself is lost. An external export provides that backup.

## Mouse-wheel casting

- Open **/ft → Custom keybinds**, then hover a spell in the list and scroll up
  or down to bind it (binding a spell turns casting on).
- Scroll while hovering a unit (unit frames or characters in the world) to cast
  on that unit. Away from a unit, the wheel keeps zooming the camera.
- Bindings change outside combat. If casting does not work, type
  **`/ft wheeldebug`**, scroll over a unit, and include the chat lines in a
  bug report.

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
- The optional low-rank marker adds a small amber corner to your own action
  buttons that use a lower rank than you know. Use **Exceptions** for spells you
  downrank on purpose; macros are not checked.
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

## License

ForeverTools' own code is released under the [MIT License](LICENSE).
Bundled third-party components (the Inter font and InFlight flight data) keep
their own licenses, listed above.

## Beta limitations

- Restricted or unavailable unit data may prevent tooltip enhancements, buff
  source names, or reminder checks. Native tooltip content is preserved where
  required by the client.
- Custom wheel casting needs Blizzard's secure state drivers; on a client
  without them the option shows as unavailable.
- Some fonts, frame skins, and protected-frame positioning depend on the client
  build and require in-game verification. Hiding Lua errors does not fix errors
  or suppress Blizzard's blocked-action warnings.
- Bank inventory browsing and bank item counts are not included.

ForeverTools is an unofficial addon and is not endorsed by Blizzard Entertainment.
Game names and referenced game assets belong to their respective owners.
