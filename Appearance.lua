local _, FT = ...
local Appearance = {}
function FT:AppearanceBack(frame)
    frame.homeButton.label:SetText("Back")
    frame.homeButton:SetScript("OnClick", function() FT:OpenModule("Appearance") end)
end
function Appearance:Open()
    if not self.frame then
        self.frame = FT:Window("ForeverToolsAppearance", "ForeverTools | Fonts & colors", 440, 290)
        local entries = {
            {"Font manager", "Choose fonts, sizes and outlines for each text area.", "FontManager", "fonts"},
            {"Unitframe colors", "Class-colored health bars for player, target, party, raid and focus.", "UnitColors", "classes"},
            {"Skins", "Built-in action-bar and buff styles with color and transparency controls.", "IconStyles", "skins"},
        }
        for i, entry in ipairs(entries) do
            local target = entry[3]
            local button = FT:QuietButton(self.frame, entry[1], 392, 46, entry[4])
            button:SetPoint("TOPLEFT", 24, -68 - (i-1)*58)
            button:SetScript("OnClick", function() FT:OpenModule(target) end)
            FT:ButtonIcon(button, entry[4], 30)
            FT:Tooltip(button, entry[1], entry[2])
        end
    end
    self.frame:Show()
end
FT:RegisterModule("Appearance", Appearance)
