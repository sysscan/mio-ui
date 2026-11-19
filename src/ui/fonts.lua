local Theme = require("ui/theme.lua")

local Fonts = {}

function Fonts.apply(label: TextLabel | TextButton | TextBox, weight: string?, themeOverride: { [string]: any }?)
	if typeof(label) ~= "Instance" or not (label:IsA("TextLabel") or label:IsA("TextButton") or label:IsA("TextBox")) then
		return false
	end
	local theme = themeOverride or Theme.get()
	weight = if typeof(weight) == "string" then string.lower(weight) else weight
	local font = theme.font
	local fontFace = theme.fontFace

	if weight == "bold" then
		font = theme.fontBold or font
		fontFace = theme.fontFaceBold or fontFace
	elseif weight == "medium" then
		font = theme.fontMedium or font
		fontFace = theme.fontFaceMedium or fontFace
	end

	label.Font = font
	if fontFace then
		pcall(function()
			local target = label :: any
			target.FontFace = fontFace
		end)
	end
	return true
end

return Fonts
