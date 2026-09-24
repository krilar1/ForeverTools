# ForeverTools 0.12.21

ForeverTools is a configurable quality-of-life addon for WoW: Forever.
Open it with `/ft`. Use `/rl` to reload the UI.

Features: curated class and generic macros with mouseover options, a live
learned-spell combo builder with optional equipment-slot actions; movable,
configurable self and instance group-buff reminders with talent-tree choices; FPS counter; Fonts & colors,
unitframe coloring and Skins;
clean chat controls with font settings; tooltip layout, font sizes and health
bar toggle and drag mover, plus caster names on buffs when the client provides them;
movable loot-roll position; custom wheel bindings when supported
by the client; minimap launcher; saved profiles with import/export strings.
System also controls WoW's Lua error display through its built-in setting.
System → Show spell ID adds the available spell ID below spell and aura tooltips.

Self-buff reminders include optional low-rank alerts for your own active buffs
and identifiable weapon enchants. Turn off **Low-rank alerts**, or enable
**Ignore rank 1** for intentional dispel bait. Learned ranks come from your
spellbook. Unlearned upgrades require a trainer visit first: the addon remembers
trainer-confirmed ranks and their level requirements for this character and
client build. Unknown ranks and buffs from other players are not flagged.
Weapon reminders accept an active temporary enchant, refresh after casting and
expiration, and keep off-hand choices saved while a two-hander, shield, or empty
off-hand slot is equipped.

For a combo macro, open Macros → Generic → 1-shot combo. Choose spells from
your character's learned spellbook, add item or attack lines in Advanced
options if wanted, and edit the text directly. Off-GCD abilities can fire
with another spell; spells on the global cooldown may require another press.
Choose General or Character macros before saving.
Use **New macro** to add an editable custom macro to Generic or your current
class list. Custom macros and their edited text are included in saved profiles.

Group-buff reminders check nearby party and raid members locally after entering
an instance. They stay quiet when solo or grouped in the open world.

## Install and update

Unzip so the game has `Interface/AddOns/ForeverTools/ForeverTools.toc`.
Close WoW before replacing the addon folder. Keep your `WTF` folder: WoW
stores settings and profiles there on a normal logout or reload. A saved
profile is an explicit snapshot; your character's working settings persist
separately. You can export a profile string for an additional backup.
Named profiles also keep a second copy inside the addon's saved settings, but
an exported string is the safest backup if the beta loses its entire file.

## Fonts and artwork

The public addon includes Inter under the SIL Open Font License 1.1, with its
license in `Media/Fonts/Inter-LICENSE.txt`. Expressway is an optional font;
provide your own licensed .ttf or .otf copy in `Media/Fonts` and restart WoW.
The FT shield was drawn for this project. Details and distribution notes are
in `ARTWORK.md` and `DISTRIBUTION.md`.

## Client limitations

The beta may restrict unit data during combat. Protected tooltip units are
left in their native format; buff caster names are omitted when protected or
unavailable. Party frame class colors are configured in Blizzard Edit Mode.
Custom wheel casting is disabled on clients that
lack the secure compiler it needs. Loot-roll anchoring attempts to reapply
Blizzard's layout in combat but must be checked in the game. The bank inventory
and bank item counts are not included in this version.

This is an unofficial addon. Game artwork and spell names remain the property
of their respective owners. No Blizzard image file is bundled.
