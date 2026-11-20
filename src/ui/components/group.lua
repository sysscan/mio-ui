local P = require("ui/primitives.lua")
local Icons = require("ui/icons.lua")
local Common = require("ui/components/common.lua")
local Toggle = require("ui/components/toggle.lua")

-- A row that opens a set of sub-options. With a toggle it reads like any other toggle row (checkbox on
-- the left, label beside it); on the right it shows how many options it holds and a chevron that turns
-- down while open.
local TOGGLE_SLOT = 24 -- puts the 12 px checkbox at x = 6, where plain toggle rows draw theirs
local LABEL_X = 26 -- plain toggle labels start here
local COUNT_WIDTH = 44

local function CountItems(items): number
	local count = 0
	for _, item in items or {} do
		if typeof(item) == "table" and item.type ~= "hint" and item.type ~= "separator" and item.type ~= "spacer" then
			count += 1
		end
	end
	return count
end

return function(section: Instance, spec, ctx)
	local theme = ctx.theme
	local toggleKey = spec.toggleKey or spec.key
	local expanded = spec.defaultExpanded == true

	local root = P.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = section,
	})
	P.listLayout(root, theme.fieldGap or 6)

	local header = P.create("Frame", {
		Size = UDim2.new(1, 0, 0, theme.rowHeight),
		BackgroundColor3 = theme.control or theme.surface,
		BackgroundTransparency = 1,
		Parent = root,
	})
	P.corner(header, theme.cornerSmall)

	local toggleReserve = toggleKey and TOGGLE_SLOT or 0
	local expandBtn = P.create("TextButton", {
		Position = UDim2.fromOffset(toggleReserve, 0),
		Size = UDim2.new(1, -toggleReserve, 1, 0),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = header,
	}) :: TextButton

	local titleX = toggleKey and (LABEL_X - TOGGLE_SLOT) or 6
	local titleLabel = P.label(expandBtn, spec.label or toggleKey or "Options", {
		Theme = theme,
		Position = UDim2.fromOffset(titleX, 0),
		Size = UDim2.new(1, -(titleX + COUNT_WIDTH + 6), 1, 0),
		TextColor3 = theme.text,
		Font = theme.fontMedium,
		TextSize = theme.textSize - 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local meta = P.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(COUNT_WIDTH, 14),
		BackgroundTransparency = 1,
		Parent = expandBtn,
	})
	local metaLayout = P.listLayout(meta, 6, Enum.FillDirection.Horizontal)
	metaLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	metaLayout.VerticalAlignment = Enum.VerticalAlignment.Center

	local itemCount = CountItems(spec.items)
	local countLabel = P.label(meta, tostring(itemCount), {
		Theme = theme,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 14),
		TextSize = theme.textSizeSmall,
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
		Visible = itemCount > 0,
	})
	local chevron = Icons.mount(meta, "tabler:chevron-right", {
		size = 12,
		color = theme.textFaint,
	})
	if chevron then
		chevron.LayoutOrder = 2
	end

	local RefreshHeader;

	if toggleKey then
		local toggleSlot = P.create("Frame", {
			Size = UDim2.new(0, TOGGLE_SLOT, 1, 0),
			BackgroundTransparency = 1,
			Parent = header,
		})
		local toggleSpec = table.clone(spec.toggleSpec or {})
		toggleSpec.type = "toggle"
		toggleSpec.key = toggleKey
		toggleSpec.label = toggleSpec.label or spec.label or toggleKey
		toggleSpec.hud = if toggleSpec.hud ~= nil then toggleSpec.hud else spec.hud
		toggleSpec.inline = true
		local control = Toggle(toggleSlot, toggleSpec, ctx)
		-- Every path that flips the switch (click, sync, mirrors) goes through set, so the title
		-- dims and brightens with it like a plain toggle's label.
		if control then
			local Set = control.set
			control.set = function( Value: boolean, Silent: boolean? )
				Set( Value, Silent );
				if ( RefreshHeader ) then RefreshHeader( ); end
			end
			control.setValue = control.set
		end
		if control and typeof(ctx.registerControl) == "function" then
			ctx.registerControl(toggleKey, control)
		elseif control and ctx.controls then
			ctx.controls[toggleKey] = control
		end
	end

	-- Sub-options sit indented behind a guide line, so it is obvious which toggle they belong to. The
	-- line lives beside the list, not in it: as a list item it took a whole row slot at the full height.
	local holder = P.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = expanded,
		Parent = root,
	})
	local Guide = P.create("Frame", {
		Position = UDim2.fromOffset(6, 2),
		Size = UDim2.new(0, 1, 1, -4),
		BorderSizePixel = 0,
		BackgroundColor3 = theme.stroke,
		Parent = holder,
	})
	local body = P.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = holder,
	})
	local BodyPadding = P.paddingXY(body, 0, 2)
	BodyPadding.PaddingLeft = UDim.new(0, 12)
	P.listLayout(body, theme.controlGap or 6)

	local Hovered = false;
	RefreshHeader = function( )
		header.BackgroundColor3 = Hovered and ( theme.controlHover or theme.overlay ) or theme.overlay;
		P.tween( header, theme.fast, { BackgroundTransparency = Hovered and 0.55 or 1 } );
		Icons.setColor( chevron, ( expanded or Hovered ) and theme.accentBright or theme.textFaint );
		countLabel.TextColor3 = expanded and theme.textDim or theme.textFaint;
		titleLabel.TextColor3 = ( toggleKey and ctx.config[ toggleKey ] ~= true ) and theme.textDim or theme.text;
		Guide.BackgroundColor3 = theme.stroke;
	end
	Common.connect( ctx, expandBtn.MouseEnter, function( )
		Hovered = true;
		RefreshHeader( );
	end )
	Common.connect( ctx, expandBtn.MouseLeave, function( )
		Hovered = false;
		RefreshHeader( );
	end )

	local function setExpanded(on: boolean, animated: boolean?)
		expanded = on
		holder.Visible = on
		-- A glyph swap, not a rotation: rotation does not render inside the scrolling page.
		if chevron then
			Icons.apply( chevron, Icons.getAsset( on and "tabler:chevron-down" or "tabler:chevron-right" ) );
		end
		RefreshHeader( );
	end

	Common.connect(ctx, expandBtn.MouseButton1Click, function()
		setExpanded(not expanded, true)
	end)

	if typeof(ctx.buildItems) == "function" then
		ctx.buildItems(body, spec.items or {}, ctx)
	end

	Common.onTheme(ctx, function()
		RefreshHeader( );
	end)

	setExpanded(expanded, false)
	return {
		setExpanded = function(on: boolean)
			setExpanded(on == true, false)
		end,
		isExpanded = function(): boolean
			return expanded
		end,
	}
end
