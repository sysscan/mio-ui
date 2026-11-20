-- Text items: separators, spacers, badges, plain labels, and readouts. A readout is any label a game
-- updates live (it has an `id`) or a hint with `presentation = "status"`. It renders as a stat row: a
-- status dot (accent while it reports something, faint when it is empty or off), the name on the left and
-- the value on the right when the text is "Name  Value" (two or more spaces) or "Name: Value", and "|"-separated parts as
-- "name value · name value". Hint text otherwise never renders (CLAUDE.md rule 3).

-- Dependencies
local P = require( "ui/primitives.lua" );
local Runtime = require( "core/runtime.lua" );
local Common = require( "ui/components/common.lua" );

-- Cache
local StringGsub = string.gsub;
local StringMatch = string.match;
local StringFind = string.find;
local StringLower = string.lower;
local StringSplit = string.split;
local TableConcat = table.concat;

-- Constants
local READOUT_HEIGHT = 22;
local DOT_SIZE = 5;
-- Readouts that start with or contain one of these report nothing live, so their dot goes faint.
local IDLE_PATTERNS = { "^off", "^idle", "^none", "^empty", "^stopped", "^disabled", "^waiting", "not ", " off%.?$" };

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

local function Escape( Text: string ): string
	local Safe = StringGsub( Text, "&", "&amp;" );
	Safe = StringGsub( Safe, "<", "&lt;" );
	Safe = StringGsub( Safe, ">", "&gt;" );
	return Safe;
end

local function Trim( Text: string ): string
	return ( StringMatch( Text, "^%s*(.-)%s*$" ) );
end

local function IsPlaceholder( Text: string ): boolean
	return Text == "" or Text == "-" or Text == "--";
end

local function IsIdle( Text: string ): boolean
	if ( IsPlaceholder( Text ) ) then
		return true;
	end

	local Lower = StringLower( Text );

	for _, Pattern in IDLE_PATTERNS do
		if ( StringFind( Lower, Pattern ) ) then
			return true;
		end
	end

	return false;
end

-- "Rounds 3 | Trees 41" -> "<dim>Rounds</dim> 3 · <dim>Trees</dim> 41", as rich text in the theme's colours.
local function RichValue( Text: string, Theme: any ): string
	if ( IsPlaceholder( Text ) ) then
		return `<font color="#{ Theme.textFaint : ToHex( ) }">—</font>`;
	end

	local Dim = Theme.textDim : ToHex( );
	local Parts = { };

	for _, Part in StringSplit( Text, "|" ) do
		local Segment = Trim( Part );

		if ( Segment ~= "" ) then
			local Name, Value = StringMatch( Segment, "^(%a[%a%s]-)%s+([%-%+%$%d%.].*)$" );

			if ( Name ) then
				Parts[ #Parts + 1 ] = `<font color="#{ Dim }">{ Escape( Name ) }</font> { Escape( Value ) }`;
			end

			if ( not Name ) then
				Parts[ #Parts + 1 ] = Escape( Segment );
			end
		end
	end

	return TableConcat( Parts, `  <font color="#{ Theme.textFaint : ToHex( ) }">·</font>  ` );
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

	-- Inset like the rows and buttons around it.
	local RowHolder = Holder( Section, nil, true );
	P.paddingXY( RowHolder, 6, 0 );
	local Row = P.create( "Frame", {
		Size = UDim2.new( 1, 0, 0, READOUT_HEIGHT );
		AutomaticSize = Enum.AutomaticSize.Y;
		BorderSizePixel = 0;
		Parent = RowHolder;
	} );
	P.corner( Row, Theme.cornerSmall );
	local Padding = P.paddingXY( Row, 8, 4 );
	Padding.PaddingLeft = UDim.new( 0, 8 );
	local Layout = P.listLayout( Row, 8, Enum.FillDirection.Horizontal );
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center;

	local Dot = P.create( "Frame", {
		Size = UDim2.fromOffset( DOT_SIZE, DOT_SIZE );
		BorderSizePixel = 0;
		LayoutOrder = 1;
		Parent = Row;
	} );
	P.corner( Dot, DOT_SIZE );

	local NameLabel = P.label( Row, "", {
		Theme = Theme;
		AutomaticSize = Enum.AutomaticSize.X;
		Size = UDim2.fromOffset( 0, READOUT_HEIGHT - 8 );
		TextSize = Theme.textSizeSmall;
		LayoutOrder = 2;
	} );

	local ValueLabel = P.label( Row, "", {
		Theme = Theme;
		Size = UDim2.new( 0, 0, 0, READOUT_HEIGHT - 8 );
		AutomaticSize = Enum.AutomaticSize.Y;
		Font = Theme.fontMedium;
		TextSize = Theme.textSizeSmall;
		TextWrapped = true;
		RichText = true;
		LayoutOrder = 3;
	} );
	-- The value takes whatever width the name leaves.
	P.create( "UIFlexItem", { FlexMode = Enum.UIFlexMode.Fill, Parent = ValueLabel } );

	local Current = Text;

	local function Render( )
		local Value = Trim( Current );
		local Name, Rest = StringMatch( Value, "^(%S[^|\n]-)%s%s+(%S.*)$" );
		local Multiline = StringFind( Value, "\n" ) ~= nil;

		-- "Active: Rage" reads the same as "Active  Rage".
		if ( not Name ) then
			Name, Rest = StringMatch( Value, "^(%a[^:|\n]-):%s+(%S.*)$" );
		end

		-- "Wins 0  |  Losses 0" is a list of parts, not a name and a value.
		if ( Multiline or ( Rest and StringFind( Rest, "^|" ) ) ) then
			Name = nil;
			Rest = nil;
		end

		NameLabel.Visible = Name ~= nil;
		NameLabel.Text = Name or "";
		ValueLabel.TextXAlignment = Name and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left;
		ValueLabel.Text = if ( Multiline ) then Escape( Value ) else RichValue( Rest or Value, Theme );

		Row.BackgroundColor3 = Theme.surfaceAlt;
		NameLabel.TextColor3 = Theme.textDim;
		ValueLabel.TextColor3 = Theme.text;
		Dot.BackgroundColor3 = IsIdle( Rest or Value ) and Theme.textFaint or Theme.accent;
	end

	Render( );
	Common.onTheme( Context, Render );
	return {
		setText = function( Value: string )
			Runtime.deferClient( function( )
				if ( not Row.Parent ) then
					return;
				end

				Current = tostring( Value );
				Render( );
			end );
		end;
		setHint = function( ) end;
	};
end
