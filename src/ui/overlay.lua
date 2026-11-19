-- Screen overlays that sit outside the menu, in the classic script-menu style: a watermark bar
-- (brand, game, fps, ping, clock) and a draggable keybind list showing each bound key and whether
-- its feature is on. ui/init.lua owns the data; this module only draws it.

-- Dependencies
local Services = require( "core/services.lua" );
local Runtime = require( "core/runtime.lua" );
local P = require( "ui/primitives.lua" );

-- Services
local RunService = Services.RunService;
local UserInputService = Services.UserInputService;
local Players = Services.Players;

-- Cache
local OsClock = os.clock;
local OsDate = os.date;
local MathFloor = math.floor;
local StringFormat = string.format;
local TableConcat = table.concat;

-- Constants
local DISPLAY_ORDER = 999;
local MARGIN = 10;
local BAR_HEIGHT = 22;
local LIST_WIDTH = 190;
local LIST_HEADER = 22;
local LIST_ROW = 17;
local TICK_INTERVAL = 0.5;

-- Types
export type KeybindRow = {
	Name: string,
	Key: string,
	Active: boolean,
};

export type OverlayOptions = {
	Theme: { [string]: any },
	Brand: string,
	Game: string,
};

-- Utilities
local Box = { }; do
	-- A panel drawn the way the menu draws its window: black outer line, lighter inner line and
	-- an accent strip along the top. Callers put their content in the returned Content frame, so
	-- their layouts and padding never touch the border pieces.
	function Box.New( Parent: Instance, Theme: any ): ( Frame, ( any ) -> ( ), Frame )
		local Frame = P.create( "Frame", {
			BorderSizePixel = 0;
			Parent = Parent;
		} ) :: Frame;
		local Outer = P.stroke( Frame, Theme.outline or Theme.stroke, 1, 0 );
		local Inner = P.create( "Frame", {
			Position = UDim2.fromOffset( 1, 1 );
			Size = UDim2.new( 1, -2, 1, -2 );
			BackgroundTransparency = 1;
			ZIndex = 3;
			Parent = Frame;
		} );
		local InnerStroke = P.stroke( Inner, Theme.stroke, 1, 0 );
		local Accent = P.create( "Frame", {
			Size = UDim2.new( 1, 0, 0, 2 );
			BorderSizePixel = 0;
			BackgroundColor3 = Color3.new( 1, 1, 1 );
			ZIndex = 4;
			Parent = Frame;
		} );
		local AccentGradient = P.gradient( Accent, Theme.accent, Theme.accentSoft or Theme.accent, 0 );
		local Content = P.create( "Frame", {
			BackgroundTransparency = 1;
			ZIndex = 5;
			Parent = Frame;
		} ) :: Frame;

		local function Paint( Colors: any )
			Frame.BackgroundColor3 = Colors.panel or Colors.background;
			Outer.Color = Colors.outline or Colors.stroke;
			InnerStroke.Color = Colors.stroke;
			AccentGradient.Color = ColorSequence.new( Colors.accent, Colors.accentSoft or Colors.accent );
		end

		Paint( Theme );
		return Frame, Paint, Content;
	end
end

local function ReadPing( ): number?
	local LocalPlayer = Players and Players.LocalPlayer;

	if ( not LocalPlayer ) then
		return nil;
	end

	local Ok, Seconds = pcall( LocalPlayer.GetNetworkPing, LocalPlayer );

	if ( not Ok or typeof( Seconds ) ~= "number" ) then
		return nil;
	end

	return Seconds * 1000;
end

local function EscapeRich( Text: string ): string
	return ( string.gsub( string.gsub( string.gsub( Text, "&", "&amp;" ), "<", "&lt;" ), ">", "&gt;" ) );
end

local function Hex( Color: Color3 ): string
	return StringFormat( "#%02X%02X%02X", MathFloor( Color.R * 255 + 0.5 ), MathFloor( Color.G * 255 + 0.5 ), MathFloor( Color.B * 255 + 0.5 ) );
end

-- Classes
local Overlay = { }; do
	Overlay.__index = Overlay;

	function Overlay.New( Options: OverlayOptions ): any
		local Theme = Options.Theme;
		local Self = setmetatable( {
			Theme = Theme;
			Brand = string.lower( Options.Brand or "" );
			Game = string.lower( Options.Game or "" );
			Painters = { };
			Connections = { };
			Rows = { };
			Binds = { };
			Signature = nil;
			WatermarkWanted = false;
			KeybindsWanted = false;
			Fps = 0;
			Destroyed = false;
		}, Overlay );

		local Screen = P.create( "ScreenGui", {
			Name = "\0";
			ResetOnSpawn = false;
			IgnoreGuiInset = false;
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
			DisplayOrder = DISPLAY_ORDER;
		} );

		if ( not Runtime.setGuiParent( Screen ) ) then
			Screen : Destroy( );
			error( "[Hub][UI] no available GUI parent for overlay" );
		end

		Self.Screen = Screen;
		Self : _BuildWatermark( );
		Self : _BuildKeybinds( );
		Self : _StartTicker( );
		Self : RefreshTheme( );
		return Self;
	end

	function Overlay : _Give( Connection: RBXScriptConnection ): RBXScriptConnection
		table.insert( self.Connections, Connection );
		return Connection;
	end

	function Overlay : _BuildWatermark( )
		local Theme = self.Theme;
		local Bar, Paint, Content = Box.New( self.Screen, Theme );
		Bar.Position = UDim2.fromOffset( MARGIN, MARGIN );
		Bar.Size = UDim2.fromOffset( 0, BAR_HEIGHT );
		Bar.AutomaticSize = Enum.AutomaticSize.X;
		Bar.Visible = false;
		Content.Size = UDim2.new( 0, 0, 1, 0 );
		Content.AutomaticSize = Enum.AutomaticSize.X;
		P.paddingXY( Content, 8, 0 );

		local Text = P.label( Content, "", {
			Theme = Theme;
			AutomaticSize = Enum.AutomaticSize.X;
			Size = UDim2.new( 0, 0, 1, 0 );
			RichText = true;
			TextSize = Theme.textSizeSmall;
			ZIndex = 5;
		} );

		self.Watermark = Bar;
		self.WatermarkText = Text;
		table.insert( self.Painters, function( Colors: any )
			Paint( Colors );
			Text.TextColor3 = Colors.textDim;
			Text.FontFace = Colors.fontFace;
		end );
	end

	function Overlay : _BuildKeybinds( )
		local Theme = self.Theme;
		local Panel, Paint, Content = Box.New( self.Screen, Theme );
		Panel.Position = UDim2.new( 0, MARGIN, 0.35, 0 );
		Panel.Size = UDim2.fromOffset( LIST_WIDTH, 0 );
		Panel.AutomaticSize = Enum.AutomaticSize.Y;
		Panel.Visible = false;
		Content.Size = UDim2.new( 1, 0, 0, 0 );
		Content.AutomaticSize = Enum.AutomaticSize.Y;
		P.listLayout( Content, 0 );

		local Header = P.label( Content, "keybinds", {
			Theme = Theme;
			Size = UDim2.new( 1, 0, 0, LIST_HEADER );
			TextXAlignment = Enum.TextXAlignment.Center;
			TextSize = Theme.textSizeSmall;
			LayoutOrder = 0;
			ZIndex = 5;
		} );
		Header.Active = true;

		local Line = P.create( "Frame", {
			Size = UDim2.new( 1, -12, 0, 1 );
			Position = UDim2.fromOffset( 6, 0 );
			BorderSizePixel = 0;
			LayoutOrder = 1;
			ZIndex = 5;
			Parent = Content;
		} );

		local List = P.create( "Frame", {
			Size = UDim2.new( 1, 0, 0, 0 );
			AutomaticSize = Enum.AutomaticSize.Y;
			BackgroundTransparency = 1;
			LayoutOrder = 2;
			ZIndex = 5;
			Parent = Content;
		} );
		P.listLayout( List, 0 );

		local ListPadding = P.paddingXY( List, 8, 0 );
		ListPadding.PaddingTop = UDim.new( 0, 3 );
		ListPadding.PaddingBottom = UDim.new( 0, 5 );

		self.KeybindPanel = Panel;
		self.KeybindList = List;
		table.insert( self.Painters, function( Colors: any )
			Paint( Colors );
			Header.TextColor3 = Colors.text;
			Header.FontFace = Colors.fontFace;
			Line.BackgroundColor3 = Colors.stroke;
		end );

		self : _EnableDrag( Panel, Header );
	end

	function Overlay : _EnableDrag( Panel: GuiObject, Handle: GuiObject )
		local Dragging: InputObject? = nil;
		local StartInput = Vector2.zero;
		local StartPosition = Panel.Position;

		self : _Give( Handle.InputBegan : Connect( function( Input: InputObject )
			local Kind = Input.UserInputType;

			if ( Kind ~= Enum.UserInputType.MouseButton1 and Kind ~= Enum.UserInputType.Touch ) then
				return;
			end

			Dragging = Input;
			StartInput = Vector2.new( Input.Position.X, Input.Position.Y );
			StartPosition = Panel.Position;
		end ) );

		self : _Give( UserInputService.InputChanged : Connect( function( Input: InputObject )
			if ( not Dragging ) then
				return;
			end

			local Moving = Input.UserInputType == Enum.UserInputType.MouseMovement or Input == Dragging;

			if ( not Moving ) then
				return;
			end

			local Delta = Vector2.new( Input.Position.X, Input.Position.Y ) - StartInput;
			Panel.Position = UDim2.new( StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y );
		end ) );

		self : _Give( UserInputService.InputEnded : Connect( function( Input: InputObject )
			if ( Input == Dragging or Input.UserInputType == Enum.UserInputType.MouseButton1 ) then
				Dragging = nil;
			end
		end ) );
	end

	function Overlay : _StartTicker( )
		local Frames = 0;
		local Since = OsClock( );

		self : _Give( RunService.Heartbeat : Connect( function( )
			Frames += 1;
			local Now = OsClock( );
			local Elapsed = Now - Since;

			if ( Elapsed < TICK_INTERVAL ) then
				return;
			end

			self.Fps = Frames / Elapsed;
			Frames = 0;
			Since = Now;

			if ( self.Watermark.Visible ) then
				self : _RenderWatermark( );
			end
		end ) );
	end

	function Overlay : _RenderWatermark( )
		local Colors = self.Theme;
		local Ping = ReadPing( );
		local Parts = { };

		if ( self.Brand ~= "" ) then
			Parts[ #Parts + 1 ] = StringFormat( '<font color="%s">%s</font>', Hex( Colors.accent ), EscapeRich( self.Brand ) );
		end

		if ( self.Game ~= "" ) then
			Parts[ #Parts + 1 ] = EscapeRich( self.Game );
		end

		Parts[ #Parts + 1 ] = StringFormat( "%d fps", MathFloor( self.Fps + 0.5 ) );
		Parts[ #Parts + 1 ] = if ( Ping ) then StringFormat( "%d ms", MathFloor( Ping + 0.5 ) ) else "-- ms";
		Parts[ #Parts + 1 ] = tostring( OsDate( "%H:%M" ) );

		local Separator = StringFormat( ' <font color="%s">|</font> ', Hex( Colors.textFaint ) );
		self.WatermarkText.Text = TableConcat( Parts, Separator );
	end

	function Overlay : _RenderKeybinds( )
		local Colors = self.Theme;

		for _, Row in self.Rows do
			Row.Frame : Destroy( );
		end

		table.clear( self.Rows );

		for Order, Bind in self.Binds do
			local Frame = P.create( "Frame", {
				Size = UDim2.new( 1, 0, 0, LIST_ROW );
				BackgroundTransparency = 1;
				LayoutOrder = Order;
				ZIndex = 5;
				Parent = self.KeybindList;
			} );
			local Name = P.label( Frame, string.lower( Bind.Name ), {
				Theme = Colors;
				Size = UDim2.new( 1, -64, 1, 0 );
				TextSize = Colors.textSizeSmall;
				TextColor3 = Bind.Active and Colors.text or Colors.textFaint;
				TextTruncate = Enum.TextTruncate.AtEnd;
				ZIndex = 6;
			} );
			local Key = P.label( Frame, "[" .. string.lower( Bind.Key ) .. "]", {
				Theme = Colors;
				AnchorPoint = Vector2.new( 1, 0 );
				Position = UDim2.fromScale( 1, 0 );
				Size = UDim2.new( 0, 64, 1, 0 );
				TextXAlignment = Enum.TextXAlignment.Right;
				TextSize = Colors.textSizeSmall;
				TextColor3 = Bind.Active and Colors.accent or Colors.textFaint;
				ZIndex = 6;
			} );
			self.Rows[ Order ] = { Frame = Frame, Name = Name, Key = Key, Active = Bind.Active };
		end

		self.KeybindPanel.Visible = self.KeybindsWanted and #self.Binds > 0;
	end

	function Overlay : SetWatermarkVisible( Visible: boolean )
		if ( self.Destroyed ) then
			return;
		end

		self.WatermarkWanted = Visible == true;
		self.Watermark.Visible = self.WatermarkWanted;

		if ( self.WatermarkWanted ) then
			self : _RenderWatermark( );
		end
	end

	function Overlay : SetKeybindsVisible( Visible: boolean )
		if ( self.Destroyed ) then
			return;
		end

		self.KeybindsWanted = Visible == true;
		self.KeybindPanel.Visible = self.KeybindsWanted and #self.Binds > 0;
	end

	-- Rebuilds only when something shown actually changed, so callers can push on every dispatch.
	function Overlay : SetKeybinds( Binds: { KeybindRow } )
		if ( self.Destroyed ) then
			return;
		end

		local Parts = { };

		for Index, Bind in Binds do
			Parts[ Index ] = Bind.Name .. "\1" .. Bind.Key .. "\1" .. tostring( Bind.Active );
		end

		local Signature = TableConcat( Parts, "\0" );

		if ( Signature == self.Signature ) then
			return;
		end

		self.Signature = Signature;
		self.Binds = Binds;
		self : _RenderKeybinds( );
	end

	function Overlay : Containers( ): { GuiObject }
		return { self.Watermark, self.KeybindPanel };
	end

	function Overlay : RefreshTheme( )
		if ( self.Destroyed ) then
			return;
		end

		for _, Painter in self.Painters do
			Painter( self.Theme );
		end

		self.Signature = nil;
		self : _RenderKeybinds( );

		if ( self.Watermark.Visible ) then
			self : _RenderWatermark( );
		end
	end

	function Overlay : Destroy( )
		if ( self.Destroyed ) then
			return;
		end

		self.Destroyed = true;

		for _, Connection in self.Connections do
			Connection : Disconnect( );
		end

		table.clear( self.Connections );
		table.clear( self.Rows );
		self.Screen : Destroy( );
	end
end

-- Main
return Overlay;
