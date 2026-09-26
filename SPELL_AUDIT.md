# Macro spell audit — 2026-09-24

The current Forever beta ability reference (build 1.60.1.69913, levels 1–20):
https://wowforevertalents.net/abilities/
Exorcism corroboration: https://foreverdiff.com/spells/exorcism-holy/

VerifiedMacros.lua supplies missing active ability names across all nine classes.
No website descriptions, icons, guide text or addon implementations were copied.
The spellbook in the running client is the authoritative source for learned spells,
rank labels and icons. The Character list and bulk list now merge newly learned
non-passive spells, deduplicate ranks, and refresh on SPELLS_CHANGED.
Unknown new spells use plain casts rather than guessed targeting conditions.
Resurrections use dead-friendly targeting; ground effects, summons, weapon buffs,
stances and other untargeted abilities avoid hostile mouseover conditions.

Bane of Agony replaces the obsolete Curse of Agony template name. Existing saved
macros are not rewritten or deleted. Exorcism is included as a hostile spell.

The external beta reference stops at level 20. Existing higher-level templates
are retained for compatibility; they are not claimed to have all been verified
against a level-60 Forever release. Future learned spells are covered dynamically.
Passive/skill entries such as Tactical Mastery and Omen of Clarity are not added
as castable templates. Spellbook-only handling covers ambiguous or future entries.

Macro capacity: creation is attempted through the game API, with failure handled
without a Lua error. A stale MAX_CHARACTER_MACROS constant no longer prevents
creation. The bulk capacity hint uses the client constant, falling back to 30.

## Auto attack and use-case audit — 0.14.4

Rules applied to every class template and to melee spells learned later:
- /startattack: melee abilities used in normal combat (strikes, finishers,
  interrupts, taunts, shouts that need a target), e.g. Stormstrike, Claw,
  Growl, Taunt, Victory Rush, Expose Armor, Kidney Shot, Hammer of Justice.
- No /startattack: stealth openers (Cheap Shot, Ambush, Garrote, Sap, Pick
  Pocket), crowd control that damage breaks (Gouge, Blind, Polymorph, Fear,
  Hibernate, Shackle Undead), ranged shots and spells, and self buffs.
- Stealth and Prowl use [nostealth], so a second press cannot drop stealth.
- Macros still holding the previous default text for a changed template are
  recognised as that macro and updated in place, never duplicated.
Stormstrike (Shaman) was added on request; the spellbook remains authoritative.

## Mouseover audit — 0.14.4

With Mouseover on, a macro casts on the unit under the cursor, and otherwise
on your target, so you can hit, dot, interrupt or crowd-control an enemy
beside you (or heal and dispel a party member) without changing target.
- Yes: every spell cast at a unit: damage spells, damage over time,
  interrupts, crowd control, debuffs, Purge, heals, buffs, dispels,
  resurrections; melee abilities aimed at a second enemy (Kick, Pummel,
  Shield Bash, Bash, Hammer of Justice, Taunt, Growl, Mocking Blow, Sunder
  Armor, Rend, Hamstring, Wing Clip, Disarm).
- No: other melee strikes (auto attack stays on your target and combo points
  would land on the wrong enemy), Auto Shot (a toggle), self buffs, ground
  effects and next-swing attacks.
- The row setting applies to every macro; a macro's own Mouseover button makes
  an exception for that macro, cleared when the row setting changes.
Common practice checked against classic guides, e.g. Icy Veins' shaman macros.
