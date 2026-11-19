-- Text items: separators, spacers, badges, plain labels, and readouts. A readout is any label a game
-- updates live (it has an `id`) or a hint with `presentation = "status"`; it gets a monospaced panel
-- so live data reads as data, not as a control. Hint text otherwise never renders (CLAUDE.md rule 3).

-- Dependencies
local P = require( "ui/primitives.lua" );
local Runtime = require( "core/runtime.lua" );
local Common = require( "ui/components/common.lua" );

-- Utilities
local function DeferSetText( Label: TextLabel, Text: string )
	Runtime.deferClient( function( )
		if ( Label.Parent ) then
			Label.Text = Text;
		end
	end );
end

local function Holder( Section: Instance, Height: number?, Automatic: boolean? ): Frame
	return P.create( "Frame", {
		BackgroundTransparency = 1;
		Size = UDim2.new( 1, 0, 0, Height or 0 );
		AutomaticSize = Automatic and Enum.AutomaticSize.Y or Enum.AutomaticSize.None;
		Parent = Section;
	} ) :: Frame;
end

-- Main
return function( Section: Instance, Spec: any, Context: any ): any
	local Theme = Context.theme;
	local Kind = Spec.type;

	if ( Kind == "separator" ) then
		local Line = P.create( "Frame", {
			AnchorPoint = Vector2.new( 0, 0.5 );
			Position = UDim2.new( 0, 6, 0.5, 0 );
			Size = UDim2.new( 1, -12, 0, 1 );
			BorderSizePixel = 0;
			Parent = Holder( Section, 12 );
		} );
		local function Paint( ) Line.BackgroundColor3 = Theme.strokeFaint; end
		Paint( );
		Common.onTheme( Context, Paint );
		return { };
	end

	if ( Kind == "spacer" ) then
		Holder( Section, tonumber( Spec.height ) or 8 );
		return { };
	end

	if ( Kind == "hint" and Spec.presentation ~= "status" ) then
		return { setText = function( ) end, setHint = function( ) end };
	end

	local Text = tostring( Spec.text or Spec.label or "" );

	if ( Kind == "badge" ) then
		local Pill = P.create( "Frame", {
			AutomaticSize = Enum.AutomaticSize.XY;
			BorderSizePixel = 0;
			Parent = Holder( Section, nil, true );
		} );
		P.corner( Pill, Theme.cornerSmall );
		P.paddingXY( Pill, 9, 4 );
		local Label = P.label( Pill, Text, {
			Theme = Theme;
			AutomaticSize = Enum.AutomaticSize.XY;
			Size = UDim2.fromOffset( 0, 14 );
			Font = Theme.fontMedium;
			TextSize = Theme.textSizeSmall;
		} );
		local function Paint( )
			Pill.BackgroundColor3 = Spec.color or Theme.accentFaint;
			Label.TextColor3 = Spec.textColor or Theme.accentBright;
		end
		Paint( );
		Common.onTheme( Context, Paint );
		return { setText = function( Value: string ) DeferSetText( Label, tostring( Value ) ); end };
	end

	local Readout = Spec.id ~= nil or Kind == "hint";

	if ( not Readout ) then
		local Wrapper = Holder( Section, nil, true );
		P.paddingXY( Wrapper, 6, 2 );
		local Label = P.label( Wrapper, Text, {
			Theme = Theme;
			Size = UDim2.new( 1, 0, 0, 0 );
			AutomaticSize = Enum.AutomaticSize.Y;
			TextWrapped = true;
			TextSize = Theme.textSize - 1;
			TextYAlignment = Enum.TextYAlignment.Top;
		} );
		local function Paint( ) Label.TextColor3 = Theme.textDim; end
		Paint( );
		Common.onTheme( Context, Paint );
		return { setText = function( Value: string ) DeferSetText( Label, tostring( Value ) ); end };
	end

	local Panel = P.create( "Frame", {
		Size = UDim2.new( 1, 0, 0, 0 );
		AutomaticSize = Enum.AutomaticSize.Y;
		BorderSizePixel = 0;
		Parent = Holder( Section, nil, true );
	} );
	P.corner( Panel, Theme.cornerSmall );
	local Padding = P.paddingXY( Panel, 12, 7 );
	Padding.PaddingLeft = UDim.new( 0, 14 );
	-- Inset from the panel's edges so the bar never reaches its rounded corners.
	local Accent = P.create( "Frame", {
		Position = UDim2.fromOffset( -9, -1 );
		Size = UDim2.new( 0, 2, 1, 2 );
		BorderSizePixel = 0;
		Parent = Panel;
	} );
	P.corner( Accent, 1 );
	local Label = P.label( Panel, Text, {
		Theme = Theme;
		Size = UDim2.new( 1, 0, 0, 0 );
		AutomaticSize = Enum.AutomaticSize.Y;
		TextWrapped = true;
		TextSize = Theme.textSizeSmall;
		TextYAlignment = Enum.TextYAlignment.Top;
		LineHeight = 1.15;
	} );

	if ( Theme.fontFaceMono ) then
		Label.FontFace = Theme.fontFaceMono;
	end

	local function Paint( )
		Panel.BackgroundColor3 = Theme.surfaceAlt;
		Accent.BackgroundColor3 = Theme.accent;
		Label.TextColor3 = Theme.text;
	end

	Paint( );
	Common.onTheme( Context, Paint );
	return {
		setText = function( Value: string ) DeferSetText( Label, tostring( Value ) ); end;
		setHint = function( ) end;
	};
end
