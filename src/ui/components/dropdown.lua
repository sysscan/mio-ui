local P = require("ui/primitives.lua")
local Icons = require("ui/icons.lua")
local Common = require("ui/components/common.lua")
local Maid = require("core/maid.lua")

local function optValue(o)
	return typeof(o) == "table" and o.value or o
end

local function optLabel(o)
	if typeof(o) == "table" then
		return tostring(o.label or o.value)
	end
	return tostring(o)
end

local OPTION_HEIGHT = 22
local OPTION_GAP = 2
local LIST_PADDING = 5
local MAX_VISIBLE = 7
local CONTROL_SHARE = 0.52
-- Long fixed lists and every dynamic list (players, catalogs, saved spots) get a search field.
local SEARCH_THRESHOLD = 12

return function(section: Instance, spec, ctx)
	local theme = ctx.theme
	local key = spec.key
	local multi = spec.multi == true or spec.multiple == true
	if ctx.config[key] == nil then
		if multi then
			ctx.config[key] = if typeof(spec.default) == "table" then table.clone(spec.default) else {}
		else
			ctx.config[key] = spec.default
		end
	end

	local root = P.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = section,
	})
	P.listLayout(root, theme.fieldGap or 6)

	local headerHost, fieldLabel = Common.row(root, theme, spec.label or key, nil, 0)
	fieldLabel.Size = UDim2.new(1 - CONTROL_SHARE, -8, 1, 0)

	local header = Common.clickable(headerHost, theme, {
		maid = ctx.maid,
		baseColor = theme.control or theme.surface,
		hoverColor = theme.controlHover or theme.overlay,
		stroke = true,
	})
	header.AnchorPoint = Vector2.new(1, 0.5)
	header.Position = UDim2.new(1, 0, 0.5, 0)
	header.Size = UDim2.new(CONTROL_SHARE, 0, 0, theme.controlHeight or 26)
	P.paddingXY(header, 9, 0)

	local valueLabel = P.label(header, "", {
		Theme = theme,
		Size = UDim2.new(1, -28, 1, 0),
		TextColor3 = theme.text,
		Font = theme.fontMedium,
		TextSize = theme.textSizeSmall,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local chevron = Icons.mount(header, "tabler:chevron-down", {
		size = 13,
		color = theme.textFaint,
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
	})

	local listHost = P.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		ClipsDescendants = true,
		Visible = false,
		Parent = root,
	})

	local listFrame = P.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 0),
		Size = UDim2.new(CONTROL_SHARE, -6, 1, 0),
		BackgroundColor3 = theme.elevated,
		BorderSizePixel = 0,
		Parent = listHost,
	})
	P.corner(listFrame, theme.cornerSmall)

	local listStroke = P.stroke(listFrame, theme.stroke, 1, 0.15)

	local scroll = P.create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0,
		ScrollBarImageColor3 = theme.textFaint,
		ScrollBarImageTransparency = 0.4,
		Parent = listFrame,
	})
	P.padding(scroll, LIST_PADDING)
	P.listLayout(scroll, OPTION_GAP)

	local SearchBox;
	local EmptyLabel;
	local Searchable = spec.searchable == true or typeof( spec.getOptions ) == "function"
		or ( typeof( spec.options ) == "table" and #spec.options > SEARCH_THRESHOLD );
	local SearchHeight = Searchable and 34 or 0;
	if ( SearchHeight > 0 ) then
		listFrame.Size = UDim2.fromScale( 1, 1 );
		SearchBox = P.create( "TextBox", {
			Position = UDim2.fromOffset( LIST_PADDING, LIST_PADDING ),
			Size = UDim2.new( 1, -LIST_PADDING * 2, 0, 26 ),
			BackgroundColor3 = theme.control,
			BorderSizePixel = 0,
			Text = "",
			PlaceholderText = "Search items",
			ClearTextOnFocus = false,
			FontFace = theme.fontFace,
			TextSize = theme.textSizeSmall,
			TextColor3 = theme.text,
			PlaceholderColor3 = theme.textFaint,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = listFrame,
		} );
		P.corner( SearchBox, theme.cornerSmall );
		P.paddingXY( SearchBox, 7, 0 );
		scroll.Position = UDim2.fromOffset( 0, SearchHeight );
		scroll.Size = UDim2.new( 1, 0, 1, -SearchHeight );
		EmptyLabel = P.label( scroll, "No matches", {
			Theme = theme,
			Size = UDim2.new( 1, 0, 0, OPTION_HEIGHT ),
			TextColor3 = theme.textFaint,
			TextSize = theme.textSizeSmall,
			Visible = false,
		} );
	end

	local options = {}
	local optionButtons = {}
	local initialized = false
	local renderedValue = nil
	local optionMaid = Maid.new()
	ctx.maid:give(function()
		optionMaid:destroy()
	end)

	local open = false

	local function openHeight(): number
		local count = 0;
		for _, Entry in optionButtons do
			if ( Entry.button.Visible ) then
				count += 1;
			end
		end
		if ( SearchBox ) then
			count = math.max( 1, count );
		end
		if count == 0 then
			return 0
		end
		local content = count * OPTION_HEIGHT + (count - 1) * OPTION_GAP + LIST_PADDING * 2
		local ceiling = MAX_VISIBLE * OPTION_HEIGHT + (MAX_VISIBLE - 1) * OPTION_GAP + LIST_PADDING * 2
		return SearchHeight + math.min(content, ceiling)
	end

	local function FilterOptions( )
		local Query = SearchBox and string.lower( SearchBox.Text ) or "";
		Query = string.gsub( string.gsub( Query, "^%s+", "" ), "%s+$", "" );
		local Matches = 0;
		for _, Entry in optionButtons do
			local Visible = string.find( string.lower( Entry.label.Text ), Query, 1, true ) ~= nil;
			Entry.button.Visible = Visible;
			if ( Visible ) then
				Matches += 1;
			end
		end
		if ( EmptyLabel ) then
			EmptyLabel.Visible = Matches == 0;
		end
		scroll.CanvasPosition = Vector2.zero;
		if ( open ) then
			listHost.Size = UDim2.new( 1, 0, 0, openHeight( ) );
		end
	end
	if ( SearchBox ) then
		Common.connect( ctx, SearchBox : GetPropertyChangedSignal( "Text" ), FilterOptions );
	end

	local function currentValues()
		if multi then
			local v = ctx.config[key]
			if typeof(v) ~= "table" then
				v = {}
				ctx.config[key] = v
			end
			return v
		end
		return ctx.config[key]
	end

	local function isSelected(value): boolean
		if multi then
			for _, v in currentValues() do
				if v == value then
					return true
				end
			end
			return false
		end
		return ctx.config[key] == value
	end

	local function summary(): string
		if multi then
			local labels = {}
			for _, o in options do
				if isSelected(optValue(o)) then
					table.insert(labels, optLabel(o))
				end
			end
			if #labels == 0 then
				return "None"
			end
			if #labels > 2 then
				return ("%d selected"):format(#labels)
			end
			return table.concat(labels, ", ")
		end
		for _, o in options do
			if optValue(o) == ctx.config[key] then
				return optLabel(o)
			end
		end
		return options[1] and optLabel(options[1]) or "-"
	end

	local control = {}

	local function refreshSelection()
		valueLabel.Text = summary()
		for _, entry in optionButtons do
			local on = isSelected(entry.value)

			entry.button.BackgroundColor3 = on and (theme.accentFaint or theme.accentDim) or theme.elevated
			if entry.stripe then
				entry.stripe.Visible = on
				entry.stripe.BackgroundColor3 = theme.accent
			end
			if entry.checkIcon then
				entry.checkIcon.Visible = on
				Icons.setColor(entry.checkIcon, on and theme.accentBright or theme.textFaint)
			end
			if entry.boxIcon then
				entry.boxIcon.Visible = not on
			end
			entry.label.TextColor3 = on and theme.text or theme.textDim
		end
	end

	local function choose(value)
		local nextValue
		if multi then

			local list = table.clone(currentValues())
			local idx = table.find(list, value)
			if idx then
				table.remove(list, idx)
			else
				table.insert(list, value)
			end
			nextValue = list
		else
			nextValue = value
		end
		control.set(nextValue)
		if not multi then control.setOpen(false) end
	end

	local function valuesEqual(a, b): boolean
		if not multi then
			return a == b
		end
		if typeof(a) ~= "table" or typeof(b) ~= "table" or #a ~= #b then
			return false
		end
		for index, value in a do
			if b[index] ~= value then
				return false
			end
		end
		return true
	end

	local function snapshot(value)
		return if multi and typeof(value) == "table" then table.clone(value) else value
	end

	local function normalizeValue(value)
		if #options == 0 then
			return if multi and typeof(value) ~= "table" then {} else value
		end
		local valid = {}
		for _, option in options do
			local optionValue = optValue(option)
			if optionValue ~= nil then
				valid[optionValue] = true
			end
		end
		if multi then
			local filtered = {}
			if typeof(value) == "table" then
				for _, selected in value do
					if valid[selected] and table.find(filtered, selected) == nil then
						table.insert(filtered, selected)
					end
				end
			end
			return filtered
		end
		return if valid[value] then value else optValue(options[1])
	end

	function control.getValue()
		local value = currentValues()
		return if multi then table.clone(value) else value
	end
	control.get = control.getValue

	function control.set(value, silent: boolean?)
		local previous = snapshot(if initialized then renderedValue else currentValues())
		value = normalizeValue(value)
		if multi then
			ctx.config[key] = if typeof(value) == "table" then table.clone(value) else {}
		else
			ctx.config[key] = value
		end
		refreshSelection()
		local changed = not valuesEqual(previous, ctx.config[key])
		renderedValue = snapshot(ctx.config[key])
		if changed and not silent then
			if spec.onChange then
				Common.safeCall(ctx, "select onChange " .. tostring(key), spec.onChange, ctx.config[key])
			end
			ctx.dispatch(key, ctx.config[key], "select")
		end
	end
	function control.setValue(value, dispatchChange: boolean?)
		control.set(value, dispatchChange == false)
	end

	local function rebuild()
		optionMaid:destroy()
		optionMaid = Maid.new()
		for _, entry in optionButtons do
			entry.button:Destroy()
		end
		table.clear(optionButtons)
		for _, o in options do
			local value = optValue(o)
			local b = Common.clickable(scroll, theme, {
				maid = optionMaid,
				getBaseColor = function()
					return isSelected(value) and (theme.accentFaint or theme.accentDim) or theme.elevated
				end,
				hoverColor = theme.controlHover or theme.overlay,
				stroke = false,
			})
			b.Size = UDim2.new(1, 0, 0, OPTION_HEIGHT)

			local stripe = P.create("Frame", {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 3, 0.5, 0),
				Size = UDim2.new(0, 2, 1, -12),
				BackgroundColor3 = theme.accent,
				BorderSizePixel = 0,
				Visible = false,
				Parent = b,
			})
			P.corner(stripe, 1)

			local inner = P.create("Frame", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Parent = b,
			})
			P.paddingXY(inner, 9, 0)
			local rowLayout = P.listLayout(inner, 8, Enum.FillDirection.Horizontal)
			rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center

			local checkIcon: ImageLabel? = nil
			local boxIcon: ImageLabel? = nil

			if multi then
				local tickSlot = P.create("Frame", {
					Size = UDim2.fromOffset(14, 14),
					BackgroundTransparency = 1,
					Parent = inner,
				})
				boxIcon = Icons.mount(tickSlot, "tabler:square", {
					size = 12,
					color = theme.textFaint,
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.5),
				})
				checkIcon = Icons.mount(tickSlot, "tabler:square-check", {
					size = 12,
					color = theme.accentBright,
					anchorPoint = Vector2.new(0.5, 0.5),
					position = UDim2.fromScale(0.5, 0.5),
				})
				if checkIcon then
					checkIcon.Visible = false
				end
			end

			local optionLabel = P.label(inner, optLabel(o), {
				Theme = theme,
				Size = UDim2.new(1, if multi then -22 else 0, 0, 16),
				TextSize = theme.textSizeSmall,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextColor3 = theme.textDim,
			})

			Common.connect({ maid = optionMaid }, b.MouseButton1Click, function()
				choose(value)
			end)
			table.insert(optionButtons, {
				button = b,
				value = value,
				label = optionLabel,
				stripe = stripe,
				checkIcon = checkIcon,
				boxIcon = boxIcon,
			})
		end
		refreshSelection()
		FilterOptions( );
		if open then

			listHost.Size = UDim2.new(1, 0, 0, openHeight())
		end
	end

	function control.refresh()
		local previous = snapshot(if initialized then renderedValue else currentValues())
		options = {}
		local source = spec.options or {}
		if typeof(spec.getOptions) == "function" then
			local ok, resolved = pcall(spec.getOptions)
			if ok and typeof(resolved) == "table" then
				source = resolved
			elseif not ok then
				Common.warn(ctx, "select getOptions", key, "->", resolved)
			end
		end
		for _, o in source do
			table.insert(options, o)
		end
		ctx.config[key] = normalizeValue(currentValues())
		rebuild()
		local changed = not valuesEqual(previous, ctx.config[key])
		renderedValue = snapshot(ctx.config[key])
		if initialized and changed then
			if spec.onChange then
				Common.safeCall(ctx, "select onChange " .. tostring(key), spec.onChange, ctx.config[key])
			end
			ctx.dispatch(key, ctx.config[key], "select")
		end
		initialized = true
	end

	local function paintHeaderStroke()
		local stroke = header:FindFirstChildOfClass("UIStroke")
		if not stroke then
			return
		end
		if open then
			stroke.Color = theme.accent
			stroke.Transparency = 0.3
		else
			stroke.Color = theme.stroke
			stroke.Transparency = 0.35
		end
	end

	function control.setOpen(value: boolean)

		if value and #optionButtons == 0 and not SearchBox then
			value = false
		end
		open = value
		if ( SearchBox and not value ) then
			SearchBox : ReleaseFocus( );
			SearchBox.Text = "";
		end

		local time = theme.fast or 0.07
		if value then
			listHost.Visible = true
		end
		local tween = P.tween(listHost, time, {
			Size = UDim2.new(1, 0, 0, if value then openHeight() else 0),
		})
		if not value then

			if tween then
				tween.Completed:Once(function()
					if not open then
						listHost.Visible = false
					end
				end)
			else
				listHost.Visible = false
			end
		end

		if chevron then
			-- Swap the glyph instead of rotating it: Roblox does not draw rotation inside a clipping
			-- ancestor, and every menu control sits in a scrolling page.
			Icons.apply(chevron, Icons.getAsset(if value then "tabler:chevron-up" else "tabler:chevron-down"))
			Icons.setColor(chevron, if value then theme.accentBright else theme.textFaint)
		end
		paintHeaderStroke()
	end

	Common.connect(ctx, header.MouseButton1Click, function()
		if not open and typeof(spec.getOptions) == "function" then
			control.refresh()
		end
		control.setOpen(not open)
	end)

	Common.connect(ctx, header.MouseLeave, function()
		if open then
			paintHeaderStroke()
		end
	end)

	control.refresh()
	Common.onTheme(ctx, function()
		if ( SearchBox ) then
			SearchBox.BackgroundColor3 = theme.control;
			SearchBox.TextColor3 = theme.text;
			SearchBox.PlaceholderColor3 = theme.textFaint;
			EmptyLabel.TextColor3 = theme.textFaint;
		end
		fieldLabel.TextColor3 = theme.textDim
		header.BackgroundColor3 = theme.control or theme.surface
		valueLabel.TextColor3 = theme.text
		listFrame.BackgroundColor3 = theme.elevated
		listStroke.Color = theme.stroke
		scroll.ScrollBarImageColor3 = theme.textFaint
		paintHeaderStroke()
		Icons.setColor(chevron, open and theme.accentBright or theme.textFaint)
		refreshSelection()
	end)

	return control
end
