# ForeverTools 0.14.3

## New
- **Quick keybind mode:** type `/kb` (or use System → Gameplay), hover any slot and press a key to bind it. Escape on a bound slot unbinds it. Uses Blizzard's own quick keybind mode.
- **Keybind snapshots:** a snapshot is taken before you start. Take more while you edit, revert to any of them, then save or discard.
- **Tooltip layout builder:** turn the name, guild, level, race, class, faction and target parts on or off, order them, and put them on the same or a new line. A live preview shows the result.
- **Faction icon** in tooltips can go before or after the name or guild, and now shows for players without a guild too.
- **Faster looting** in System → Gameplay: with auto loot on, everything is looted the moment you open a corpse. Off by default.
- **Restore keybinds** in System → Gameplay: pick one of your last 10 keybind sessions. Hovering a session lists what it changed (for example "Action Button 1: 1 → Q").

## Changed
- New FT logo; the minimap button uses the same round border as other addons' minimap buttons.
- The Tooltip page has a two-column layout: build the tooltip on the left, other options on the right.
- Clearer, shorter tooltips and help texts across the addon. The export window (?) explains what carries over after updates.
- Profiles panel: more room between controls, clearer icons, and long profile names wrap onto two lines.
- Buff reminders page: clearer two-column layout with sections. Start with your own buffs on the left; group, low-rank and look options are on the right.

## Fixed
- Macros: Add all now adds spells you know first, then by the level you learn them, so when the Character tab is full (WoW allows 30) only later spells are left out. The prompt names them, and the status line lists skipped macros on hover.
- Font manager and Skins: the list scrollbar no longer touches the settings next to it.
