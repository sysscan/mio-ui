# mio-ui

The menu framework used by the Mio hub scripts: windows, pages, sections, toggles, sliders, dropdowns,
color pickers, keybinds, profiles, the HUD, notifications and the overlay layer.

The hub scripts don't ship a copy of it. At startup they download `dist/mio-ui.lua` from one **pinned
commit** of this repository, check its SHA-256 against the hash built into the script, and load it. If the
file doesn't match, the script refuses to load it, so a change pushed here never reaches existing scripts
until a new script release pins it.

## Layout

| Path | What it is |
| --- | --- |
| `src/ui/` | The modules, one file each, named by the id they are required by (`ui/init.lua`, `ui/components/toggle.lua`, ...). |
| `dist/mio-ui.lua` | All modules in one file: `return { Format = 1, Modules = { ["ui/init.lua"] = "<source>", ... } }`. This is what the scripts download. |

## Host requirements

The modules use a `require(id)` supplied by the host. Besides each other (`ui/*`), they require these host
modules, which are not part of this repository:

`core/runtime.lua`, `core/services.lua`, `core/input.lua`, `core/config.lua`, `core/maid.lua`,
`core/util.lua`, `visuals/occlusion.lua`, `visuals/esp/controls.lua`

The entry point is `ui/init.lua`. Menus are built declaratively:

```lua
local UI = require("ui/init.lua")

local window = UI.create({
	title = "EXAMPLE",
	configName = "example",
	config = config,
	toggleKey = Enum.KeyCode.RightShift,
	pages = {
		{
			label = "Main",
			sections = {
				{
					title = "Feature",
					items = {
						{ type = "toggle", key = "Enabled", label = "Enabled" },
						{ type = "slider", key = "Intensity", label = "Intensity", min = 0, max = 100, step = 5 },
						{ type = "select", key = "Mode", label = "Mode", options = { "Fast", "Balanced" } },
						{ type = "color", key = "Accent", label = "Accent" },
					},
				},
			},
		},
	},
})
```

## Contributing

This repository is generated from the hub's source tree, so a pull request here gets re-applied upstream
rather than merged directly. Issues and suggestions are welcome.

## License

MIT, see [LICENSE](LICENSE). Bundled icon data: see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
