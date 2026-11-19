local P = require("ui/primitives.lua")
local Common = require("ui/components/common.lua")

-- A square checkbox to the left of the label, shaded top to bottom like the classic script menus.
local BOX = 12
local LABEL_INDENT = BOX + 8

local function makeSwitch(parent: Instance, theme, state: boolean)
	local switch = P.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(BOX, BOX),
		BackgroundColor3 = state and theme.accent or (theme.control or theme.surface),
		BorderSizePixel = 0,
		Parent = parent,
	})
	P.corner(switch, 2)
	local stroke = P.stroke(switch, theme.outline or theme.stroke, 1, 0)
	local shade = P.gradient(switch, Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165), 90)
	return switch, stroke, shade
end

return function(section: Instance, spec, ctx)
	local theme = ctx.theme
	local key = spec.key
	local rawState = ctx.config[key]
	local state = if rawState == nil then spec.default == true else rawState == true
	ctx.config[key] = state

	if spec.hud then
		ctx.registerHud(key, tostring(spec.hud))
	end

	local host = section
	local label = nil
	local clickParent = section
	if not spec.inline then
		local row, rowLabel = Common.row(section, theme, spec.label or key, nil, 0)
		rowLabel.Position = UDim2.fromOffset(LABEL_INDENT, 0)
		rowLabel.Size = UDim2.new(1, -LABEL_INDENT, 1, 0)
		host = row
		clickParent = row
		label = rowLabel
	end

	local switch, stroke, shade = makeSwitch(host, theme, state)
	if spec.inline then
		switch.AnchorPoint = Vector2.new(0.5, 0.5)
		switch.Position = UDim2.fromScale(0.5, 0.5)
	end

	local btn = P.create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.fromScale(1, 1),
		Parent = clickParent,
	}) :: TextButton

	local hovered = false
	local control = {}

	local function render(animated: boolean)
		local time = animated and (theme.normal or 0.14) or 0
		P.tween(switch, time, {
			BackgroundColor3 = state and theme.accent or (hovered and (theme.controlHover or theme.overlay) or (theme.control or theme.surface)),
		})
		stroke.Color = hovered and theme.strokeBright or (theme.outline or theme.stroke)
		stroke.Transparency = 0

		if label then
			label.TextColor3 = state and theme.text or theme.textDim
		end
	end

	function control.set(value: boolean, silent: boolean?)
		local nextState = value == true
		local changed = nextState ~= state
		state = nextState
		ctx.config[key] = state
		render(changed)
		if changed and not silent then
			if spec.onChange then
				Common.safeCall(ctx, "toggle onChange " .. tostring(key), spec.onChange, state)
			end
			ctx.dispatch(key, state, "toggle")
		end
	end

	function control.get(): boolean
		return state
	end
	control.setValue = control.set
	control.getValue = control.get

	Common.connect(ctx, btn.MouseEnter, function()
		hovered = true
		if not spec.inline then
			P.tween(host, theme.fast or 0.1, { BackgroundTransparency = 0.55 })
		end
		render(true)
	end)
	Common.connect(ctx, btn.MouseLeave, function()
		hovered = false
		if not spec.inline then
			P.tween(host, theme.fast or 0.1, { BackgroundTransparency = 1 })
		end
		render(true)
	end)
	Common.connect(ctx, btn.MouseButton1Click, function()
		control.set(not state)
	end)

	render(false)
	Common.onTheme(ctx, function()
		render(false)
	end)

	return control
end
