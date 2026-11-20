-- Orders a menu's pages and each page's sections by category, so every game's menu reads the same way:
-- overview, combat, visuals, movement, player, world and automation, then misc. A label's category comes
-- from the words in it ("Silent Aim" is combat, "Teleports" is world). Labels with no known word sit
-- between world and misc. Items inside a section never move.
--
-- A page or section with a numeric `order` uses it as its rank instead (the ranks below run 0 to 7), and
-- `Hub.UI.create{ organize = false }` turns ordering off. Ties keep their declared order.

-- Cache
local StringLower = string.lower;
local StringFind = string.find;
local TableSort = table.sort;
local TypeOf = typeof;
local ToString = tostring;

-- Constants
local UNKNOWN_RANK = 6;

-- Each word matches at the start of a word in the label: "aim" matches "Aimbot" and "Anti Aim".
local CATEGORIES = {
	{ Rank = 0, Words = { "main", "home", "dashboard", "overview", "general", "info", "status" } };
	{ Rank = 1, Words = { "combat", "aim", "silent", "rage", "legit", "trigger", "weapon", "gun", "kill", "attack", "fight", "pvp", "hitbox", "melee", "parry", "block" } };
	{ Rank = 2, Words = { "visual", "esp", "chams", "render", "radar", "crosshair", "tracer", "highlight", "camera", "view", "spectate" } };
	{ Rank = 3, Words = { "movement", "move", "speed", "fly", "jump", "noclip", "walk", "dash" } };
	{ Rank = 4, Words = { "player", "character", "self", "local", "humanoid" } };
	{ Rank = 5, Words = { "world", "farm", "auto", "harvest", "garden", "plant", "economy", "shop", "sell", "store", "teleport", "map", "server", "quest", "pet", "event", "upgrade", "tool", "crate", "item", "loot" } };
	{ Rank = 7, Words = { "misc", "other", "extra", "fun", "troll", "util", "credit", "stat" } };
};

-- Types
type Entry = { [ string ]: any };

-- Main
local Organize = { }; do
	function Organize.Rank( Label: any ): number
		if ( TypeOf( Label ) ~= "string" ) then
			return UNKNOWN_RANK;
		end

		local Lower = StringLower( Label );

		for _, Category in CATEGORIES do
			for _, Word in Category.Words do
				if ( StringFind( Lower, "%f[%w]" .. Word ) ) then
					return Category.Rank;
				end
			end
		end

		return UNKNOWN_RANK;
	end

	-- Stable sort of `List` in place by rank; `LabelOf` reads an entry's label.
	function Organize.Sort( List: { Entry }, LabelOf: ( Entry ) -> any )
		local Keys = { };

		for Index, Item in List do
			local Rank = TypeOf( Item ) == "table" and Item.order;

			if ( TypeOf( Rank ) ~= "number" or Rank ~= Rank ) then
				Rank = Organize.Rank( LabelOf( Item ) );
			end

			Keys[ Item ] = { Rank = Rank, Index = Index };
		end

		TableSort( List, function( Left: Entry, Right: Entry ): boolean
			local A = Keys[ Left ];
			local B = Keys[ Right ];

			if ( A.Rank ~= B.Rank ) then
				return A.Rank < B.Rank;
			end

			return A.Index < B.Index;
		end );
	end

	function Organize.Pages( Pages: { Entry } )
		Organize.Sort( Pages, function( Page: Entry ): any
			return Page.label;
		end );
	end

	function Organize.Sections( Sections: { Entry } )
		Organize.Sort( Sections, function( Section: Entry ): any
			return Section.title and ToString( Section.title ) or nil;
		end );
	end
end

return Organize;
