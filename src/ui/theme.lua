-- Theme tokens for the hub menu. Keys stay lowercase: every component and every game's `theme`
-- override reads them by these names, so they are part of the Hub.UI contract.

-- Constants
-- Inter (Creator Store font 12187365364): built for small UI text, taller x-height than Ubuntu.
local FONT_FAMILY = "rbxassetid://12187365364";
local MONO_FAMILY = "rbxasset://fonts/families/RobotoMono.json";

-- Utilities
local function FontFace( Family: string, Weight: Enum.FontWeight ): Font?
	local Ok, Face = pcall( Font.new, Family, Weight, Enum.FontStyle.Normal );

	if ( not Ok ) then
		return nil;
	end

	return Face;
end

-- Main
local Theme = { };

Theme.active = {
	background = Color3.fromRGB( 15, 15, 17 );
	panel = Color3.fromRGB( 15, 15, 17 );
	rail = Color3.fromRGB( 12, 12, 14 );
	titleBar = Color3.fromRGB( 15, 15, 17 );
	surface = Color3.fromRGB( 19, 19, 22 );
	surfaceAlt = Color3.fromRGB( 24, 24, 28 );
	overlay = Color3.fromRGB( 29, 29, 34 );
	elevated = Color3.fromRGB( 22, 22, 26 );
	control = Color3.fromRGB( 26, 26, 30 );
	controlHover = Color3.fromRGB( 34, 34, 40 );

	-- Classic script menus draw every box with a black outer line and a lighter inner one.
	outline = Color3.fromRGB( 0, 0, 0 );
	stroke = Color3.fromRGB( 42, 42, 48 );
	strokeBright = Color3.fromRGB( 66, 66, 74 );
	strokeFaint = Color3.fromRGB( 32, 32, 37 );

	text = Color3.fromRGB( 222, 222, 226 );
	textDim = Color3.fromRGB( 150, 150, 158 );
	textFaint = Color3.fromRGB( 98, 98, 106 );

	accent = Color3.fromRGB( 237, 116, 174 );
	accentBright = Color3.fromRGB( 255, 186, 218 );
	accentDim = Color3.fromRGB( 105, 53, 80 );
	accentSoft = Color3.fromRGB( 191, 85, 136 );
	accentFaint = Color3.fromRGB( 57, 34, 47 );
	positive = Color3.fromRGB( 123, 218, 173 );
	negative = Color3.fromRGB( 245, 112, 112 );
	warning = Color3.fromRGB( 232, 194, 128 );

	font = Enum.Font.Gotham;
	fontMedium = Enum.Font.GothamMedium;
	fontBold = Enum.Font.GothamBold;
	fontFamily = FONT_FAMILY;
	-- Script menus run one weight for every label; bold is kept for titles. Inter's Regular is too thin
	-- on a dark panel at 12-14 px, so labels use Medium.
	fontFace = FontFace( FONT_FAMILY, Enum.FontWeight.Medium );
	fontFaceMedium = FontFace( FONT_FAMILY, Enum.FontWeight.Medium );
	fontFaceBold = FontFace( FONT_FAMILY, Enum.FontWeight.Bold );
	fontFaceMono = FontFace( MONO_FAMILY, Enum.FontWeight.Regular );
	textSize = 14;
	textSizeSmall = 12;
	textSizeTitle = 14;

	-- One radius for every rounded box: window, panels, controls and tabs.
	corner = 4;
	cornerSmall = 4;
	rowHeight = 25;
	controlHeight = 21;
	padding = 10;
	sectionPadding = 8;
	sectionGap = 10;
	controlGap = 2;
	fieldGap = 4;
	headerHeight = 38;
	tabHeight = 28;
	windowSize = Vector2.new( 820, 540 );
	-- Cap on the full sidebar; it shrinks to its longest label (ui/window.lua).
	tabWidth = 144;
	columnGap = 10;
	logoImage = "MicroHub/src/ui/assets/mioicon.png";
	logoImageAlt = "src/ui/assets/mioicon.png";

	-- Density presets the Settings page switches between; touch always gets the tall rows.
	rowHeightCompact = 22;
	rowHeightTouch = 34;

	fast = 0.05;
	normal = 0.08;
	slow = 0.12;
};

local Brand = shared.__HubBrand;

if ( typeof( Brand ) == "table" ) then
	if ( typeof( Brand.logoImage ) == "string" and Brand.logoImage ~= "" ) then
		Theme.active.logoImage = Brand.logoImage;
		Theme.active.logoImageAlt = Brand.logoImage;
	end

	for Key, Value in ( typeof( Brand.colors ) == "table" and Brand.colors or { } ) do
		if ( typeof( Value ) == "Color3" ) then
			Theme.active[ Key ] = Value;
		end
	end
end

Theme.brandPalette = {
	accent = Theme.active.accent;
	accentBright = Theme.active.accentBright;
	accentDim = Theme.active.accentDim;
	accentSoft = Theme.active.accentSoft;
	accentFaint = Theme.active.accentFaint;
	strokeBright = Theme.active.strokeBright;
};

Theme.brandName = ( typeof( Brand ) == "table" and typeof( Brand.name ) == "string" and Brand.name ~= "" ) and Brand.name or "MicroHub";

Theme.colorPresets = {
	{ name = "Red", value = Color3.fromRGB( 255, 91, 112 ) };
	{ name = "Green", value = Color3.fromRGB( 92, 219, 143 ) };
	{ name = "Amber", value = Color3.fromRGB( 255, 190, 76 ) };
	{ name = "Teal", value = Color3.fromRGB( 54, 214, 184 ) };
	{ name = "Orange", value = Color3.fromRGB( 255, 136, 84 ) };
	{ name = "Sky", value = Color3.fromRGB( 103, 190, 244 ) };
	{ name = "Violet", value = Color3.fromRGB( 185, 134, 255 ) };
	{ name = "White", value = Color3.fromRGB( 255, 255, 255 ) };
};

function Theme.get( )
	return Theme.active;
end

function Theme.merge( Overrides: { [string]: any }? ): { [string]: any }
	if ( typeof( Overrides ) ~= "table" ) then
		return Theme.active;
	end

	local Merged = table.clone( Theme.active );

	for Key, Value in Overrides do
		Merged[ Key ] = Value;
	end

	return Merged;
end

return Theme;
