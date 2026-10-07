local _, FT = ...
-- Appearance is a group of pages (Fonts, Unit frames, Skins, Chat, Tooltip):
-- see Hubs.lua. Its pages go back to the main menu.
function FT:AppearanceBack(frame)
    frame.homeButton:SetScript("OnClick", function() FT:OpenHome() end)
end
