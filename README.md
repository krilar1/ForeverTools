# ForeverTools — 0.9.8

## New in 0.9.8

- Tooltip Target displays You in red when the unit targets your character. Other target names remain white.

## New in 0.9.7

- Player tooltip begins with Name <Guild>, then level/race/class, then Target. The standalone guild row is removed; other useful details follow these rows.
- Guild tags, including brackets, use native PLAYER_FACTION_COLOR_HORDE/ALLIANCE or PLAYER_FACTION_COLORS values. Unknown/neutral factions retain normal text coloring. No guessed RGB replacements.
- Automated execution remains unverified following the approval-service credit failure; test tooltip layout in game.

## New in 0.9.6

- Target/focus health colors use a muted finish to approximate the player artwork, retaining their hue. Target-of-target and focus-target inherit their parent class-color toggle. NPC reaction hues are retained at reduced brightness. Player appearance is unchanged.
- Visual matching is based on supplied screenshots and needs in-game confirmation. Automated testing remains unverified following the approval-service credit failure.

## New in 0.9.5

- Player level circle and text render above the portrait while class colors are enabled. Their anchors, colors and original parents are preserved and restored when disabled.
- Automated execution remains blocked by the previously reported approval-service credit issue; in-game validation is required.

## New in 0.9.4

- Closing/leaving System saves the current loot-roll drag position and hides the preview. A non-interactive sample loot card appears above the drag handle.
- Native player portrait/border decorations are layered above the class-color fill. Disabling player class colors restores the original frame level. This applies independently of dark mode.
- Regression cases added for preview closure and frame-level restoration. Automated execution remains blocked by the previously reported approval-service credit issue; these changes require in-game validation.

## New in 0.9.3

- Removes the native standalone class-name duplicate below the race/class tooltip line. Keeps the addon-colored class after race and preserves other tooltip information.
- Final automated execution remains blocked by the previously reported approval-service credit issue.

## New in 0.9.2

- Health class colors retain the native fill alpha mask, including the portrait cutout, while keeping neutral class coloring.
- Minimap logo enlarged by 15%.
- System > Move loot rolls shows a draggable placeholder. Off locks its position. The initial position is just right of center (68% across, 50% up). Position persists across reloads and profiles; movement locks during combat.
- Font manager > Cooldown numbers adds a number-color picker and optional greyscale for action icons on cooldown. The global cooldown is excluded; restricted beta cooldown data is skipped. Reset this area restores native number colors and disables greyscale.

Validation: the existing 34 check groups passed after the initial health/loot changes. Subsequent focused tests and cooldown styling could not be executed because the workspace approval service was out of credits. This release is not fully verified; in-game testing is required.

## New in 0.9.1

- Removed an unsupported beta spell-learning event registration. The learned-spell picker continues to refresh through SPELLS_CHANGED. Regression checks now reject the unavailable event.

## New in 0.9.0

- Profiles use explicit snapshots: loading a profile never silently overwrites another. Each character retains a working copy. Closing the addon after changes offers to save as Character-Realm. Export/import text strings provide portable backups; imports do not automatically apply.
- WoW saves these settings locally in WTF on normal reload/logout. It cannot write arbitrary text files; copy exported strings into a backup file yourself. Preserve WTF during addon updates. Ten internal overwrite backups are retained per profile; there is no revision browser yet. This supersedes the shared autosave behavior in older notes below.
- Skins has independent area settings for color, transparency and icon-border thickness. Added level circles, focus target and XP/reputation artwork. Rare/elite artwork toggles are separate and off by default. Native artwork keeps its shape; thickness adjustments apply to action/buff icons.
- Font manager adds a General tab, confirmed bulk apply/reset, custom font registration, objective tracker support and native chat-size synchronization. Thin outline uses a subtle half-pixel shadow. Combat previews remain bounded.
- Custom keybinds shows learned spells and icons. Hover a spell row and scroll to assign it. Casting remains disabled when the beta secure compiler is unavailable; configuration still works.
- Class-colored health fills use native masks and suppress the managed health-loss flash. Tooltips place the colored class after race: Level 16 Undead Paladin (Player).
- Improved mouseover control layout, dual-purpose Dispel Magic and resurrection targeting. Minimap logo enlarged another 25%. Addon description now describes the general toolkit.

Automated Lua regression checks simulate WoW APIs; actual beta rendering, combat behavior and third-party integrations still need in-game testing.

## New in 0.8.2

- Removed the extra bronze minimap tracking ring and offset background. The original FT logo is centered and enlarged from 19 to 22 pixels (about 15%). Dragging and saved position are unchanged.

## New in 0.8.1

- Fix login errors when the beta lacks loadstring_untainted. Custom wheel casting stays inactive on that client, with an explanation in its menu; saved spell settings remain intact. Disabled casting no longer creates secure handlers. Binding cleanup uses the native out-of-combat API, without executing a secure snippet.
- Regression suite includes the missing-compiler configuration.

## New in 0.8.0

- System contains welcome message, minimap launcher, native minimap coordinates and tooltip target toggles. Tooltip targets display "You" for your character.
- Profiles expand beside Close on Home. Existing snapshots and character assignments remain intact; System and per-class custom bindings are included.
- Optional Custom keybinds: enter friendly/enemy spell names for wheel up/down. Secure hover bindings cover world units and unitframes; ordinary wheel bindings resume off eligible units. Configuration changes wait until combat ends. The native state driver can take a fraction of a second to recognize a changed hover. No additional addon is needed.
- Font manager adds RestedXP, main-hand and off-hand swing timers. RestedXP guide rows reapply when refreshed; the built-in swing timer must be enabled in game settings. Font areas scroll in the left-hand menu.
- New/reset defaults keep native chat, tooltip and unitframe text fonts; other managed areas use Expressway. Social-button default is Mouseover. Existing saved font and chat choices are retained.
- Skins adds independent minimap, micro menu, bags, player, target, target-of-target and focus artwork switches. Existing bar fills, portraits and labels are not darkened. Weapon-enchant outlines preserve their purple meaning.
- Class-color health bars use a neutral fill while managed, fixing green-tinted class colors on native colored artwork. Disabling restores the original atlas. This beta feature still needs in-game validation.
- Fixed the advanced editor's cursor animation using a frame update script rather than an unsupported texture script.
- New purple fantasy FT badge, inspired by the supplied Forever reference.

### Validation and beta limitations

Lua 5.1 regression tests cover defaults, profiles, native coordinate CVar, tooltip targets, secure binding transitions, frame art restoration, integration fonts and previous macro/position behavior. These are simulated API tests, not a running WoW client. In-game testing is still required, particularly combat hover binding behavior and beta protected/secret unit data.

Native interface references: [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns), including Blizzard_SwingTimer, Blizzard_Minimap, Blizzard_UnitFrame, Blizzard_MicroMenu and Blizzard_MainMenuBarBagButtons. RestedXP frame names were verified against the locally installed addon. No third-party source code is bundled.

## New in 0.7.2

- Side-control mouseover includes the button rectangle plus a small margin.
- Action previews place sample bindings inside four icons; unitframe previews no longer show spell icons. Animated previews retain their phase during font changes.
- Turning an area off retains its selected font in the selector. World-number size/outline limitations are explained on the disabled controls.
- Missing named profiles are recovered from the legacy saved table without overwriting current profiles. Profiles store latest settings, not revision history. Update only Interface/AddOns/ForeverTools; keep WTF intact. WoW writes settings on normal logout/reload, so exit normally before updating and back up WTF for recovery.

## New in 0.7.1

- Selecting a profile loads it. Active-profile changes save when switching or logging out; Save writes immediately and names the destination. The name field is only for creating profiles.
- New characters receive a profile-choice prompt if saved profiles exist. Characters remember their active profile. Shared profiles intentionally share edits between characters using that profile.
- Version appears only at the bottom of Home.
- Chat mode labels include icons. Tabs reveal together; social and side-control hover regions are independent. Alpha hooks prevent native fades from briefly revealing hidden controls.
- Plus/minus controls sit together in a bordered box. The first size adjustment starts from the area's actual loaded font size (or the preview size if unavailable).

## New in 0.7.0

- Chat menu: cycle social button, chat tabs, side controls and input artwork through Shown, Hidden and Mouseover. Input remains usable. Settings participate in profiles.
- New font areas default to enabled Expressway. Existing saved choices remain intact. Apply selected font to all enables every area without overwriting individual sizes/outlines.
- Size and outline use minus/plus controls. Cooldown previews animate on a spell icon; damage/healing numbers animate, while action labels, health text, chat, quest text and tooltips use contextual samples. Previews are simulations, not a guarantee of beta-client rendering.
- Aura styling suppresses detected native border textures, preserves their semantic colors on replacement edges, and restores originals when disabled.
- Automated Lua tests cover default fonts, steppers, all-area changes, previews, chat visibility and aura border restoration. In-game beta verification remains needed.

## New in 0.6.1

- Font selectors report the font on currently loaded text, including mixed/unavailable states. Selecting a font enables that area's management.
- The labeled preview uses “The quick brown fox jumps over the lazy dog.” Info buttons use graphical help artwork.
- New skin settings and selecting Dark mode enable action-bar shading and shadow outline. Existing explicit toggle choices remain saved until changed or the preset is selected again.

## New in 0.6.0

- Expressway is the addon interface font, with TTF/OTF probing and a stock fallback.
- Home profiles create local settings snapshots. Select a profile and Load to restore it, Save to overwrite it, or Delete to remove it. Snapshots include FPS position, fonts, unit colors, skins, minimap, welcome and macro destination preferences. Macro history and installed macros remain separate. WoW writes SavedVariables at normal logout/reload; profiles cannot prevent data loss from a client crash before that write.
- Fonts & colors uses the same 46-pixel navigation buttons as Home, with hover help. Font manager and Skins use tooltips and info buttons.
- Skins adds Class colors, Silver and Warm bronze. New settings start with Dark mode: black border, 100% shading transparency, shadow off. Class colors follows the current character.
- Aura borders and shadows anchor to the texture, excluding duration text. Nested aura containers are deduplicated.
- Unitframe colors displays a development badge and beta compatibility notice; controls remain available.
- General macro destination explains its class restriction even while disabled. Bulk Mouseover includes the game Combat settings tip. Window close buttons use Blizzard artwork.

Validation: automated Lua regression tests cover profiles and nested aura frames. Visual behavior still needs in-game beta testing.

## Install

Fully exit WoW. Replace `Interface/AddOns/ForeverTools` with the complete **ForeverTools** folder from this zip, then restart. Include all Lua and Media files. Open `/ft`. Shortcuts: `/ft macros`, `/ft fps`, `/ft appearance`, `/ft fonts`, `/ft colors`, `/ft icons` and `/rl`. `/kt` is not registered. Keep your SavedVariables files.

If upgrading from an old KrilarTools-folder release, remove that old addon folder from AddOns so both copies do not load. To retain old preferences, while WoW is closed copy the account's `WTF/Account/<account>/SavedVariables/KrilarTools.lua` to `ForeverTools.lua` in the same directory (only if it does not overwrite newer settings). Version 0.5.0 imports the legacy KrilarToolsDB table once into ForeverToolsDB. Existing ForeverToolsDB takes priority, and every module shares the same table for the rest of the session. Normal upgrades retain preferences automatically.

## New in 0.5.7

- Fixed saved-settings compatibility: `ForeverToolsDB` is authoritative, while `KrilarToolsDB` remains a compatibility alias for older ForeverTools saves. Reloading or restarting no longer drops preferences.
- The first-run FPS counter now starts at the top-left of the screen. The Home menu and minimap tooltip display the installed version.
- Centered the FT logo inside the minimap border.
- Icon styles now preserve Blizzard's original action-button and aura artwork. Shading is a rounded layer behind the original border, icons, labels, cooldowns and debuff borders. It has a transparency slider, color picker and Dark mode, Soft shadow, Charcoal and Purple dusk presets.
- Unit-frame class colors queue after Blizzard updates health bars and retain separate class colors for player, target, focus, party and raid units.
- Macro controls use lavender tooltip help, the main page shows **Tip: Enable Mouseover Cast in combat settings**, and bulk adding has a Mouseover on/off choice used by every eligible macro.

## New in 0.5.0

- **Fonts & colors** is the home-menu section for Font manager, Unit-frame colors and Icon styles. Each submenu has a Back button.
- Settings initialize only after this addon's SavedVariables have loaded, with a one-time legacy migration. Login no longer rebinds module settings to another table.
- FPS dragging now uses cursor coordinates directly, without StartMoving/StopMoving or the game's separate layout cache. Coordinates save during movement and on release. The minimap also saves its angle during movement. Both restore after layout changes.
- The minimap uses the standard Classic gold tracking border with the same geometry as the installed RestedXP launcher: 17px logo, 20px background and 31px transparent hit area. This replaces the larger opaque purple circle.
- Expressway tries `expressway.ttf` first, then `expressway.otf` (also accepting capitalized filenames). Both supplied files are included unmodified. Validation checks the resulting Font object, so a false SetFont return alone no longer rejects a loaded font. The dropdown and help text reflect both formats.

## Unit-frame colors

Open **Fonts & colors > Unit-frame colors**, or `/ft colors`. Enable all groups together or individually choose Player, Target, Party, Raid and Focus. These switches color Blizzard health bars using the unit's class. NPC reaction colors, dead/offline colors and power-bar colors remain native. Classic and compact party/raid frames are supported; nameplates and third-party unit-frame addons are not targeted. Disable a switch to restore the latest native color. Changes to switches during combat wait until combat ends; already-enabled colors continue following normal health-bar updates.

## Icon styles

Open **Fonts & colors > Icon styles**, or `/ft icons`. Independently enable action-bar and buff/debuff shading, choose a preset, and adjust transparency, shading color and Blizzard-border color. No Masque, SharedMedia or skin-pack addon is required.

The module styles Blizzard action bars and the player's buff/debuff/weapon-enchant icons. It crops the icon slightly and replaces neutral slot artwork with the chosen edge. Cooldowns, checked/usable/highlight states, counts, key bindings and debuff-type borders remain under Blizzard's control. Disable an area or choose **Restore default icons** to restore its original artwork. Styling and discovery of new aura buttons defer during combat; previews remain interactive. Third-party action-bar addons are not included in this initial implementation.

## Position check after updating

Move both widgets once, lock the FPS counter, then use `/rl` and also test logout/login. The previous settings file inspected during development had no minimap angle and had default FPS coordinates; older positions already lost from that file cannot be reconstructed by this release. The update preserves any coordinates that remain saved.

Automated Lua 5.1 checks cover actual late SavedVariables initialization, legacy migration, complete settings-table serialization across reloads, saving during drag, both font formats, independent class-color toggles, native-color restoration, icon-style restoration and combat deferral. Actual appearance and persistence still require testing in the Forever game client.

## New in 0.4.2

- Fixed the minimap startup error caused by calling SetUserPlaced on a frame that uses custom angle-based dragging rather than WoW's movable-frame API. Saved-angle dragging and position restoration remain active.
- The regression harness now enforces the movable/resizable requirement and reproduces the original failure before the fix.

## New in 0.4.1

- Included the supplied Expressway OpenType file and updated its font-picker path.

## New in 0.4.0

- FPS position saves only after an actual drag, in UIParent coordinates with the screen dimensions. Locking/closing no longer resaves a potentially shifted position. Screen-size changes preserve the relative screen position; temporary startup clamping does not overwrite the saved location.
- Both movable widgets avoid WoW's separate frame-position cache and reapply their saved location after world entry and scale/layout changes. The minimap saves its last drag angle, including at logout, and updates when the minimap changes size.
- **Font manager** is a separate home-menu module with nine independently enabled areas: action-bar labels, cooldown numbers, unit-frame text, portrait damage/healing, scrolling combat text, native world damage/healing, chat, tooltips and quest text.
- Each supported text area has a font dropdown, original/custom size, outline, preview and reset. Everything defaults to off. Changes save automatically, restore originals when disabled, and wait until combat ends before applying.

Move the minimap icon and FPS counter to the desired locations once after updating, then test `/rl` and logout/login. Existing numeric positions are retained, but any drift already written by the old version cannot be reconstructed.

## Font manager: fonts and compatibility

**Included:** Inter Regular (static TrueType, v4.1, with its SIL Open Font License). Friz Quadrata, Arial Narrow, Morpheus and Skurri use the game's own font files. More installed fonts are discovered through LibSharedMedia-3.0 when another addon provides it; no extra library is required for the included choices.

**Expressway:** both user-supplied `expressway.ttf` and `expressway.otf` are included in `Media/Fonts/`. Select **Expressway** in Font manager; the first successfully loaded format is used, preferring TTF. Fully restart WoW after adding font files so the client discovers them. SharedMedia providers remain supported. Operating-system font installation alone does not make a font accessible to WoW. An unsupported or missing font leaves the current choice intact and shows an explanation mentioning both formats. Other fonts such as Roboto Condensed are supported when registered by an installed SharedMedia provider.

The module targets Blizzard's frames and font objects, not arbitrary third-party unit frames/action bars. Unsupported or not-yet-loaded text areas report that no matching text is loaded. **Reapply fonts** refreshes matching objects after another addon changes their styling. An external addon that continually replaces its fonts must be configured in that addon.

**World damage/healing** sets the client's `DAMAGE_TEXT_FONT` selection. Its engine-rendered numbers share a font; separate damage/healing styles and their size/outline are not exposed here. Log out to character selection and back in after changing or disabling this area. This setting is client-dependent: some builds ignore the override. No game files are replaced. Scrolling combat text and unit-frame hits are separate areas; the game may control animation size itself. Font manager does not enable combat text that is switched off in WoW's settings.

The positions and font changes have regression coverage in a Lua 5.1 test harness, including scaled coordinates, repeated serialized reloads, missing fonts, independent area restoration and combat deferral. Actual rendering and persistence still need testing in the Forever client.

Font sources: https://rsms.me/inter/download/ ; https://github.com/rsms/inter/releases/tag/v4.1
SharedMedia API: https://www.wowace.com/projects/libsharedmedia-3-0/pages/api-documentation

## Previous update (0.3.1)

- A smaller minimap button encloses the logo in a purple circle. Hide minimap icon uses a map icon, as does its toggle in the home menu.
- Subtle vertical gradients add depth to rounded menus and controls.
- Spell lists prefer the live spell texture, then fall back to the original catalogue icon when the game does not resolve a spell (especially other classes). This does not override automatic icons on imported action-bar macros.
- The macro preview is directly editable and saves locally as you type.
- Advanced is a separate screen, opened with **Advanced...**. It has class, spell and rank dropdowns and an obvious **Back** button. Rank selection is hidden when it does not apply.
- Load template, Save draft and Save to WoW buttons have been removed from Advanced. Editing is local and automatic; the existing **Add selected macro** action in the normal view remains the deliberate way to import or replace a game macro.

## Other features

- A custom silver/lavender FT logo appears before the home-menu title and on the minimap. Home uses a transparent hearthstone-style icon. The home menu includes “Made by Krilar”.
- Minimap button moved closer to the rim. Left-drag it around the minimap; its angle is saved. Left-click opens the menu; right-click offers **Hide minimap icon**. Re-enable it from `/ft` using the existing minimap toggle.
- The FPS counter starts on by default. Its single on/off toggle, free movement, saved font size/position, and original GameFontNormal gold/brown appearance remain.
- Rank arrows/labels are hidden for macros without selectable ranks, including generic utilities.
- **Add all [class icon] Hunter macros** follows the class selected in the Classes browser. Importing another class shows a warning. The confirmation remembers the class shown when you opened it. Delete still targets your own class and still requires two confirmations, without announcing the second step in the first popup.

## Macro names and icons

Class-specific macros are created with the name consisting of one space, so no label is drawn on the action button. Generic macros keep their names. All imports use WoW's automatic question-mark icon with `#showtooltip`, allowing the client to resolve the spell's own icon; hardcoded catalogue icons no longer override imported macros. In-addon spell rows request the live game spell texture and fall back to the original catalogue icon when it is unavailable.

Class duplicates are checked by full macro text in the Character tab, not their shared blank names. Re-importing an identical class macro applies the blank name and automatic icon to that existing macro without duplicating it or changing its text. Differently edited text is not silently overwritten. General macros are never used as the destination for class macros.

## Mouseover

Targeted friendly and offensive templates expose the mouseover toggle. Friendly templates use help/nodead with target/self fallback. Offensive templates, including Hammer of Justice, use harm/nodead with enemy-target fallback.

The entire existing catalogue was reviewed under this policy. Self-only abilities, generic utility macros, and non-unit-targeted spells do not expose mouseover. Explicit exclusions are Consecration, Freezing Trap, Frost Nova, Psychic Scream, Howl of Terror, Thunder Clap, War Stomp, Swipe, and the queued next-swing attacks Heroic Strike, Cleave, Maul and Raptor Strike. Actual spell behavior remains governed by your game build; this library is not a spellbook scan.

## Editing and save log

Select a macro and type directly in its preview. The current text saves immediately to the addon's saved preferences. After a pause, on leaving a field/screen, or at logout, changes are grouped into a revision in the save log. No installed WoW macro is changed by typing, choosing builder options, or restoring a saved version.

Click **Advanced...** to open the separate builder:

- The class dropdown chooses a class, your racial abilities, or generic utilities. The spell dropdown lists that group's templates. Class spells default to max rank; select a specific rank from the rank dropdown when ranks exist.
- Target/Mouseover/Focus/Self, Shift/Ctrl/Alt, Stop casting first and Start attack update the editable text live. Targeting options follow the selected template's capabilities.
- These builder options regenerate the first `/cast` line and control exact `/stopcasting` and `/startattack` lines, while retaining other command lines. Inspect a manually written complex cast expression after applying a builder option.
- Edits save automatically in the addon. There are no separate load-template or save buttons.
- **Back** returns to the normal view with the edited spell selected and its locally saved text visible.
- The save log is per template and persists between sessions. Click a version to restore it locally; older versions remain available through its page arrows.

Use **Add selected macro** in the normal view when you want the locally edited text installed in WoW. If a matching installed macro exists, the addon offers Replace macro / Cancel. Replacement rechecks the existing slot and logs the before/after versions. Creation and replacement are blocked in combat and enforce the 255-byte limit. Local drafts may be longer while you work. Bulk class import continues to use the original max-rank templates.

## Deletion

Delete my class macros matches your own class's unchanged templates in Character macros, including blank names and older named/prefixed imports. It excludes General macros, racials and customized contents. Both confirmations remain mandatory. If macros change while confirmation is open, changed candidates are skipped. Deleting can leave unused action-bar slots.

## Validation

Lua 5.1 simulations cover navigation, saved preferences, minimap dragging/hiding, default always-on FPS, all nine class catalogues' mouseover policy, rank visibility, live icon lookup, blank-name duplicate handling, captured cross-class confirmations, macro editor conditions, manual text preservation, replacement/cancellation, stale-slot and combat protection, byte limits, and revision persistence. Additional checks cover local-only editing, persisted previews, class/spell/rank dropdown selection, Back navigation, catalogue fallback icons, and circular minimap assets. Visual layout and actual spell casts require an in-game check.

Logo source PNGs and in-game TGA textures are in Media. See ARTWORK.md for generation details.
