-- Profiles: one set of controls per profile (Kontra's per-weapon-class aim tuning), switched by a tab
-- strip at the top of the block so it is always visible which profile is being edited.

-- Dependencies
local P = require( "ui/primitives.lua" );
local Common = require( "ui/components/common.lua" );

-- Main
return function( Section: Instance, Spec: any, Context: any ): any
	local Theme = Context.theme;
	local Names = { };
	local Panels = { };
	local Tabs = { };

	for _, Profile in Spec.profiles or { } do
		local Name = Profile.label;

		if ( typeof( Name ) == "string" and Name ~= "" and not table.find( Names, Name ) ) then
			Names[ #Names + 1 ] = Name;
		end
	end

	if ( #Names == 0 ) then
		return nil;
	end

	local Root = P.create( "Frame", {
		BackgroundTransparency = 1;
		Size = UDim2.new( 1, 0, 0, 0 );
		AutomaticSize = Enum.AutomaticSize.Y;
		Parent = Section;
	} );
	P.listLayout( Root, Theme.fieldGap or 6 );

	if ( Spec.label ) then
		local Caption = P.label( Root, Spec.label, {
			Theme = Theme;
			Size = UDim2.new( 1, 0, 0, 18 );
			Font = Theme.fontMedium;
			TextSize = Theme.textSizeSmall;
		} );
		P.paddingXY( Caption, 6, 0 );
		Common.onTheme( Context, function( ) Caption.TextColor3 = Theme.textFaint; end );
		Caption.TextColor3 = Theme.textFaint;
	end

	local Strip = P.create( "ScrollingFrame", {
		Size = UDim2.new( 1, 0, 0, 30 );
		BorderSizePixel = 0;
		ScrollBarThickness = 0;
		ScrollingDirection = Enum.ScrollingDirection.X;
		CanvasSize = UDim2.new( );
		AutomaticCanvasSize = Enum.AutomaticSize.X;
		Parent = Root;
	} );
	P.corner( Strip, Theme.cornerSmall );
	P.padding( Strip, 2 );
	P.listLayout( Strip, 2, Enum.FillDirection.Horizontal );

	local Active: string? = nil;

	local function Paint( )
		Strip.BackgroundColor3 = Theme.control;

		for Name, Tab in Tabs do
			local On = Name == Active;
			Tab.BackgroundColor3 = On and Theme.accent or Theme.control;
			Tab.BackgroundTransparency = On and 0 or 1;
			Tab.TextColor3 = On and Theme.background or Theme.textDim;
			Tab.FontFace = On and Theme.fontFaceBold or Theme.fontFaceMedium;
		end
	end

	-- The selection is navigation, never a saved game setting. Child controls keep their own keys
	-- and stay registered while their panel is hidden.
	local function Show( Name: string ): boolean
		if ( not Panels[ Name ] ) then
			return false;
		end

		Active = Name;

		for Label, Panel in Panels do
			Panel.Visible = Label == Name;
		end

		Paint( );
		return true;
	end

	for Order, Name in Names do
		local Tab = P.create( "TextButton", {
			Size = UDim2.new( 0, 0, 1, 0 );
			AutomaticSize = Enum.AutomaticSize.X;
			BorderSizePixel = 0;
			AutoButtonColor = false;
			Text = Name;
			TextSize = Theme.textSizeSmall;
			LayoutOrder = Order;
			Parent = Strip;
		} );
		P.corner( Tab, Theme.cornerSmall );
		P.paddingXY( Tab, 12, 0 );
		Tabs[ Name ] = Tab;
		Common.connect( Context, Tab.Activated, function( ) Show( Name ); end );
	end

	for _, Profile in Spec.profiles do
		local Name = Profile.label;

		if ( not table.find( Names, Name ) or Panels[ Name ] ) then
			continue;
		end

		local Panel = P.create( "Frame", {
			Name = "Profile_" .. Name;
			BackgroundTransparency = 1;
			Size = UDim2.new( 1, 0, 0, 0 );
			AutomaticSize = Enum.AutomaticSize.Y;
			Visible = false;
			Parent = Root;
		} );
		P.listLayout( Panel, Theme.controlGap or 4 );
		Panels[ Name ] = Panel;
		Context.buildItems( Panel, Profile.items or { } );
	end

	Show( table.find( Names, Spec.defaultProfile ) and Spec.defaultProfile or Names[ 1 ] );
	Common.onTheme( Context, Paint );

	return {
		selectProfile = Show;
		getProfile = function( ): string?
			return Active;
		end;
	};
end
