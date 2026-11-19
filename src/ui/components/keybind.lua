local Services = require("core/services.lua")
local Input = require("core/input.lua")
local P = require("ui/primitives.lua")
local Common = require("ui/components/common.lua")

local UserInputService = Services.UserInputService

return function(section: Instance, spec, ctx)
	local theme = ctx.theme
	local key = spec.key

	local MOUSE_BUTTON_LABELS = {}
	local MOUSE_KEYCODE_LABELS = {}
	local SIDE_MOUSE_KEYCODES = {}

	for _, inputType in Enum.UserInputType:GetEnumItems() do
		local number = string.match(inputType.Name, "^MouseButton(%d+)$")
		if number then
			MOUSE_BUTTON_LABELS[inputType] = "Mouse" .. number
		end
	end

	local knownMouseKeyLabels = {
		MouseLeftButton = "Mouse1",
		MouseRightButton = "Mouse2",
		MouseMiddleButton = "Mouse3",
		MouseBackButton = "Mouse4",
		MouseForwardButton = "Mouse5",
		MouseXButton1 = "Mouse4",
		MouseXButton2 = "Mouse5",
	}
	for _, keyCode in Enum.KeyCode:GetEnumItems() do
		local label = knownMouseKeyLabels[keyCode.Name]
		if label then
			MOUSE_KEYCODE_LABELS[keyCode] = label
			if label == "Mouse4" or label == "Mouse5" then
				SIDE_MOUSE_KEYCODES[keyCode] = true
			end
		end
	end

	local function validBinding(value): boolean
		if typeof(value) ~= "EnumItem" then
			return false
		end
		if ( spec.isValidBinding and not spec.isValidBinding( value ) ) then
			return false;
		end
		if value.EnumType == Enum.KeyCode then
			return true
		end
		return value.EnumType == Enum.UserInputType and MOUSE_BUTTON_LABELS[value] ~= nil
	end

	local defaultBinding = if validBinding(spec.default) then spec.default else Enum.KeyCode.Unknown
	local bound = if validBinding(ctx.config[key]) then ctx.config[key] else defaultBinding
	ctx.config[key] = bound

	local row = Common.row(section, theme, spec.label or key, nil, 66)

	local btn = Common.clickable(row, theme, {
		maid = ctx.maid,
		baseColor = theme.control or theme.surface,
		hoverColor = theme.controlHover or theme.overlay,
	})
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, 0, 0.5, 0)
	btn.Size = UDim2.fromOffset(64, theme.controlHeight or 21)
	local btnLabel = P.label(btn, "", {
		Theme = theme,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = theme.textSizeSmall,
		TextColor3 = theme.accentBright,
		Font = theme.fontMedium,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local liveHandle = nil
	local listenConn = nil
	local control = {}

	local function displayName(value): string
		if value == Enum.KeyCode.Unknown then
			return spec.noneLabel or "None"
		end
		return MOUSE_BUTTON_LABELS[value] or MOUSE_KEYCODE_LABELS[value] or value.Name
	end

	local function render()
		btnLabel.Text = displayName(bound)
	end

	local function rebindLive()
		if liveHandle then
			liveHandle.disconnect()
			liveHandle = nil
		end
		if spec.mode and bound ~= Enum.KeyCode.Unknown then
			liveHandle = ctx.maid:give(Input.bind("ui." .. key, bound, spec.mode, function(state)
				if spec.onChange then
					Common.safeCall(ctx, "keybind callback " .. tostring(key), spec.onChange, state)
				end
			end))
		end
	end

	function control.set(k: EnumItem, silent: boolean?)
		-- Keep the previous assignment when a control rejects a captured key.
		if ( spec.isValidBinding and not spec.isValidBinding( k ) ) then
			ctx.config[ key ] = bound;
			render( );
			return;
		end
		local nextBinding = if validBinding(k) then k else defaultBinding
		local changed = nextBinding ~= bound
		bound = nextBinding
		ctx.config[key] = bound
		render()
		rebindLive()
		if changed and not silent then
			ctx.dispatch(key, bound, "keybind")
		end
	end
	function control.get(): EnumItem
		return bound
	end
	control.setValue = control.set
	control.getValue = control.get

	local function captureBinding(input: InputObject): (EnumItem?, boolean)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Unknown then
				return nil, false
			elseif input.KeyCode == Enum.KeyCode.Escape then
				return nil, true
			elseif input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Delete then
				return Enum.KeyCode.Unknown, true
			end
			return input.KeyCode, true
		elseif SIDE_MOUSE_KEYCODES[input.KeyCode] == true then
			return input.KeyCode, true
		elseif MOUSE_BUTTON_LABELS[input.UserInputType] ~= nil then
			return input.UserInputType, true
		elseif input.KeyCode ~= Enum.KeyCode.Unknown and MOUSE_KEYCODE_LABELS[input.KeyCode] ~= nil then
			return input.KeyCode, true
		end
		return nil, false
	end

	local listening = false
	Common.connect(ctx, btn.MouseButton1Click, function()
		if listening then
			return
		end
		listening = true
		btnLabel.Text = "..."
		if listenConn then
			listenConn:Disconnect()
		end
		listenConn = UserInputService.InputBegan:Connect(function(input)
			local captured, done = captureBinding(input)
			if not done then
				return
			end
			listenConn:Disconnect()
			listenConn = nil
			listening = false
			if captured then
				control.set(captured)
			else
				render()
			end
		end)
	end)
	ctx.maid:give(function()
		if listenConn then
			listenConn:Disconnect()
			listenConn = nil
		end
	end)

	render()
	rebindLive()
	Common.onTheme(ctx, function()
		btn.BackgroundColor3 = theme.control or theme.surface
		btnLabel.TextColor3 = theme.accentBright
	end)
	return control
end
