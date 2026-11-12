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
local paths = require("paths")

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
		-- SPRUCE sets these three; PyUI defaults the other way, so an unset theme differs from the
		-- stock one. The volume PICTOGRAMS are a separate gap: PyUI draws them whatever this says.
		displayVolumeNumbers = state.showVolumeNumber and true or false,
		setTopBarTextToGameSelection = state.topBarShowsGame and true or false,
		fullScreenGridGameMenuResizeType = state.fullScreenGridFit == "Zoom" and "ZOOM" or "FIT",
		-- SPRUCE insets the top-bar text by 60 at the 640x480 base; PyUI's own default is 20, which
		-- leaves the clock tight against the edge of bar art that came from SPRUCE's geometry.
		topBarInitialXOffset = px(60, s),
		-- The grid of THIS resolution set: one row of 4 (5 on 16:9, PyUI's own int(4*multiplier)),
		-- or SPRUCE's override (2x3 on the Zero 40); rows and the text offset are added below
		mainMenuColCount = (state.mainMenuGrid(width, height)),
		recentsEnabled = state.showRecents and true or false,
		favoritesEnabled = state.showFavorites and true or false,
		collectionsEnabled = state.showCollections and true or false,
		appsEnabled = true,
		settingsEnabled = true,
	}

	-- Set only when hiding: PyUI falls back to its own title when the key is absent, so "" is the
	-- only way to suppress it (SPRUCE ships ""). Not written inline, because `a and nil or ""`
	-- yields "" for BOTH branches in Lua and would hide the title unconditionally.
	if not state.showMainMenuTitle then
		cfg.mainMenuTitle = ""
	end

	if (state.boxArtWidth or 0) > 0 then
		local w = px(state.boxArtWidth, s)
		cfg.listGameSelectImgWidth = w
		cfg.listGameSelectImgHeight = w
	end

	-- The base set leaves the grid to PyUI, as SPRUCE's config.json does: PyUI reads it on 640x480
	-- (its default there is 4) and patches it for panels without their own set, where int(4*multiplier)
	-- fits the real panel. Rows and the text offset only where SPRUCE writes them.
	if string.format("%dx%d", width, height) == paths.BASE_RESOLUTION then
		cfg.mainMenuColCount = nil
	else
		local _, menuRows, textYOffset = state.mainMenuGrid(width, height)
		if menuRows ~= 1 then
			cfg.mainMenuRowCount = menuRows
		end
		if textYOffset then
			cfg.multiRowGridTextYOffset = textYOffset
		end
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
