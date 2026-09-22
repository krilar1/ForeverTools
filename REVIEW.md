# Request review — 0.8.0

## Included

- ForeverTools folder/name, /ft only, /rl, native Macro UI launcher, smaller draggable minimap launcher and replacement purple FT badge.
- Saved settings, persistent free FPS/minimap positions, top-left FPS default, on/off and font-size controls.
- Main-menu module layout, System last, Custom keybinds above it, compact expandable Profiles beside Close, version only in footer.
- System welcome message, minimap launcher, built-in coordinates and tooltip-target switches; targets display You when appropriate.
- Independent local named profiles, save-name confirmation, cross-character onboarding, save/load/delete and legacy-profile recovery. Normal updates retain SavedVariables. Profiles store the latest snapshot; they do not provide revision history.
- Fonts: TTF/OTF Expressway fallback, independent settings, steppers, appropriate previews, apply-font-to-all, original chat/tooltip/unitframe-text defaults, RestedXP and both built-in weapon swing timers.
- Skins: dark preset black border / 100% fill transparency, class-colored preset, independent frame-area toggles, native border tint, aura-only outlines with semantic enchant/debuff colors.
- Unitframe class-color toggles use neutral health fill instead of multiplying color into green art; development notice retained.
- Clean chat controls, mode icons, independent padded social/side hover areas and grouped chat tabs; social defaults to mouseover.
- Macro class browsing, clear selection, generic filter, blank class-macro titles, live icon resolution, automatic imported icons, mouseover options and bulk flow, character-only class destinations, safe two-confirmation deletion.
- Direct macro editing, separate advanced builder, class/spell/rank dropdowns, Default reset, success toast, replacement confirmation and deletable revision history. Advanced editor cursor animation now runs on its EditBox.
- Close addon windows on entering combat. Existing regression coverage retained.

## Limits / in-game checks

- Custom bindings use native secure state drivers, with a short native polling delay as the hover changes. Test wheel casting and zoom in and out of combat on this beta; simulated tests cannot certify taint behavior.
- Exact swing and coordinate control names were verified against the Forever UI source. RestedXP frame names were verified against the installed version. Addon fonts do not enable the underlying swing timer itself.
- New font/chat defaults apply to new or reset settings. Existing profile choices are preserved. Reset an area to adopt its new default.
- The optional separate-weapon Shaman enchant templates remain unimplemented; the existing Windfury template remains. Applying an enchant to a particular weapon needs beta spell-behavior verification before adding a reliable template.
- Macro capacity is not increased. Bulk import checks the client-provided limits and warns about insufficient space.
- No in-game session was operated. Final visual sizing, live combat behavior, beta unitframe restrictions and exact aura artwork still require user testing.
