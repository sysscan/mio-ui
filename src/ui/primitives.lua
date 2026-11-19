local Services = require("core/services.lua")
local Theme = require("ui/theme.lua")

local TweenService = Services.TweenService

local P = {}
local activeTweens = setmetatable({}, { __mode = "k" })

function P.create(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local inst = Instance.new(className)
	if props then
		local parent = props.Parent
		local fontFace = props.FontFace
		for key, value in pairs(props) do
			if key ~= "Parent" and key ~= "FontFace" then
				inst[key] = value
			end
		end
		if fontFace ~= nil then
			pcall(function()
				(inst :: any).FontFace = fontFace
			end)
		end
		if parent then
			inst.Parent = parent
		end
	end
	if children then
		for _, child in children do
			child.Parent = inst
		end
	end
	return inst
end

function P.corner(parent: Instance, radius: number?): UICorner
	return P.create("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = parent })
end

function P.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return P.create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

function P.padding(parent: Instance, all: number): UIPadding
	return P.create("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		Parent = parent,
	})
end

function P.paddingXY(parent: Instance, x: number, y: number): UIPadding
	return P.create("UIPadding", {
		PaddingTop = UDim.new(0, y),
		PaddingBottom = UDim.new(0, y),
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		Parent = parent,
	})
end

function P.listLayout(parent: Instance, spacing: number?, dir: Enum.FillDirection?): UIListLayout
	return P.create("UIListLayout", {
		Padding = UDim.new(0, spacing or 4),
		FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = parent,
	})
end

function P.gradient(
	parent: Instance,
	startColor: Color3,
	endColor: Color3,
	rotation: number?
): UIGradient
	return P.create("UIGradient", {
		Color = ColorSequence.new(startColor, endColor),
		Rotation = rotation or 0,
		Parent = parent,
	})
end

function P.accentStripe(parent: Instance, theme, width: number?): Frame
	return P.create("Frame", {
		Size = UDim2.new(0, width or 3, 1, 0),
		BackgroundColor3 = theme.accent,
		BorderSizePixel = 0,
		Parent = parent,
	}) :: Frame
end

function P.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local theme = (props and props.Theme) or Theme.get()
	local merged = {
		BackgroundTransparency = 1,
		Font = theme.font or Enum.Font.Gotham,
		FontFace = theme.fontFace,
		Text = text,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(236, 237, 245),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}
	if props then
		for key, value in pairs(props) do
			if key ~= "Theme" then
				merged[key] = value
			end
		end
	end
	if merged.Font == theme.fontBold and theme.fontFaceBold then
		merged.FontFace = theme.fontFaceBold
	elseif merged.Font == theme.fontMedium and theme.fontFaceMedium then
		merged.FontFace = theme.fontFaceMedium
	elseif merged.FontFace == nil then
		merged.FontFace = theme.fontFace
	end
	return P.create("TextLabel", merged) :: TextLabel
end

function P.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?): Tween?
	local previous = activeTweens[inst]
	if previous then
		pcall(function()
			previous:Cancel()
		end)
		activeTweens[inst] = nil
	end

	if time <= 0 then
		for key, value in props do
			inst[key] = value
		end
		return nil :: any
	end

	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(inst, info, props)
	activeTweens[inst] = tween
	local completed
	local destroying
	destroying = inst.Destroying:Connect(function()
		if activeTweens[inst] == tween then
			activeTweens[inst] = nil
		end
		pcall(function() tween:Cancel() end)
		if completed then completed:Disconnect() end
		if destroying then destroying:Disconnect() end
	end)
	completed = tween.Completed:Connect(function()
		completed:Disconnect()
		destroying:Disconnect()
		if activeTweens[inst] == tween then
			activeTweens[inst] = nil
		end
	end)
	tween:Play()
	return tween
end

return P
