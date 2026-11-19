local P = require("ui/primitives.lua")
local Common = require("ui/components/common.lua")

return function(section: Instance, spec, ctx)
	local theme = ctx.theme
	local key = spec.key

	local initial = ctx.config[key]
	if initial == nil then
		initial = if spec.default == nil then "" else tostring(spec.default)
	else
		initial = tostring(initial)
	end
	if spec.numeric and initial ~= "" and tonumber(initial) == nil then
		initial = if tonumber(spec.default) ~= nil then tostring(tonumber(spec.default)) else ""
	end
	ctx.config[key] = initial

	local inline = spec.layout == "inline"
	local parentRow, controlSlot
	if inline then
		parentRow = Common.row(section, theme, spec.label or key, theme.rowHeight + 4, 132)
		controlSlot = parentRow
	else
		local field
		field, _, controlSlot = Common.field(section, theme, spec.label or key, theme.controlHeight or 30)
		parentRow = field
	end

	local box = P.create("TextBox", {
		Size = if inline
			then UDim2.fromOffset(132, 26)
			else UDim2.new(1, 0, 1, 0),
		AnchorPoint = if inline then Vector2.new(1, 0.5) else nil,
		Position = if inline then UDim2.new(1, 0, 0.5, 0) else UDim2.fromOffset(0, 0),
		BackgroundColor3 = theme.control or theme.surface,
		Text = initial,
		PlaceholderText = spec.placeholder or "",
		Font = theme.font,
		FontFace = theme.fontFace,
		TextSize = theme.textSizeSmall,
		TextColor3 = theme.text,
		PlaceholderColor3 = theme.textFaint,
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = controlSlot,
	}) :: TextBox
	P.corner(box, theme.cornerSmall)
	local stroke = P.stroke(box, theme.stroke, 1, 0.35)
	P.paddingXY(box, 10, 0)

	local control = {}
	local focused = false
	local Hovered = false;

	local function RefreshSurface( Animated: boolean )
		local Highlighted = focused or Hovered;
		local Background = theme.control or theme.surface;
		if ( Highlighted ) then
			Background = theme.controlHover or theme.overlay;
		end
		P.tween( box, Animated and ( theme.fast or 0.1 ) or 0, { BackgroundColor3 = Background } );
		stroke.Color = theme.stroke;
		stroke.Transparency = 0.35;
		if ( Hovered ) then
			stroke.Color = theme.strokeBright;
			stroke.Transparency = 0.18;
		end
		if ( focused ) then
			stroke.Color = theme.accent;
			stroke.Transparency = 0;
		end
	end

	Common.connect( ctx, box.MouseEnter, function( )
		Hovered = true;
		RefreshSurface( true );
	end )
	Common.connect( ctx, box.MouseLeave, function( )
		Hovered = false;
		RefreshSurface( true );
	end )
	function control.get(): string
		return box.Text or ""
	end
	function control.set(text: string, silent: boolean?)
		local nextText = if text == nil then "" else tostring(text)
		if spec.numeric and nextText ~= "" then
			local numeric = tonumber(nextText)
			nextText = if numeric ~= nil then tostring(numeric)
				else (if tonumber(spec.default) ~= nil then tostring(tonumber(spec.default)) else "")
		end
		local changed = nextText ~= (box.Text or "")
		box.Text = nextText
		ctx.config[key] = nextText
		if changed and not silent then
			if spec.onChange then
				Common.safeCall(ctx, "text onChange " .. tostring(key), spec.onChange, nextText)
			end
			ctx.dispatch(key, nextText, "text")
		end
	end
	control.setValue = control.set
	control.getValue = control.get

	Common.connect(ctx, box.Focused, function()
		focused = true
		RefreshSurface( true );
	end)
	Common.connect(ctx, box.FocusLost, function()
		focused = false
		RefreshSurface( true );

		local before = tostring(ctx.config[key] or "")
		local text = box.Text or ""
		if spec.numeric then
			if text == "" then
				ctx.config[key] = ""
			else
				local n = tonumber(text)
				ctx.config[key] = n and tostring(n) or ctx.config[key]
				box.Text = ctx.config[key]
			end
		else
			ctx.config[key] = text
		end
		if ctx.config[key] == before then
			return
		end
		if spec.onChange then
			Common.safeCall(ctx, "text onChange " .. tostring(key), spec.onChange, ctx.config[key])
		end
		ctx.dispatch(key, ctx.config[key], "text")
	end)

	Common.onTheme(ctx, function()
		RefreshSurface( false );
		box.TextColor3 = theme.text
		box.PlaceholderColor3 = theme.textFaint
	end)

	return control
end
