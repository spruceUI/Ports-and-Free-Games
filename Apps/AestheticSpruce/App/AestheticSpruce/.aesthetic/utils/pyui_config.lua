--- PyUI theme config writer
---
--- Builds the config.json (base 640x480) and config_<W>x<H>.json tables PyUI reads
--- (App/PyUI/main-ui/themes/theme.py) from the editor state. Only keys PyUI actually consumes
--- are emitted, plus name/author/description which the theme picker ignores but humans read.
--- Enum spellings come from views/view_type.py: GRID, TEXT_ONLY, TEXT_AND_IMAGE, ICON_AND_DESC,
--- FULLSCREEN_GRID, CAROUSEL. Unknown strings silently fall back to PyUI defaults, so they must
--- be exact.
local json = require("json_lua.json")
local state = require("state")
local fonts = require("ui.fonts")
local system = require("utils.system")
local fail = require("utils.fail")

local pyuiConfig = {}

-- Editor labels -> PyUI ViewType names (views/view_type.py); unknown names fall back to PyUI defaults
local VIEW = {
	games = { ["Text"] = "TEXT_ONLY", ["Text + Box Art"] = "TEXT_AND_IMAGE", ["Full Screen Grid"] = "FULLSCREEN_GRID", ["Carousel"] = "CAROUSEL" },
	-- the systems list is ICON_AND_DESC, not TEXT_ONLY: its entries carry an icon, and TEXT_ONLY
	-- draws none, so the tiles we generate never showed. systemIcons = false already forces
	-- TEXT_ONLY below, so this branch only runs with icons switched on.
	systems = { ["Grid"] = "GRID", ["Text"] = "ICON_AND_DESC", ["Carousel"] = "CAROUSEL" },
	apps = { ["Icons + Details"] = "ICON_AND_DESC", ["Text"] = "TEXT_ONLY" },
}
pyuiConfig.VIEW = VIEW

-- SPRUCE scales its font sizes by ~1.5 at 1280x720 and 1024x768; min(w/640, h/480) reproduces
-- that and keeps 720x480 at 1.0 and 720x720 at 1.125.
function pyuiConfig.scaleFor(width, height)
	return math.min(width / 640, height / 480)
end

function pyuiConfig.fontSizeMultiplier()
	local base = fonts.themeFontSizeOptions["Default"] or 24
	local chosen = fonts.themeFontSizeOptions[state.fontSize] or base
	return chosen / base
end

-- The TTF shipped inside the theme, referenced by bare filename from the config
function pyuiConfig.fontFile()
	for _, def in ipairs(fonts.themeDefinitions) do
		if def.name == state.fontFamily then
			return def.ttf:match("[^/]+$"), def.ttf
		end
	end
	return nil
end

local function px(base, scale)
	return math.max(8, math.floor(base * scale + 0.5))
end

-- PyUI defaults the system grid to 4 columns by 2 rows (scaled). SPRUCE overrides that on the two
-- panels where it reads badly: 4x3 on the 720x720 squares, 3x3 on the Zero 40's portrait panel.
-- Generated themes follow it, and leave PyUI's default alone everywhere else.
local SYSTEM_GRID = {
	["720x720"] = { cols = 4, rows = 3 },
	["480x800"] = { cols = 3, rows = 3 },
}

function pyuiConfig.build(width, height)
	local fontFile = pyuiConfig.fontFile()
	if not fontFile then
		return nil, "Selected font not found: " .. tostring(state.fontFamily)
	end
	local s = pyuiConfig.scaleFor(width, height)
	local fm = pyuiConfig.fontSizeMultiplier()
	local fg = state.getColorValue("foreground")
	local bg = state.getColorValue("background")
	local batteryActive = state.getColorValue("batteryActive")
	local grid = state.homeScreenLayout == "Grid"

	local cfg = {
		name = state.themeName,
		author = "Aesthetic Spruce",
		description = "Generated on-device by Aesthetic Spruce (duo-tone)",

		list = { font = fontFile, size = px(24 * fm, s), color = fg, selectedcolor = bg },
		-- grid labels are drawn by PyUI beside/below the tile on the background, so the selected label
		-- stays in the foreground colour (the tile itself carries the selection)
		grid = { font = fontFile, grid1x4 = px(25 * fm, s), grid3x4 = px(18 * fm, s), color = fg, selectedcolor = fg },
		title = { font = fontFile, size = px(25, s), color = fg },
		currentpage = { font = fontFile, size = px(22, s), color = fg },
		total = { font = fontFile, size = px(22, s), color = fg },
		batteryPercentage = { font = fontFile, size = px(18, s), color = fg },
		listFontSize = px(24 * fm, s),

		-- the main menu stays TEXT_ONLY in list mode: PyUI builds its entries with icon = nil and
		-- does not pass icon_and_desc_use_image_in_place_of_icon, so a list there cannot show icons
		mainMenuViewType = grid and "GRID" or "TEXT_ONLY",
		systemSelectViewType = state.systemIcons and (VIEW.systems[state.systemsView] or "GRID") or "TEXT_ONLY",
		gameSelectionViewType = VIEW.games[state.gameListView] or "TEXT_AND_IMAGE",
		appMenuViewType = VIEW.apps[state.appsView] or "ICON_AND_DESC",
		-- PyUI draws the labels under grid tiles; the generated tiles carry no text of their own
		mainMenuShowTextGridMode = true,
		systemSelectShowTextGridMode = true,
		showIndexText = state.showIndex and true or false,
		includeIndexText = state.showIndex and true or false,
		screensaver = {
			screensaverTimeoutSec = math.max(0, math.floor((state.screensaverMinutes or 0) * 60)),
			bgColor = bg,
			overlayColor = bg,
			overlayOpacity = 0.3,
			-- PyUI's fallback widgets are hardcoded white/grey/green, so emit our own in the
			-- theme's colours. Sizes stay 640x480-base and unscaled: PyUI's own screensaver
			-- renderer re-applies scaleFor's factor to fontSize, so pre-scaling would double it.
			widgets = {
				{ type = "clock", x = 0.5, y = 0.37, fontSize = px(64, 1), color = fg, enabled = true, font = fontFile },
				{ type = "date", x = 0.5, y = 0.55, fontSize = px(22, 1), color = fg, enabled = true, font = fontFile },
				{ type = "battery", x = 0.5, y = 0.70, fontSize = px(18, 1), color = batteryActive, enabled = true, font = fontFile },
			},
		},

		showTopBarText = state.showTopBarText and true or false,
		showBottomBar = state.showBottomBar and true or false,
		showClock = state.showClock and true or false,
		displayBatteryIcon = state.showBattery and true or false,
		displayBatteryPercent = state.showBattery and true or false,
		showBottomBarButtons = true,
		recentsEnabled = state.showRecents and true or false,
		favoritesEnabled = state.showFavorites and true or false,
		collectionsEnabled = state.showCollections and true or false,
		appsEnabled = true,
		settingsEnabled = true,
	}

	if (state.boxArtWidth or 0) > 0 then
		local w = px(state.boxArtWidth, s)
		cfg.listGameSelectImgWidth = w
		cfg.listGameSelectImgHeight = w
	end

	local systemGrid = SYSTEM_GRID[string.format("%dx%d", width, height)]
	if systemGrid then
		cfg.gameSystemSelectColCount = systemGrid.cols
		cfg.gameSystemSelectRowCount = systemGrid.rows
	end

	return cfg
end

function pyuiConfig.write(path, width, height)
	local cfg, err = pyuiConfig.build(width, height)
	if not cfg then
		return fail(err)
	end
	local ok, encoded = pcall(json.encode, cfg)
	if not ok then
		return fail("Failed to encode theme config: " .. tostring(encoded))
	end
	return system.writeFile(path, encoded .. "\n")
end

return pyuiConfig
