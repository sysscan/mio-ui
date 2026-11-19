local Services = require("core/services.lua")
local Util = require("core/util.lua")
local P = require("ui/primitives.lua")
local Common = require("ui/components/common.lua")

local UserInputService = Services.UserInputService
local TRACK_HEIGHT = 8
local VALUE_WIDTH = 50
-- One line: label on the left 42%, a flat bar in the middle, the editable value on the right.
local LABEL_SHARE = 0.42
local TRACK_INSET = 0

return function(section: Instance, spec, ctx)
	local theme = ctx.theme
	local key = spec.key
	local function finite(value, fallback: number): number
		local numberValue = tonumber(value)
		if numberValue == nil or numberValue ~= numberValue or numberValue == math.huge or numberValue == -math.huge then
			return fallback
		end
		return numberValue
	end
	local minV = finite(spec.min, 0)
	local maxV = finite(spec.max, minV + 1)
	if maxV <= minV then
		maxV = minV + 1
	end
	local step = finite(spec.step, 1)
	if step <= 0 then
		step = 1
	end
	local decimals = math.max(Util.stepDecimals(step), Util.stepDecimals(minV))
	local suffix = tostring(spec.suffix or "")
	local itemType = spec.type == "number" and "number" or "slider"

	local defaultValue = finite(spec.default, minV)
	local value = Util.snap(finite(ctx.config[key], defaultValue), minV, maxV, step)
	ctx.config[key] = value

	local row, label = Common.row(section, theme, spec.label or key, nil, 0)
	label.Size = UDim2.new(LABEL_SHARE, -8, 1, 0)

	local Editor = P.create( "TextBox", {
		AnchorPoint = Vector2.new( 1, 0.5 ); Position = UDim2.new( 1, 0, 0.5, 0 );
		Size = UDim2.fromOffset( VALUE_WIDTH, 18 ); BackgroundColor3 = theme.control;
		BackgroundTransparency = 1; BorderSizePixel = 0; Text = ""; ClearTextOnFocus = false;
		TextColor3 = theme.textDim; Font = theme.font; TextSize = theme.textSizeSmall;
		FontFace = theme.fontFace; TextXAlignment = Enum.TextXAlignment.Right;
		Parent = row;
	} );
	P.corner( Editor, theme.cornerSmall );
	local EditorStroke = P.stroke( Editor, theme.stroke, 1, 1 );

	local track = P.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(LABEL_SHARE, TRACK_INSET, 0.5, 0),
		Size = UDim2.new(1 - LABEL_SHARE, -(TRACK_INSET * 2 + VALUE_WIDTH + 8), 0, TRACK_HEIGHT),
		BackgroundColor3 = theme.control,
		BorderSizePixel = 0,
		Parent = row,
	})
	local trackStroke = P.stroke(track, theme.outline or theme.stroke, 1, 0)
	P.gradient(track, Color3.new(1, 1, 1), Color3.fromRGB(175, 175, 175), 90)

	local fill = P.create("Frame", {
		BackgroundColor3 = theme.accent,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	local fillGradient = P.gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165), 90)

	local function format(v: number): string
		if decimals > 0 then
			return string.format("%." .. decimals .. "f%s", v, suffix)
		end
		return string.format("%d%s", v, suffix)
	end

	local function render(animated: boolean?)
		local alpha = (value - minV) / (maxV - minV)
		local clamped = Util.clamp(alpha, 0, 1)
		fill.Size = UDim2.fromScale(clamped, 1)
		if ( not Editor : IsFocused( ) ) then Editor.Text = format( value ); end
	end

	local control = {}

	function control.set(v: number, silent: boolean?)
		local nextValue = Util.snap(finite(v, defaultValue), minV, maxV, step)
		local changed = nextValue ~= value
		value = nextValue
		ctx.config[key] = value
		render(changed)
		if changed and not silent then
			if spec.onChange then
				Common.safeCall(ctx, "slider onChange " .. tostring(key), spec.onChange, value)
			end
			ctx.dispatch(key, value, itemType)
		end
	end

	function control.get(): number
		return value
	end
	control.setValue = control.set
	control.getValue = control.get

	render(false)
	Common.connect( ctx, Editor.Focused, function( )
		Editor.Text = tostring( value ); EditorStroke.Color = theme.accent; EditorStroke.Transparency = 0;
		Editor.BackgroundTransparency = 0; Editor.TextColor3 = theme.text;
	end );
	Common.connect( ctx, Editor.FocusLost, function( )
		local Number = tonumber( Editor.Text );
		if ( Number and Number == Number and math.abs( Number ) ~= math.huge ) then control.set( Number ); end
		Editor.Text = format( value );
		EditorStroke.Transparency = 1;
		Editor.BackgroundTransparency = 1; Editor.TextColor3 = theme.textDim;
	end );
	Common.connect( ctx, Editor.InputBegan, function( Input )
		if ( not Editor : IsFocused( ) ) then return; end
		local Direction = 0;
		if ( Input.KeyCode == Enum.KeyCode.Up ) then Direction = 1; end
		if ( Input.KeyCode == Enum.KeyCode.Down ) then Direction = -1; end
		if ( Direction == 0 ) then return; end
		local Multiplier = 1;
		if ( UserInputService : IsKeyDown( Enum.KeyCode.LeftShift ) or UserInputService : IsKeyDown( Enum.KeyCode.RightShift ) ) then Multiplier = 10; end
		control.set( finite( tonumber( Editor.Text ), value ) + Direction * step * Multiplier );
		Editor.Text = tostring( value );
	end );

	local activeInput: InputObject? = nil
	local function updateFromX(x: number)
		local absPos = track.AbsolutePosition.X
		local absSize = track.AbsoluteSize.X
		local alpha = Util.clamp((x - absPos) / math.max(absSize, 1), 0, 1)
		control.set(minV + alpha * (maxV - minV))
	end

	Common.connect(ctx, track.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if activeInput then return end
			activeInput = input
			updateFromX(input.Position.X)
		end
	end)
	local hit = P.create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(1 - LABEL_SHARE, -(VALUE_WIDTH + 6), 1, 0),
		Position = UDim2.new(LABEL_SHARE, 0, 0, 0),
		Parent = row,
	}) :: TextButton
	Common.connect(ctx, hit.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if activeInput then return end
			activeInput = input
			updateFromX(input.Position.X)
		end
	end)

	ctx.maid:give(UserInputService.InputChanged:Connect(function(input)
		if not activeInput then
			return
		end
		if activeInput.UserInputType == Enum.UserInputType.Touch then
			if input == activeInput then
				updateFromX(input.Position.X)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			updateFromX(input.Position.X)
		end
	end))
	ctx.maid:give(UserInputService.InputEnded:Connect(function(input)
		if input == activeInput then
			activeInput = nil
		end
	end))

	Common.onTheme(ctx, function()
		Editor.BackgroundColor3 = theme.control;
		Editor.TextColor3 = Editor : IsFocused( ) and theme.text or theme.textDim;
		EditorStroke.Color = theme.accent;
		track.BackgroundColor3 = theme.control
		trackStroke.Color = theme.outline or theme.stroke
		fill.BackgroundColor3 = theme.accent
		fillGradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(165, 165, 165))

	end)

	return control
end
