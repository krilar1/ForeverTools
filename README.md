# ForeverTools

**Quality-of-life tools for WoW: Forever — version 0.60.0.**

ForeverTools brings everyday interface adjustments and useful tools together in
one place. Everything starts **off**, so the game looks like Blizzard's until you
choose otherwise. A short first-time setup offers Minimal, Dark mode and Full
presets, and new characters can reuse any saved profile.

Open the menu with **`/ft`** or the minimap button, and search any setting from
the home window. Use **`/rl`** to reload the UI.

## Features

- **Skins and dark mode:** Style action bars, buffs and debuffs, bags, micro
  menu, minimap, XP/reputation bars, stance and totem bars, gryphons, unit
  frames (player, pet, target, focus, party), the personal resource display,
  cast bars and swing timers. Choose a preset for all areas or adjust each area separately, with
  border, fill and transparency controls and separate rare/elite switches.
  Save your own looks as skin templates and switch between them.
- **Fonts and cooldowns:** Adjust supported fonts, sizes, outlines and colors,
  including cooldown numbers.
- **Unit-frame colors:** Class-colored health bars for player, target,
  target-of-target, focus and focus-target frames. Party colors link to
  Blizzard's Edit Mode settings.
- **Dispel glow:** A soft glow around player, target, focus, party or raid
  frames while they have a debuff you can remove, in a color per debuff type
  that you can change. Only dispels you have learned count; no icons are added.
- **Tooltips:** Build your own player tooltip: turn name, guild, level, race,
  class, faction and target on or off, order them and choose which share a
  line, with a live preview. Also text sizes, position, faction icon, health
  bar, buff sources and tooltip IDs.
- **Chat:** Show, hide or mouseover-reveal chat controls, change the chat font,
  and optional clickable links that open a copy box.
- **Macros:** Browse class, racial and general templates; select ranks; add
  mouseover support; and build custom macros with spell and equipment actions.
  Add all fits your macro tab (Make room), hides macros you never use, and can
  give unlearned spells their icon so bars can be set up from level 1.
  A macro can also equip items (a weapon swap, for example): pick a slot and an
  item you wear or carry.
- **Buff reminders:** Self and group buff notices with talent-based choices,
  weapon enchants, low-rank alerts and an optional low-rank marker on action
  bars, with per-spell exceptions. Choose where notices appear and how long
  they stay. Any buff can get a notice look of its own (bar, icon and text, or
  icon only) with its own size, colors and place on screen.
  A food buff reminder (Well Fed gives 5% more experience from kills in
  Forever) works for every class, while leveling or always.
  Notices hide in combat, except for buffs you set to also remind in combat
  (Battle Shout, for example).
- **Leveling stats:** XP per hour, time to level, kills to level, XP progress and
  rested XP. Pick which to show and their order, one per line or on a single
  line, with an optional rounded background; font size and transparency
  sliders; movable, and also added to the XP bar tooltip.
- **Totems (shamans):** each placed totem's 30-yard reach as a soft circle on
  the minimap, and a left-behind warning that pulses the totem's icon red when
  you move too far from it (Combat → Totems).
- **Move elements:** The move button in any window's title bar unlocks every on-screen
  element (FPS, leveling stats, flight timer, threat meter, rare alert,
  reminders, loot rolls, tooltip) to drag them all at once, with an option to
  include elements you don't use and to reset positions. Also `/ft move`. The
  window shrinks to its title bar while you move and opens again on Done.
- **Flight countdown:** A one-line countdown next to your destination, for
  example "0:24 - Crossroads, The Barrens". Completed
  flights teach new routes and replace bundled estimates.
- **Threat:** a threat meter styled like and placed next to the game's damage
  meter, and your threat % above your target (Combat). Fonts
  can change the threat meter's and the damage meter's text.
- **Cooldown reminders:** a short nudge to use a ready racial, trinket or long
  cooldown on elites, rares and big pulls, and now and then while leveling
  (Buff reminders).
- **Spell binds:** bind spells, items and macros to keys without an action
  bar, plus role keys (interrupt, taunt, dispel, crowd control, burst, slow…) that pick your class's spell
  and an optional on-screen role bar (Keybinds).
- **Action bars and backups:** export and import your action bar layout with
  keybinds and spell binds, and keep backups you can put back any time
  (Keybinds → Backups and restore).
- **Smart interact key:** one key that uses RestedXP's quest item or target
  button when the guide shows one, and is Interact with target otherwise
  (Keybinds).
- **Rare alerts:** a glowing notice and optional sound when a rare appears.
  Click it to target the rare, out of combat (Combat).
- **Quest objectives:** keep the objective tracker collapsed or open after
  login and reload, or hide it altogether (System → Gameplay).
- **Death glow:** turn off the glowing screen effect while dead or a ghost
  (System → Gameplay; the game's own ffxDeath setting).
- **Druid mana bar:** your mana as a third bar on the player frame while in
  bear, cat or another form, in the game's own frame art (Appearance →
  Unitframe colors). Off by default.
- **Faster looting:** With auto loot on, take everything the moment a corpse
  opens. Off by default.
- **Merchant helpers:** Optional auto-sell of grey items, optionally white
  weapons and armor, and items you mark yourself with a key of your choice
  (always-sell marks). At most 12 items are sold per visit, so all of them can
  be bought back. Selling is silent; auto-repair (with guild funds if allowed)
  reports its cost in one chat line (System → Merchant).
- **Minimap:** ForeverTools button, coordinates, and an optional launcher that
  groups other addons' minimap buttons into one menu.
- **Profiles:** Named profiles shared by the characters that use them, saved
  automatically with an Undo list, export/import as text (optionally with
  keybinds, action bars and spell binds), and a profile or a fresh start on
  each new character.
- **Quick keybinds:** `/kb` binds keys by hovering a slot, with snapshots to
  revert, save or discard; earlier sessions are in Keybinds → Backups and restore.
- **More:** FPS counter, movable loot rolls, group-role helper, custom
  mouse-wheel casting on mouseover, a Lua-error toggle and a copyable bug report.
- **Where things are:** Fonts, unit-frame colors, skins and chat are under
  **Appearance**. FPS counter, leveling stats and flight countdown are under
  **System → On-screen info**. Quick keybinds, mouse-wheel casting and the
  smart interact key are under **Keybinds**, and the threat meter, rare alerts
  and totems under **Combat**, both on the main menu.
- **Menus:** every settings window has Back, a close X, move and minimize
  buttons, and an (i) icon explaining the page; pop-ups have only the X. A short What's new panel appears after each update (can be turned off
  in System → General).
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

- Open **Profiles** from the main menu. Every change is saved to the profile
  you use automatically: when a settings window closes, when you switch
  profiles, and on logout or reload. A character without a profile gets one
  named after it on its first change.
- Profiles are shared: every character using a profile follows it and gets
  changes made on another character at its next login. The Profiles page shows
  which characters use each profile.
- **Undo** lists earlier versions of the profile, saved automatically before
  your first change each session, before a restore and before default settings.
- **New profile** starts from default settings, **Copy** duplicates the current
  profile, and **Rename** and **Delete** manage it. Deleting a profile sends
  other characters that used it back to default settings at their next login.
- **Default settings** resets the profile and returns everything ForeverTools
  changes to Blizzard's defaults, as if the addon was just installed.
- Profiles also remember where your macros sit on the action bars, separately
  for each class. Loading or importing the profile on that class offers to put
  them back, adding any macros you are missing (outside combat).
- A new character starts from Blizzard's defaults and asks whether to use a
  saved profile or start a new one. The profile chosen under **Profiles → New
  characters** (by default, the last one you used) is preselected. Closing the
  question keeps Blizzard's defaults; a fight or a reload only postpones it.
- **Include keybinds** on the export window adds all your key bindings to the
  string. When you import a string with keybinds, **Apply keybinds** replaces
  your current bindings with them (outside combat).
- **System → General → Reset all settings** returns everything to the defaults
  (all off) and reloads. Saved profiles, custom macros and flight times are kept.
- Working settings and profiles are stored through WoW's SavedVariables system,
  which normally writes to disk on logout or reload.
- Export important profiles and keep the text somewhere outside WoW. Select the
  export text and press **Ctrl+C**; import it by pasting with **Ctrl+V**.
- Export strings keep working after ForeverTools and game updates. Settings added
  later start at their defaults, keybinds for actions that no longer exist are
  skipped, mouse-wheel spells need to be learned, and custom fonts need the same
  font file on the other computer.
- A secondary copy inside the saved settings cannot recover profiles if the
  SavedVariables file itself is lost. An external export provides that backup.

## Quick keybinds

- Type **`/kb`** or use **Keybinds → Quick keybind mode**. Hover any
  action button and press a key to bind it; press Escape on a bound slot to
  unbind it. This opens Blizzard's own quick keybind mode.
- A snapshot of your keybinds is taken when you start. **Take snapshot** saves
  more points while you edit, and **Revert to snapshot** returns to any of them.
  Finish with **Save** or **Discard**.
- **Backups and restore** (Keybinds) also lists your last 10 saved sessions.
  Hover one to see what it changed, such as "Action Button 1: 1 → Q"; choose it
  to put back the keybinds from before it. Only changed keys are stored, on
  this computer, and never in profile exports. Keybinds change only outside
  combat.

## Mouse-wheel casting

- Open **/ft → Keybinds → Mouse-wheel casting**, click a spell in the list, then scroll up or
  down to bind it (binding a spell turns casting on). A click or Esc
  cancels; scrolling over the list without clicking only pages it.
- Scroll while hovering a unit (unit frames or characters in the world) to cast
  on that unit. Away from a unit, the wheel keeps zooming the camera.
- Friendly NPCs (vendors, quest givers) are skipped, so zooming while you talk
  to one never casts on it. **Cast on friendly NPCs** on the page turns that
  off. Totems are always skipped; pets never. In combat the wheel casts on
  friendly NPCs and totems too.
- A dispel on the wheel (Cure Poison, Remove Curse, Cleanse and the like) is
  only cast when the unit has a debuff it removes, and never on a player's
  character in the world: scroll over their unit frame instead. Otherwise the
  wheel zooms the camera. This works out of combat; in a fight the wheel
  casts as usual.
- Bindings change outside combat. If casting does not work, include a bug
  report (System → Troubleshooting → Copy bug report).

## Macro tips

- Use **New macro** to add a custom entry to Generic or your class list.
- For a combination macro, open **Macros → Generic → 1-shot combo**. Add learned
  spells with the row at the top, then use the gear button in front of the macro
  name for equipment-slot or other supported lines.
- **Add all class macros** adds spells you know first, then by learn level, and
  skips utility spells such as teleports and tracking (add those one by one).
  **Delete character macros** removes either the ForeverTools macros you have not changed
  or every Character macro; both ask twice.
- If Add all does not fit, a **Make room** window lists your Character macros
  and the new ones. Tick what to delete and what to add; the slot counter turns
  green when it fits.
- Each row has two small buttons: hide, and **X** to delete. Both move the
  macro to **Hidden**, where you can bring it back; hidden and deleted macros
  are never added by Add all. Your own macros can be deleted for good from
  Hidden.
- **Default** (beside the macro name) only shows when you changed the text.
- **Icons** (in the top row) gives macros for spells you have not
  learned yet their icon, so bars can be set up from level 1. Add all again to
  give macros you already added their icon.
- **Mouseover** in the Add all row is the default for every macro and is
  remembered; a macro's own Mouseover button makes an exception (marked *),
  cleared when the row setting changes.
- With mouseover on, spells cast on the unit under your mouse and keep your
  target. Melee strikes stay on your target, except interrupts, taunts, stuns
  and debuffs meant for a second enemy.
- Melee abilities start auto attack. Stealth openers (Cheap Shot, Ambush,
  Garrote) and effects that damage would break (Gouge, Sap, Blind) do not.
  Stealth and Prowl only enter stealth.
- Choose **General** or **Character** with **Save to** in the top row before adding a macro.
  The game determines whether space is available.
- Macros still require your input and obey normal casting rules. Off-global-
  cooldown abilities may work alongside another spell; global-cooldown spells
  may require separate presses.
- The external Forever spell audit covers the available level 1–20 beta reference.
  Higher-level legacy templates remain, and learned-spell discovery supplements
  the catalogue. See [spell audit details](SPELL_AUDIT.md).

## Reminder and flight details

- Buff notices hide during combat, flights, death, and other unsupported player
  states. Use **Show in** to pick where self and group notices appear: open
  world, cities (while resting), dungeons, raids and PvP. Group notices default
  to dungeons, raids and PvP, and always need a group.
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
- The FT logo was drawn for this project from simple shapes. See
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
