local Services = require("core/services.lua")
local Runtime = require("core/runtime.lua")
local Input = require("core/input.lua")
local ConfigStore = require("core/config.lua")
local Theme = require("ui/theme.lua")
local Icons = require("ui/icons.lua")
local Window = require("ui/window.lua")
local Hud = require("ui/hud.lua")
local Overlay = require( "ui/overlay.lua" );
local Notify = require("ui/notify.lua")
local P = require("ui/primitives.lua")
local Common = require("ui/components/common.lua")
local Occlusion = require("visuals/occlusion.lua")
local EspControls = require( "visuals/esp/controls.lua" );
local FeatureWorkspace = require( "ui/workspace.lua" );
local Appearance = require( "ui/appearance.lua" );
local Organize = require( "ui/organize.lua" );

local UserInputService = Services.UserInputService
local HttpService = Services.HttpService

local COMPONENTS = {
	toggle = require("ui/components/toggle.lua"),
	slider = require("ui/components/slider.lua"),
	number = require("ui/components/slider.lua"),
	select = require("ui/components/dropdown.lua"),
	color = require("ui/components/colorpicker.lua"),
	keybind = require("ui/components/keybind.lua"),
	button = require("ui/components/button.lua"),
	text = require("ui/components/textbox.lua"),
	label = require("ui/components/label.lua"),
	hint = require("ui/components/label.lua"),
	separator = require("ui/components/label.lua"),
	spacer = require("ui/components/label.lua"),
	badge = require("ui/components/label.lua"),
	group = require("ui/components/group.lua"),
	collapsible = require("ui/components/group.lua"),
	profiles = require( "ui/components/profiles.lua" );
	segmented = require( "ui/components/segmented.lua" );
}

-- Hub-wide settings (menu key, accent, ...) persist independently of any
-- single game's config, so every game shares one save under microhub/configs.
local HUB_CONFIG_NAME = "hub"
local HUB_SETTINGS_DEFAULTS = {
	MenuKey = Enum.KeyCode.RightShift,
	AccentColor = Color3.fromRGB(238, 72, 150),
	-- Tracked separately from AccentColor: the color picker component always
	-- writes a resolved concrete color back into its config key on first
	-- construction (even with no user interaction), so that alone can't tell
	-- "user picked a color" apart from "component just initialized."
	AccentCustomized = false,
	Favorites = { };
	CollapsedSections = { };
	BackgroundStyle = "Brand";
	MenuScale = 1;
	ReducedMotion = false;
	Density = "Comfortable";
	ShowWatermark = true;
	ShowKeybindList = true;
}

local function scaleColor(c: Color3, factor: number): Color3
	return Color3.new(
		math.clamp(c.R * factor, 0, 1),
		math.clamp(c.G * factor, 0, 1),
		math.clamp(c.B * factor, 0, 1)
	)
end

local function tintColor(c: Color3, amount: number): Color3
	return Color3.new(
		c.R + (1 - c.R) * amount,
		c.G + (1 - c.G) * amount,
		c.B + (1 - c.B) * amount
	)
end

-- Derives the rest of the accent-driven palette from a single picked color,
-- approximating the ratios used by the shipped brand palettes (see
-- src/brand/*.json) so a custom accent still looks coherent everywhere.
local function applyAccent(theme, accent: Color3)
	theme.accent = accent
	theme.accentBright = tintColor(accent, 0.45)
	theme.accentDim = scaleColor(accent, 0.46)
	theme.accentSoft = scaleColor(accent, 0.87)
	theme.accentFaint = scaleColor(accent, 0.23)
	theme.strokeBright = tintColor(scaleColor(accent, 0.75), 0.12)
end

local ACCENT_KEYS = { "accent", "accentBright", "accentDim", "accentSoft", "accentFaint", "strokeBright" }

local function brandPaletteFor(theme, overrides)
	local palette = {}
	for _, key in ACCENT_KEYS do
		local override = typeof(overrides) == "table" and overrides[key] or nil
		palette[key] = if typeof(override) == "Color3" then override else Theme.brandPalette[key] or theme[key]
	end
	return palette
end

local function restoreAccentPalette(theme, palette)
	for _, key in ACCENT_KEYS do
		theme[key] = palette[key]
	end
end

local function copyToClipboard(text: string): boolean
	local ok = Runtime.callExecutor("setclipboard", text)
	return ok == true
end

-- Whitelists keys against the config's own defaults so an imported blob can't
-- inject arbitrary fields, then decodes Color3/EnumItem the same way autosave does.
local function applyImportedConfig(configTable, configName: string?, json: string): (boolean, string?)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, json)
	if not ok or typeof(decoded) ~= "table" then
		return false, "That isn't valid JSON."
	end
	local defaults = configName and ConfigStore.defaults(configName)
	local allowed = defaults or configTable
	local applied = 0
	for key, value in decoded do
		if typeof(key) == "string" and allowed[key] ~= nil then
			configTable[key] = ConfigStore.decodeValue(value)
			applied += 1
		end
	end
	if applied == 0 then
		return false, "No recognized settings in that JSON."
	end
	if configName then
		ConfigStore.markDirty(configName)
	end
	return true, applied .. " setting(s) imported."
end

local UI = {}
UI.version = "7.4.0"
UI.colorPresets = Theme.colorPresets
UI.icons = Icons
UI.notify = Notify.push
UI.dismissNotification = Notify.dismiss
UI.clearNotifications = Notify.destroy

local KEYED_TYPES = {
	toggle = true,
	slider = true,
	number = true,
	select = true,
	color = true,
	keybind = true,
	text = true,
}

local TYPE_ALIASES = {
	dropdown = "select",
	multiselect = "select",
	textbox = "text",
	input = "text",
}

local function uiWarn(...)
	warn("[Hub][UI]", ...)
end

local function safeCall(label: string, fn, ...)
	if typeof(fn) ~= "function" then
		return nil
	end
	local ok, result = pcall(fn, ...)
	if not ok then
		uiWarn(label, "->", result)
		return nil
	end
	return result
end

local function shallowCopy(tbl)
	local copy = {}
	for key, value in pairs(tbl or {}) do
		copy[key] = value
	end
	return copy
end

local function normalizeItem(item)
	if typeof(item) ~= "table" then
		return nil
	end
	local copy = shallowCopy(item)
	local itemType = copy.type
	if itemType == nil and copy.key and copy.label then
		itemType = "toggle"
	end
	if typeof(itemType) == "string" then
		-- `multiselect` is a behavioral alias, not only a renderer alias. Preserve
		-- that intent before normalizing it to the shared select component.
		if itemType == "multiselect" then
			copy.multi = true
		end
		itemType = TYPE_ALIASES[itemType] or itemType
	end
	if copy.multiple == true then
		copy.multi = true
	end
	copy.type = itemType
	if ( itemType == "profiles" ) then
		copy.profiles = { };
		for _, Profile in item.profiles or { } do
			local Entry = shallowCopy( Profile );
			Entry.items = { };
			for _, Child in Profile.items or { } do
				local Normalized = normalizeItem( Child );
				if ( Normalized ) then
					table.insert( Entry.items, Normalized );
				end
			end
			table.insert( copy.profiles, Entry );
		end
	end
	return copy
end

local GROUP_BREAK_TYPES = {
	toggle = true,
	separator = true,
	group = true,
	profiles = true,
	collapsible = true,
	button = true,
	hint = true,
	label = true,
	keybind = true,
	text = true,
	badge = true,
	spacer = true,
}

local COMPACT_NEST_TYPES = {
	slider = true,
	select = true,
	color = true,
	number = true,
}

local function compactItems(items: { any }): { any }
	local compacted = {}
	local index = 1
	while index <= #items do
		local item = items[index]
		if item.type == "group" or item.type == "collapsible" then
			table.insert(compacted, item)
			index += 1
			continue
		end
		if item.type == "toggle" and item.compact ~= false and not item.nogroup then
			local nested = {}
			index += 1
			while index <= #items do
				local nextItem = items[index]
				if GROUP_BREAK_TYPES[nextItem.type] then
					break
				end
				if not COMPACT_NEST_TYPES[nextItem.type] then
					break
				end
				table.insert(nested, nextItem)
				index += 1
			end
			if #nested > 0 then
				table.insert(compacted, {
					type = "group",
					label = item.label,
					toggleKey = item.key,
					hud = item.hud,
					hint = item.hint,
					description = item.description,
					tooltip = item.tooltip,
					hintTitle = item.hintTitle,
					toggleSpec = shallowCopy(item),
					defaultExpanded = item.defaultExpanded,
					items = nested,
				})
			else
				table.insert(compacted, item)
			end
		else
			table.insert(compacted, item)
			index += 1
		end
	end
	return compacted
end

local function normalizeSection(section, uiOpts)
	if typeof(section) ~= "table" then
		return nil
	end
	local items = {}
	for _, item in section.items or {} do
		local normalized = normalizeItem(item)
		if normalized then
			if normalized.type == "group" or normalized.type == "collapsible" then
				local nested = {}
				for _, child in normalized.items or {} do
					local childItem = normalizeItem(child)
					if childItem then
						table.insert(nested, childItem)
					end
				end
				normalized.items = nested
			end
			table.insert(items, normalized)
		end
	end
	for _, item in section.toggles or {} do
		local normalized = normalizeItem(item)
		if normalized then
			table.insert(items, normalized)
		end
	end
	if section.compact == true or (section.compact ~= false and uiOpts and uiOpts.compact == true) then
		items = compactItems(items)
	end
	return {
		title = section.title,
		items = items,
		compact = section.compact,
		collapsible = section.collapsible,
		order = section.order,
	}
end

local function buildPages(opts)
	if typeof(opts.pages) == "table" and #opts.pages > 0 then
		local pages = {}
		for _, page in opts.pages do
			if typeof(page) == "table" then
				local sections = {}
				for _, section in page.sections or {} do
					local normalized = normalizeSection(section, opts)
					if normalized then
						table.insert(sections, normalized)
					end
				end
				table.insert(pages, {
					label = page.label or page.title or "Page",
					icon = page.icon,
					sections = sections,
					order = page.order,
				})
			end
		end
		return pages
	end

	local sections = {}
	for _, section in opts.sections or {} do
		local normalized = normalizeSection(section, opts)
		if normalized then
			table.insert(sections, normalized)
		end
	end

	local footerItems = (opts.footer and opts.footer.items) or {}
	if #footerItems > 0 then
		local footer = { title = "ACTIONS", items = {} }
		for _, item in footerItems do
			local normalized = normalizeItem(item)
			if normalized then
				table.insert(footer.items, normalized)
			end
		end
		table.insert(sections, footer)
	end

	return { { label = "Menu", sections = sections } }
end

local function describeItem(item)
	return tostring(item.key or item.id or item.label or item.text or item.type or "<unnamed>")
end

function UI.create(opts)
	opts = opts or {}
	local config = opts.config or {}
	local configName = opts.configName
	local theme = table.clone( Theme.merge( opts.theme ) );
	-- The live menu palette (accent edits land on this table), read by drawn overlays such as the radar so
	-- they share the menu's accent.
	UI.activeTheme = theme;
	local Maid = require("core/maid.lua")
	local maid = Maid.new()

	-- Shared across every game/brand this session: menu keybind + accent
	-- customization live here, separate from the per-game config passed in.
	local hubSettings = ConfigStore.new(HUB_CONFIG_NAME, HUB_SETTINGS_DEFAULTS)
	theme.touch = UserInputService.TouchEnabled == true;
	local AppearanceBase = table.clone( theme );
	Appearance.apply( theme, AppearanceBase, hubSettings );
	local brandPalette = brandPaletteFor(theme, opts.theme)
	local brandDefaultAccent = brandPalette.accent
	if hubSettings.AccentCustomized == true and typeof(hubSettings.AccentColor) == "Color3" then
		applyAccent(theme, hubSettings.AccentColor)
	else
		hubSettings.AccentCustomized = false
		hubSettings.AccentColor = brandDefaultAccent
		restoreAccentPalette(theme, brandPalette)
	end

	local hudEntries = {}
	local themeListeners = {}
	local hudShowKey = (opts.hud and opts.hud.showKey) or "ShowHUD"

	local window = Window.new({ title = opts.title, maid = maid, theme = theme, touch = theme.touch })
	window.sectionPreferences = hubSettings.CollapsedSections;
	window.sectionScope = tostring( configName or opts.title or "default" );
	window.onSectionCollapse = function( ) ConfigStore.markDirty( HUB_CONFIG_NAME ); end;
	local hudOk, hudOrError = pcall(Hud.new, opts.title or Theme.brandName, theme)
	if not hudOk then
		maid:destroy()
		window:destroy()
		error(hudOrError)
	end
	local hud = hudOrError

	-- The watermark and keybind list are extras: if they cannot be built the menu still works.
	local OverlayOk, OverlayOrError = pcall( Overlay.New, { Theme = theme, Brand = Theme.brandName, Game = opts.title or "" } );
	local overlay = OverlayOk and OverlayOrError or nil;
	if ( not OverlayOk ) then
		uiWarn( "overlay unavailable ->", OverlayOrError );
	end

	-- The Drawing layer composites ABOVE ScreenGuis, so without this the ESP
	-- paints straight over the window. Registering the instances (rather than
	-- pushing coordinates) means dragging, resizing, hiding or re-theming the
	-- window all keep working with no further bookkeeping.
	--
	-- The HUD is registered too. It has no panel behind it by design, so a
	-- skeleton or trail crossing it would otherwise render its outlined text
	-- unreadable -- which is the thing the readout exists to avoid.
	Occlusion.watch("hub.window", window.shell)
	Occlusion.watch("hub.hud", hud.container)
	Occlusion.watch( "hub.pill", window.pill );
	Occlusion.watch( "hub.reopen", window.floatingButton );
	if ( overlay ) then
		local Containers = overlay : Containers( );
		Occlusion.watch( "hub.watermark", Containers[ 1 ] );
		Occlusion.watch( "hub.keybinds", Containers[ 2 ] );
	end
	maid:give(function()
		Occlusion.unwatch("hub.window")
		Occlusion.unwatch("hub.hud")
		Occlusion.unwatch( "hub.pill" );
		Occlusion.unwatch( "hub.reopen" );
		Occlusion.unwatch( "hub.watermark" );
		Occlusion.unwatch( "hub.keybinds" );
	end)

	local refreshHud
	local RefreshOverlay;

	local Mirrors = { };
	local FeaturePages = { };
	local ctx
	ctx = {
		theme = theme,
		config = config,
		maid = maid,
		controls = {},
		controlOrder = {},
		containers = { };
		warn = uiWarn,
		safeCall = safeCall,
		registerHud = function(key, label)
			if ( opts.lazyPages == true ) then
				for _, Entry in hudEntries do
					if ( Entry.key == key ) then
						Entry.label = label;
						return;
					end
				end
			end
			table.insert(hudEntries, { key = key, label = label })
		end,
		registerControl = function(key, control)
			if key == nil or control == nil then
				return
			end
			local Existing = ctx.controls[ key ];
			if ( Existing == nil ) then
				table.insert( ctx.controlOrder, key );
			end
			-- Two controls on one key (SCP binds ESPNpcColor twice) both stay in sync: the earlier
			-- one becomes a mirror that dispatch updates alongside the newest.
			if ( Existing and Existing ~= control and typeof( Existing.set ) == "function" ) then
				Mirrors[ key ] = Mirrors[ key ] or { };
				table.insert( Mirrors[ key ], Existing );
			end
			ctx.controls[ key ] = control;
		end,
		onTheme = function(fn)
			table.insert(themeListeners, fn)
			return fn
		end,
		dispatch = function(key, value, itemType)
			local Primary = ctx.controls[ key ];
			if ( Primary and Primary.set ) then Primary.set( value, true ); end
			for _, Mirror in Mirrors[ key ] or { } do Mirror.set( value, true ); end
			if configName then
				ConfigStore.markDirty(configName)
			end
			if opts.onChange then
				safeCall("window onChange " .. tostring(key), opts.onChange, key, value, itemType)
			end
			if itemType == "toggle" then
				if opts.onToggle then
					safeCall("window onToggle " .. tostring(key), opts.onToggle, key, value)
				end
				if refreshHud then
					refreshHud(key)
				end
			end
			if ( RefreshOverlay ) then
				RefreshOverlay( );
			end
		end,
	}

	-- A select with two or three short fixed options reads better as a segmented control.
	local function IsSegmented( Item: any ): boolean
		if ( Item.type ~= "select" or Item.multi or Item.getOptions or typeof( Item.options ) ~= "table" ) then
			return false;
		end

		if ( #Item.options < 2 or #Item.options > 3 ) then
			return false;
		end

		local Length = 0;

		for _, Option in Item.options do
			Length += #( typeof( Option ) == "table" and tostring( Option.label or Option.value ) or tostring( Option ) );
		end

		return Length <= 20;
	end

	local function ButtonRun( Items: { any }, Start: number ): number
		local Count = 0;

		for Index = Start, #Items do
			if ( ( TYPE_ALIASES[ Items[ Index ].type ] or Items[ Index ].type ) ~= "button" ) then
				break;
			end

			Count += 1;
		end

		return Count;
	end

	local function buildItems( parent: Instance, items: { any } )
		local ButtonGrid = nil;

		for Index, item in items do
			if ( typeof( item.type ) ~= "string" ) then
				uiWarn( "skipping item with missing type", describeItem( item ) );
				continue;
			end

			local itemType = TYPE_ALIASES[ item.type ] or item.type;

			-- Hint text never reaches the menu (CLAUDE.md rule 3). Status readouts are data, so they stay.
			if ( itemType == "hint" and item.presentation ~= "status" ) then
				continue;
			end

			if ( itemType ~= "button" ) then
				ButtonGrid = nil;
			end

			local make = COMPONENTS[ itemType ];

			if ( IsSegmented( item ) ) then
				make = COMPONENTS.segmented;
			end

			if ( not make ) then
				uiWarn( "skipping item with invalid type", item.type, describeItem( item ) );
				continue;
			end

			if ( KEYED_TYPES[ itemType ] and not item.key ) then
				uiWarn( "skipping", itemType, "without key", describeItem( item ) );
				continue;
			end

			local buildSpec = item;

			if ( buildSpec.type ~= itemType ) then
				buildSpec = shallowCopy( item );
				buildSpec.type = itemType;
			end

			-- Runs of buttons share rows, two per row, instead of stacking full width.
			local Host = parent;

			if ( itemType == "button" and not ButtonGrid and ButtonRun( items, Index ) > 1 ) then
				ButtonGrid = P.create( "Frame", {
					BackgroundTransparency = 1;
					Size = UDim2.new( 1, 0, 0, 0 );
					AutomaticSize = Enum.AutomaticSize.Y;
					Parent = parent;
				} );
				P.create( "UIGridLayout", {
					CellSize = UDim2.new( 0.5, -2, 0, theme.touch and 32 or 22 );
					CellPadding = UDim2.fromOffset( 4, 4 );
					SortOrder = Enum.SortOrder.LayoutOrder;
					Parent = ButtonGrid;
				} );
				P.paddingXY( ButtonGrid, 6, 0 );
			end

			if ( itemType == "button" and ButtonGrid ) then
				Host = ButtonGrid;
			end

			local ok, controlOrErr = pcall( make, Host, buildSpec, ctx );

			if ( not ok ) then
				uiWarn( "failed to build", itemType, describeItem( item ), "->", controlOrErr );
				continue;
			end

			if ( itemType == "group" or itemType == "collapsible" or itemType == "profiles" ) then
				ctx.containers[ item ] = controlOrErr;
			end

			if ( controlOrErr and ( item.key or item.id ) and itemType ~= "group" and itemType ~= "collapsible" ) then
				ctx.registerControl( item.key or item.id, controlOrErr );
			end
		end
	end

	ctx.buildItems = buildItems

	local LazyPages = opts.lazyPages == true;
	local PageBuilders = { };
	local PageOrder = { };

	local function BuildPage( Index: number )
		local Builder = PageBuilders[ Index ];
		if ( not Builder ) then
			return;
		end
		PageBuilders[ Index ] = nil;
		Builder( );
	end

	local function BuildAllPages( )
		for _, Index in PageOrder do
			BuildPage( Index );
		end
	end

	local function Preseed( Items: { any } )
		for _, Item in Items do
			local Key = if ( Item.type == "group" or Item.type == "collapsible" ) then Item.toggleKey else Item.key;
			if ( Item.type == "toggle" or ( Key ~= nil and Item.toggleKey ~= nil ) ) then
				if ( Key ~= nil and config[ Key ] == nil ) then
					config[ Key ] = Item.default == true;
				end
				if ( Key ~= nil and Item.hud ) then
					ctx.registerHud( Key, tostring( Item.hud ) );
				end
			elseif ( Key ~= nil and Item.default ~= nil and config[ Key ] == nil ) then
				config[ Key ] = Item.default;
			end
			if ( Item.type == "group" and Item.toggleSpec ~= nil and Item.toggleKey ~= nil and Item.toggleSpec.hud ~= nil ) then
				ctx.registerHud( Item.toggleKey, tostring( Item.toggleSpec.hud ) );
			end
			if ( Item.items ~= nil ) then
				Preseed( Item.items );
			end
			for _, Profile in Item.profiles or { } do
				Preseed( Profile.items or { } );
			end
		end
	end

	-- Pages and their sections are put in category order (ui/organize.lua) unless the game opts out.
	local Organized = opts.organize ~= false;
	local SpecPages = buildPages( opts );

	if ( Organized ) then
		Organize.Pages( SpecPages );
	end

	for Index, Page in SpecPages do
		Page = table.clone( Page );
		Page.sections = table.clone( Page.sections or { } );
		for _, Section in EspControls.sections( opts.configName, Page ) do
			Page.sections[ #Page.sections + 1 ] = Section;
		end
		if ( Organized ) then
			Organize.Sections( Page.sections );
		end
		local PageObject = window : addPage( Page.label or "Page", Page.icon );
		Page.object = PageObject;
		Page.windowIndex = #window.pages;
		FeaturePages[ #FeaturePages + 1 ] = Page;
		local function Builder( )
			for _, Section in Page.sections or { } do
				local Body = PageObject : addSection( Section.title or "General", { collapsible = Section.collapsible } );
				buildItems( Body, Section.items or { } );
			end
		end
		if ( LazyPages and Index > 1 ) then
			PageBuilders[ Index ] = Builder;
			PageOrder[ #PageOrder + 1 ] = Index;
			for _, Section in Page.sections or { } do
				Preseed( Section.items or { } );
			end
		else
			Builder( );
		end
	end

	if ( LazyPages ) then
		window.beforeShowPage = BuildPage;
	end

	local hudShown = nil
	refreshHud = function(changedKey)
		local show = config[hudShowKey] == true
		if changedKey == hudShowKey or hudShown ~= show then
			hudShown = show
			hud:setVisible(show)
		end
		if not show then
			return
		end
		local active = {}
		for _, entry in hudEntries do
			if config[entry.key] == true then
				table.insert(active, entry.label)
			end
		end
		hud:setActive(active)
	end
	refreshHud(hudShowKey)

	local controller = {}
	controller.window = window
	controller.config = config
	controller.controls = ctx.controls

	function controller:setVisible(visible)
		if self._destroyed then return end
		window:setVisible(visible)
	end
	function controller:isVisible()
		return window:isVisible()
	end
	function controller:toggle()
		if self._destroyed then return end
		window:setVisible(not window:isVisible())
	end
	function controller:refreshHud()
		if self._destroyed then return end
		refreshHud(hudShowKey)
	end
	function controller:getControl(key)
		if self._destroyed then return nil end
		return ctx.controls[key]
	end
	function controller:syncControls(fireCallbacks: boolean?)
		if self._destroyed then return end
		BuildAllPages( );
		for _, key in ctx.controlOrder do
			local control = ctx.controls[key]
			if control and typeof(control.set) == "function" then
				safeCall("sync control " .. tostring(key), control.set, config[key], fireCallbacks ~= true)
			end
			for _, Mirror in Mirrors[ key ] or { } do Mirror.set( config[ key ], true ); end
		end
		refreshHud(hudShowKey)
	end
	function controller:refreshTheme()
		if self._destroyed then return end
		Appearance.apply( theme, AppearanceBase, hubSettings );
		Common.resizeRows( theme );
		window:refreshTheme()
		hud:refreshTheme()
		if ( overlay ) then
			overlay : RefreshTheme( );
		end
		for _, listener in themeListeners do
			safeCall("theme refresh", listener)
		end
	end
	function controller:destroy()
		if self._destroyed then
			return
		end
		self._destroyed = true
		maid:destroy()
		window:destroy()
		hud:destroy()
		if ( overlay ) then
			overlay : Destroy( );
		end
		table.clear(themeListeners)
		table.clear(ctx.controls)
		table.clear(ctx.controlOrder)
		table.clear(hudEntries)
	end
	controller.Destroy = controller.destroy

	window:setVisible(opts.startVisible ~= false)

	if ( LazyPages ) then
		task.spawn( function( )
			task.wait( opts.lazyPageDelay or 4 );
			for _, Index in PageOrder do
				if ( controller._destroyed ) then
					return;
				end
				BuildPage( Index );
				task.wait( opts.lazyPageGap or 0.15 );
			end
		end );
	end

	local defaultToggleKey = opts.toggleKey or Enum.KeyCode.RightShift
	local function IsValidMenuKey( Value ): boolean
		if ( typeof( Value ) ~= "EnumItem" ) then
			return false;
		end
		if ( Value.EnumType == Enum.KeyCode ) then
			return Value ~= Enum.KeyCode.Unknown and Value.Name ~= "MouseLeftButton" and Value.Name ~= "MouseButton1";
		end
		return Value.EnumType == Enum.UserInputType and Value ~= Enum.UserInputType.MouseButton1
			and string.match( Value.Name, "^MouseButton%d+$" ) ~= nil;
	end
	if ( not IsValidMenuKey( defaultToggleKey ) ) then
		defaultToggleKey = Enum.KeyCode.RightShift;
	end
	if ( not IsValidMenuKey( hubSettings.MenuKey ) ) then
		hubSettings.MenuKey = defaultToggleKey;
		ConfigStore.markDirty( HUB_CONFIG_NAME );
	end
	local menuToggleHandle = Input.bind("ui.menu.toggle", hubSettings.MenuKey, "press", function()
		controller:toggle()
	end, { ignoreGameProcessed = true })
	maid:give(menuToggleHandle)
	local mobileKey = opts.mobileToggleKey or Enum.KeyCode.ButtonY
	local mobileToggleHandle = nil
	local function syncMobileBinding()
		if mobileToggleHandle then
			mobileToggleHandle.disconnect()
			mobileToggleHandle = nil
		end
		if hubSettings.MenuKey ~= mobileKey then
			mobileToggleHandle = Input.bind("ui.menu.toggle.mobile", mobileKey, "press", function()
				controller:toggle()
			end, { ignoreGameProcessed = true })
		end
	end
	syncMobileBinding()
	maid:give(function()
		if mobileToggleHandle then
			mobileToggleHandle.disconnect()
			mobileToggleHandle = nil
		end
	end)

	-- Hub pages pinned in the sidebar footer: Favorites (ui/workspace.lua) and Settings, which also
	-- holds the saved configs. The
	-- header search field is wired up by the workspace as well.
	local Workspace = FeatureWorkspace( {
		window = window; context = ctx; components = COMPONENTS;
		preferences = hubSettings; scope = configName or opts.title;
		pages = FeaturePages; buildAll = BuildAllPages;
		save = function( ) ConfigStore.markDirty( HUB_CONFIG_NAME ); end;
		registerMirror = function( Key: string, Control: any )
			-- Only a settable control may mirror: a component builder can return a bare value (a slider
			-- surfaced in the header search handed back a number), and dispatch calls Mirror.set on every
			-- entry, so a non-control here would crash every later dispatch of this key -- matches the guard
			-- registerControl applies to the same Mirrors list.
			if ( typeof( Control ) ~= "table" ) or ( typeof( Control.set ) ~= "function" ) then
				return;
			end
			Mirrors[ Key ] = Mirrors[ Key ] or { };
			table.insert( Mirrors[ Key ], Control );
		end;
	} );
	controller.featureSearch = Workspace.search;

	local function KeyName( Value: any ): string
		if ( typeof( Value ) == "EnumItem" and Value.Name ~= "Unknown" ) then
			return Value.Name;
		end

		if ( typeof( Value ) == "string" and Value ~= "" and Value ~= "Unknown" ) then
			return Value;
		end

		return "None";
	end

	-- Keybind list: every keybind on a feature page, named after its own label or, for generic
	-- labels like "Toggle Key", the group or section it sits in. A bind is shown as on when the
	-- toggle it belongs to is on (the enclosing group's toggle, the toggle its key is named after,
	-- or the first toggle beside it); actions with no toggle show as on whenever they are bound.
	local OverlayBinds = { };
	local GENERIC_BIND_LABELS = { [ "key" ] = true, [ "keybind" ] = true, [ "bind" ] = true, [ "toggle key" ] = true, [ "activation key" ] = true, [ "hold key" ] = true };
	local MOUSE_KEY_NAMES = { MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3" };

	local function StripBindSuffix( Text: string ): string
		local Stripped = string.gsub( string.gsub( Text, "%s*[Kk]ey[Bb]ind$", "" ), "%s*[Kk]ey$", "" );
		return ( string.gsub( Stripped, "%s*[Bb]ind$", "" ) );
	end

	local function CollectBinds( Items: { any }, Where: string, GroupToggle: string? )
		local Sibling = nil;

		for _, Item in Items do
			if ( Item.type == "toggle" and Item.key and not Sibling ) then
				Sibling = Item.key;
			end
		end

		for _, Item in Items do
			if ( Item.type == "keybind" and Item.key ) then
				local Label = tostring( Item.label or Item.key );
				local Name = StripBindSuffix( Label );
				if ( GENERIC_BIND_LABELS[ string.lower( Label ) ] or Name == "" ) then
					Name = Where;
				end
				local Named = StripBindSuffix( tostring( Item.key ) );
				local StateKey = GroupToggle;
				if ( not StateKey and Named ~= Item.key and typeof( config[ Named ] ) == "boolean" ) then
					StateKey = Named;
				end
				OverlayBinds[ #OverlayBinds + 1 ] = { key = Item.key, name = Name, state = StateKey or Sibling };
			end

			if ( Item.items ) then
				local Toggle = if ( Item.type == "group" or Item.type == "collapsible" ) then ( Item.toggleKey or Item.key ) else nil;
				CollectBinds( Item.items, tostring( Item.label or Where ), Toggle or GroupToggle );
			end

			for _, Profile in Item.profiles or { } do
				CollectBinds( Profile.items or { }, Where, GroupToggle );
			end
		end
	end

	for _, Page in FeaturePages do
		for _, Section in Page.sections or { } do
			CollectBinds( Section.items or { }, tostring( Section.title or Page.label or "" ), nil );
		end
	end

	RefreshOverlay = function( )
		if ( controller._destroyed or not overlay ) then
			return;
		end

		local Rows = { };

		for _, Bind in OverlayBinds do
			local Name = KeyName( config[ Bind.key ] );
			if ( Name ~= "None" ) then
				Rows[ #Rows + 1 ] = { Name = Bind.name, Key = MOUSE_KEY_NAMES[ Name ] or Name, Active = Bind.state == nil or config[ Bind.state ] == true };
			end
		end

		overlay : SetKeybinds( Rows );
	end

	if ( overlay ) then
		overlay : SetWatermarkVisible( hubSettings.ShowWatermark ~= false );
		overlay : SetKeybindsVisible( hubSettings.ShowKeybindList ~= false );
	end

	-- Game code flips toggles silently too, so the list re-reads config on its own beat.
	task.spawn( function( )
		while ( not controller._destroyed ) do
			RefreshOverlay( );
			task.wait( 0.5 );
		end
	end );

	do
		local hubCtx = {
			theme = theme,
			config = hubSettings,
			maid = maid,
			controls = {},
			onTheme = ctx.onTheme,
			warn = uiWarn,
			safeCall = safeCall,
			registerHud = function( ) end,
			-- keybind.lua's own `onChange` fires on every *press* of the bound key (a live trigger
			-- callback), not on rebinding. `dispatch` fires exactly once when the assignment itself
			-- changes, so the menu-key rebind hooks in here.
			dispatch = function(key, value, itemType)
				ConfigStore.markDirty(HUB_CONFIG_NAME)
				if itemType == "keybind" and key == "MenuKey" then
					menuToggleHandle.rebind(value)
					syncMobileBinding()
				end
			end,
		}

		local function Refresh( )
			controller : refreshTheme( );
		end

		-- Saved configs live on the Settings page, built with the rest of it on first open.
		local settingsPage = window : addPage( "Settings", "heroicons:cog-6-tooth", { utility = true } );
		local BuildSavedConfigs = nil;

		if ( configName ) then
			local ConfigsPage = settingsPage;

			local function BuildConfigs( )
				local Saved = ConfigsPage : addSection( "Saved Configs", { collapsible = false } );
				local Status = COMPONENTS.label( Saved, { type = "label", id = "__configStatus", text = "Active: " .. tostring( ConfigStore.activeProfile( configName ) or "Default" ) }, hubCtx );

				-- Built from primitives (not the text component) so the name buffer never lands in a save.
				local CreateRow = P.create( "Frame", { Size = UDim2.new( 1, 0, 0, 22 ), BackgroundTransparency = 1, Parent = Saved } );
				P.paddingXY( CreateRow, 6, 0 );
				local NameBox = P.create( "TextBox", {
					Size = UDim2.new( 1, -84, 1, 0 ); BackgroundColor3 = theme.control; BorderSizePixel = 0;
					Text = ""; PlaceholderText = "Config name"; ClearTextOnFocus = false;
					FontFace = theme.fontFace; TextSize = theme.textSizeSmall; TextColor3 = theme.text;
					PlaceholderColor3 = theme.textFaint; TextXAlignment = Enum.TextXAlignment.Left; Parent = CreateRow;
				} ) :: TextBox;
				P.corner( NameBox, theme.cornerSmall );
				P.stroke( NameBox, theme.stroke, 1, 0 );
				P.paddingXY( NameBox, 10, 0 );
				local CreateHost = P.create( "Frame", { AnchorPoint = Vector2.new( 1, 0 ), Position = UDim2.fromScale( 1, 0 ), Size = UDim2.new( 0, 78, 1, 0 ), BackgroundTransparency = 1, Parent = CreateRow } );

				local List = P.create( "Frame", { Size = UDim2.new( 1, 0, 0, 0 ), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = Saved } );
				P.paddingXY( List, 6, 0 );
				P.listLayout( List, 4 );
				local RefreshList;

				local function RowButton( Parent: Instance, Label: string, Primary: boolean, Action: ( ) -> ( ) )
					local Button = Common.clickable( Parent, theme, {
						maid = maid;
						getBaseColor = function( ) return Primary and theme.accent or theme.control; end;
						getHoverColor = function( ) return Primary and theme.accentBright or theme.controlHover; end;
					} );
					Button.Size = UDim2.fromOffset( 56, 20 );
					Button.Text = Label;
					Button.FontFace = theme.fontFaceMedium;
					Button.TextSize = theme.textSizeSmall;
					Button.TextColor3 = Primary and theme.background or theme.text;
					maid : give( Button.Activated : Connect( Action ) );
					return Button;
				end

				local function Report( Success: boolean, Message: string? )
					Status.setText( Message or ( Success and "Done." or "Failed." ) );
				end

				RefreshList = function( )
					for _, Child in List : GetChildren( ) do
						if ( Child : IsA( "GuiObject" ) ) then
							Child : Destroy( );
						end
					end

					local Active = ConfigStore.activeProfile( configName );

					for Order, Name in ConfigStore.profiles( configName ) do
						local IsActive = Name == Active;
						local Row = P.create( "Frame", {
							Size = UDim2.new( 1, 0, 0, 26 ); BackgroundColor3 = theme.surfaceAlt;
							BorderSizePixel = 0; LayoutOrder = Order; Parent = List;
						} );
						P.corner( Row, theme.cornerSmall );
						P.stroke( Row, IsActive and theme.accentDim or theme.stroke, 1, 0 );
						P.label( Row, Name, {
							Theme = theme; Position = UDim2.fromOffset( 12, 0 ); Size = UDim2.new( 1, -250, 1, 0 );
							Font = theme.fontMedium; TextSize = theme.textSize - 1; TextColor3 = theme.text; TextTruncate = Enum.TextTruncate.AtEnd;
						} );
						local Actions = P.create( "Frame", { AnchorPoint = Vector2.new( 1, 0.5 ), Position = UDim2.new( 1, -8, 0.5, 0 ), Size = UDim2.fromOffset( 240, 22 ), BackgroundTransparency = 1, Parent = Row } );
						local Layout = P.listLayout( Actions, 6, Enum.FillDirection.Horizontal );
						Layout.HorizontalAlignment = Enum.HorizontalAlignment.Right;
						Layout.VerticalAlignment = Enum.VerticalAlignment.Center;

						if ( IsActive ) then
							local Badge = P.label( Actions, "Active", {
								Theme = theme; Size = UDim2.fromOffset( 50, 20 ); TextXAlignment = Enum.TextXAlignment.Center;
								Font = theme.fontMedium; TextSize = theme.textSizeSmall - 1; TextColor3 = theme.accentBright; LayoutOrder = 0;
							} );
							Badge.BackgroundTransparency = 0;
							Badge.BackgroundColor3 = theme.accentFaint;
							P.corner( Badge, theme.cornerSmall );
							RowButton( Actions, "Save", true, function( )
								Report( ConfigStore.save( configName ) );
							end ).LayoutOrder = 1;
						end

						if ( not IsActive ) then
							RowButton( Actions, "Load", false, function( )
								local Success, Message = ConfigStore.loadProfile( configName, Name );
								Report( Success, Success and ( "Loaded " .. Name .. "." ) or Message );
								controller : syncControls( true );
								RefreshList( );
							end ).LayoutOrder = 1;
						end

						RowButton( Actions, "Delete", false, function( )
							local Success, Message = ConfigStore.deleteProfile( configName, Name );
							Report( Success, Success and ( "Deleted " .. Name .. "." ) or Message );
							controller : syncControls( true );
							RefreshList( );
						end ).LayoutOrder = 2;
					end

					Status.setText( "Active: " .. tostring( ConfigStore.activeProfile( configName ) or "Default" ) );
				end

				COMPONENTS.button( CreateHost, {
					label = "Create"; variant = "primary"; inset = false;
					onClick = function( )
						local Success, Message = ConfigStore.createProfile( configName, NameBox.Text );
						Report( Success, Success and ( "Created " .. tostring( ConfigStore.activeProfile( configName ) ) .. "." ) or Message );

						if ( Success ) then
							NameBox.Text = "";
							RefreshList( );
						end
					end;
				}, hubCtx );
				RefreshList( );

				local Share = ConfigsPage : addSection( "Share", { collapsible = false } );
				local ImportHost = P.create( "Frame", { Size = UDim2.new( 1, 0, 0, 22 ), BackgroundTransparency = 1, Parent = Share } );
				P.paddingXY( ImportHost, 6, 0 );
				local ImportBox = P.create( "TextBox", {
					Size = UDim2.fromScale( 1, 1 ); BackgroundColor3 = theme.control; BorderSizePixel = 0;
					Text = ""; PlaceholderText = "Paste config JSON"; ClearTextOnFocus = false;
					FontFace = theme.fontFace; TextSize = theme.textSizeSmall; TextColor3 = theme.text;
					PlaceholderColor3 = theme.textFaint; TextXAlignment = Enum.TextXAlignment.Left; TextTruncate = Enum.TextTruncate.AtEnd; Parent = ImportHost;
				} ) :: TextBox;
				P.corner( ImportBox, theme.cornerSmall );
				P.stroke( ImportBox, theme.stroke, 1, 0 );
				P.paddingXY( ImportBox, 10, 0 );
				buildItems( Share, {
					{ type = "button"; label = "Import"; onClick = function( )
						if ( ImportBox.Text == "" ) then
							Report( false, "Paste JSON first." );
							return;
						end

						local Success, Message = applyImportedConfig( config, configName, ImportBox.Text );
						Report( Success, Message );

						if ( Success ) then
							ImportBox.Text = "";
							controller : syncControls( true );
						end
					end };
					{ type = "button"; label = "Copy to Clipboard"; onClick = function( )
						local Ok, Encoded = pcall( HttpService.JSONEncode, HttpService, ConfigStore.encodeValue( config ) );

						if ( not Ok ) then
							Report( false, "Couldn't serialize the current config." );
							return;
						end

						local Copied = copyToClipboard( Encoded );
						Report( Copied, Copied and "Copied config JSON." or "This executor has no setclipboard." );
					end };
					{ type = "button"; label = "Reset to Defaults"; onClick = function( )
						ConfigStore.reset( configName );
						controller : syncControls( true );
						Report( true, "Reset to defaults." );
					end };
				} );
			end

			BuildSavedConfigs = BuildConfigs;
		end

		local KeybindList = nil;

		local function FillKeybinds( )
			if ( not KeybindList ) then
				return;
			end

			for _, Child in KeybindList : GetChildren( ) do
				if ( Child : IsA( "GuiObject" ) ) then
					Child : Destroy( );
				end
			end

			local Binds = { { label = "Menu Key", where = "Hub", value = hubSettings.MenuKey } };

			for _, Entry in Workspace.entries do
				if ( Entry.spec.type == "keybind" and Entry.key ) then
					Binds[ #Binds + 1 ] = { label = Entry.label, where = Entry.page.label, value = config[ Entry.key ], entry = Entry };
				end
			end

			local Uses = { };

			for _, Bind in Binds do
				local Name = KeyName( Bind.value );

				if ( Name ~= "None" ) then
					Uses[ Name ] = ( Uses[ Name ] or 0 ) + 1;
				end
			end

			for Order, Bind in Binds do
				local Name = KeyName( Bind.value );
				local Conflict = Name ~= "None" and Uses[ Name ] > 1;
				local Row = P.create( "TextButton", {
					Size = UDim2.new( 1, 0, 0, theme.rowHeight ); BackgroundColor3 = theme.overlay; BackgroundTransparency = 1;
					AutoButtonColor = false; Text = ""; LayoutOrder = Order; Parent = KeybindList;
				} );
				P.corner( Row, theme.cornerSmall );
				P.label( Row, Bind.label, {
					Theme = theme; Position = UDim2.fromOffset( 6, 0 ); Size = UDim2.new( 0.5, -6, 1, 0 );
					Font = theme.fontMedium; TextSize = theme.textSize - 1; TextColor3 = theme.textDim; TextTruncate = Enum.TextTruncate.AtEnd;
				} );
				P.label( Row, Bind.where, {
					Theme = theme; Position = UDim2.fromScale( 0.5, 0 ); Size = UDim2.new( 0.5, -100, 1, 0 );
					TextSize = theme.textSizeSmall; TextColor3 = theme.textFaint; TextTruncate = Enum.TextTruncate.AtEnd;
				} );
				local Chip = P.label( Row, Name, {
					Theme = theme; AnchorPoint = Vector2.new( 1, 0.5 ); Position = UDim2.new( 1, -4, 0.5, 0 ); Size = UDim2.fromOffset( 88, 22 );
					TextXAlignment = Enum.TextXAlignment.Center; Font = theme.fontMedium; TextSize = theme.textSizeSmall;
					TextColor3 = Conflict and theme.negative or ( Name == "None" and theme.textFaint or theme.accentBright );
					TextTruncate = Enum.TextTruncate.AtEnd;
				} );
				Chip.BackgroundTransparency = 0;
				Chip.BackgroundColor3 = theme.control;
				P.corner( Chip, theme.cornerSmall );
				P.stroke( Chip, Conflict and theme.negative or theme.stroke, 1, Conflict and 0.2 or 0 );
				maid : give( Row.MouseEnter : Connect( function( ) Row.BackgroundTransparency = 0.5; end ) );
				maid : give( Row.MouseLeave : Connect( function( ) Row.BackgroundTransparency = 1; end ) );

				if ( Bind.entry ) then
					maid : give( Row.Activated : Connect( function( ) Workspace.open( Bind.entry ); end ) );
				end
			end
		end

		local function BuildSettings( )
			local Menu = settingsPage : addSection( "Menu" );
			COMPONENTS.keybind( Menu, { key = "MenuKey", label = "Menu Key", default = defaultToggleKey, isValidBinding = IsValidMenuKey }, hubCtx );
			COMPONENTS.slider( Menu, { key = "MenuScale"; label = "Scale"; min = 0.75; max = 1.25; step = 0.05; suffix = "x"; onChange = Refresh }, hubCtx );
			COMPONENTS.segmented( Menu, { key = "Density"; label = "Density"; options = { "Comfortable", "Compact" }; onChange = Refresh }, hubCtx );
			COMPONENTS.toggle( Menu, { key = "ReducedMotion"; label = "Reduced Motion"; onChange = Refresh }, hubCtx );

			local Screen = settingsPage : addSection( "Overlay" );
			COMPONENTS.toggle( Screen, { key = "ShowWatermark"; label = "Watermark"; onChange = function( Value: boolean )
				if ( overlay ) then
					overlay : SetWatermarkVisible( Value );
				end
			end }, hubCtx );
			COMPONENTS.toggle( Screen, { key = "ShowKeybindList"; label = "Keybind List"; onChange = function( Value: boolean )
				if ( overlay ) then
					overlay : SetKeybindsVisible( Value );
				end
			end }, hubCtx );


			local Look = settingsPage : addSection( "Appearance" );
			COMPONENTS.segmented( Look, { key = "BackgroundStyle"; label = "Background"; options = { "Brand", "Midnight", "Graphite" }; onChange = Refresh }, hubCtx );
			local accentControl = COMPONENTS.color( Look, {
				key = "AccentColor";
				label = "Accent";
				default = brandDefaultAccent;
				onChange = function( Color: Color3 )
					-- markDirty happens via hubCtx.dispatch, which the colour picker calls right after onChange.
					hubCtx.config.AccentCustomized = true;
					applyAccent( theme, Color );
					controller : refreshTheme( );
				end;
			}, hubCtx );
			COMPONENTS.button( Look, {
				label = "Reset Accent";
				onClick = function( )
					hubCtx.config.AccentCustomized = false;
					ConfigStore.markDirty( HUB_CONFIG_NAME );
					accentControl.set( brandDefaultAccent, true );
					restoreAccentPalette( theme, brandPalette );
					controller : refreshTheme( );
				end;
			}, hubCtx );

			if ( BuildSavedConfigs ) then
				BuildSavedConfigs( );
			end

			KeybindList = settingsPage : addSection( "Keybinds" );
			FillKeybinds( );
		end

		local SettingsIndex = #window.pages;
		PageBuilders[ SettingsIndex ] = BuildSettings;
		PageOrder[ #PageOrder + 1 ] = SettingsIndex;

		-- Utility pages build on first open; the keybind overview re-reads every time it is shown.
		local Before = window.beforeShowPage;
		window.beforeShowPage = function( Index: number )
			if ( Before ) then
				Before( Index );
			end

			BuildPage( Index );

			if ( Index == SettingsIndex ) then
				FillKeybinds( );
			end
		end
	end

	return controller
end

return UI
