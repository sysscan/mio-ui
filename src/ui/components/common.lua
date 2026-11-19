-- Shared helpers for the menu components: guarded callbacks, maid-tracked connections, theme
-- listeners, and the standard row / field / clickable building blocks.

-- Dependencies
local P = require( "ui/primitives.lua" );
local Runtime = require( "core/runtime.lua" );

-- Main
local Common = { };

function Common.warn( Context: any, ... )
	if ( Context and typeof( Context.warn ) == "function" ) then
		Context.warn( ... );
		return;
	end

	warn( "[Hub][UI]", ... );
end

function Common.safeCall( Context: any, Label: string, Callback: any, ... ): any
	if ( typeof( Callback ) ~= "function" ) then
		return nil;
	end

	local Ok, Result = pcall( Callback, ... );

	if ( not Ok ) then
		Common.warn( Context, Label, "->", Result );
		return nil;
	end

	return Result;
end

function Common.defer( Context: any, Label: string, Callback: ( ) -> ( ) ): any
	local Connection = Runtime.deferClient( function( )
		Common.safeCall( Context, Label, Callback );
	end );

	if ( Connection and Context and Context.maid ) then
		Context.maid : give( Connection );
	end

	return Connection;
end

function Common.connect( Context: any, Signal: RBXScriptSignal, Callback: ( ...any ) -> ( ) ): RBXScriptConnection
	local Connection = Signal : Connect( Callback );

	if ( Context and Context.maid ) then
		Context.maid : give( Connection );
	end

	return Connection;
end

function Common.onTheme( Context: any, Callback: any ): any
	if ( Context and typeof( Context.onTheme ) == "function" and typeof( Callback ) == "function" ) then
		return Context.onTheme( Callback );
	end

	return nil;
end

-- A label-left / control-right row. Rows built at the theme's row height are remembered on the
-- theme so a density change can resize them in place (see Common.resizeRows).
function Common.row( Parent: Instance, Theme: any, Text: string, Height: number?, ControlWidth: number? ): ( Frame, TextLabel )
	local Reserve = ( ControlWidth or 72 ) + 12;
	local Row = P.create( "Frame", {
		BackgroundColor3 = Theme.overlay;
		BackgroundTransparency = 1;
		Size = UDim2.new( 1, 0, 0, Height or Theme.rowHeight );
		Parent = Parent;
	} ) :: Frame;
	P.corner( Row, Theme.cornerSmall );
	P.paddingXY( Row, 6, 0 );

	local Label = P.label( Row, Text, {
		Theme = Theme;
		Size = UDim2.new( 1, -Reserve, 1, 0 );
		TextColor3 = Theme.textDim;
		Font = Theme.fontMedium;
		TextSize = Theme.textSize - 1;
		TextTruncate = Enum.TextTruncate.AtEnd;
	} );

	if ( Height == nil ) then
		Theme.__rows = Theme.__rows or { };
		table.insert( Theme.__rows, Row );
	end

	return Row, Label;
end

function Common.resizeRows( Theme: any )
	local Rows = Theme.__rows;

	if ( not Rows ) then
		return;
	end

	for Index = #Rows, 1, -1 do
		local Row = Rows[ Index ];

		if ( not Row.Parent ) then
			table.remove( Rows, Index );
			continue;
		end

		Row.Size = UDim2.new( 1, 0, 0, Theme.rowHeight );
	end
end

function Common.field( Parent: Instance, Theme: any, Text: string, ControlHeight: number? ): ( Frame, TextLabel, Frame )
	local Field = P.create( "Frame", {
		BackgroundTransparency = 1;
		Size = UDim2.new( 1, 0, 0, 0 );
		AutomaticSize = Enum.AutomaticSize.Y;
		Parent = Parent;
	} ) :: Frame;
	P.listLayout( Field, Theme.fieldGap or 6 );
	P.paddingXY( Field, 6, 2 );

	local Label = P.label( Field, Text, {
		Theme = Theme;
		Size = UDim2.new( 1, 0, 0, 16 );
		TextColor3 = Theme.textDim;
		Font = Theme.fontMedium;
		TextSize = Theme.textSize - 1;
		TextTruncate = Enum.TextTruncate.AtEnd;
	} );

	local Control = P.create( "Frame", {
		BackgroundTransparency = 1;
		Size = UDim2.new( 1, 0, 0, ControlHeight or Theme.controlHeight or Theme.rowHeight );
		Parent = Field;
	} ) :: Frame;

	return Field, Label, Control;
end

function Common.clickable( Parent: Instance, Theme: any, Options: any? ): TextButton
	Options = Options or { };

	local function BaseColor( ): Color3
		if ( typeof( Options.getBaseColor ) == "function" ) then
			return Options.getBaseColor( );
		end

		return Options.baseColor or Theme.surfaceAlt;
	end

	local function HoverColor( ): Color3
		if ( typeof( Options.getHoverColor ) == "function" ) then
			return Options.getHoverColor( );
		end

		return Options.hoverColor or Theme.controlHover or Theme.overlay;
	end

	local function HoverStrokeColor( ): Color3
		if ( typeof( Options.getHoverStrokeColor ) == "function" ) then
			return Options.getHoverStrokeColor( );
		end

		return Options.hoverStrokeColor or Theme.strokeBright;
	end

	local Button = P.create( "TextButton", {
		AutoButtonColor = false;
		BackgroundColor3 = BaseColor( );
		Text = "";
		ClipsDescendants = true;
		Parent = Parent;
	} ) :: TextButton;
	P.corner( Button, Theme.cornerSmall );
	local PressScale = P.create( "UIScale", { Scale = 1, Parent = Button } );
	local Stroke = nil;

	if ( Options.stroke ~= false ) then
		Stroke = P.stroke( Button, Theme.stroke, 1, 0 );
	end

	local Tracker = { maid = Options.maid };
	Common.connect( Tracker, Button.MouseEnter, function( )
		if ( Options.disabled == true ) then
			return;
		end

		P.tween( Button, Theme.fast or 0.1, { BackgroundColor3 = HoverColor( ) } );

		if ( Stroke ) then
			Stroke.Color = HoverStrokeColor( );
		end
	end );
	Common.connect( Tracker, Button.MouseLeave, function( )
		P.tween( Button, Theme.fast or 0.1, { BackgroundColor3 = BaseColor( ) } );
		P.tween( PressScale, Theme.fast or 0.1, { Scale = 1 } );

		if ( Stroke ) then
			Stroke.Color = Theme.stroke;
		end
	end );
	Common.connect( Tracker, Button.MouseButton1Down, function( )
		if ( Options.disabled ~= true ) then
			P.tween( PressScale, Theme.fast or 0.1, { Scale = 0.985 } );
		end
	end );
	Common.connect( Tracker, Button.MouseButton1Up, function( )
		P.tween( PressScale, Theme.fast or 0.1, { Scale = 1 } );
	end );

	return Button;
end

return Common;
