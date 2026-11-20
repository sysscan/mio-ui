local Runtime = require("core/runtime.lua")
local Theme = require("ui/theme.lua")
local Icons = require("ui/icons.lua")
local P = require("ui/primitives.lua")
local Occlusion = require("visuals/occlusion.lua")

local Notify = {}

local container = nil
local screen = nil
local activeCards = {}
local expiryTasks = {}
local HOST_ATTRIBUTE = "MicroHubNotificationHostV1"
local cleanupScheduled = false
local cardCount = 0

local function scheduleHostCleanup()
	if cleanupScheduled then
		return
	end
	cleanupScheduled = true
	task.defer(function()
		cleanupScheduled = false
		if #activeCards ~= 0 then
			return
		end
		local host = screen
		container = nil
		screen = nil
		if host and host.Parent then
			host:Destroy()
		end
	end)
end

local function looksLikeNotificationScreen(screen: Instance): boolean
	return screen:IsA("ScreenGui") and screen:GetAttribute(HOST_ATTRIBUTE) == true
end

local function ensureContainer()
	if container and container.Parent then
		return container
	end
	local ok, children = pcall(function()
		return Runtime.withExecutorIdentity(function()
			return Runtime.gui():GetChildren()
		end)
	end)
	if ok then
		for _, child in children do
			if looksLikeNotificationScreen(child) then
				pcall(function() child:Destroy() end)
			end
		end
	end
	screen = P.create("ScreenGui", {
		Name = "\0",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 1001,
	})
	screen:SetAttribute(HOST_ATTRIBUTE, true)
	if not Runtime.setGuiParent(screen) then
		screen:Destroy()
		screen = nil
		return nil
	end
	local holder = P.create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(1, -40, 1, -40),
		BackgroundTransparency = 1,
		Parent = screen,
	})
	P.create("UISizeConstraint", {
		MaxSize = Vector2.new(320, 440),
		MinSize = Vector2.new(180, 0),
		Parent = holder,
	})
	local layout = P.listLayout(holder, 8)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	container = holder
	return holder
end

function Notify.push(arg, duration: number?, color: Color3?)
	local theme = Theme.get()
	local title, text, dur, accent, iconName
	if typeof(arg) == "table" then
		title, text = arg.title, arg.text
		dur = arg.duration or 3
		accent = arg.color or theme.accent
		iconName = arg.icon
	else
		if arg == nil then
			return nil
		end
		text = tostring(arg)
		dur = duration or 3
		accent = color or theme.accent
	end
	if iconName == nil then
		iconName = title and "bell" or "info"
	end
	if text == nil or tostring(text) == "" then
		return nil
	end
	title = if title ~= nil and tostring(title) ~= "" then tostring(title) else nil
	text = tostring(text)
	dur = tonumber(dur) or 3
	if dur ~= dur or dur == math.huge or dur == -math.huge then
		dur = 3
	end
	dur = math.clamp(dur, 0.1, 60)
	if typeof(accent) ~= "Color3" then
		accent = theme.accent
	end

	local holder = ensureContainer()
	if not holder then
		return nil
	end
	local card = P.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.surface or theme.panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = holder,
	})
	table.insert(activeCards, card)
	-- Drawing paints above ScreenGuis, so each toast is registered for the ESP to keep clear of.
	cardCount += 1
	local occlusionKey = "hub.toast." .. cardCount
	Occlusion.watch(occlusionKey, card)
	card.Destroying:Connect(function()
		Occlusion.unwatch(occlusionKey)
		local expiryThread = expiryTasks[card]
		if expiryThread then
			pcall(task.cancel, expiryThread)
			expiryTasks[card] = nil
		end
		local index = table.find(activeCards, card)
		if index then
			table.remove(activeCards, index)
		end
		scheduleHostCleanup()
	end)
	P.corner(card, theme.cornerSmall)
	P.stroke(card, theme.stroke, 1, 0)

	P.create("Frame", {
		Size = UDim2.new(0, 2, 1, 0),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = card,
	})

	local body = P.create("Frame", {
		Position = UDim2.fromOffset(3, 0),
		Size = UDim2.new(1, -3, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	})
	P.paddingXY(body, 10, 7)

	local contentRow = P.create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = body,
	})
	P.listLayout(contentRow, 8, Enum.FillDirection.Horizontal)

	local iconBadge = P.create("Frame", {
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = accent,
		BackgroundTransparency = 0.86,
		BorderSizePixel = 0,
		Parent = contentRow,
	})
	P.corner(iconBadge, theme.cornerSmall)
	Icons.mount(iconBadge, iconName, {
		size = 13,
		color = accent,
		anchorPoint = Vector2.new(0.5, 0.5),
		position = UDim2.fromScale(0.5, 0.5),
	})

	local textCol = P.create("Frame", {
		Size = UDim2.new(1, -32, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = contentRow,
	})
	P.listLayout(textCol, 3)

	if title then
		P.label(textCol, title, {
			Theme = theme,
			Size = UDim2.new(1, 0, 0, 14),
			TextColor3 = theme.text,
			Font = theme.fontMedium,
			TextSize = theme.textSizeSmall,
		})
	end
	P.label(textCol, text, {
		Theme = theme,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextColor3 = theme.text,
		TextSize = theme.textSizeSmall,
		TextYAlignment = Enum.TextYAlignment.Top,
	})

	local progress = P.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = theme.strokeFaint,
		BorderSizePixel = 0,
		Parent = card,
	})
	local progressFill = P.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = progress,
	})
	card.Position = UDim2.new(1, 32, 0, 0)
	card.BackgroundTransparency = 1
	P.tween(card, theme.normal, {
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 0.04,
	})
	P.tween(progressFill, dur, { Size = UDim2.fromScale(0, 1) })

	local expiryThread
	expiryThread = task.delay(dur, function()
		expiryTasks[card] = nil
		if card.Parent then
			P.tween(card, theme.normal, { BackgroundTransparency = 1, Position = UDim2.new(1, 36, 0, 0) })
			task.wait(theme.normal)
			card:Destroy()
		end
		local index = table.find(activeCards, card)
		if index then
			table.remove(activeCards, index)
		end
	end)
	expiryTasks[card] = expiryThread

	return card
end

function Notify.dismiss(card: Instance)
	if typeof(card) ~= "Instance" then
		return
	end
	local expiryThread = expiryTasks[card]
	if expiryThread then
		pcall(task.cancel, expiryThread)
		expiryTasks[card] = nil
	end
	local index = table.find(activeCards, card)
	if index then
		table.remove(activeCards, index)
	end
	if card.Parent then
		card:Destroy()
	end
	scheduleHostCleanup()
end

function Notify.destroy()
	for _, expiryThread in expiryTasks do
		pcall(task.cancel, expiryThread)
	end
	table.clear(expiryTasks)
	for _, card in activeCards do
		if card.Parent then
			card:Destroy()
		end
	end
	table.clear(activeCards)
	if container then
		local parentScreen = container:FindFirstAncestorOfClass("ScreenGui")
		if parentScreen then
			parentScreen:Destroy()
		else
			container:Destroy()
		end
		container = nil
	end
	if screen then
		if screen.Parent then
			screen:Destroy()
		end
		screen = nil
	end
	local ok, children = pcall(function()
		return Runtime.withExecutorIdentity(function()
			return Runtime.gui():GetChildren()
		end)
	end)
	if not ok then
		return
	end
	for _, child in children do
		if looksLikeNotificationScreen(child) then
			pcall(function()
				child:Destroy()
			end)
		end
	end
end

return Notify
