# ForeverTools 0.50.0 (2026-10-03)

## New
- **Buff notice looks** (Buff reminders → Your buffs → the gear on a buff): give a buff a notice of its own instead of the shared one. Choose **Bar**, **Icon and text** or **Icon only**, then its size, transparency, text color, text outline, icon border and a gentle pulse, and drag it where you want it (while the gear panel is open, or with Move). Until you drag it, it sits where the shared notice sits, in the same size and color, so switching looks never makes it jump. Weapon buffs have a gear too. The default look is unchanged, and Default puts a buff back in the shared notice. While a buff's gear panel is open a sample is always on screen (its own notice, or the shared one when it uses Default), and **Preview** shows the shared notice plus every buff with its own look. Like every reminder, these show out of combat only.
- **Totem left-behind warning** (Combat → Totems, off by default): the totem's own icon under your player frame pulses red once you are farther from the totem than the distance you set (30 yards by default, 20 to 60), so a forgotten totem doesn't pull for you. Outdoors the distance is measured from where you placed it. In dungeons and raids the game hides your position, so it is a guess: the yards you have run out of combat since you placed it.
- **Druid mana bar** (Appearance → Unitframe colors): in bear, cat and other forms that hide your mana, a third bar under your rage or energy shows it. It uses the game's own three-bar player frame art, so it looks like part of the frame, and follows the Player frame skin. Hover the bar for the numbers (or always, with the game's status text option). Off by default; other classes are not affected.
- **Death glow** switch (System → Gameplay): turn off the glowing, washed-out screen while you are dead or a ghost. This is the game's own setting (the same as `/console ffxDeath 0`), so it applies to all your characters.
- **Swing timers** skin area (Appearance → Skins): dark mode and the other presets now also cover Forever's main-hand, off-hand and ranged swing timer bars (the frame and its backing; the moving fill keeps its color). The Dark mode and Full setup presets turn it on with the rest.

## Changed
- **Dispel glow, softer and easier to see:** instead of thin lines around the bars, the frame's own glow (the one the game lights up for aggro) now shows in the debuff's color around the whole frame, on player, target, focus and party frames. **Each debuff type has its own color** (magic, curse, disease, poison) that you can change under Appearance → Unitframe colors; picking a color shows it on your frames for a few seconds, and right-click puts the default back. The default colors are brighter than before. A party shown with raid-style frames now follows the **Party** switch (before, it needed Raid-style on), and the Raid switch is for raid frames only.
- **Mouse-wheel casting skips friendly NPCs:** scrolling over a vendor, quest giver or other friendly NPC now zooms the camera instead of casting your wheel spell on them. A new **Cast on friendly NPCs** switch on the page turns the old behavior back on. Totems and other summoned helpers are always skipped. Players, their pets and enemies are unaffected; in combat the wheel still casts on friendly NPCs and totems, because the game does not allow this to change during a fight.
- **Mouse-wheel dispels only when there is something to remove:** a dispel on the wheel (Cure Poison, Cure Disease, Remove Curse, Dispel Magic, Cleanse and the like) is now only cast when the unit under your mouse has a debuff it removes. With nothing to remove, the wheel zooms the camera. Dispels also no longer fire on a player's character in the world, where a scroll is nearly always meant for the camera: scroll over their unit frame instead. Built in, no switch. Heals and other spells on the wheel are unchanged. The check runs out of combat; in a fight the game does not allow the wheel to change, so it casts as before. Dispels are recognized by their English spell names.
- **Cooldown reminders while leveling** come sooner: after about 8 kills (was 15), at most every 5 minutes (was 10).
- **Buff reminders page, rebuilt:** instead of one very wide window with everything showing, the sections are listed on the left (Your buffs, Group buffs, Low ranks, Look and position, Cooldown reminders), each with its current state, and only the chosen section's options show on the right, like the Macros and Skins pages. Self reminders, Group reminders, Preview and Move sit in a top row. Every option is still there, and the window keeps one size whichever section you open.
- **Also sell white gear** is smarter and needs no input from you. It still only sells white weapons and armor (never potions, food, reagents, quest items, tools, shirts, bags or jewelry), and now keeps what could be useful: gear for an empty slot, gear in an equipment set and, up to level 20, anything better than what you wear in that slot. From level 21 white gear is sold, since quest and dungeon greens have replaced it by then. Armor and weapons your class can't use are always sold. The chat line names the white gear that was sold, so it is easy to buy back.
- **Macros window, tidier:**
  - The **Classes** button is gone. To look at another class's macros (for an alt), right-click **Character** and pick the class; a left-click goes back to your own.
  - **Save to: Character / General** moved to the top row, next to Mouseover and Icons (short for icons on unlearned spells; hover it), so the same choice applies everywhere. Add all and Delete character macros sit on the right. The buttons size themselves to their text, so nothing is cut off. The two save buttons under the macro text are gone, and the text box is taller.
  - A **new macro** now appears at the top of the list (your own macros are listed first, newest on top).
  - **Advanced options** shows every gear slot as its own button instead of a dropdown, with the icon of what you have equipped.
  - The macro text box's scrollbar only shows when the text is longer than the box.
  - **Delete from the list:** each macro row has an **X** next to the hide button (now an eye). Deleted and hidden macros both go to **Hidden**, a list of its own with a **Hidden** part and a **Deleted** part, where one click brings them back. Click Character or Generic to return to the normal list. A macro you made yourself can be deleted for good from Hidden (asks first). This only tidies the ForeverTools list; macros already added to WoW are removed with Delete… in the top row, as before.
  - **Save to** is a dropdown (Character or General, Character by default) and no longer cut off. General is greyed out, with the reason, when the selected macro uses class or racial spells.
  - The macro panel is simpler: **Choose learned spell** and **Add spell** sit at the top, **Advanced options** is a small gear button in front of the macro name, and **Default** only appears once you have changed the macro's text (typing, Add spell or an Advanced line). The text box is as wide as the button below it. **Add selected macro** is the only button below the text box, and bigger. Add spell (a plus) and Add selected macro (a note) have their own icons.
  - **Party GZ** now starts with `#showtooltip GZ`.
  - The macro text box has a blinking gold **typing line**, and clicking anywhere in the text (built-in or your own macros) puts the cursor there.
- **Bug report** (System → Troubleshooting) now includes a line with what the totem tools are tracking, for shamans with them on.
- **Tooltip target line** sits with the unit's own lines, above the beta's "Press F6 to submit an issue" line instead of below it.

## Fixed
- **Cooldown reminders** (for example Blood Fury) could stay silent: in a fight the game hides whether a cooldown is ready, and the reminder waited for an answer that never came. ForeverTools now keeps its own record (the game's answer out of combat, your own casts in a fight), remembers whether your target was tough from before the pull, and looks again for a racial the game had no data for right after login. Hover a cooldown on the Cooldown reminders page to see whether it counts as ready.
- **Totem range circles** no longer stay behind when a totem runs out or is replaced during a fight, and are checked against the game again when the fight ends.
- **Profile import** no longer says "Invalid toggle" for a profile that has Quest objectives set to Collapsed, Open or Hidden.
- No more "Font not set" errors if the addon's font file can't be read (for example when the addon folder is replaced while the game is running); the game's own font is used instead.

# ForeverTools 0.40.0 (2026-09-30)

## Changed
- **Buff and debuff borders** (Appearance → Skins → Buffs / debuffs) are drawn in real screen pixels: 1 px is now a true one-pixel line instead of thick frame art, and 2 to 4 px step up evenly. The icon keeps its full size (before, the rounded frame shrank it and the fill color showed as an extra dark ring). Existing 3 px buff borders become 1 px once.
- **Shadow** (buffs, action bars, stance bars) is now soft and fades out, with new **Shadow size** (1 to 8 px) and **Shadow darkness** sliders.
- Buffs / debuffs no longer show the fill color and fill transparency settings, since buff icons cover them completely.

## Fixed
- **Smoother sliders:** dragging a slider in Skins (for example Buffs / debuffs transparency) no longer makes the game stutter or spike the CPU. While you drag, only that area is recolored; the full update runs once when you let go. Size and transparency sliders for buff reminders, leveling stats, the threat % and the flight timer update at most 20 times a second too, and so do color pickers while you drag the color wheel (skins, reminders, leveling stats, threat %, flight timer, cooldown numbers). Dispel glow checks each unit at most ten times a second in busy groups.

# ForeverTools 0.30.0 (2026-09-30)

## Removed
- **Standing in fire sound** is taken out for now: it also went off on damage over time (bleeds, poisons), not only fire on the ground. It may come back once it can tell them apart.

## Fixed
- **Totem range circles** show up reliably: a new totem, one replacing another of the same element, and several dropped in a row each get their circle where you stood when you cast it. A totem ForeverTools can't place (already down before) no longer keeps an old circle. In combat, when the game hides totem details, circles stay up, totems you drop mid-fight get theirs too, and a totem you click away, that dies or runs out loses its circle.
- **First-time setup** now also shows for players who had another addon called "ForeverTools" installed before (it uses the same folder); its leftover settings are ignored.

# ForeverTools 0.20.0 (2026-09-29)

## New
- **Spell binds** (Keybinds, off by default): bind spells, items and macros straight to keys, without putting them on an action bar. **Role keys** (Interrupt, Taunt, Dispel, Defensive, Heal, Movement, Crowd control, Burst, Slow) pick your class's spell for each job (click a role's icon to choose among the ones you know, like Flash of Light or Holy Light, or drag any spell onto it), so the same key does the same job on every character. Click a bind to open its own small window: set its key (Esc cancels), turn it on or off, clear it or remove it. An optional on-screen bar shows the role spells you gave a key, with short key names (like c-R) and cooldown, matches your action bar skin and font, and can't be clicked by accident while you move it. Turning the bar on while spell binds are off asks to turn them on too, and new characters are asked once whether to use your usual role keys. Spell binds sit on top of your normal key bindings and never change them: keys you don't use here keep working, and a key you clear gets its old action back.
- **Action bars in profiles:** export and import now have three switches: **Keybinds**, **Action bars** (the spell, item or macro in every slot) and **Spell binds**. On import, action bars go back in the same slots on a character of the same class; spells not learned yet and items not in your bags are skipped and listed. Mounts, pets and similar slots are left as they are.
- **Backups and restore** (Keybinds): one list to put things back. It holds full backups (keybinds, action bars and spell binds, saved automatically before an import changes them, and whenever you choose "Save a backup now") and your last keybind sessions (keybinds only; this replaces the separate Restore keybinds). Restoring a full backup backs up your current setup first.
- **Profiles save by themselves:** every change goes straight into the profile you use (when a settings window closes, when you switch profiles, and on logout or reload), so the "Save changes?" question is gone. A character without a profile gets one named after it on its first change. Changes you had kept with "Not now" are moved into your profile once.
- **Profiles page rebuilt:** switch profiles at the top and see which characters use it; New, Copy, Rename and Delete; Export and Import; **Undo** with earlier versions of the profile (saved automatically before your first change each session, before a restore and before default settings); and the profile for new characters. Importing switches you to the new profile. Keybinds start switched off on every export.
- **Move elements from any window:** a move button in the title bar of the main menu and every settings page (it replaces the Move elements bar on the main menu). Open windows shrink to their title bar while you move things and open again when you click Done; a new minimize button does the same any time. The Move elements bar pulses gently while you're editing, and the buff reminder notices get the same outline box as the other elements.

## Fixed
- **Dungeons:** tighter checks everywhere the game can hide information inside instances (target of target, nameplates, threat, dispel glow, rare alerts, cooldown reminders, tooltips), so hidden values are skipped instead of causing errors.
- **Class colors:** no more Lua errors (thousands at a time) on the target-of-target bar when the game hides who that unit is; the bar keeps its color until it can tell.
- **Move elements:** turning an element on or off on its own page while moving now makes it movable (or puts it away) right away, instead of leaving it clickable and stuck.
- **Buff and debuff borders** sit right on the icon again at every thickness (they started 2 px outside the icon, which showed a dark ring at thicker borders).
- **Settings reverting:** settings could jump back to an older value (for example the objectives bar showing again) when the same profile was used or saved on another character.
- **Low-rank marker:** macros that name a spell without a rank (they always cast your best rank) are no longer flagged, even when the game briefly reports rank 1 (seen in Orgrimmar).
- **Totem range circles** stay in place when the map changes (cities, sub-zones, zone borders) and with several totems down, and move smoothly with the map instead of shivering while you walk.
- **Standing in fire** now catches campfires and lava: out of combat, two magic hits up to about 3 seconds apart are enough (world fire can tick slower than the in-combat rule allowed), and hits where the game hides the amount or school count too.

# ForeverTools 0.15.0 (2026-09-28)

## New
- **Totems** (Combat, off by default): shows each totem's 30-yard reach as a circle on the minimap, in its element color (orange fire, sandy brown earth, dark blue water, cyan air by default; pick your own colors and how see-through they are; your arrow stays visible on top), so you can see when you're leaving it or need a new one. Circles appear only for totems you place while it is on. The circle sits where you stood when you placed the totem; after Totemic Projection it hides until you place again, and it isn't drawn in dungeons and raids, where the game hides your position.
- **Cooldown reminders: remind while leveling** (on when cooldown reminders are on): leveling fights are rarely tough enough for the other reminders, so after about 8 kills without using a ready offensive cooldown, the next fight gets a quiet nudge ("Ready: Blood Fury"), slightly see-through, no sound, at most once every 5 minutes (15 kills and 10 minutes before 0.50.0).
- **Move elements** (main menu): one click unlocks the FPS counter, leveling stats, flight timer, threat meter, threat % above target, rare alert, buff and cooldown reminders, loot rolls and tooltip position, so you can drag them all at once. A bar at the top has Settings and Done; entering combat locks everything. Its settings page (also in System → On-screen info) chooses whether elements you don't use show while moving, and resets positions one by one or all at once. Also `/ft move`.
- **Sell white gear too** (System → Merchant, off by default): auto-sell can also sell plain white weapons and armor. Tools and other useful items are never sold (fishing poles, mining picks, skinning knives, blacksmith hammers, shirts, tabards, bags, quivers, rings, necklaces, trinkets and relics). Sold items can be bought back as usual.
- **More skin areas** (Appearance → Skins): **Pet frame**, **Party frames**, **Personal resources** (the personal resource display under your character) and **Cast bars** (yours, your target's and your focus's) now support dark mode and the other templates.

## Changed
- **New look: Classic gold.** Every ForeverTools window, button and list trades the purple for dark brown with a thin gold trim and gold titles; buttons light up gold when you point at them, and switches that are on turn a warm dark gold. Notices, yes/no questions and the rare alert keep the damage meter look.
- **Main menu:** two columns of buttons, each with a short line saying what's inside, plus the Move elements button. The version and "By Krilar" share one quiet line at the bottom.
- **Moving things** (FPS counter, leveling stats, flight timer, loot rolls): the same rounded outline everywhere with room around the text. The name and "Drag to move" keep clear of the screen edge and of the other elements being moved, going above, below, right or left, wherever there is room. Loot rolls show a sample roll inside the box, exactly where rolls will appear. Group reminders show too while moving.
- Removed the troubleshooting commands `/ft cpu`, `/ft probe` and `/ft wheeldebug`.
- Icons across ForeverTools have softly rounded corners (menus, headings, reminders and notices). The main menu is a bit wider and its descriptions can use two lines.
- **Class-colored health bars** now use Blizzard's own white health fill, so they show the true class color, as bright as the party and raid frames, instead of a darker tint of the green bar. The player frame no longer puts its frame artwork over the bar, which made your own bar darker than your target's.
- **Leveling stats** stay hidden until you earn experience, so nothing sits on screen before there is anything to show.
- Removed tooltips that only repeated what a button already says (main menu buttons, Close, Back and a few On/Off switches).
- **Flight timer:** a single tidy line. The countdown sits on the left at a fixed width, then the destination, like "0:24 - Crossroads, The Barrens". Long names are shortened instead of wrapping to a new line.
- **Main menu tooltips** now all list what's inside (for example Appearance: Font manager, Unitframe colors, Skins and Chat). Buttons that open their own settings page say so in their tooltip.
- Sound warnings no longer mention Ctrl+S, since that key can be bound to something else; they say "the game's sound on/off key" instead.

## Fixed
- Low-rank marker now also checks macros: a macro that casts a lower rank (for example `/cast Healing Wave(Rank 3)`) gets the amber corner too.
- Buff reminders: changing the size in Look and position no longer pushes the notices up and off the screen.
- Buff reminder icons sit centered in the notice instead of on its bottom edge.
- First-time setup and What's new no longer disappear for good when combat starts while they are open; they come back after combat until you answer them.
- **Standing in fire** now also counts environmental damage such as campfires and lava, which the game reports without a magic school.

# ForeverTools 0.14.7 (2026-09-27)

## New
- **Threat meter** (Combat, off by default): your group's threat on your target, highest first, styled like the game's own damage meter and placed next to it (above it, or below when there is no room). It uses the damage meter's bar height, spacing and background. Drag its title bar to move it and its bottom-right corner to resize it (the corner shows always or on mouseover), or lock it in place. Reset position and size puts it back. The gear opens its settings and the arrow hides the bars. Show it in combat, in a group or always. In some dungeons and raids the game keeps threat numbers private; the meter still shows them there, but can't sort or color them.
- **Threat % above target:** your threat on your target, just above its portrait, turning yellow, orange and red as you get close to pulling aggro. Choose font, size, outline and an optional background with color and transparency (with a live preview in the settings), and move it where you like.
- **Meter fonts** (Appearance → Fonts): new **Threat meter** and **Damage meter** areas set the font, size and outline of the threat meter and of the game's own damage meter bars. Shortcuts on the threat settings page.
- **Standing in fire sound** (Combat, off by default): a warning sound when you keep taking magic damage in a steady rhythm, like standing in fire, lava or another ground effect. Works without setup; optionally pick one of five game sounds and whether it follows your effects or master volume; choosing either plays the sound, and a warning shows when your volume is very low. Turning game sound off mutes it. It can't tell ground effects from a fast spell cast on you and doesn't catch physical damage.
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

# ForeverTools 0.14.6 (2026-09-27)

## New
- **Rare alerts** (Combat, off by default): a notice with a soft gold glow when a rare appears on your minimap or nearby, with an optional sound from the game's own sounds. Click the notice to target the rare (out of combat; the game blocks this in combat). Each rare alerts once, and the settings warn you if your game volume is very low or muted. Choose how long it stays, its size, glow color and position.
- `/ft probe`: an optional test that reports in chat what the game lets addons read during combat (threat and damage taken). It helps plan the upcoming threat meter and "standing in fire" warning.

## Changed
- Profiles: **Rename** now sits with Load, Save and Delete and acts on the profile you chose. It opens a box with that profile's name already filled in, so it is clear what you rename.

# ForeverTools 0.14.5 (2026-09-27)

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
