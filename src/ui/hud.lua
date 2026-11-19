local Services = require("core/services.lua")
local Runtime = require("core/runtime.lua")
local Theme = require("ui/theme.lua")
local P = require("ui/primitives.lua")

local TextService = Services.TextService

local Hud = {}
Hud.__index = Hud

local ROW_HEIGHT = 22
local ROW_GAP = 2
local RIGHT_MARGIN = 12
local TOP_MARGIN = 12
local CONTAINER_WIDTH = 320
local ENTRY_TEXT_SIZE = 13

local DISPLAY_ORDER = 2000000000

local function trim(value: any): string
	return (tostring(value or ""):match("^%s*(.-)%s*$")) or ""
end

local function colorForIndex(theme, index: number, total: number): Color3
	local top = theme.accent
	local bottom = theme.accentBright or theme.accent
	if total <= 1 then
		return top
	end
	return top:Lerp(bottom, (index - 1) / (total - 1))
end

local function measureWidth(text: string, font: Enum.Font, size: number): number
	local ok, bounds = pcall(function()
		return TextService:GetTextSize(text, size, font, Vector2.new(1000, 40))
	end)
	if ok and typeof(bounds) == "Vector2" then
		return bounds.X
	end
	return #text * (size * 0.55)
end

local function sortedLabels(labels, theme)
	local font = Enum.Font.SourceSansSemibold
	local seen = {}
	local entries = {}
	for _, rawLabel in (if typeof(labels) == "table" then labels else {}) do
		local text = trim(rawLabel)
		local key = string.lower(text)
		if text ~= "" and not seen[key] then
			seen[key] = true
			table.insert(entries, {
				key = key,
				text = text,
				width = measureWidth(text, font, ENTRY_TEXT_SIZE),
			})
		end
	end
	table.sort(entries, function(a, b)
		if math.abs(a.width - b.width) > 0.5 then
			return a.width > b.width
		end
		return a.key < b.key
	end)
	return entries
end

local function createOutlinedLabel(parent: Instance, text: string, props: { [string]: any })
	local holder = P.create("Frame", {
		Size = props.Size,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = props.Visible ~= false,
		Parent = parent,
	})

	local content = P.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, props.EnterOffset or 0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = holder,
	})

	local initialTransparency = tonumber(props.InitialTransparency) or 0

	local foreground = P.label(content, text, {
		Theme = props.Theme,
		Size = UDim2.new(1, -12, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		AutomaticSize = Enum.AutomaticSize.None,
		TextXAlignment = props.TextXAlignment,
		TextYAlignment = props.TextYAlignment,
		TextColor3 = props.TextColor3,
		TextTransparency = initialTransparency,
		Font = props.Font,
		TextSize = props.TextSize,
		TextStrokeTransparency = 0.65 + initialTransparency * 0.35,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		ZIndex = 2,
	})

	local Marker = P.create( "Frame", {
		AnchorPoint = Vector2.new( 1, 0.5 ),
		Position = UDim2.new( 1, -1, 0.5, 0 ),
		Size = UDim2.fromOffset( 3, 3 ),
		BackgroundColor3 = props.TextColor3,
		BackgroundTransparency = initialTransparency,
		BorderSizePixel = 0,
		Visible = props.ShowMarker == true,
		Parent = content,
	} );
	P.corner( Marker, 2 );

	local api = {
		holder = holder,
		content = content,
		fg = foreground,
	}

	function api.setText(newText: string)
		foreground.Text = newText

	end

	function api.setVisible(visible: boolean)
		holder.Visible = visible
	end

	function api.setColor(color: Color3)
		foreground.TextColor3 = color
		Marker.BackgroundColor3 = color;
	end

	function api.tweenTransparency(transparency: number, duration: number)
		P.tween(foreground, duration, {
			TextTransparency = transparency,
			TextStrokeTransparency = 0.65 + transparency * 0.35,
		})
		P.tween( Marker, duration, { BackgroundTransparency = transparency } );
	end

	return api
end

function Hud.new(title: string, themeOverride: { [string]: any }?)
	local theme = themeOverride or Theme.get()
	title = trim(title)
	if title == "" then
		title = Theme.brandName
	end
	local self = setmetatable({
		theme = theme,
		title = title,
		rows = {},
		rowsByKey = {},
		_signature = nil,
	}, Hud)

	local screen = P.create("ScreenGui", {
		Name = "\0",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = DISPLAY_ORDER,
	})
	if not Runtime.setGuiParent(screen) then
		screen:Destroy()
		error("[Hub][UI] no available GUI parent for HUD")
	end
	self.screen = screen

	local container = P.create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -RIGHT_MARGIN, 0, TOP_MARGIN),
		Size = UDim2.new(0, CONTAINER_WIDTH, 0, ROW_HEIGHT),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = screen,
	})
	self.container = container
	self.containerScale = P.create("UIScale", { Scale = 1, Parent = container })
	P.listLayout(container, ROW_GAP)

	self.titleRow = createOutlinedLabel(container, title, {
		Theme = theme,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = theme.text,
		Font = theme.fontBold,
		TextSize = 14,
		LayoutOrder = 0,
		Visible = false,
	})

	self.statusRow = createOutlinedLabel(container, "idle", {
		Theme = theme,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = theme.textFaint,
		Font = theme.fontBold,
		TextSize = ENTRY_TEXT_SIZE,
		LayoutOrder = 1,
		Visible = false,
	})

	return self
end

function Hud:_createRow(entry, index: number, total: number)
	local theme = self.theme
	local row = createOutlinedLabel(self.container, entry.text, {
		Theme = theme,
		Size = UDim2.new(1, 0, 0, ROW_HEIGHT),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextColor3 = colorForIndex(theme, index, total),
		ShowMarker = true,
		Font = theme.fontMedium or theme.font,
		TextSize = ENTRY_TEXT_SIZE,
		LayoutOrder = index + 1,
		InitialTransparency = 1,
		EnterOffset = 10,
	})
	row.key = entry.key
	row.removing = false
	P.tween(row.content, theme.normal or 0.1, { Position = UDim2.fromScale(1, 0) }, Enum.EasingStyle.Quint)
	row.tweenTransparency(0, theme.normal or 0.1)
	return row
end

function Hud:_removeRow(row)
	if row.removing then
		return
	end
	row.removing = true
	row.holder.LayoutOrder = 10000
	local duration = self.theme.normal or 0.1
	P.tween(row.content, duration, { Position = UDim2.new(1, 12, 0, 0) }, Enum.EasingStyle.Quint)
	row.tweenTransparency(1, duration)
	task.delay(duration + 0.03, function()
		if row.holder and row.holder.Parent then
			row.holder:Destroy()
		end
	end)
end

function Hud:setVisible(visible: boolean)
	if not self.screen then
		return
	end
	local show = visible == true
	if show and not self.screen.Enabled then
		self.screen.Enabled = true
		self.containerScale.Scale = 1
		P.tween(self.containerScale, self.theme.normal or 0.1, { Scale = 1 }, Enum.EasingStyle.Quint)
	elseif not show then
		self.screen.Enabled = false
	end
end

function Hud:setActive(labels: { string })
	if not self.screen then
		return
	end
	local entries = sortedLabels(labels, self.theme)
	local signatureParts = {}
	local nextKeys = {}
	for _, entry in entries do
		table.insert(signatureParts, entry.key .. "=" .. entry.text)
		nextKeys[entry.key] = true
	end
	local signature = table.concat(signatureParts, "\0")
	if signature == self._signature then
		return
	end
	self._signature = signature

	for key, row in self.rowsByKey do
		if not nextKeys[key] then
			self.rowsByKey[key] = nil
			self:_removeRow(row)
		end
	end

	local orderedRows = {}
	for index, entry in entries do
		local row = self.rowsByKey[entry.key]
		if not row then
			row = self:_createRow(entry, index, #entries)
			self.rowsByKey[entry.key] = row
		else
			row.setText(entry.text)
			row.holder.LayoutOrder = index + 1
			row.setColor(colorForIndex(self.theme, index, #entries))
		end
		table.insert(orderedRows, row)
	end
	self.rows = orderedRows

	local active = #entries > 0
	self.titleRow.setText( self.title .. "  /  " .. tostring( #entries ) );
	self.titleRow.setVisible(active)
	self.statusRow.setVisible(not active)
	if not active then
		self.statusRow.setText("idle")
	end
end

function Hud:refreshTheme()
	if not self.screen then
		return
	end
	local theme = self.theme
	self.titleRow.setColor(theme.text)
	self.statusRow.setColor(theme.textFaint)
	for index, row in self.rows do
		row.setColor(colorForIndex(theme, index, #self.rows))
	end
end

function Hud:destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self.screen then
		self.screen:Destroy()
		self.screen = nil
	end
	table.clear(self.rows)
	table.clear(self.rowsByKey)
end

return Hud
