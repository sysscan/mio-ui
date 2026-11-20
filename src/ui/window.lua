-- Window shell for the hub menu: sidebar of game pages with the hub's own pages (Favorites,
-- Settings) pinned in a footer, a header with search, and masonry pages of section cards. The
-- active page's section tabs stack under it in the sidebar. It switches between a full sidebar,
-- an icon rail and a bottom tab bar as the window narrows, and always uses the tab bar on touch
-- devices; those two have no room for section tabs, so the page shows them in a strip instead.
--
-- `addPage`, `showPage`, `refreshTheme`, `setVisible`, `isVisible`, `destroy` and each page's
-- `addSection` keep their old names and shapes: ui/init.lua and ui/workspace.lua drive them.

-- Dependencies
local Runtime = require( "core/runtime.lua" );
local Services = require( "core/services.lua" );
local Theme = require( "ui/theme.lua" );
local Icons = require( "ui/icons.lua" );
local P = require( "ui/primitives.lua" );

-- Services
local UserInputService = Services.UserInputService;
local TextService = Services.TextService;

-- Constants
local RAIL_BREAKPOINT = 720;
local BAR_BREAKPOINT = 540;
local RAIL_WIDTH = 66;
local BAR_HEIGHT = 52;
local FOOTER_HEIGHT = 40;
local BRAND_HEIGHT = 48;
local CHIP_BAR_HEIGHT = 28;
local CHIP_THRESHOLD = 5;
-- Full sidebar: tabs sit TAB_INSET in from each edge, labels start TAB_TEXT_LEFT into the tab, and
-- the sidebar is as wide as its longest label needs, between TAB_MIN_WIDTH and theme.tabWidth.
local TAB_MIN_WIDTH = 112;
local TAB_INSET = 6;
local TAB_TEXT_LEFT = 32;
local TAB_TEXT_RIGHT = 8;
local SECTION_TAB_HEIGHT = 22;
local THREE_COLUMN_WIDTH = 860;
local TWO_COLUMN_WIDTH = 440;
local VIEWPORT_MARGIN = Vector2.new( 20, 28 );
local TOUCH_MARGIN = Vector2.new( 12, 10 );
local DRAG_MARGIN = 8;
local IMAGE_CACHE_DIR = "microhub/cache";
local ACRONYMS = { ESP = true, FOV = true, UI = true, FPS = true, RMB = true, NPC = true, NPCS = true, AFK = true, HUD = true };

-- Utilities
local function Trim( Value: any ): string
	local Cleaned = string.gsub( string.gsub( tostring( Value or "" ), "^%s+", "" ), "%s+$", "" );

	if ( Cleaned == "" ) then
		return "UI";
	end

	return Cleaned;
end

-- Game titles arrive in capitals ("PHANTOM FORCES"); short words are usually acronyms (SCP, TTK).
local function PrettyTitle( Title: string ): string
	if ( Title ~= string.upper( Title ) ) then
		return Title;
	end

	return ( string.gsub( Title, "%a+", function( Word: string ): string
		if ( #Word <= 3 ) then
			return Word;
		end

		return string.sub( Word, 1, 1 ) .. string.lower( string.sub( Word, 2 ) );
	end ) );
end

local function SectionCaption( Title: string ): string
	if ( Title ~= string.upper( Title ) ) then
		return Title;
	end

	local Caption = string.gsub( Title, "%a+", function( Word: string ): string
		if ( ACRONYMS[ Word ] ) then
			return Word;
		end

		return string.lower( Word );
	end );

	return ( string.gsub( Caption, "^%l", string.upper ) );
end

local function ResolveRemoteImage( Url: string ): string?
	if ( not Runtime.canFs ) then
		return nil;
	end

	local Slug = string.sub( ( string.gsub( Url, "%W", "" ) ), -48 );
	local Clean = string.gsub( string.gsub( Url, "%?.*$", "" ), "#.*$", "" );
	local Extension = string.match( Clean, "%.([%a%d]+)$" );

	if ( not Extension or #Extension > 5 ) then
		Extension = "png";
	end

	local Path = IMAGE_CACHE_DIR .. "/logo_" .. tostring( #Url ) .. "_" .. Slug .. "." .. string.lower( Extension );

	if ( not Runtime.fileExists( Path ) ) then
		local Ok, Body = pcall( function( ) return game : HttpGet( Url ); end );

		if ( not Ok or typeof( Body ) ~= "string" or Body == "" ) then
			return nil;
		end

		Runtime.makeFolder( "microhub" );
		Runtime.makeFolder( IMAGE_CACHE_DIR );

		if ( not Runtime.writeFile( Path, Body ) ) then
			return nil;
		end
	end

	return Runtime.customAsset( Path );
end

local function ResolveImage( Paths: { string? } ): string?
	for _, RawPath in Paths do
		if ( typeof( RawPath ) ~= "string" or RawPath == "" ) then
			continue;
		end

		if ( string.find( RawPath, "^rbxasset" ) ) then
			return RawPath;
		end

		if ( string.find( RawPath, "^http" ) ) then
			local Asset = ResolveRemoteImage( RawPath );

			if ( Asset ) then
				return Asset;
			end

			continue;
		end

		if ( Runtime.canFs and not Runtime.fileExists( RawPath ) ) then
			continue;
		end

		local Asset = Runtime.customAsset( RawPath );

		if ( Asset ) then
			return Asset;
		end
	end

	return nil;
end

-- Main
local Window = { };
Window.__index = Window;

function Window.new( Options: any ): any
	Options = Options or { };
	local Palette = Options.theme or Theme.get( );
	local Title = Trim( Options.title or Theme.brandName );
	local Self = setmetatable( {
		theme = Palette;
		title = Title;
		subtitle = Options.subtitle or Options.meta or "";
		pages = { };
		tabButtons = { };
		activePage = nil;
		_maid = Options.maid;
		_connections = { };
		_painters = { };
		_touch = Options.touch == true;
		_mode = "full";
		_columns = 2;
	}, Window );

	local Screen = P.create( "ScreenGui", {
		Name = "\0";
		ResetOnSpawn = false;
		IgnoreGuiInset = true;
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling;
		DisplayOrder = 1000;
	} );

	if ( not Runtime.setGuiParent( Screen ) ) then
		Screen : Destroy( );
		error( "[Hub][UI] no available GUI parent" );
	end

	Self.screen = Screen;

	local Shell = P.create( "Frame", {
		Name = "\0";
		AnchorPoint = Vector2.new( 0.5, 0.5 );
		Position = UDim2.fromScale( 0.5, 0.5 );
		Size = UDim2.fromOffset( 820, 540 );
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		Parent = Screen;
	} );
	Self.shell = Shell;
	Self.shellScale = P.create( "UIScale", { Scale = Palette.menuScale or 1, Parent = Shell } );

	local Root = P.create( "Frame", {
		Name = "\0";
		Size = UDim2.fromScale( 1, 1 );
		BorderSizePixel = 0;
		ClipsDescendants = true;
		Parent = Shell;
	} );
	P.corner( Root, Palette.corner );
	Self.root = Root;

	local Border = P.create( "Frame", {
		Size = UDim2.fromScale( 1, 1 );
		BackgroundTransparency = 1;
		Active = false;
		ZIndex = 40;
		Parent = Shell;
	} );
	P.corner( Border, Palette.corner );
	local BorderStroke = P.stroke( Border, Palette.outline or Palette.stroke, 1, 0 );

	-- Black outer line and a lighter line one pixel inside it.
	local InnerBorder = P.create( "Frame", {
		Position = UDim2.fromOffset( 1, 1 );
		Size = UDim2.new( 1, -2, 1, -2 );
		BackgroundTransparency = 1;
		Active = false;
		ZIndex = 40;
		Parent = Shell;
	} );
	P.corner( InnerBorder, math.max( Palette.corner - 1, 0 ) );
	local InnerStroke = P.stroke( InnerBorder, Palette.stroke, 1, 0 );

	-- Keyboard and gamepad navigation draw Roblox's blue selection box outside the selected
	-- object. Every button and text box here uses this one instead: an accent line inset one
	-- pixel, so it stays on the control's own edge.
	local Selection = P.create( "Frame", {
		Name = "\0";
		Position = UDim2.fromOffset( 1, 1 );
		Size = UDim2.new( 1, -2, 1, -2 );
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
	} );
	P.corner( Selection, Palette.corner );
	local SelectionStroke = P.stroke( Selection, Palette.accent, 1, 0 );
	Self._selection = Selection;

	local function AdoptSelection( Object: Instance )
		if ( not ( Object : IsA( "GuiButton" ) or Object : IsA( "TextBox" ) ) ) then
			return;
		end

		( Object :: GuiObject ).SelectionImageObject = Selection;
	end

	Self : _give( Screen.DescendantAdded : Connect( AdoptSelection ) );

	Self : _paint( function( Colors )
		Root.BackgroundColor3 = Colors.panel or Colors.background;
		BorderStroke.Color = Colors.outline or Colors.stroke;
		InnerStroke.Color = Colors.stroke;
		SelectionStroke.Color = Colors.accent;
	end );

	Self : _buildSidebar( );
	Self : _buildHeader( );

	local Content = P.create( "Frame", {
		BackgroundTransparency = 1;
		ClipsDescendants = true;
		ZIndex = 2;
		Parent = Root;
	} );
	Self.content = Content;

	Self : _buildBottomBar( );
	Self : _buildMinimizedPill( );

	if ( Self._touch ) then
		Self : _buildFloatingButton( );
	end

	Self : _enableDrag( Self.header );
	Self : _enableDrag( Self.brand );
	Self : _enableResize( );
	Self : _watchViewport( );
	Self : _applyViewport( );
	return Self;
end

function Window : _give( Item: any ): any
	if ( self._maid ) then
		self._maid : give( Item );
		return Item;
	end

	table.insert( self._connections, Item );
	return Item;
end

-- Every themed property is set through a painter, so a theme refresh is one loop over them.
function Window : _paint( Painter: ( any ) -> ( ) )
	table.insert( self._painters, Painter );
	Painter( self.theme );
end

function Window : _hover( Button: GuiButton, OnChange: ( boolean ) -> ( ) )
	self : _give( Button.MouseEnter : Connect( function( ) OnChange( true ); end ) );
	self : _give( Button.MouseLeave : Connect( function( ) OnChange( false ); end ) );
end

function Window : _iconButton( Parent: Instance, IconName: string, Size: number ): ( TextButton, ImageLabel? )
	local Button = P.create( "TextButton", {
		Size = UDim2.fromOffset( Size, Size );
		BackgroundTransparency = 1;
		AutoButtonColor = false;
		Text = "";
		ZIndex = 6;
		Parent = Parent;
	} ) :: TextButton;
	P.corner( Button, self.theme.cornerSmall );

	local Icon = Icons.mount( Button, IconName, {
		size = math.floor( Size * 0.5 );
		anchorPoint = Vector2.new( 0.5, 0.5 );
		position = UDim2.fromScale( 0.5, 0.5 );
		zIndex = 7;
	} );
	local Hovered = false;

	self : _paint( function( Colors )
		Button.BackgroundColor3 = Colors.overlay;
		Button.BackgroundTransparency = Hovered and 0.2 or 1;
		Icons.setColor( Icon, Hovered and Colors.text or Colors.textDim );
	end );
	self : _hover( Button, function( State: boolean )
		Hovered = State;
		Button.BackgroundTransparency = State and 0.2 or 1;
		Icons.setColor( Icon, State and self.theme.text or self.theme.textDim );
	end );

	return Button, Icon;
end

function Window : _buildSidebar( )
	local Colors = self.theme;
	local Sidebar = P.create( "Frame", {
		BorderSizePixel = 0;
		ZIndex = 2;
		Parent = self.root;
	} );
	self.rail = Sidebar;

	-- ClipsDescendants clips to the rectangle, not the window's rounded corners, so the sidebar
	-- rounds its own outer corners and a patch squares off the edge it shares with the content.
	P.corner( Sidebar, Colors.corner );
	local Patch = P.create( "Frame", {
		AnchorPoint = Vector2.new( 1, 0 );
		Position = UDim2.fromScale( 1, 0 );
		Size = UDim2.new( 0, Colors.corner, 1, 0 );
		BorderSizePixel = 0;
		ZIndex = 2;
		Parent = Sidebar;
	} );

	local Divider = P.create( "Frame", {
		AnchorPoint = Vector2.new( 1, 0 );
		Position = UDim2.fromScale( 1, 0 );
		Size = UDim2.new( 0, 1, 1, 0 );
		BorderSizePixel = 0;
		ZIndex = 3;
		Parent = Sidebar;
	} );

	local Brand = P.create( "Frame", {
		Size = UDim2.new( 1, 0, 0, BRAND_HEIGHT );
		BackgroundTransparency = 1;
		ZIndex = 3;
		Parent = Sidebar;
	} );
	self.brand = Brand;

	local Logo = P.create( "Frame", {
		Position = UDim2.fromOffset( 12, 12 );
		Size = UDim2.fromOffset( 24, 24 );
		BorderSizePixel = 0;
		ZIndex = 4;
		Parent = Brand;
	} );
	P.corner( Logo, Colors.corner );
	self.logo = Logo;

	local LogoImage = ResolveImage( { Colors.logoImage, Colors.logoImageAlt } );
	local LogoGradient = nil;
	local LogoLetter = nil;

	if ( LogoImage ) then
		Logo.BackgroundTransparency = 1;
		local Bitmap = P.create( "ImageLabel", {
			Size = UDim2.fromScale( 1, 1 );
			BackgroundTransparency = 1;
			Image = LogoImage;
			ScaleType = Enum.ScaleType.Crop;
			ZIndex = 5;
			Parent = Logo;
		} );
		P.corner( Bitmap, Colors.corner );
	end

	if ( not LogoImage ) then
		LogoGradient = P.gradient( Logo, Colors.accent, Colors.accentDim, 45 );
		LogoLetter = P.label( Logo, string.upper( string.sub( Theme.brandName, 1, 1 ) ), {
			Theme = Colors;
			TextXAlignment = Enum.TextXAlignment.Center;
			Font = Colors.fontBold;
			TextSize = 14;
			ZIndex = 5;
		} );
	end

	local BrandName = P.label( Brand, Theme.brandName, {
		Theme = Colors;
		Position = UDim2.fromOffset( 44, 10 );
		Size = UDim2.new( 1, -52, 0, 15 );
		Font = Colors.fontBold;
		TextSize = 14;
		TextTruncate = Enum.TextTruncate.AtEnd;
		ZIndex = 4;
	} );
	local GameName = P.label( Brand, PrettyTitle( self.title ), {
		Theme = Colors;
		Position = UDim2.fromOffset( 44, 25 );
		Size = UDim2.new( 1, -52, 0, 13 );
		Font = Colors.font;
		TextSize = Colors.textSizeSmall - 1;
		TextTruncate = Enum.TextTruncate.AtEnd;
		ZIndex = 4;
	} );
	self.brandLabel = BrandName;
	self.gameLabel = GameName;

	local TabList = P.create( "ScrollingFrame", {
		Position = UDim2.fromOffset( 0, BRAND_HEIGHT );
		Size = UDim2.new( 1, 0, 1, -( BRAND_HEIGHT + FOOTER_HEIGHT ) );
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		ScrollBarThickness = 0;
		ScrollingDirection = Enum.ScrollingDirection.Y;
		CanvasSize = UDim2.new( );
		AutomaticCanvasSize = Enum.AutomaticSize.Y;
		ZIndex = 3;
		Parent = Sidebar;
	} );
	P.paddingXY( TabList, TAB_INSET, 2 );
	P.listLayout( TabList, 2 );
	self.tabScroll = TabList;

	-- The active page's section tabs, slotted under its page tab by LayoutOrder.
	local SectionList = P.create( "Frame", {
		Size = UDim2.new( 1, 0, 0, 0 );
		AutomaticSize = Enum.AutomaticSize.Y;
		BackgroundTransparency = 1;
		Visible = false;
		ZIndex = 4;
		Parent = TabList;
	} );
	P.listLayout( SectionList, 1 );
	self.sectionList = SectionList;

	local Footer = P.create( "Frame", {
		AnchorPoint = Vector2.new( 0, 1 );
		Position = UDim2.fromScale( 0, 1 );
		Size = UDim2.new( 1, 0, 0, FOOTER_HEIGHT );
		BackgroundTransparency = 1;
		ZIndex = 3;
		Parent = Sidebar;
	} );
	local FooterLine = P.create( "Frame", {
		Size = UDim2.new( 1, 0, 0, 1 );
		BorderSizePixel = 0;
		ZIndex = 4;
		Parent = Footer;
	} );
	local FooterRow = P.create( "Frame", {
		Position = UDim2.fromOffset( 0, 1 );
		Size = UDim2.new( 1, 0, 1, -1 );
		BackgroundTransparency = 1;
		ZIndex = 4;
		Parent = Footer;
	} );
	local FooterLayout = P.listLayout( FooterRow, 6, Enum.FillDirection.Horizontal );
	FooterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center;
	FooterLayout.VerticalAlignment = Enum.VerticalAlignment.Center;
	self.footer = Footer;
	self.footerRow = FooterRow;
	self.footerLayout = FooterLayout;

	self : _paint( function( Palette )
		Sidebar.BackgroundColor3 = Palette.rail or Palette.background;
		Patch.BackgroundColor3 = Palette.rail or Palette.background;
		Divider.BackgroundColor3 = Palette.stroke;
		FooterLine.BackgroundColor3 = Palette.stroke;
		BrandName.TextColor3 = Palette.text;
		GameName.TextColor3 = Palette.textFaint;

		if ( LogoGradient ) then
			LogoGradient.Color = ColorSequence.new( Palette.accent, Palette.accentDim );
			LogoLetter.TextColor3 = Palette.text;
		end
	end );
end

function Window : _buildHeader( )
	local Colors = self.theme;
	local Header = P.create( "Frame", {
		BackgroundTransparency = 1;
		ZIndex = 4;
		Parent = self.root;
	} );
	self.header = Header;

	local PageTitle = P.label( Header, self.title, {
		Theme = Colors;
		Position = UDim2.fromOffset( 14, 0 );
		Size = UDim2.new( 1, -380, 1, 0 );
		Font = Colors.fontBold;
		TextSize = Colors.textSizeTitle;
		TextTruncate = Enum.TextTruncate.AtEnd;
		ZIndex = 5;
	} );
	self.pageTitleLabel = PageTitle;

	local Cluster = P.create( "Frame", {
		AnchorPoint = Vector2.new( 1, 0.5 );
		Position = UDim2.new( 1, -8, 0.5, 0 );
		Size = UDim2.new( 0, 240, 0, 26 );
		BackgroundTransparency = 1;
		ZIndex = 5;
		Parent = Header;
	} );
	local ClusterLayout = P.listLayout( Cluster, 4, Enum.FillDirection.Horizontal );
	ClusterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right;
	ClusterLayout.VerticalAlignment = Enum.VerticalAlignment.Center;
	self.headerCluster = Cluster;

	-- Search field. ui/workspace.lua owns what happens when it changes.
	local SearchFrame = P.create( "Frame", {
		Size = UDim2.fromOffset( 180, 22 );
		BorderSizePixel = 0;
		LayoutOrder = 1;
		ZIndex = 5;
		Parent = Cluster;
	} );
	P.corner( SearchFrame, Colors.cornerSmall );
	local SearchStroke = P.stroke( SearchFrame, Colors.stroke, 1, 0 );
	local SearchIcon = Icons.mount( SearchFrame, "tabler:search", {
		size = 12;
		anchorPoint = Vector2.new( 0, 0.5 );
		position = UDim2.new( 0, 7, 0.5, 0 );
		zIndex = 6;
	} );
	local SearchBox = P.create( "TextBox", {
		Position = UDim2.fromOffset( 24, 0 );
		Size = UDim2.new( 1, -30, 1, 0 );
		BackgroundTransparency = 1;
		Text = "";
		PlaceholderText = "search...";
		ClearTextOnFocus = false;
		FontFace = Colors.fontFace;
		TextSize = Colors.textSizeSmall;
		TextXAlignment = Enum.TextXAlignment.Left;
		TextTruncate = Enum.TextTruncate.AtEnd;
		ZIndex = 6;
		Parent = SearchFrame;
	} ) :: TextBox;
	self.NavSearch = SearchBox;
	self.searchFrame = SearchFrame;
	self : _give( SearchBox.Focused : Connect( function( ) SearchStroke.Color = self.theme.accent; end ) );
	self : _give( SearchBox.FocusLost : Connect( function( ) SearchStroke.Color = self.theme.stroke; end ) );
	self : _give( SearchBox : GetPropertyChangedSignal( "Text" ) : Connect( function( )
		if ( self.onFeatureSearch ) then
			self.onFeatureSearch( ( string.gsub( string.gsub( string.lower( SearchBox.Text ), "^%s+", "" ), "%s+$", "" ) ) );
		end
	end ) );

	local Minimize = self : _iconButton( Cluster, "tabler:chevron-down", 24 );
	Minimize.LayoutOrder = 3;
	self : _give( Minimize.Activated : Connect( function( )
		self : setVisible( false );

		if ( not self._touch ) then
			self.pill.Visible = true;
		end
	end ) );

	local Close, CloseIcon = self : _iconButton( Cluster, "tabler:x", 24 );
	Close.LayoutOrder = 4;
	self : _hover( Close, function( State: boolean )
		Close.BackgroundColor3 = State and self.theme.negative or self.theme.overlay;
		Close.BackgroundTransparency = State and 0.1 or 1;
		Icons.setColor( CloseIcon, State and self.theme.text or self.theme.textDim );
	end );
	self : _give( Close.Activated : Connect( function( ) self : setVisible( false ); end ) );
	self.closeButton = Close;
	self.minimizeButton = Minimize;

	local HeaderLine = P.create( "Frame", {
		AnchorPoint = Vector2.new( 0, 1 );
		Position = UDim2.fromScale( 0, 1 );
		Size = UDim2.new( 1, 0, 0, 1 );
		BorderSizePixel = 0;
		ZIndex = 5;
		Parent = Header;
	} );

	self : _paint( function( Palette )
		PageTitle.TextColor3 = Palette.text;
		SearchFrame.BackgroundColor3 = Palette.control;
		SearchStroke.Color = SearchBox : IsFocused( ) and Palette.accent or Palette.stroke;
		Icons.setColor( SearchIcon, Palette.textFaint );
		SearchBox.TextColor3 = Palette.text;
		SearchBox.PlaceholderColor3 = Palette.textFaint;
		HeaderLine.BackgroundColor3 = Palette.stroke;
	end );
end

function Window : _buildBottomBar( )
	-- The bar's background is a separate rounded frame (top corners patched square) so its bottom
	-- corners follow the window's; the scrolling strip on top of it stays transparent.
	local Back = P.create( "Frame", {
		AnchorPoint = Vector2.new( 0, 1 );
		Position = UDim2.fromScale( 0, 1 );
		Size = UDim2.new( 1, 0, 0, BAR_HEIGHT );
		BorderSizePixel = 0;
		Visible = false;
		ZIndex = 5;
		Parent = self.root;
	} );
	P.corner( Back, self.theme.corner );
	local TopPatch = P.create( "Frame", {
		Size = UDim2.new( 1, 0, 0, self.theme.corner );
		BorderSizePixel = 0;
		ZIndex = 5;
		Parent = Back;
	} );

	local Bar = P.create( "ScrollingFrame", {
		AnchorPoint = Vector2.new( 0, 1 );
		Position = UDim2.fromScale( 0, 1 );
		Size = UDim2.new( 1, 0, 0, BAR_HEIGHT );
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		ScrollBarThickness = 0;
		ScrollingDirection = Enum.ScrollingDirection.X;
		CanvasSize = UDim2.new( );
		AutomaticCanvasSize = Enum.AutomaticSize.X;
		Visible = false;
		ZIndex = 6;
		Parent = self.root;
	} );
	P.paddingXY( Bar, 6, 0 );
	local Layout = P.listLayout( Bar, 2, Enum.FillDirection.Horizontal );
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center;

	local Line = P.create( "Frame", {
		Size = UDim2.new( 1, 0, 0, 1 );
		BorderSizePixel = 0;
		Visible = false;
		ZIndex = 7;
		Parent = self.root;
	} );
	self.bottomBar = Bar;
	self.bottomBack = Back;
	self.bottomLine = Line;

	self : _paint( function( Colors )
		Back.BackgroundColor3 = Colors.rail or Colors.background;
		TopPatch.BackgroundColor3 = Colors.rail or Colors.background;
		Line.BackgroundColor3 = Colors.strokeFaint;
	end );
end

function Window : _buildMinimizedPill( )
	local Colors = self.theme;
	local Pill = P.create( "TextButton", {
		AnchorPoint = Vector2.new( 0.5, 0 );
		Position = UDim2.new( 0.5, 0, 0, 14 );
		Size = UDim2.fromOffset( 0, 32 );
		AutomaticSize = Enum.AutomaticSize.X;
		BorderSizePixel = 0;
		AutoButtonColor = false;
		Text = "";
		Visible = false;
		ZIndex = 90;
		Parent = self.screen;
	} ) :: TextButton;
	P.corner( Pill, Colors.cornerSmall );
	P.paddingXY( Pill, 12, 0 );
	local Stroke = P.stroke( Pill, Colors.strokeBright, 1, 0 );
	local Layout = P.listLayout( Pill, 8, Enum.FillDirection.Horizontal );
	Layout.VerticalAlignment = Enum.VerticalAlignment.Center;
	local Dot = P.create( "Frame", { Size = UDim2.fromOffset( 6, 6 ), BorderSizePixel = 0, ZIndex = 91, Parent = Pill } );
	local Name = P.label( Pill, Theme.brandName, {
		Theme = Colors;
		AutomaticSize = Enum.AutomaticSize.X;
		Size = UDim2.fromOffset( 0, 32 );
		Font = Colors.fontBold;
		TextSize = 14;
		ZIndex = 91;
		LayoutOrder = 2;
	} );
	self.pill = Pill;
	self : _give( Pill.Activated : Connect( function( ) self : setVisible( true ); end ) );

	self : _paint( function( Palette )
		Pill.BackgroundColor3 = Palette.panel or Palette.background;
		Stroke.Color = Palette.strokeBright;
		Dot.BackgroundColor3 = Palette.accent;
		Name.TextColor3 = Palette.text;
	end );
end

-- Touch devices have no menu key, so a draggable button reopens the menu. It only shows while the
-- menu is closed, so it can never cover a control.
function Window : _buildFloatingButton( )
	local Colors = self.theme;
	local Button = P.create( "TextButton", {
		AnchorPoint = Vector2.new( 1, 0.5 );
		Position = UDim2.new( 1, -16, 0.42, 0 );
		Size = UDim2.fromOffset( 48, 48 );
		BorderSizePixel = 0;
		AutoButtonColor = false;
		Text = "";
		Visible = false;
		ZIndex = 95;
		Parent = self.screen;
	} ) :: TextButton;
	P.corner( Button, 24 );
	local Stroke = P.stroke( Button, Colors.accent, 2, 0.1 );
	local Letter = P.label( Button, string.upper( string.sub( Theme.brandName, 1, 1 ) ), {
		Theme = Colors;
		TextXAlignment = Enum.TextXAlignment.Center;
		Font = Colors.fontBold;
		TextSize = 20;
		ZIndex = 96;
	} );
	self.floatingButton = Button;

	local Moved = false;
	local Start, Origin, Active = nil, nil, nil;
	self : _give( Button.InputBegan : Connect( function( Input )
		if ( Input.UserInputType ~= Enum.UserInputType.Touch and Input.UserInputType ~= Enum.UserInputType.MouseButton1 ) then
			return;
		end

		Active, Start, Origin, Moved = Input, Input.Position, Button.Position, false;
	end ) );
	self : _give( UserInputService.InputChanged : Connect( function( Input )
		if ( not Active ) then
			return;
		end

		if ( Active.UserInputType == Enum.UserInputType.Touch and Input ~= Active ) then
			return;
		end

		if ( Active.UserInputType ~= Enum.UserInputType.Touch and Input.UserInputType ~= Enum.UserInputType.MouseMovement ) then
			return;
		end

		local Delta = Input.Position - Start;

		if ( Delta.Magnitude > 6 ) then
			Moved = true;
		end

		Button.Position = UDim2.new( Origin.X.Scale, Origin.X.Offset + Delta.X, Origin.Y.Scale, Origin.Y.Offset + Delta.Y );
	end ) );
	self : _give( UserInputService.InputEnded : Connect( function( Input )
		if ( Input ~= Active ) then
			return;
		end

		Active = nil;

		if ( not Moved ) then
			self : setVisible( true );
		end
	end ) );

	self : _paint( function( Palette )
		Button.BackgroundColor3 = Palette.panel or Palette.background;
		Stroke.Color = Palette.accent;
		Letter.TextColor3 = Palette.accentBright;
	end );
end

-- Screen pixels per window unit: the menu scale times any UIScale above the window.
function Window : pixelScale( ): number
	local Width = self.shell.Size.X.Offset;

	if ( Width <= 0 or self.root.AbsoluteSize.X <= 0 ) then
		return self.shellScale.Scale;
	end

	return self.root.AbsoluteSize.X / Width;
end

function Window : _viewportSize( ): Vector2
	local Camera = Services.Workspace.CurrentCamera;
	return Camera and Camera.ViewportSize or Vector2.new( 800, 600 );
end

function Window : _clampPosition( Position: UDim2 ): UDim2
	local Viewport = self : _viewportSize( );
	local Size = self.shell.AbsoluteSize;

	if ( Size.X <= 0 or Size.Y <= 0 ) then
		Size = Vector2.new( self.shell.Size.X.Offset, self.shell.Size.Y.Offset );
	end

	local MaxX = math.max( 0, ( Viewport.X - Size.X ) / 2 - DRAG_MARGIN );
	local MaxY = math.max( 0, ( Viewport.Y - Size.Y ) / 2 - DRAG_MARGIN );
	return UDim2.new( 0.5, math.clamp( Position.X.Offset, -MaxX, MaxX ), 0.5, math.clamp( Position.Y.Offset, -MaxY, MaxY ) );
end

function Window : _sidebarWidth( ): number
	if ( self._mode == "rail" ) then
		return RAIL_WIDTH;
	end

	if ( self._mode == "bar" ) then
		return 0;
	end

	return self._fitWidth or self.theme.tabWidth or 144;
end

-- Width of a label in a medium-weight Gotham, which runs wider than the menu font, so a width
-- sized from it always fits.
function Window : _measure( Text: string, Size: number ): number
	local Ok, Bounds = pcall( TextService.GetTextSize, TextService, Text, Size, self.theme.fontMedium or Enum.Font.GothamMedium, Vector2.new( 2000, 200 ) );

	if ( not Ok or typeof( Bounds ) ~= "Vector2" ) then
		return #Text * Size * 0.62;
	end

	return Bounds.X;
end

function Window : _showsSectionTabs( Page: any ): boolean
	return #Page.sections >= CHIP_THRESHOLD and not Page.utility;
end

-- The full sidebar is as wide as its longest page or section label needs; theme.tabWidth caps it,
-- and a label past the cap wraps onto a second line.
function Window : _fitSidebar( )
	local Widest = 0;

	for _, Entry in self.tabButtons do
		local Page = Entry.page;

		if ( not Page.utility ) then
			Widest = math.max( Widest, self : _measure( Page.label, self.theme.textSize - 1 ) );
		end

		if ( self : _showsSectionTabs( Page ) ) then
			for _, Section in Page.sections do
				Widest = math.max( Widest, self : _measure( SectionCaption( Section.caption or "Section" ), self.theme.textSizeSmall ) );
			end
		end
	end

	local Needed = math.ceil( Widest + TAB_INSET * 2 + TAB_TEXT_LEFT + TAB_TEXT_RIGHT );
	local Width = math.min( math.max( Needed, TAB_MIN_WIDTH ), self.theme.tabWidth or 144 );

	if ( Width == self._fitWidth ) then
		return;
	end

	self._fitWidth = Width;

	if ( self._mode == "full" ) then
		self : _setMode( "full" );
	end
end

function Window : _layoutTab( Entry: any )
	local Mode = self._mode;
	local Button = Entry.button;
	local Utility = Entry.page.utility;

	Button.AutomaticSize = Enum.AutomaticSize.None;
	Entry.label.AutomaticSize = Enum.AutomaticSize.None;
	Entry.label.TextWrapped = false;
	Entry.label.TextTruncate = Enum.TextTruncate.None;
	Entry.label.TextYAlignment = Enum.TextYAlignment.Center;

	if ( Mode == "bar" ) then
		-- Each tab is as wide as its label needs, never narrower than a thumb.
		Button.Parent = self.bottomBar;
		Button.Size = UDim2.fromOffset( math.max( 74, math.ceil( self : _measure( Entry.page.label, 11 ) ) + 12 ), BAR_HEIGHT - 8 );
		Button.LayoutOrder = Entry.order + ( Utility and 1000 or 0 );
		Entry.icon.AnchorPoint = Vector2.new( 0.5, 0 );
		Entry.icon.Position = UDim2.new( 0.5, 0, 0, 6 );
		Entry.label.Visible = true;
		Entry.label.TextXAlignment = Enum.TextXAlignment.Center;
		Entry.label.TextSize = 11;
		Entry.label.Position = UDim2.new( 0, 2, 0, 26 );
		Entry.label.Size = UDim2.new( 1, -4, 0, 14 );
		Entry.bar.Visible = false;
		return;
	end

	if ( Utility ) then
		Button.Parent = self.footerRow;
		Button.Size = UDim2.fromOffset( Mode == "rail" and 40 or 52, 34 );
		Button.LayoutOrder = Entry.order;
		Entry.icon.AnchorPoint = Vector2.new( 0.5, 0.5 );
		Entry.icon.Position = UDim2.fromScale( 0.5, 0.5 );
		Entry.label.Visible = false;
		Entry.bar.Visible = false;
		return;
	end

	-- Page tabs take even LayoutOrders so the section list can sit right under the active one.
	Button.Parent = self.tabScroll;
	Button.LayoutOrder = Entry.order * 2;

	if ( Mode == "rail" ) then
		-- Two lines under the icon, so a two-word label wraps instead of being cut.
		Button.Size = UDim2.new( 1, 0, 0, 52 );
		Entry.icon.AnchorPoint = Vector2.new( 0.5, 0 );
		Entry.icon.Position = UDim2.new( 0.5, 0, 0, 7 );
		Entry.label.Visible = true;
		Entry.label.TextXAlignment = Enum.TextXAlignment.Center;
		Entry.label.TextYAlignment = Enum.TextYAlignment.Top;
		Entry.label.TextWrapped = true;
		Entry.label.TextSize = 10;
		Entry.label.Position = UDim2.new( 0, 1, 0, 25 );
		Entry.label.Size = UDim2.new( 1, -2, 0, 25 );
		Entry.bar.Visible = false;
		return;
	end

	-- A label wider than the capped sidebar wraps and the tab grows to fit it.
	local Height = self.theme.tabHeight or 34;
	Button.Size = UDim2.new( 1, 0, 0, Height );
	Button.AutomaticSize = Enum.AutomaticSize.Y;
	Entry.icon.AnchorPoint = Vector2.new( 0, 0.5 );
	Entry.icon.Position = UDim2.new( 0, 10, 0.5, 0 );
	Entry.label.Visible = true;
	Entry.label.TextXAlignment = Enum.TextXAlignment.Left;
	Entry.label.TextWrapped = true;
	Entry.label.TextSize = self.theme.textSize - 1;
	Entry.label.Position = UDim2.fromOffset( TAB_TEXT_LEFT, 0 );
	Entry.label.Size = UDim2.new( 1, -( TAB_TEXT_LEFT + TAB_TEXT_RIGHT ), 0, Height );
	Entry.label.AutomaticSize = Enum.AutomaticSize.Y;
	Entry.bar.Visible = true;
end

function Window : _setMode( Mode: string )
	self._mode = Mode;
	local Header = self.theme.headerHeight or 52;
	local Sidebar = self : _sidebarWidth( );
	local Bar = Mode == "bar";

	self.rail.Visible = not Bar;
	self.rail.Size = UDim2.new( 0, Sidebar, 1, 0 );
	self.brandLabel.Visible = Mode == "full";
	self.gameLabel.Visible = Mode == "full";
	self.logo.Position = Mode == "full" and UDim2.fromOffset( 12, 12 ) or UDim2.fromOffset( ( RAIL_WIDTH - 24 ) / 2, 12 );
	self.footerLayout.FillDirection = Mode == "rail" and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal;
	self.footer.Size = UDim2.new( 1, 0, 0, Mode == "rail" and 132 or FOOTER_HEIGHT );
	self.tabScroll.Size = UDim2.new( 1, 0, 1, -( BRAND_HEIGHT + self.footer.Size.Y.Offset ) );
	self.tabScroll.Position = UDim2.fromOffset( 0, BRAND_HEIGHT );
	local TabPadding = self.tabScroll : FindFirstChildOfClass( "UIPadding" );
	TabPadding.PaddingLeft = UDim.new( 0, TAB_INSET );
	TabPadding.PaddingRight = UDim.new( 0, TAB_INSET );

	self.header.Position = UDim2.fromOffset( Sidebar, 0 );
	self.header.Size = UDim2.new( 1, -Sidebar, 0, Header );
	self.content.Position = UDim2.fromOffset( Sidebar, Header );
	self.content.Size = UDim2.new( 1, -Sidebar, 1, -Header - ( Bar and BAR_HEIGHT or 0 ) );
	self.bottomBar.Visible = Bar;
	self.bottomBack.Visible = Bar;
	self.bottomLine.Visible = Bar;
	self.bottomLine.Position = UDim2.new( 0, 0, 1, -BAR_HEIGHT );
	self.searchFrame.Size = UDim2.fromOffset( Bar and 140 or 180, 22 );
	self.minimizeButton.Visible = not self._touch;
	self.pageTitleLabel.Size = UDim2.new( 1, -( self.headerCluster.Size.X.Offset + 24 ), 1, 0 );

	for _, Entry in self.tabButtons do
		self : _layoutTab( Entry );
	end

	self : _refreshColumns( );

	-- Section tabs move between the sidebar and the page strip with the mode.
	if ( self.activePage ) then
		self : _buildChips( self.pages[ self.activePage ] );
	end
end

function Window : _refreshColumns( )
	local Width = self.shell.Size.X.Offset - self : _sidebarWidth( ) - ( self.theme.padding or 14 ) * 2;
	local Count = 1;

	if ( Width >= TWO_COLUMN_WIDTH ) then
		Count = 2;
	end

	if ( Width >= THREE_COLUMN_WIDTH ) then
		Count = 3;
	end

	local Changed = Count ~= self._columns;
	self._columns = Count;

	for _, Page in self.pages do
		if ( Changed or not Page._laidOut ) then
			self : _reflow( Page );
		end
	end
end

-- Masonry: each section goes into whichever column is currently shortest, in declaration order.
function Window : _reflow( Page: any )
	local Count = Page.singleColumn and 1 or self._columns;
	local Gap = self.theme.columnGap or 12;
	local Heights = { };

	for Index, Column in Page.columns do
		Column.Visible = Index <= Count;
		Column.Size = UDim2.new( 1 / Count, -Gap * ( Count - 1 ) / Count, 0, 0 );
		Heights[ Index ] = 0;
	end

	for Order, Section in Page.sections do
		local Target = 1;

		for Index = 2, Count do
			if ( Heights[ Index ] < Heights[ Target ] - 1 ) then
				Target = Index;
			end
		end

		Section.card.Parent = Page.columns[ Target ];
		Section.card.LayoutOrder = Order;
		Heights[ Target ] += Section.card.AbsoluteSize.Y + Gap;
	end

	Page._laidOut = true;
end

function Window : _queueReflow( Page: any )
	if ( Page._reflowQueued ) then
		return;
	end

	Page._reflowQueued = true;
	task.defer( function( )
		Page._reflowQueued = false;

		if ( self._destroyed ) then
			return;
		end

		self : _reflow( Page );
		self : _buildChips( Page );
	end );
end

-- Section tabs: stacked under the active page tab in the full sidebar, or a strip above the page
-- in the rail and tab-bar modes, which have no room for them in the sidebar.
function Window : _buildChips( Page: any )
	local Bar = Page.chipBar;
	local Active = self.activePage ~= nil and self.pages[ self.activePage ] == Page;

	for _, Child in Bar : GetChildren( ) do
		if ( Child : IsA( "GuiButton" ) ) then
			Child : Destroy( );
		end
	end

	local Show = self : _showsSectionTabs( Page );
	local InSidebar = Show and self._mode == "full";
	local InStrip = Show and not InSidebar;
	Bar.Visible = InStrip;
	Page.scroll.Position = UDim2.fromOffset( 0, InStrip and CHIP_BAR_HEIGHT + 4 or 0 );
	Page.scroll.Size = UDim2.new( 1, 0, 1, InStrip and -( CHIP_BAR_HEIGHT + 4 ) or 0 );

	if ( Active ) then
		self : _buildSectionTabs( Page, InSidebar );
	end

	if ( Show ) then
		self : _fitSidebar( );
	end

	if ( not InStrip ) then
		return;
	end

	local Colors = self.theme;

	for Order, Section in Page.sections do
		local Chip = P.create( "TextButton", {
			Size = UDim2.fromOffset( 0, 22 );
			AutomaticSize = Enum.AutomaticSize.X;
			BackgroundColor3 = Colors.surface;
			BorderSizePixel = 0;
			AutoButtonColor = false;
			Text = SectionCaption( Section.caption or "Section" );
			FontFace = Colors.fontFace;
			TextSize = Colors.textSizeSmall;
			TextColor3 = Colors.textDim;
			LayoutOrder = Order;
			ZIndex = 4;
			Parent = Bar;
		} ) :: TextButton;
		P.corner( Chip, Colors.cornerSmall );
		P.paddingXY( Chip, 9, 0 );
		local Stroke = P.stroke( Chip, Colors.stroke, 1, 0 );
		self : _hover( Chip, function( State: boolean )
			Chip.TextColor3 = State and self.theme.text or self.theme.textDim;
			Stroke.Color = State and self.theme.strokeBright or self.theme.stroke;
		end );
		self : _give( Chip.Activated : Connect( function( )
			self : revealSection( Page, Section );
		end ) );
	end
end

function Window : _buildSectionTabs( Page: any, Show: boolean )
	local List = self.sectionList;

	for _, Child in List : GetChildren( ) do
		if ( Child : IsA( "GuiButton" ) ) then
			Child : Destroy( );
		end
	end

	List.Visible = Show;

	if ( not Show ) then
		return;
	end

	local Colors = self.theme;
	List.LayoutOrder = self.activePage * 2 + 1;

	for Order, Section in Page.sections do
		local Tab = P.create( "TextButton", {
			Size = UDim2.new( 1, 0, 0, SECTION_TAB_HEIGHT );
			AutomaticSize = Enum.AutomaticSize.Y;
			BackgroundColor3 = Colors.overlay;
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			AutoButtonColor = false;
			Text = SectionCaption( Section.caption or "Section" );
			FontFace = Colors.fontFace;
			TextSize = Colors.textSizeSmall;
			TextColor3 = Colors.textDim;
			TextXAlignment = Enum.TextXAlignment.Left;
			TextWrapped = true;
			LayoutOrder = Order;
			ZIndex = 5;
			Parent = List;
		} ) :: TextButton;
		P.corner( Tab, Colors.corner );
		local Padding = P.paddingXY( Tab, 0, 4 );
		Padding.PaddingLeft = UDim.new( 0, TAB_TEXT_LEFT );
		Padding.PaddingRight = UDim.new( 0, TAB_TEXT_RIGHT );
		self : _hover( Tab, function( State: boolean )
			Tab.TextColor3 = State and self.theme.text or self.theme.textDim;
			Tab.BackgroundTransparency = State and 0.6 or 1;
		end );
		self : _give( Tab.Activated : Connect( function( )
			self : revealSection( Page, Section );
		end ) );
	end
end

function Window : revealSection( Page: any, Section: any )
	if ( Section.setExpanded ) then
		Section.setExpanded( true );
	end

	task.defer( function( )
		local Scroll = Page.scroll;
		local Scale = self : pixelScale( );
		local Offset = ( Section.card.AbsolutePosition.Y - Scroll.AbsolutePosition.Y ) / Scale + Scroll.CanvasPosition.Y;
		Scroll.CanvasPosition = Vector2.new( 0, math.max( 0, Offset - 4 ) );
	end );
end

function Window : _applyViewport( )
	if ( self._destroyed or not self.shell ) then
		return;
	end

	self._resizeInput = nil;
	local Scale = self.theme.menuScale or 1;
	local Viewport = self : _viewportSize( );
	local Requested = self._requestedSize or self.theme.windowSize or Vector2.new( 900, 580 );
	local Margin = self._touch and TOUCH_MARGIN or VIEWPORT_MARGIN;
	local Size = Vector2.new(
		math.min( Requested.X, math.max( 1, ( Viewport.X - Margin.X ) / Scale ) ),
		math.min( Requested.Y, math.max( 1, ( Viewport.Y - Margin.Y ) / Scale ) )
	);

	-- Phones get the whole screen; there is nothing useful behind a half-size menu there.
	if ( self._touch ) then
		Size = Vector2.new( math.max( 1, ( Viewport.X - Margin.X ) / Scale ), math.max( 1, ( Viewport.Y - Margin.Y ) / Scale ) );
	end

	self.shellScale.Scale = Scale;
	self.shell.Size = UDim2.fromOffset( Size.X, Size.Y );
	self : _setMode( self : _modeFor( Size.X ) );
	self.shell.Position = self : _clampPosition( self.shell.Position );
end

function Window : _modeFor( Width: number ): string
	if ( self._touch or Width < BAR_BREAKPOINT ) then
		return "bar";
	end

	if ( Width < RAIL_BREAKPOINT ) then
		return "rail";
	end

	return "full";
end

function Window : _watchViewport( )
	local CameraConnection = nil;
	local function BindCamera( )
		if ( CameraConnection ) then
			CameraConnection : Disconnect( );
			CameraConnection = nil;
		end

		local Camera = Services.Workspace.CurrentCamera;

		if ( Camera ) then
			CameraConnection = Camera : GetPropertyChangedSignal( "ViewportSize" ) : Connect( function( ) self : _applyViewport( ); end );
		end

		self : _applyViewport( );
	end

	self : _give( Services.Workspace : GetPropertyChangedSignal( "CurrentCamera" ) : Connect( BindCamera ) );
	self : _give( function( )
		if ( CameraConnection ) then
			CameraConnection : Disconnect( );
		end
	end );
	BindCamera( );
end

function Window : _enableResize( )
	if ( self._touch ) then
		return;
	end

	local Grip = P.create( "TextButton", {
		AnchorPoint = Vector2.new( 1, 1 );
		Position = UDim2.fromScale( 1, 1 );
		Size = UDim2.fromOffset( 18, 18 );
		BackgroundTransparency = 1;
		Text = "";
		AutoButtonColor = false;
		ZIndex = 45;
		Parent = self.shell;
	} );
	local Mark = P.label( Grip, "\u{25E2}", { Theme = self.theme, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 46 } );
	self : _paint( function( Colors ) Mark.TextColor3 = Colors.textFaint; end );

	local StartPointer, StartSize, StartPosition = nil, nil, nil;
	self : _give( Grip.InputBegan : Connect( function( Input )
		if ( self._dragInput or self._resizeInput ) then
			return;
		end

		if ( Input.UserInputType ~= Enum.UserInputType.MouseButton1 ) then
			return;
		end

		self._resizeInput = Input;
		StartPointer = Input.Position;
		StartSize = Vector2.new( self.shell.Size.X.Offset, self.shell.Size.Y.Offset );
		StartPosition = self.shell.Position;
	end ) );
	self : _give( UserInputService.InputChanged : Connect( function( Input )
		if ( not self._resizeInput or Input.UserInputType ~= Enum.UserInputType.MouseMovement ) then
			return;
		end

		local Viewport = self : _viewportSize( );
		local Scale = self.theme.menuScale or 1;
		local Left = Viewport.X / 2 + StartPosition.X.Offset - StartSize.X * Scale / 2;
		local Top = Viewport.Y / 2 + StartPosition.Y.Offset - StartSize.Y * Scale / 2;
		local MaximumX = math.max( 1, ( Viewport.X - DRAG_MARGIN - Left ) / Scale );
		local MaximumY = math.max( 1, ( Viewport.Y - DRAG_MARGIN - Top ) / Scale );
		local Delta = Input.Position - StartPointer;
		local Width = math.clamp( StartSize.X + Delta.X / Scale, math.min( 460, MaximumX ), MaximumX );
		local Height = math.clamp( StartSize.Y + Delta.Y / Scale, math.min( 320, MaximumY ), MaximumY );
		self._requestedSize = Vector2.new( Width, Height );
		self.shell.Size = UDim2.fromOffset( Width, Height );
		self.shell.Position = UDim2.new( 0.5, StartPosition.X.Offset + ( Width - StartSize.X ) * Scale / 2, 0.5, StartPosition.Y.Offset + ( Height - StartSize.Y ) * Scale / 2 );
		local Mode = self : _modeFor( Width );

		if ( Mode ~= self._mode ) then
			self : _setMode( Mode );
			return;
		end

		self : _refreshColumns( );
	end ) );
	self : _give( UserInputService.InputEnded : Connect( function( Input )
		if ( Input == self._resizeInput ) then
			self._resizeInput = nil;
		end
	end ) );
end

function Window : _enableDrag( Handle: GuiObject )
	if ( self._touch ) then
		return;
	end

	local Active, StartPosition, StartOffset = nil, nil, nil;
	self : _give( Handle.InputBegan : Connect( function( Input )
		if ( Input.UserInputType ~= Enum.UserInputType.MouseButton1 ) then
			return;
		end

		if ( self._dragInput or self._resizeInput ) then
			return;
		end

		Active, StartPosition, StartOffset = Input, Input.Position, self.shell.Position;
		self._dragInput = Input;
	end ) );
	self : _give( UserInputService.InputChanged : Connect( function( Input )
		if ( not Active or self._dragInput ~= Active or Input.UserInputType ~= Enum.UserInputType.MouseMovement ) then
			return;
		end

		local Delta = Input.Position - StartPosition;
		self.shell.Position = self : _clampPosition( UDim2.new( StartOffset.X.Scale, StartOffset.X.Offset + Delta.X, StartOffset.Y.Scale, StartOffset.Y.Offset + Delta.Y ) );
	end ) );
	self : _give( UserInputService.InputEnded : Connect( function( Input )
		if ( Input ~= Active ) then
			return;
		end

		Active = nil;

		if ( self._dragInput == Input ) then
			self._dragInput = nil;
		end
	end ) );
end

function Window : addPage( Label: string, IconName: string?, PageOptions: any? ): any
	if ( self._destroyed ) then
		return nil;
	end

	Label = Trim( Label );
	local Colors = self.theme;
	local Utility = PageOptions ~= nil and PageOptions.utility == true;
	local Index = #self.pages + 1;
	local Owner = self;

	local Button = P.create( "TextButton", {
		Name = Label;
		BackgroundTransparency = 1;
		AutoButtonColor = false;
		Text = "";
		ZIndex = 4;
	} ) :: TextButton;
	P.corner( Button, Colors.corner );
	-- Inset top and bottom so the accent bar clears the tab's rounded corners.
	local Bar = P.create( "Frame", {
		AnchorPoint = Vector2.new( 0, 0.5 );
		Position = UDim2.fromScale( 0, 0.5 );
		Size = UDim2.new( 0, 2, 1, -12 );
		BorderSizePixel = 0;
		ZIndex = 5;
		Parent = Button;
	} );
	local Icon = Icons.mount( Button, Icons.resolvePageIcon( Label, IconName ) or "circle", { size = 15, zIndex = 6 } )
		or P.create( "Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset( 15, 15 ), Parent = Button } );
	local Text = P.label( Button, Label, {
		Theme = Colors;
		Font = Colors.font;
		TextTruncate = Enum.TextTruncate.AtEnd;
		ZIndex = 6;
	} );

	local Container = P.create( "Frame", {
		Size = UDim2.fromScale( 1, 1 );
		BackgroundTransparency = 1;
		Visible = false;
		Parent = self.content;
	} );
	P.padding( Container, Colors.padding or 14 );

	local ChipBar = P.create( "ScrollingFrame", {
		Size = UDim2.new( 1, 0, 0, CHIP_BAR_HEIGHT );
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		ScrollBarThickness = 0;
		ScrollingDirection = Enum.ScrollingDirection.X;
		CanvasSize = UDim2.new( );
		AutomaticCanvasSize = Enum.AutomaticSize.X;
		Visible = false;
		ZIndex = 3;
		Parent = Container;
	} );
	local ChipLayout = P.listLayout( ChipBar, 4, Enum.FillDirection.Horizontal );
	ChipLayout.VerticalAlignment = Enum.VerticalAlignment.Center;

	local Scroll = P.create( "ScrollingFrame", {
		Size = UDim2.fromScale( 1, 1 );
		BackgroundTransparency = 1;
		BorderSizePixel = 0;
		ScrollBarThickness = 3;
		ScrollBarImageTransparency = 0.4;
		ScrollingDirection = Enum.ScrollingDirection.Y;
		CanvasSize = UDim2.new( );
		AutomaticCanvasSize = Enum.AutomaticSize.Y;
		Parent = Container;
	} ) :: ScrollingFrame;
	local Columns = P.create( "Frame", {
		Size = UDim2.new( 1, -6, 0, 0 );
		AutomaticSize = Enum.AutomaticSize.Y;
		BackgroundTransparency = 1;
		Parent = Scroll;
	} );
	P.listLayout( Columns, Colors.columnGap or 12, Enum.FillDirection.Horizontal );

	local Page = {
		label = Label;
		icon = IconName;
		utility = Utility;
		container = Container;
		scroll = Scroll;
		chipBar = ChipBar;
		columns = { };
		sections = { };
		singleColumn = false;
		_sectionCount = 0;
	};

	for Column = 1, 3 do
		local Frame = P.create( "Frame", {
			Size = UDim2.new( 0.5, 0, 0, 0 );
			AutomaticSize = Enum.AutomaticSize.Y;
			BackgroundTransparency = 1;
			LayoutOrder = Column;
			Parent = Columns;
		} );
		P.listLayout( Frame, Colors.sectionGap or 12 );
		Page.columns[ Column ] = Frame;
	end

	function Page : addSection( Title: string?, SectionOptions: any? ): Frame
		self._sectionCount += 1;
		local Palette = Owner.theme;
		local Card = P.create( "Frame", {
			Size = UDim2.new( 1, 0, 0, 0 );
			AutomaticSize = Enum.AutomaticSize.Y;
			BorderSizePixel = 0;
			LayoutOrder = self._sectionCount;
			Parent = self.columns[ 1 ];
		} );
		P.corner( Card, Palette.corner );
		local CardStroke = P.stroke( Card, Palette.stroke, 1, 0 );
		P.listLayout( Card, 0 );

		local Entry = { caption = Title, card = Card };
		local HeaderRow = nil;
		local Caption = nil;
		local Chevron = nil;

		if ( Title and Title ~= "" ) then
			HeaderRow = P.create( "TextButton", {
				Size = UDim2.new( 1, 0, 0, 26 );
				BackgroundTransparency = 1;
				AutoButtonColor = false;
				Text = "";
				Parent = Card;
			} );
			Caption = P.label( HeaderRow, SectionCaption( Title ), {
				Theme = Palette;
				Position = UDim2.fromOffset( 10, 0 );
				Size = UDim2.new( 1, -36, 1, 0 );
				Font = Palette.fontMedium;
				TextSize = Palette.textSize - 1;
				TextTruncate = Enum.TextTruncate.AtEnd;
			} );
		end

		local Body = P.create( "Frame", {
			Size = UDim2.new( 1, 0, 0, 0 );
			AutomaticSize = Enum.AutomaticSize.Y;
			BackgroundTransparency = 1;
			Parent = Card;
		} );
		local Padding = P.padding( Body, Palette.sectionPadding or 12 );
		Padding.PaddingTop = UDim.new( 0, HeaderRow and 0 or 6 );
		Padding.PaddingBottom = UDim.new( 0, 6 );
		Padding.PaddingLeft = UDim.new( 0, 4 );
		Padding.PaddingRight = UDim.new( 0, 4 );
		P.listLayout( Body, Palette.controlGap or 4 );
		Entry.panel = Body;
		Entry.title = Caption;
		Entry.stroke = CardStroke;

		Owner : _paint( function( Colors )
			Card.BackgroundColor3 = Colors.surface;
			CardStroke.Color = Colors.stroke;

			if ( Caption ) then
				Caption.TextColor3 = Colors.text;
			end

			Icons.setColor( Chevron, Colors.textFaint );
		end );

		if ( HeaderRow and ( not SectionOptions or SectionOptions.collapsible ~= false ) ) then
			Chevron = Icons.mount( HeaderRow, "tabler:chevron-down", {
				size = 11;
				color = Palette.textFaint;
				anchorPoint = Vector2.new( 1, 0.5 );
				position = UDim2.new( 1, -10, 0.5, 0 );

			} );
			Entry.chevron = Chevron;
			local StateKey = tostring( Owner.sectionScope or "default" ) .. "/" .. self.label .. "/" .. tostring( self._sectionCount ) .. "/" .. Title;
			local function SetExpanded( Expanded: boolean )
				local Changed = Body.Visible ~= Expanded;
				Body.Visible = Expanded;

				if ( Chevron ) then
					Chevron.Rotation = Expanded and 0 or -90;
				end

				if ( Owner.sectionPreferences ) then
					local Collapsed = not Expanded or nil;
					local Dirty = Owner.sectionPreferences[ StateKey ] ~= Collapsed;
					Owner.sectionPreferences[ StateKey ] = Collapsed;

					if ( Dirty and Owner.onSectionCollapse ) then
						Owner.onSectionCollapse( );
					end
				end

				if ( Changed ) then
					Owner : _queueReflow( self );
				end
			end

			Entry.setExpanded = SetExpanded;
			SetExpanded( not ( Owner.sectionPreferences and Owner.sectionPreferences[ StateKey ] ) );
			Owner : _give( HeaderRow.Activated : Connect( function( ) SetExpanded( not Body.Visible ); end ) );
		end

		table.insert( self.sections, Entry );
		Owner : _queueReflow( self );
		return Body;
	end

	local Entry = {
		button = Button;
		icon = Icon;
		label = Text;
		bar = Bar;
		page = Page;
		order = Index;
		hovered = false;
	};
	self.pages[ Index ] = Page;
	self.tabButtons[ Index ] = Entry;
	self : _layoutTab( Entry );
	self : _fitSidebar( );

	self : _paint( function( Palette )
		local Active = self.activePage == Index;
		Button.BackgroundColor3 = Active and Palette.surfaceAlt or Palette.overlay;
		Button.BackgroundTransparency = ( Active and 0 ) or ( Entry.hovered and 0.6 ) or 1;
		Bar.BackgroundColor3 = Palette.accent;
		Bar.BackgroundTransparency = Active and 0 or 1;
		Text.TextColor3 = ( Active and Palette.text ) or ( Entry.hovered and Palette.text ) or Palette.textDim;

		if ( Icon : IsA( "ImageLabel" ) ) then
			Icons.setColor( Icon, ( Active and Palette.accent ) or ( Entry.hovered and Palette.text ) or Palette.textDim );
		end

		Scroll.ScrollBarImageColor3 = Palette.textFaint;
	end );
	Entry.repaint = self._painters[ #self._painters ];

	self : _hover( Button, function( State: boolean )
		Entry.hovered = State;
		Entry.repaint( self.theme );
	end );
	self : _give( Button.Activated : Connect( function( ) self : showPage( Index ); end ) );

	if ( not self.activePage and not Utility ) then
		self : showPage( Index );
	end

	return Page;
end

function Window : showPage( Index: number )
	if ( self._destroyed or not self.tabButtons[ Index ] ) then
		return;
	end

	local BeforeShow = self.beforeShowPage;

	if ( BeforeShow ) then
		BeforeShow( Index );
	end

	self.activePage = Index;

	for Other, Entry in self.tabButtons do
		Entry.page.container.Visible = Other == Index;
		Entry.repaint( self.theme );
	end

	local Page = self.pages[ Index ];
	self.pageTitleLabel.Text = Page.label;
	self : _reflow( Page );
	self : _buildChips( Page );
end

function Window : refreshTheme( )
	if ( self._destroyed ) then
		return;
	end

	self : _applyViewport( );

	for _, Painter in self._painters do
		Painter( self.theme );
	end
end

function Window : setVisible( Visible: boolean )
	if ( not self.shell ) then
		return;
	end

	self.shell.Visible = Visible == true;
	self.pill.Visible = false;

	if ( self.floatingButton ) then
		self.floatingButton.Visible = Visible ~= true;
	end

	if ( Visible == true ) then
		return;
	end

	self._dragInput = nil;
	self._resizeInput = nil;
end

function Window : isVisible( ): boolean
	return self.shell ~= nil and self.shell.Visible;
end

function Window : destroy( )
	if ( self._destroyed ) then
		return;
	end

	self._destroyed = true;

	if ( not self._maid ) then
		for Index = #self._connections, 1, -1 do
			local Item = self._connections[ Index ];
			pcall( function( )
				if ( typeof( Item ) == "RBXScriptConnection" ) then
					Item : Disconnect( );
				end

				if ( typeof( Item ) == "function" ) then
					Item( );
				end
			end );
		end
	end

	table.clear( self._connections );
	table.clear( self._painters );

	if ( self.screen ) then
		self.screen : Destroy( );
		self.screen = nil;
	end

	if ( self._selection ) then
		self._selection : Destroy( );
		self._selection = nil;
	end

	self.root = nil;
	self.shell = nil;
	table.clear( self.pages );
	table.clear( self.tabButtons );
end

return Window;
