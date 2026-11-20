-- Feature search and favorites. Search is an overlay under the header's search field rather than a
-- page; each hit carries a live mirror of its control, and clicking its path jumps to the feature.
-- Favorites is a hub page pinned in the sidebar footer.

-- Dependencies
local P = require( "ui/primitives.lua" );
local Common = require( "ui/components/common.lua" );
local Index = require( "ui/feature-index.lua" );

-- Constants
local PAGE_SIZE = 30;
local PANEL_WIDTH = 420;
local PANEL_HEIGHT = 400;
local EDITABLE = { toggle = true, slider = true, number = true, select = true, color = true, text = true };

-- Main
return function( Options: any ): any
	local Window, Context, Components = Options.window, Options.context, Options.components;
	local Theme = Context.theme;
	local Entries = Index.collect( Options.pages );
	local Preferences = Options.preferences;
	local Scope = tostring( Options.scope or "default" );

	if ( typeof( Preferences.Favorites[ Scope ] ) ~= "table" ) then
		Preferences.Favorites[ Scope ] = { };
	end

	local Saved = Preferences.Favorites[ Scope ];

	-- Favorites page.
	local FavoritesPage = Window : addPage( "Favorites", "sparkles", { utility = true } );
	FavoritesPage.singleColumn = true;
	local FavoritesIndex = #Window.pages;
	local FavoritesBody = FavoritesPage : addSection( "Favorites", { collapsible = false } );
	local FavoritesEmpty = P.label( FavoritesBody, "No favorites", { Theme = Theme, Size = UDim2.new( 1, 0, 0, 28 ), TextColor3 = Theme.textDim, TextSize = Theme.textSize - 1 } );

	-- Search overlay. The catcher behind it closes it on any outside click.
	local Catcher = P.create( "TextButton", {
		Size = UDim2.fromScale( 1, 1 );
		BackgroundTransparency = 1;
		Text = "";
		AutoButtonColor = false;
		Visible = false;
		ZIndex = 60;
		Parent = Window.root;
	} );
	local Panel = P.create( "ScrollingFrame", {
		AnchorPoint = Vector2.new( 1, 0 );
		Size = UDim2.fromOffset( PANEL_WIDTH, 0 );
		BorderSizePixel = 0;
		ScrollBarThickness = 3;
		CanvasSize = UDim2.new( );
		AutomaticCanvasSize = Enum.AutomaticSize.Y;
		Visible = false;
		ZIndex = 61;
		Parent = Window.root;
	} ) :: ScrollingFrame;
	P.corner( Panel, Theme.cornerSmall );
	local PanelStroke = P.stroke( Panel, Theme.strokeBright, 1, 0 );
	P.padding( Panel, 10 );
	local PanelLayout = P.listLayout( Panel, 6 );
	local Count = P.label( Panel, "", { Theme = Theme, Size = UDim2.new( 1, 0, 0, 16 ), LayoutOrder = -1, TextSize = Theme.textSizeSmall } );
	local SearchEmpty = P.label( Panel, "No matching features", { Theme = Theme, Size = UDim2.new( 1, 0, 0, 26 ), LayoutOrder = 0, TextSize = Theme.textSize - 1 } );
	local More = P.create( "TextButton", {
		Size = UDim2.new( 1, 0, 0, 28 );
		BorderSizePixel = 0;
		AutoButtonColor = false;
		Text = "Show More";
		FontFace = Theme.fontFaceMedium;
		TextSize = Theme.textSizeSmall;
		LayoutOrder = 100000;
		Visible = false;
		Parent = Panel;
	} );
	P.corner( More, Theme.cornerSmall );

	local Rows, FavoriteRows = { }, { };
	local Limit = PAGE_SIZE;
	local Refresh;

	local function HidePanel( )
		Panel.Visible = false;
		Catcher.Visible = false;
	end

	local function Open( Entry: any )
		HidePanel( );
		Options.buildAll( );
		Window : showPage( Entry.page.windowIndex );
		local Target = nil;

		for _, Section in Entry.page.object.sections do
			if ( Section.caption == ( Entry.section.title or "General" ) ) then
				Target = Section;
			end
		end

		for _, Ancestor in Entry.ancestors do
			local Control = Context.containers[ Ancestor.spec ];

			if ( Control and Control.setExpanded ) then
				Control.setExpanded( true );
			end

			if ( Control and Ancestor.profile and Control.selectProfile ) then
				Control.selectProfile( Ancestor.profile );
			end
		end

		if ( Target ) then
			Window : revealSection( Entry.page.object, Target );
		end
	end

	local function Row( Parent: Instance, Entry: any, Cache: any ): any
		if ( Cache[ Entry.id ] ) then
			return Cache[ Entry.id ];
		end

		local Root = P.create( "Frame", {
			Size = UDim2.new( 1, 0, 0, 0 );
			AutomaticSize = Enum.AutomaticSize.Y;
			BorderSizePixel = 0;
			LayoutOrder = table.find( Entries, Entry ) or 0;
			Parent = Parent;
		} );
		P.corner( Root, Theme.cornerSmall );
		local Padding = P.padding( Root, 8 );
		Padding.PaddingTop = UDim.new( 0, 6 );
		local Border = P.stroke( Root, Theme.strokeFaint, 1, 0 );
		P.listLayout( Root, 2 );

		local Header = P.create( "Frame", { BackgroundTransparency = 1, Size = UDim2.new( 1, 0, 0, 20 ), Parent = Root } );
		local Kind = Entry.spec.type;
		local Editable = Entry.key ~= nil and EDITABLE[ Kind ] == true;
		local PathText = Entry.path;

		if ( Editable ) then
			PathText = string.sub( Entry.path, 1, #Entry.path - #Entry.label - 3 );
		end

		local Link = P.create( "TextButton", {
			BackgroundTransparency = 1;
			Size = UDim2.new( 1, -26, 1, 0 );
			Text = PathText;
			TextXAlignment = Enum.TextXAlignment.Left;
			TextTruncate = Enum.TextTruncate.AtEnd;
			FontFace = Theme.fontFaceMedium;
			TextSize = Theme.textSizeSmall;
			Parent = Header;
		} );
		local Star = P.create( "TextButton", {
			AnchorPoint = Vector2.new( 1, 0.5 );
			Position = UDim2.new( 1, 0, 0.5, 0 );
			Size = UDim2.fromOffset( 22, 22 );
			BorderSizePixel = 0;
			Text = "☆";
			FontFace = Theme.fontFaceBold;
			TextSize = 16;
			Parent = Header;
		} );
		P.corner( Star, Theme.cornerSmall );

		Common.connect( Context, Link.MouseButton1Click, function( ) Open( Entry ); end );
		Common.connect( Context, Link.MouseEnter, function( ) Link.TextColor3 = Theme.accentBright; end );
		Common.connect( Context, Link.MouseLeave, function( ) Link.TextColor3 = Theme.textFaint; end );
		Common.connect( Context, Star.MouseButton1Click, function( )
			Saved[ Entry.id ] = not Saved[ Entry.id ] or nil;
			Options.save( );
			Refresh( );
		end );

		if ( Editable ) then
			Options.buildAll( );
			local MirrorContext = table.clone( Context );
			MirrorContext.registerHud = function( ) end;
			local Control = Components[ Kind ]( Root, Entry.spec, MirrorContext );
			Options.registerMirror( Entry.key, Control );
		end

		local function Paint( )
			Root.BackgroundColor3 = Theme.surface;
			Border.Color = Theme.strokeFaint;
			Link.TextColor3 = Theme.textFaint;
			Star.TextColor3 = Theme.accent;
			Star.BackgroundColor3 = Theme.accentFaint;
		end

		Paint( );
		Common.onTheme( Context, Paint );
		Cache[ Entry.id ] = { root = Root, star = Star };
		return Cache[ Entry.id ];
	end

	local function Query( ): string
		return ( string.gsub( string.gsub( string.lower( Window.NavSearch.Text ), "^%s+", "" ), "%s+$", "" ) );
	end

	Refresh = function( )
		local Text = Query( );
		local Matches, Pins = 0, 0;

		for _, Entry in Entries do
			local Favorite = Saved[ Entry.id ] == true;
			local Match = Text ~= "" and Index.matches( Entry, Text );

			if ( Match ) then
				Matches += 1;
			end

			if ( Favorite ) then
				Pins += 1;
			end

			local SearchRow = Rows[ Entry.id ];

			if ( Match and Matches <= Limit and Panel.Visible ) then
				SearchRow = Row( Panel, Entry, Rows );
			end

			if ( SearchRow ) then
				SearchRow.root.Visible = Match and Matches <= Limit;
				SearchRow.star.Text = Favorite and "★" or "☆";
				SearchRow.star.BackgroundTransparency = Favorite and 0 or 1;
			end

			local FavoriteRow = FavoriteRows[ Entry.id ];

			if ( Favorite and Window.activePage == FavoritesIndex ) then
				FavoriteRow = Row( FavoritesBody, Entry, FavoriteRows );
			end

			if ( FavoriteRow ) then
				FavoriteRow.root.Visible = Favorite;
				FavoriteRow.star.Text = "★";
				FavoriteRow.star.BackgroundTransparency = 0;
			end
		end

		SearchEmpty.Visible = Matches == 0;
		More.Text = "Show More (" .. tostring( math.max( 0, Matches - Limit ) ) .. ")";
		More.Visible = Matches > Limit;
		FavoritesEmpty.Visible = Pins == 0;
		Count.Text = tostring( Matches ) .. ( Matches == 1 and " result" or " results" );
	end;

	local function PlacePanel( )
		local Scale = Window : pixelScale( );
		local Root = Window.root;
		local Anchor = Window.searchFrame;
		local Width = math.min( PANEL_WIDTH, Root.AbsoluteSize.X / Scale - 24 );
		local Right = ( Root.AbsolutePosition.X + Root.AbsoluteSize.X - ( Anchor.AbsolutePosition.X + Anchor.AbsoluteSize.X ) ) / Scale;
		local Top = ( Anchor.AbsolutePosition.Y + Anchor.AbsoluteSize.Y - Root.AbsolutePosition.Y ) / Scale + 6;
		local Height = math.min( PANEL_HEIGHT, Root.AbsoluteSize.Y / Scale - Top - 12, PanelLayout.AbsoluteContentSize.Y / Scale + 20 );
		Panel.Position = UDim2.new( 1, -math.max( 12, Right ), 0, Top );
		Panel.Size = UDim2.fromOffset( Width, Height );
	end

	Common.connect( Context, PanelLayout : GetPropertyChangedSignal( "AbsoluteContentSize" ), function( )
		if ( Panel.Visible ) then
			PlacePanel( );
		end
	end );

	local function Search( Text: string )
		Limit = PAGE_SIZE;

		if ( Window.NavSearch.Text ~= Text and Query( ) ~= Text ) then
			Window.NavSearch.Text = Text;
		end

		if ( Text == "" ) then
			HidePanel( );
			Refresh( );
			return;
		end

		Panel.Visible = true;
		Catcher.Visible = true;
		Refresh( );
		PlacePanel( );
	end

	Common.connect( Context, Catcher.Activated, HidePanel );
	Common.connect( Context, More.MouseButton1Click, function( )
		Limit += PAGE_SIZE;
		Refresh( );
	end );
	Window.onFeatureSearch = Search;

	local Before = Window.beforeShowPage;
	Window.beforeShowPage = function( PageIndex: number )
		if ( Before ) then
			Before( PageIndex );
		end

		if ( PageIndex == FavoritesIndex ) then
			-- showPage calls this before activePage changes; refresh once it has.
			Common.defer( Context, "refresh favorites", Refresh );
		end
	end;

	local function Paint( )
		Panel.BackgroundColor3 = Theme.elevated;
		Panel.ScrollBarImageColor3 = Theme.textFaint;
		PanelStroke.Color = Theme.strokeBright;
		Count.TextColor3 = Theme.textFaint;
		SearchEmpty.TextColor3 = Theme.textDim;
		FavoritesEmpty.TextColor3 = Theme.textDim;
		More.BackgroundColor3 = Theme.control;
		More.TextColor3 = Theme.text;
	end

	Paint( );
	Common.onTheme( Context, Paint );
	return { refresh = Refresh, search = Search, open = Open, entries = Entries };
end
