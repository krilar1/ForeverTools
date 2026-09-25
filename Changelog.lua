local _,FT=...
-- Short player-facing notes for the "What's new" window. Newest first.
FT.changelog={
    {version="0.14.2",notes={
        "New: dispel glow. A colored outline on player, target, focus, party or raid-style frames while they have a debuff you can remove (Fonts & colors → Unitframe colors). Off by default.",
        "New: profile exports can include all your keybinds, and importing applies them (Profiles → Export / Import).",
        "Mouse-wheel binding is now deliberate: click a spell in Custom keybinds, then scroll to bind it. Scrolling the list only pages it.",
        "New characters now ask whether to use a saved profile or start a new one.",
        "New: optional rounded background for leveling stats, with color and transparency.",
        "Buff reminders: choose where self and group notices appear — open world, cities, dungeons, raids and PvP.",
        "Every popup now has the same close button.",
        "Fixes: no more gap in the dark-mode target health bar next to the portrait, and XP per hour starts with your first kill.",
    }},
    {version="0.13.6",notes={
        "Everything now starts off on new installs, so the game looks like Blizzard's until you choose otherwise. Existing setups are unchanged.",
        "New: a short first-time setup with Minimal, Dark mode and Full presets. Run it again from System → General.",
        "New: new characters automatically use your profile. Choose which one in Profiles → New characters. New profiles start from default settings, and Profiles → Default settings returns everything to Blizzard's defaults.",
        "Mouse-wheel casting on mouseover (Custom keybinds) now works; away from a unit the wheel still zooms the camera.",
        "New: leveling stats with XP per hour, time to level, kills to level, XP and rested XP. Choose which to show, their order, and one per line or all on one line (System → Gameplay).",
        "New: an optional low-rank marker on action bars, with per-spell exceptions (Buff reminders).",
        "New: auto-sell grey items and auto-repair, each opt-in (System → Gameplay).",
        "New: clickable links in chat that open a copy box (Chat).",
        "New: search settings from the /ft home window.",
        "New: copy a bug report from System → Troubleshooting.",
        "Guild names in player tooltips are plain white by default; faction colors are an option on the Tooltip page.",
        "System is now split into General, Minimap, Gameplay and Troubleshooting. Tooltip IDs moved to the Tooltip page.",
        "Fixes: totem bar dark mode, weapon-enchant buff borders, weapon buff reminder, grouped minimap buttons and the target health bar.",
    }},
}
