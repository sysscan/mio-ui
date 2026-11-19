-- Cache
local Lower = string.lower;
local Find = string.find;
local M = { };
local Aliases = { dropdown = "select", multiselect = "select", textbox = "text", input = "text" };
local Supported = { toggle = true, slider = true, number = true, select = true, color = true, text = true, keybind = true, button = true };

function M.collect( Pages: { any } ): { any }
	local Entries, Seen = { }, { };
	local function Visit( Items: { any }, Page: any, Section: any, Path: string, Ancestors: { any } )
		for _, Item in Items do
			local Label = tostring( Item.label or Item.key or "" );
			local Kind = Item.type;
			local Control = Item;
			if ( Kind == "group" or Kind == "collapsible" ) then
				Control = table.clone( Item.toggleSpec or { } );
				Control.type = "toggle";
				Control.key = Item.toggleKey or Item.key;
				Control.label = Control.label or Label;
				Control.inline = false;
			elseif ( Aliases[ Kind ] ) then
				Control = table.clone( Item );
				Control.type = Aliases[ Kind ];
			end
			local Key = Control.key;
			local Id = Key or ( Control.type == "button" and Path .. "/" .. Label );
			if ( Supported[ Control.type ] and Id and not Seen[ Id ] and Label ~= "" ) then
				Seen[ Id ] = true;
				Entries[ #Entries + 1 ] = {
					id = Id; key = Key; label = Label; spec = Control;
					path = Path .. " / " .. Label; page = Page; section = Section;
					ancestors = table.clone( Ancestors );
					search = Lower( Path .. " " .. Label .. " " .. tostring( Key or "" ) );
				};
			end
			local Nested = table.clone( Ancestors );
			Nested[ #Nested + 1 ] = { spec = Item };
			if ( Item.items ) then
				Visit( Item.items, Page, Section, Path .. " / " .. Label, Nested );
			end
			for _, Profile in Item.profiles or { } do
				local ProfilePath = table.clone( Ancestors );
				ProfilePath[ #ProfilePath + 1 ] = { spec = Item, profile = Profile.label };
				Visit( Profile.items or { }, Page, Section, Path .. " / " .. Label .. " / " .. Profile.label, ProfilePath );
			end
		end
	end
	for _, Page in Pages do
		for _, Section in Page.sections or { } do
			Visit( Section.items or { }, Page, Section, Page.label .. " / " .. tostring( Section.title or "General" ), { } );
		end
	end
	return Entries;
end

function M.matches( Entry: any, Query: string ): boolean
	for Token in Lower( Query ) : gmatch( "%S+" ) do
		if ( not Find( Entry.search, Token, 1, true ) ) then
			return false;
		end
	end
	return true;
end

return M;
