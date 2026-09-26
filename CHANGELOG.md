# ForeverTools 0.14.4

## New
- **Quest objectives** (System → Gameplay): Default, Collapsed on login, Open on login, or Hidden. Collapsed/Open are applied at login and reload; opening or closing it yourself is kept for the session.
- **A fresh look, kept quiet:** windows have a soft purple title band with a thin gold line, section headings have a small icon and a fading underline, buttons glow softly on hover, and windows fade in.
- **Main menu:** six buttons in an even grid; Profiles is now one of them.
- Macros: **Unlearned icons** (off by default, in the Add all row). Macros for spells you have not learned yet get the spell's icon (from your spellbook, talents or the template), so you can set up your bars from level 1. Running *Add all* again also gives macros you already added their icon.
- Macros: **Stormstrike** for Shamans (starts auto attack).
- **Rename profiles:** type the new name in the Profiles window and click Rename. It asks first ("Rename profile X to Y?").
- **Macro placements in profiles:** saving a profile remembers where your macros sit on the action bars, separately for each class. Loading or importing it on that class offers to put them back in the same slots, adding any macros you are missing. Export strings include them.
- **Make room:** when *Add all class macros* does not fit, a window lists your Character macros and the new ones. Tick what to delete and what to add; a slot counter shows when it fits, and it asks once before deleting.
- **Hide macros:** a small X on each macro row hides it from the list. Hidden macros are never added by *Add all*; the **Hidden** filter shows them so you can bring them back.

## Changed
- Profiles are **shared**: characters using the same profile follow it. Save on one character and the others get the change at their next login (a character with unsaved changes of its own keeps them until you save or load).
- **Profiles** opens in its own window (movable, with Back and close). The Save changes, keybind snapshots and role pop-ups can be dragged, and the panels inside Macros move the Macros window.
- Every settings window has a **Back** button (to the page it came from) next to the close X; pop-ups have only the X. Headings and their descriptions have more room.
- Buff reminders: **Hide notice after** (Look and position): never, 10 s, 30 s, 1 min or 2 min. The countdown only restarts when a new buff goes missing, and a dismissed notice stays gone until then.
- Leveling stats: font size and background transparency are sliders.
- Macros: **mouseover audit.** With mouseover on, every spell cast at a unit uses it, so you can hit, dot, interrupt or crowd-control an enemy beside you, or heal and dispel a party member, without changing target. Melee strikes stay on your target, except those aimed at a second enemy (interrupts, taunts, stuns, Sunder Armor, Rend, Hamstring). *Add all* updates unchanged ForeverTools macros to match instead of adding copies. **Mouseover** in the Add all row applies to every macro and is remembered; a macro's own Mouseover button makes an exception (marked *), cleared when the row setting changes.
- Macros: the Add all row holds Mouseover, Unlearned icons, Add all and Delete macros side by side.
- Chat: side buttons set to Mouseover appear when the cursor is anywhere over their box, not only exactly on a button.
- Macros: **auto attack audit.** Melee abilities used in normal combat start auto attack (now also Claw, Growl, Taunt, Victory Rush, Expose Armor, and melee spells learned later such as Crusader Strike or Shield Slam). Stealth openers and effects that damage would break do not: Cheap Shot, Ambush, Garrote, Gouge, Sap and Blind. Stealth and Prowl only enter stealth, so pressing them again no longer drops it. Existing Character macros with the old default text are updated by *Add all* instead of being added twice.
- **What's new** is now a small panel near the top right instead of the middle of the screen, with an icon and a short line per change.
- Menus: **Fonts & colors** is now **Appearance** and also holds **Chat**. The FPS counter, leveling stats and flight countdown moved to **System → On-screen info**; quick keybinds and mouse-wheel casting (formerly Custom keybinds) moved to **System → Keybinds**.
- Buff reminders: buffs are grouped by type (group buffs, blessings, auras & stances, armor, self buffs, weapon buffs).
- Macros: **Add all class macros** skips utility spells such as teleports and tracking (they can still be added one by one) and no longer adds Attack or racial spells.
- Macros: **Delete macros** offers *Delete unchanged macros* (ForeverTools macros you have not changed, including racial and generic ones) or *Delete ALL Character macros*. Both ask twice.
- Deleting a profile names it in the confirmation. Other characters that used it start from default settings at their next login.

## Performance
- Less CPU use: buff reminders check at most four times a second during aura bursts (raids) and reuse the spellbook scan; fonts are only reapplied to the areas an event affects and skipped when already right; unit colors ignore other units' health updates; closing a menu no longer builds a full export string to check for unsaved changes.
- Background work only runs when needed: cooldown styling pauses while its options are off, chat mouseover checks only run when a chat element is set to Mouseover, and several modules update once instead of once per loaded addon.
- Smaller saved data: a character's settings are not stored twice when they match its profile, and each profile keeps 3 safety backups instead of 10 (unchanged saves add none).
- Macros search waits for a short pause in typing and reuses the list.

## Fixed
- Profiles: loading a profile now also applies quest objectives and grouped minimap buttons right away.
- Auto-sell grey items: sold items now show in the merchant's Buyback tab (the last 12, as usual).
- Unit colors: a target in combat could show a dark olive health bar instead of its class color. The bar now repaints right away, also in combat.
- Fonts: **Thin outline** now works: a light outline without the drop shadow that makes Outline look heavy. Chat no longer lists "No outline", which was the same as Default; "Original outline" is now called Default.
- Macros: every confirmed macro is deleted, even though WoW re-sorts the macro tab while deleting.
- Buff reminders page no longer opens empty and jumbled while you are on a flight path (or dead, or in combat).
- Buff reminders: talent trees are recognized even when Forever names them differently, and before you have talent points the tree you pick is used.
- Font manager: a chosen font file that was removed no longer causes a Lua error. You get one message saying which file is missing and where to put it back; the game's font is used meanwhile.
