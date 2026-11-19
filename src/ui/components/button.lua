local P = require("ui/primitives.lua")
local Runtime = require("core/runtime.lua")
local Icons = require("ui/icons.lua")
local Common = require("ui/components/common.lua")

local BUTTON_HEIGHT = 24
local BUTTON_ICON_SIZE = 13

local function inferIcon(label: string): string?
	local lower = string.lower(label)
	if string.find(lower, "tp") or string.find(lower, "teleport") then
		return "map-pin"
	end
	if string.find(lower, "shoot") then
		return "crosshair"
	end
	if string.find(lower, "kill") then
		return "swords"
	end
	if string.find(lower, "refresh") then
		return "refresh-cw"
	end
	if string.find(lower, "view") or string.find(lower, "spectate") then
		return "eye"
	end
	if string.find(lower, "cancel") or string.find(lower, "leave") then
		return "x"
	end
	if string.find(lower, "join") then
		return "log-in"
	end
	if string.find(lower, "redeem") then
		return "ticket"
	end
	if string.find(lower, "activate") or string.find(lower, "apply") then
		return "zap"
	end
	if string.find(lower, "reset") then
		return "refresh-cw"
	end
	if string.find(lower, "set") then
		return "check"
	end
	if string.find(lower, "get") or string.find(lower, "unlock") then
		return "package"
	end
	if string.find(lower, "fling") then
		return "send"
	end
	return nil
end

return function(section: Instance, spec, ctx)
	local theme = ctx.theme
	local variant = spec.variant or "secondary"
	local labelText = spec.label or spec.text or "Run"

	local holder = P.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT),
		Parent = section,
	})

	-- Primary buttons carry the accent fill; everything else is a quiet control-coloured button.
	local Primary = variant == "primary"
	local function baseColor()
		return Primary and theme.accent or (theme.control or theme.surface)
	end
	local function hoverColor()
		return Primary and theme.accentBright or (theme.controlHover or theme.overlay)
	end

	local btn = Common.clickable(holder, theme, {
		maid = ctx.maid,
		getBaseColor = baseColor,
		getHoverColor = hoverColor,
		getHoverStrokeColor = function()
			return theme.textFaint
		end,
	})
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 0

	local row = P.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = btn,
	})
	P.listLayout(row, 6, Enum.FillDirection.Horizontal)
	local rowLayout = row:FindFirstChildOfClass("UIListLayout")
	if rowLayout then
		rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	end

	local iconName = if typeof(spec.icon) == "string" and spec.icon ~= "" then spec.icon else inferIcon(labelText)
	local icon = nil
	if iconName then
		icon = Icons.mount(row, iconName, {
			size = BUTTON_ICON_SIZE,
			color = Primary and theme.background or theme.textDim,
		})
	end

	local label = P.label(row, labelText, {
		Theme = theme,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, BUTTON_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = theme.fontMedium,
		TextColor3 = Primary and theme.background or theme.text,
		TextSize = theme.textSize - 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local LabelBounds = P.create( "UISizeConstraint", { Parent = label } );
	local function RefreshLabelBounds( )
		local Reserved = 20;
		if ( icon ) then
			Reserved += BUTTON_ICON_SIZE + 6;
		end
		LabelBounds.MaxSize = Vector2.new( math.max( 0, row.AbsoluteSize.X - Reserved ), BUTTON_HEIGHT );
	end
	Common.connect( ctx, row : GetPropertyChangedSignal( "AbsoluteSize" ), RefreshLabelBounds );
	RefreshLabelBounds( );
	if spec.getLabel then
		local resolved = Common.safeCall(ctx, "button getLabel", spec.getLabel)
		if resolved ~= nil then
			label.Text = tostring(resolved)
		end
	end

	Common.onTheme(ctx, function()
		btn.BackgroundColor3 = baseColor()
		Icons.setColor(icon, Primary and theme.background or theme.textDim)
		label.TextColor3 = Primary and theme.background or theme.text
	end)

	local busy = false
	Common.connect(ctx, btn.MouseButton1Click, function()
		if busy then
			return
		end
		busy = true
		Common.defer(ctx, "button onClick " .. tostring(spec.label or spec.id or "Run"), function()
			if spec.canClick and not Common.safeCall(ctx, "button canClick", spec.canClick) then
				busy = false
				return
			end
			local fn = spec.onClick or spec.callback
			if typeof(fn) == "function" then
				Common.safeCall(ctx, "button onClick " .. tostring(spec.label or spec.id or "Run"), fn)
			end
			if spec.getLabel then
				local resolved = Common.safeCall(ctx, "button getLabel", spec.getLabel)
				if resolved ~= nil then
					label.Text = tostring(resolved)
				end
			end
			busy = false
		end)
	end)

	return {
		getText = function(): string
			return label.Text
		end,
		setText = function(t: string)
			Runtime.deferClient(function()
				if label.Parent then
					label.Text = tostring(t)
				end
			end)
		end,
	}
end
