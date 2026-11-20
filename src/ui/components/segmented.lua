-- Segmented control: a select with two or three short fixed options, shown as one row of buttons
-- so the choice is visible without opening anything. ui/init.lua routes qualifying selects here;
-- the control keeps the select contract (set/get/setValue/getValue, dispatch type "select").

-- Dependencies
local P = require( "ui/primitives.lua" );
local Common = require( "ui/components/common.lua" );

-- Utilities
local function OptionValue( Option: any ): any
	if ( typeof( Option ) == "table" ) then
		return Option.value;
	end

	return Option;
end

local function OptionLabel( Option: any ): string
	if ( typeof( Option ) == "table" ) then
		return tostring( Option.label or Option.value );
	end

	return tostring( Option );
end

-- Main
return function( Section: Instance, Spec: any, Context: any ): any
	local Theme = Context.theme;
	local Key = Spec.key;
	local Options = Spec.options or { };

	local function Valid( Value: any ): boolean
		for _, Option in Options do
			if ( OptionValue( Option ) == Value ) then
				return true;
			end
		end

		return false;
	end

	local Value = Context.config[ Key ];

	if ( not Valid( Value ) ) then
		Value = Valid( Spec.default ) and Spec.default or OptionValue( Options[ 1 ] );
	end

	Context.config[ Key ] = Value;

	local Row, Label = Common.row( Section, Theme, Spec.label or Key, nil, 168 );
	local Track = P.create( "Frame", {
		AnchorPoint = Vector2.new( 1, 0.5 );
		Position = UDim2.new( 1, 0, 0.5, 0 );
		Size = UDim2.new( 0.56, 0, 0, Theme.controlHeight or 26 );
		BorderSizePixel = 0;
		Parent = Row;
	} );
	Label.Size = UDim2.new( 0.44, -8, 1, 0 );
	P.corner( Track, Theme.cornerSmall );
	local TrackStroke = P.stroke( Track, Theme.stroke, 1, 0 );
	P.padding( Track, 2 );
	P.listLayout( Track, 2, Enum.FillDirection.Horizontal );

	local Buttons = { };
	local Control = { };

	local function Render( )
		Track.BackgroundColor3 = Theme.control;
		TrackStroke.Color = Theme.stroke;
		Label.TextColor3 = Theme.textDim;

		for _, Entry in Buttons do
			local On = Entry.value == Value;
			Entry.button.BackgroundColor3 = Theme.overlay;
			Entry.button.BackgroundTransparency = On and 0 or 1;
			Entry.button.TextColor3 = On and Theme.accent or Theme.textDim;
			Entry.button.FontFace = Theme.fontFaceMedium;
		end
	end

	for Order, Option in Options do
		local Button = P.create( "TextButton", {
			Size = UDim2.new( 1 / #Options, -2 * ( #Options - 1 ) / #Options, 1, 0 );
			BorderSizePixel = 0;
			AutoButtonColor = false;
			Text = OptionLabel( Option );
			TextSize = Theme.textSizeSmall;
			TextTruncate = Enum.TextTruncate.AtEnd;
			LayoutOrder = Order;
			Parent = Track;
		} );
		P.corner( Button, Theme.cornerSmall );
		Buttons[ #Buttons + 1 ] = { button = Button, value = OptionValue( Option ) };
		Common.connect( Context, Button.Activated, function( )
			Control.set( OptionValue( Option ) );
		end );
	end

	function Control.set( Next: any, Silent: boolean? )
		if ( not Valid( Next ) ) then
			return;
		end

		local Changed = Next ~= Value;
		Value = Next;
		Context.config[ Key ] = Value;
		Render( );

		if ( not Changed or Silent ) then
			return;
		end

		if ( Spec.onChange ) then
			Common.safeCall( Context, "select onChange " .. tostring( Key ), Spec.onChange, Value );
		end

		Context.dispatch( Key, Value, "select" );
	end

	function Control.get( ): any
		return Value;
	end

	function Control.refresh( ) end

	Control.setValue = Control.set;
	Control.getValue = Control.get;

	Render( );
	Common.onTheme( Context, Render );
	return Control;
end
