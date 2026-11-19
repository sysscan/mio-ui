local Molto = require("ui/molto.lua")

local Assets = {
	Logo = { Image = "rbxassetid://83222639901823", Logo = true },
	Bullseye = "rbxassetid://88639165254091",
	Smile = { Image = "rbxthumb://type=Asset&id=11955884989&w=150&h=150", RectOffset = Vector2.new(20, 20), RectSize = Vector2.new(110, 110) },
	Globe = "rbxassetid://11887653877",
	Bomb = "rbxthumb://type=Asset&id=13424571238&w=150&h=150",
	Gear = "rbxassetid://9753762469",
	Robot = "rbxthumb://type=Asset&id=78007610361363&w=150&h=150",
	HeartCrack = "rbxthumb://type=Asset&id=15331784488&w=150&h=150",
	Wrench = "rbxthumb://type=Asset&id=11435662333&w=150&h=150",
	Cube = "rbxthumb://type=Asset&id=9802015008&w=150&h=150",
	Search = { Image = "rbxthumb://type=Asset&id=85365761530931&w=150&h=150", RectOffset = Vector2.new(14, 14), RectSize = Vector2.new(122, 122) },
	Check = "rbxassetid://18856185133",
	User = "rbxassetid://18854794412",
	Users = "rbxassetid://6479819618",
	Plus = "rbxassetid://139167062679792",
	Trash = "rbxassetid://88050953687180",
	Checker = "rbxassetid://18274452449",
	Warning = "rbxassetid://11745872910",
	Error = "rbxassetid://5419926701",
	Info = "rbxassetid://7634887649",
	Arrow = "rbxassetid://153287088",
	Brush = "rbxassetid://10910211661",
	Eye = "rbxassetid://6473251976",
	Key = "rbxassetid://18854840832",
	Gun = "rbxassetid://3189074890",
	Knife = "rbxassetid://2992801749",
	Crown = "rbxassetid://6458974334",
	Lock = "rbxassetid://15117261700",
	Circle = "rbxassetid://9208578430",
}

local Aliases = {
	[ "layout-dashboard" ] = "Cube",
	[ "layout-grid" ] = "Cube",
	[ "home" ] = "Cube",
	[ "scan-eye" ] = "Eye",
	[ "eye" ] = "Eye",
	[ "shield" ] = "Bullseye",
	[ "crosshair" ] = "Bullseye",
	[ "focus" ] = "Bullseye",
	[ "target" ] = "Bullseye",
	[ "circle-dot" ] = "Gun",
	[ "swords" ] = "Knife",
	[ "flag" ] = "Crown",
	[ "trophy" ] = "Crown",
	[ "sparkles" ] = "HeartCrack",
	[ "banknote" ] = "Cube",
	[ "coins" ] = "Cube",
	[ "palette" ] = "Brush",
	[ "paintbrush" ] = "Brush",
	[ "user" ] = "User",
	[ "users" ] = "Users",
	[ "map" ] = "Globe",
	[ "map-pin" ] = "Globe",
	[ "telescope" ] = "Eye",
	[ "ghost" ] = "Bomb",
	[ "package" ] = "Cube",
	[ "settings" ] = "Gear",
	[ "settings-2" ] = "Gear",
	[ "sliders-horizontal" ] = "Gear",
	[ "wrench" ] = "Wrench",
	[ "compass" ] = "Globe",
	[ "globe" ] = "Globe",
	[ "activity" ] = "Bullseye",
	[ "sun-medium" ] = "Eye",
	[ "sun" ] = "Eye",
	[ "volume-2" ] = "Robot",
	[ "moon" ] = "Eye",
	[ "rocket" ] = "Smile",
	[ "footprints" ] = "Smile",
	[ "sprout" ] = "Cube",
	[ "wheat" ] = "Cube",
	[ "flower-2" ] = "Cube",
	[ "shovel" ] = "Wrench",
	[ "store" ] = "Cube",
	[ "cart" ] = "Cube",
	[ "shopping-cart" ] = "Cube",
	[ "paw-print" ] = "Smile",
	[ "wand-sparkles" ] = "Wrench",
	[ "circle" ] = "Circle",
	[ "check" ] = "Check",
	[ "check-square-2" ] = "Check",
	[ "square" ] = "Checker",
	[ "x" ] = "Error",
	[ "chevron-down" ] = "Arrow",
	[ "chevron-right" ] = "Arrow",
	[ "chevron-up" ] = "Arrow",
	[ "chevron-left" ] = "Arrow",
	[ "arrow-right" ] = "Arrow",
	[ "arrow-left" ] = "Arrow",
	[ "arrow-up" ] = "Arrow",
	[ "arrow-down" ] = "Arrow",
	[ "refresh-cw" ] = "Arrow",
	[ "log-in" ] = "Arrow",
	[ "log-out" ] = "Arrow",
	[ "send" ] = "Arrow",
	[ "key" ] = "Key",
	[ "keyboard" ] = "Key",
	[ "lock" ] = "Lock",
	[ "unlock" ] = "Lock",
	[ "plus" ] = "Plus",
	[ "trash" ] = "Trash",
	[ "trash-2" ] = "Trash",
	[ "search" ] = "Search",
	[ "info" ] = "Info",
	[ "alert-triangle" ] = "Warning",
	[ "triangle-alert" ] = "Warning",
	[ "zap" ] = "Bomb",
	[ "ticket" ] = "Cube",
	[ "box" ] = "Cube",
	[ "gun" ] = "Gun",
};
local Rotations = { [ "chevron-right" ] = -90, [ "chevron-up" ] = 180, [ "chevron-left" ] = 90, [ "arrow-right" ] = -90, [ "arrow-up" ] = 180, [ "arrow-left" ] = 90 };


local Icons = {}

Icons.pageDefaults = {
	Home = "layout-dashboard",
	Menu = "layout-grid",
	Visuals = "scan-eye",
	ESP = "scan-eye",
	Farm = "sprout",
	Combat = "shield",
	Aim = "focus",
	Weapon = "circle-dot",
	Match = "flag",
	Fun = "sparkles",
	Economy = "banknote",
	Skins = "palette",
	Player = "user",
	Teleport = "map",
	Teleports = "map",
	Spectate = "telescope",
	Troll = "ghost",
	Crates = "package",
	Misc = "settings",
	Settings = "wrench",
	Client = "wrench",
	World = "compass",
	Radar = "activity",
	View = "sun-medium",
	Audio = "volume-2",
	Stealing = "moon",
	Extras = "wrench",
	Move = "rocket",

	Main = "layout-dashboard",
	Harvest = "wheat",
	Garden = "flower-2",
	Planting = "shovel",
	Sell = "sprout",
	Shop = "store",
	Pets = "paw-print",
	Events = "sparkles",
	Movement = "rocket",
	Upgrades = "wand-sparkles",
	Tools = "map",
}

local PageIconRefresh = {
	[ "home" ] = "layout-dashboard",
	[ "eye" ] = "scan-eye",
	[ "crosshair" ] = "focus",
	[ "swords" ] = "shield",
	[ "target" ] = "circle-dot",
	[ "trophy" ] = "flag",
	[ "footprints" ] = "rocket",
	[ "globe" ] = "compass",
	[ "settings-2" ] = "wrench",
	[ "sliders-horizontal" ] = "wrench",
	[ "map-pin" ] = "map",
	[ "coins" ] = "sprout",
};

local normalizedPageDefaults = {}
for label, icon in Icons.pageDefaults do
	normalizedPageDefaults[string.lower(label)] = icon
end

export type MountOpts = {
	size: number?,
	sheetSize: number?,
	color: Color3?,
	anchorPoint: Vector2?,
	position: UDim2?,
	sizeDim: UDim2?,
	zIndex: number?,
}

local function resolvePageIcon(label: string?, explicit: string?): string?
	if typeof(explicit) == "string" and explicit ~= "" then
		local Resolved = PageIconRefresh[ explicit ] or explicit;
		if ( Icons.getAsset( Resolved ) ) then
			return Resolved;
		end
	end
	if typeof(label) == "string" then
		local normalized = label:lower():gsub("^%s+", ""):gsub("%s+$", "")
		return Icons.pageDefaults[label] or normalizedPageDefaults[normalized]
	end
	return nil
end

function Icons.resolvePageIcon(label: string?, explicit: string?): string?
	return resolvePageIcon(label, explicit)
end

function Icons.getAsset(name: string, sheetSize: number?)
	if typeof(name) ~= "string" or name == "" then
		return nil
	end
	local molto = Molto.getAsset(name)
	if molto then
		return molto
	end
	local Normalized = string.lower( name );
	local Key = Aliases[ Normalized ] or name;
	local Entry = Assets[ Key ];
	if ( not Entry ) then
		for AssetName, Value in Assets do
			if ( string.lower( AssetName ) == Normalized ) then
				Key = AssetName;
				Entry = Value;
				break;
			end
		end
	end
	if ( not Entry ) then
		return nil;
	end
	local Asset = typeof( Entry ) == "table" and Entry or { Image = Entry };
	return {
		IconName = Key,
		Url = Asset.Image,
		ImageRectSize = Asset.RectSize or Vector2.zero,
		ImageRectOffset = Asset.RectOffset or Vector2.zero,
		Rotation = Rotations[ Normalized ] or 0,
	};
end

function Icons.apply(label: ImageLabel, asset: any, color: Color3?)
	if typeof(label) ~= "Instance" or not label:IsA("ImageLabel") or typeof(asset) ~= "table" then
		return false
	end
	label.Name = asset.IconName
	label.Rotation = asset.Rotation or 0;
	label.Image = asset.Url
	label.ImageRectSize = asset.ImageRectSize
	label.ImageRectOffset = asset.ImageRectOffset
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.ScaleType = Enum.ScaleType.Fit
	label.ImageColor3 = color or Color3.new(1, 1, 1)
	return true
end

function Icons.create(parent: Instance, name: string, opts: MountOpts?): ImageLabel?
	if typeof(parent) ~= "Instance" or typeof(name) ~= "string" or name == "" then
		return nil
	end
	local iconName = name:lower():gsub("^%s+", ""):gsub("%s+$", "")
	local asset = Icons.getAsset(iconName, (opts and opts.sheetSize) or 48)
	if not asset then
		return nil
	end

	local px = (opts and opts.size) or 16
	local img = Instance.new("ImageLabel")
	Icons.apply(img, asset, opts and opts.color)
	img.Size = (opts and opts.sizeDim) or UDim2.fromOffset(px, px)
	if opts and opts.anchorPoint then
		img.AnchorPoint = opts.anchorPoint
	end
	if opts and opts.position then
		img.Position = opts.position
	end
	if opts and opts.zIndex then
		img.ZIndex = opts.zIndex
	end
	img.Parent = parent
	return img
end

function Icons.mount(parent: Instance, name: string?, opts: MountOpts?): ImageLabel?
	if typeof(name) ~= "string" or name == "" then
		return nil
	end
	return Icons.create(parent, name, opts)
end

function Icons.setColor(img: ImageLabel?, color: Color3)
	if img and img.Parent then
		img.ImageColor3 = color
	end
end

return Icons
