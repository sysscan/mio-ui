local Services = require("core/services.lua")
local Util = require("core/util.lua")
local Theme = require("ui/theme.lua")
local P = require("ui/primitives.lua")
local Common = require("ui/components/common.lua")

local UserInputService = Services.UserInputService

return function(section: Instance, spec, ctx)
	local theme = ctx.theme
	local key = spec.key

	local defaultColor = if typeof(spec.default) == "Color3" then spec.default else theme.accent
	local color = ctx.config[key]
	if typeof(color) ~= "Color3" then
		color = defaultColor
		ctx.config[key] = color
	end
	local h, s, v = color:ToHSV()

	local root = P.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, theme.rowHeight),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = section,
	})
	P.listLayout(root, theme.controlGap or 8)

	local header = P.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, theme.rowHeight),
		Parent = root,
	})
	P.paddingXY(header, 6, 0)
	P.label(header, spec.label or key, {
		Theme = theme,
		Size = UDim2.new(1, -40, 1, 0),
		TextColor3 = theme.textDim,
		Font = theme.fontMedium,
		TextSize = theme.textSize - 1,
	})
	local swatchBtn = P.create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Size = UDim2.fromOffset(26, 12),
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = false,
		Parent = header,
	}) :: TextButton
	P.corner(swatchBtn, theme.cornerSmall)
	local swatchStroke = P.stroke(swatchBtn, theme.outline or theme.strokeBright, 1, 0)

	local panel = P.create("Frame", {
		BackgroundColor3 = theme.surfaceAlt,
		Size = UDim2.new(1, 0, 0, 144),
		Visible = false,
		Parent = root,
	})
	P.corner(panel, theme.cornerSmall)
	local panelStroke = P.stroke(panel, theme.strokeBright, 1, 0.34)
	P.padding(panel, 10)

	local svBox = P.create("Frame", {
		Size = UDim2.new(1, -30, 0, 98),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		Parent = panel,
	})
	P.corner(svBox, theme.cornerSmall)
	P.create("UIGradient", {
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = svBox,
	})
	local blackOverlay = P.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		Parent = svBox,
	})
	P.corner(blackOverlay, 4)
	P.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Parent = blackOverlay,
	})
	local svCursor = P.create("Frame", {
		Size = UDim2.fromOffset(8, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = blackOverlay,
	})
	P.corner(svCursor, 4)
	P.stroke(svCursor, Color3.new(0, 0, 0), 1)

	local hueBar = P.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(20, 98),
		Parent = panel,
	}) :: Frame
	P.corner(hueBar, theme.cornerSmall)
	P.create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
			ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
			ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
			ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
			ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
		}),
		Parent = hueBar,
	})
	local hueCursor = P.create("Frame", {
		Size = UDim2.new(1, 4, 0, 3),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = hueBar,
	})
	P.stroke(hueCursor, Color3.new(0, 0, 0), 1)

	local presetRow = P.create("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 0, 104),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	P.listLayout(presetRow, 5, Enum.FillDirection.Horizontal)

	local control = {}
	local presetStrokes = {}

	local function applyToConfig(fire: boolean)
		color = Color3.fromHSV(h, s, v)
		ctx.config[key] = color
		swatchBtn.BackgroundColor3 = color
		svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(0.5, h)
		if fire then
			if spec.onChange then
				Common.safeCall(ctx, "color onChange " .. tostring(key), spec.onChange, color)
			end
			ctx.dispatch(key, color, "color")
		end
	end

	function control.set(c: Color3, silent: boolean?)
		if typeof(c) ~= "Color3" then
			c = defaultColor
		end
		local previous = color
		h, s, v = c:ToHSV()
		applyToConfig(not silent and c ~= previous)
	end
	function control.get(): Color3
		return color
	end
	control.setValue = control.set
	control.getValue = control.get

	for _, preset in (spec.presets or Theme.colorPresets) do
		local pv = typeof(preset) == "table" and preset.value or preset
		if typeof(pv) ~= "Color3" then
			continue
		end
		local b = P.create("TextButton", {
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = pv,
			Text = "",
			AutoButtonColor = false,
			Parent = presetRow,
		}) :: TextButton
		P.corner(b, theme.cornerSmall)
		local presetStroke = P.stroke(b, theme.stroke, 1, 0.45)
		table.insert(presetStrokes, presetStroke)
		Common.connect(ctx, b.MouseButton1Click, function()
			control.set(pv)
		end)
	end

	local activeSVInput: InputObject? = nil
	local activeHueInput: InputObject? = nil
	local function updateSV(px: number, py: number)
		local pos = svBox.AbsolutePosition
		local size = svBox.AbsoluteSize
		s = Util.clamp((px - pos.X) / math.max(size.X, 1), 0, 1)
		v = 1 - Util.clamp((py - pos.Y) / math.max(size.Y, 1), 0, 1)
		applyToConfig(true)
	end
	local function updateHue(py: number)
		local pos = hueBar.AbsolutePosition
		local size = hueBar.AbsoluteSize
		h = Util.clamp((py - pos.Y) / math.max(size.Y, 1), 0, 1)
		applyToConfig(true)
	end

	Common.connect(ctx, svBox.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if activeSVInput or activeHueInput then return end
			activeSVInput = input
			activeHueInput = nil
			updateSV(input.Position.X, input.Position.Y)
		end
	end)
	Common.connect(ctx, hueBar.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if activeSVInput or activeHueInput then return end
			activeHueInput = input
			activeSVInput = nil
			updateHue(input.Position.Y)
		end
	end)
	ctx.maid:give(UserInputService.InputChanged:Connect(function(input)
		if activeSVInput and ((activeSVInput.UserInputType == Enum.UserInputType.Touch and input == activeSVInput)
			or (activeSVInput.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.MouseMovement)) then
			updateSV(input.Position.X, input.Position.Y)
		elseif activeHueInput and ((activeHueInput.UserInputType == Enum.UserInputType.Touch and input == activeHueInput)
			or (activeHueInput.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType == Enum.UserInputType.MouseMovement)) then
			updateHue(input.Position.Y)
		end
	end))
	ctx.maid:give(UserInputService.InputEnded:Connect(function(input)
		if input == activeSVInput then
			activeSVInput = nil
		end
		if input == activeHueInput then
			activeHueInput = nil
		end
	end))

	local open = false
	Common.connect(ctx, swatchBtn.MouseButton1Click, function()
		open = not open
		panel.Visible = open
	end)

	Common.onTheme(ctx, function()
		swatchStroke.Color = theme.outline or theme.strokeBright
		panel.BackgroundColor3 = theme.surfaceAlt
		panelStroke.Color = theme.strokeBright
		for _, stroke in presetStrokes do
			if stroke.Parent then
				stroke.Color = theme.stroke
			end
		end
	end)

	applyToConfig(false)
	return control
end
