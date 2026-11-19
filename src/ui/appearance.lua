-- Applies the hub-wide appearance preferences (background, motion, scale, density) on top of the
-- brand theme. `Base` is the untouched theme, so switching back to a preset restores it exactly.

-- Constants
local PRESETS = {
	Midnight = {
		background = Color3.fromRGB( 13, 15, 22 ); panel = Color3.fromRGB( 13, 15, 22 ); rail = Color3.fromRGB( 10, 12, 18 ); titleBar = Color3.fromRGB( 13, 15, 22 );
		surface = Color3.fromRGB( 17, 20, 29 ); surfaceAlt = Color3.fromRGB( 21, 25, 35 ); overlay = Color3.fromRGB( 27, 32, 44 ); elevated = Color3.fromRGB( 19, 23, 33 );
		control = Color3.fromRGB( 22, 26, 37 ); controlHover = Color3.fromRGB( 30, 35, 48 ); stroke = Color3.fromRGB( 38, 44, 60 ); strokeFaint = Color3.fromRGB( 28, 33, 45 );
	};
	Graphite = {
		background = Color3.fromRGB( 24, 24, 24 ); panel = Color3.fromRGB( 24, 24, 24 ); rail = Color3.fromRGB( 20, 20, 20 ); titleBar = Color3.fromRGB( 24, 24, 24 );
		surface = Color3.fromRGB( 30, 30, 30 ); surfaceAlt = Color3.fromRGB( 35, 35, 35 ); overlay = Color3.fromRGB( 44, 44, 44 ); elevated = Color3.fromRGB( 33, 33, 33 );
		control = Color3.fromRGB( 38, 38, 38 ); controlHover = Color3.fromRGB( 48, 48, 48 ); stroke = Color3.fromRGB( 56, 56, 56 ); strokeFaint = Color3.fromRGB( 44, 44, 44 );
	};

};

-- Main
local Appearance = { };

function Appearance.apply( Theme: any, Base: any, Preferences: any )
	for Key in PRESETS.Midnight do
		Theme[ Key ] = Base[ Key ];
	end

	for Key, Value in PRESETS[ Preferences.BackgroundStyle ] or { } do
		Theme[ Key ] = Value;
	end

	for _, Key in { "fast", "normal", "slow" } do
		Theme[ Key ] = Preferences.ReducedMotion and 0 or Base[ Key ];
	end

	local Scale = tonumber( Preferences.MenuScale ) or 1;

	if ( Scale ~= Scale or math.abs( Scale ) == math.huge ) then
		Scale = 1;
	end

	Theme.menuScale = math.clamp( Scale, 0.75, 1.25 );

	-- Touch always gets the tall rows; otherwise the Density preference picks them.
	Theme.rowHeight = ( Theme.touch and Base.rowHeightTouch ) or ( Preferences.Density == "Compact" and Base.rowHeightCompact ) or Base.rowHeight;
end

return Appearance;
