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
