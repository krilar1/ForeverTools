# ForeverTools 0.14.7

## New
- **Threat meter** (Combat, off by default): your group's threat on your target, highest first, styled like the game's own damage meter and placed next to it (above it, or below when there is no room). It uses the damage meter's bar height, spacing and background. Drag its title bar to move it and its bottom-right corner to resize it (the corner shows always or on mouseover), or lock it in place. Reset position and size puts it back. The gear opens its settings and the arrow hides the bars. Show it in combat, in a group or always. In some dungeons and raids the game keeps threat numbers private; the meter still shows them there, but can't sort or color them.
- **Threat % above target:** your threat on your target, just above its portrait, turning yellow, orange and red as you get close to pulling aggro. Choose font, size, outline and an optional background with color and transparency (with a live preview in the settings), and move it where you like.
- **Meter fonts** (Appearance → Fonts): new **Threat meter** and **Damage meter** areas set the font, size and outline of the threat meter and of the game's own damage meter bars. Shortcuts on the threat settings page.
- **Standing in fire sound** (Combat, off by default): a warning sound when you keep taking magic damage in a steady rhythm, like standing in fire, lava or another ground effect. Works without setup; optionally pick one of five game sounds and whether it follows your effects or master volume; choosing either plays the sound, and a warning shows when your volume is very low. Ctrl+S mutes it. It can't tell ground effects from a fast spell cast on you and doesn't catch physical damage.
- **Cooldown reminders** (Buff reminders → Cooldown reminders, off by default): each cooldown has a role. **Offensive** ones (Blood Fury, Berserking, Recklessness, on-use trinkets…) are reminded on tough targets (elite, rare, boss or 3+ levels above you) and big pulls (3+ enemies after a few seconds), at most once per fight and once a minute, and not if you already used one. **Defensive** ones (Shield Wall, Evasion, Ice Block, Stoneform…) only when you're in trouble: a burst of damage, or an effect the spell removes (Stoneform: poison or disease; Will of the Forsaken: fear; curse breakers: curses). Known cooldowns get their role automatically; others start off and you can set them.
- **Smart interact key** (Keybinds, off by default): one key for questing. It uses RestedXP's quest item when the guide shows one, targets RestedXP's target when you have no target, and is Interact with target the rest of the time (always while a dialog is open, so nothing closes). You choose the key yourself and confirm it; nothing is bound on its own. Works in combat.
- `/ft threat` opens the threat settings.
- `/ft cpu`: an optional timing check. Type it, play for a bit, then type it again to see which ForeverTools parts used the most time.

## Changed
- **Tidier settings pages:** explanations moved out of the pages into tooltips, plus an (i) icon in each page's title bar for the page as a whole. Buttons have the same sizes and spacing everywhere (main switches a bit larger). Nothing was removed.
- **Notices and questions** (rare alerts, buff and cooldown reminders, short messages, yes/no questions and the save prompt) use the game's damage meter look, with the game's own buttons; the rare alert keeps its glow.
- **Leveling stats:** moves like the FPS counter (follows the mouse and goes right up to the screen edge) and has a new **Line up** choice (left, center or right); the stats stay anchored on that side. The tilde in "Kills to level: ~12" now sits in the middle of the line.
- The FPS counter now moves and lines up exactly like the leveling stats: right up to the screen edge, with the same **Line up** choice (left, center or right), so the two line up with each other.
- The FPS counter, leveling stats and flight timer now sit behind game windows (like the macro window) instead of on top; they come to the front only while you move them.
- **Menus reorganized:** the main menu gets **Combat** (threat meter, rare alerts, standing in fire) and **Keybinds** (quick keybind, restore, mouse-wheel casting, smart key). System keeps General, Minimap, Gameplay (role, looting, loot rolls, quest objectives), **Merchant** (auto-sell, repair, guild funds), On-screen info and Troubleshooting.
- Performance: much less work in and after combat, and while idle. Buff reminders and the low-rank marker wait until combat ends; class-colored health bars do nothing while they are off; skins only redo the part that changed (target frame, one bag window or bag button, buffs, action or totem buttons, XP bar, which reputation gains now only repaint) and read their settings far less often; looting no longer redoes every skinned area; class-colored health bars only repaint the unit whose health changed, and only when its color changes; mouseover chat controls only check when the mouse moves; quest objective fonts update when quests change instead of every 2 seconds; cooldown number colors react to cooldown changes instead of checking five times a second.

## Fixed
- Tooltip: no more Lua error in combat when a long guild name made the name line too wide.
- Leveling stats could vanish until turned off and on again (for example after zoning).
- Some text showed empty squares where the game font has no arrow character.

# ForeverTools 0.14.6

## New
- **Rare alerts** (Combat, off by default): a notice with a soft gold glow when a rare appears on your minimap or nearby, with an optional sound from the game's own sounds. Click the notice to target the rare (out of combat; the game blocks this in combat). Each rare alerts once, and the settings warn you if your game volume is very low or muted. Choose how long it stays, its size, glow color and position.
- `/ft probe`: an optional test that reports in chat what the game lets addons read during combat (threat and damage taken). It helps plan the upcoming threat meter and "standing in fire" warning.

## Changed
- Profiles: **Rename** now sits with Load, Save and Delete and acts on the profile you chose. It opens a box with that profile's name already filled in, so it is clear what you rename.

# ForeverTools 0.14.5

## New
- **Skin templates:** save your own skin look (every area, with its colors, transparency and borders) as a template in Skins → Everything, and switch between templates any time. Save as new, Update, Rename and Delete, with tooltips on every button. Templates are shared by all your characters and travel with profile exports.

## Changed
- Skins → Bag menu: **Hide window art** and **Hide empty slot art** are now separate, so you can keep the bag window's own background and only remove the empty-slot pictures (slots get the same soft frame as the action buttons, in your border color). New **Slot color** with its own **Slot color transparency** slider (100% shows no color, so the bag window shows through).
- Skins: the border and fill transparency sliders now work the same way (right = more see-through, ends labeled Solid and See-through) and explain themselves on hover.
- Closing ForeverTools because of combat remembers the page you were on; opening it again after the fight brings you straight back there.
- **Class-colored health bars** now keep Blizzard's own health bar art and only recolor it, so they have the same shading and edges as the default green bar, and incoming heals and absorbs look exactly like in the default look.
- **Buff and debuff borders** use the same soft, rounded frame as the action buttons, fully solid instead of see-through, with rounded inner corners; icons reach the border. Border thickness goes up to 4 px (thicker looked off).
- **Leveling stats** read label first on every line, so rows line up: *XP/h: 567*, *Level in: 1h 20m*, *Kills to level: ~12*, *Rested: 3.2k*.

## Fixed
- Buff and debuff borders: no more Lua error when auras change in combat.
- Chat: with the input box border set to Mouseover, the border now also shows while you type (for example after clicking a name to whisper).
- Buff reminders: missing self buffs (for example Lightning Shield or Rockbiter Weapon) show again after combat, a flight or dying. Before, their timer kept running while notices were paused, so they could stay hidden until you toggled reminders.
- Quest objectives set to Hidden no longer pop up in combat (for example after a kill). The tracker turns invisible right away and is hidden fully when combat ends.
- The "Save changes?" prompt no longer appears when you only opened a page without changing anything.
- Tooltip page: the Layout description no longer runs into the first row.
- Target and focus frames (dark mode): the dark edge now reaches the portrait on the right, so the bar's top and bottom edges look the same on both sides.
