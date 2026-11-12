--- Application state and the theme model
---
--- The theme model is the set of options a generated PyUI theme is built from. Every option
--- is declared once in THEME_FIELDS / COLOR_FIELDS; settings (auto-restore) and presets both
--- serialise state through exportTheme()/importTheme(), so adding an option means adding one
--- line here and using it in the renderer.
local fail = require("utils.fail")
local colorUtils = require("utils.color")
local logger = require("utils.logger")

local isDevMode = os.getenv("DEV") == "true"

--- A colour context holds one editable colour plus the picker UI state for it
local function createColorContext(defaultColor)
	return {
		palette = { selectedRow = 0, selectedCol = 0, scrollY = 0 },
		hsv = { hue = 0, sat = 1, val = 1, focusSquare = false, cursor = { svX = nil, svY = nil, hueY = nil } },
		hex = { input = "", selectedButton = { row = 1, col = 1 } },
		currentColor = defaultColor,
	}
end

local state = {}

-- Scalar theme options: key, Lua type, default
state.THEME_FIELDS = {
	{ key = "themeName", type = "string", default = "Aesthetic Spruce" },
	{ key = "fontFamily", type = "string", default = "Inter" },
	{ key = "fontSize", type = "string", default = "Default" },
	{ key = "homeScreenLayout", type = "string", default = "Grid" }, -- "Grid" | "List"
	{ key = "backgroundType", type = "string", default = "Gradient" }, -- "Solid" | "Gradient"
	{ key = "backgroundGradientDirection", type = "string", default = "Vertical" }, -- "Vertical" | "Horizontal"
	{ key = "systemIcons", type = "boolean", default = true }, -- emit icons/ and use grid system select
	{ key = "systemIconStyle", type = "string", default = "Glyph" }, -- "Glyph" | "Letter" | "SPRUCE Art" (SPRUCE's art in two tones) | "SPRUCE Mono" (same art, one colour)
	{ key = "boxArtWidth", type = "number", default = 0 }, -- 0 = PyUI default
	{ key = "showTopBarText", type = "boolean", default = true }, -- PyUI showTopBarText
	{ key = "showBottomBar", type = "boolean", default = true }, -- PyUI showBottomBar
	{ key = "showClock", type = "boolean", default = true }, -- PyUI showClock
	{ key = "showBattery", type = "boolean", default = true }, -- PyUI displayBatteryIcon/Percent
	-- spruceOS / PyUI specific
	{ key = "gameListView", type = "string", default = "Text + Box Art" }, -- gameSelectionViewType
	{ key = "systemsView", type = "string", default = "Grid" }, -- systemSelectViewType
	{ key = "appsView", type = "string", default = "Icons + Details" }, -- appMenuViewType
	{ key = "showRecents", type = "boolean", default = false }, -- recentsEnabled (SPRUCE turns it off)
	{ key = "showCollections", type = "boolean", default = false }, -- collectionsEnabled (PyUI default too)
	{ key = "showFavorites", type = "boolean", default = true }, -- favoritesEnabled
	{ key = "showIndex", type = "boolean", default = true }, -- showIndexText / includeIndexText ("A 02/13")
	{ key = "showVolumeNumber", type = "boolean", default = true }, -- displayVolumeNumbers (SPRUCE sets it)
	{ key = "topBarShowsGame", type = "boolean", default = true }, -- setTopBarTextToGameSelection
	{ key = "fullScreenGridFit", type = "string", default = "Fit" }, -- fullScreenGridGameMenuResizeType
	{ key = "showMainMenuTitle", type = "boolean", default = true }, -- false emits mainMenuTitle ""
	{ key = "screensaverMinutes", type = "number", default = 1 }, -- screensaver.screensaverTimeoutSec, 0 = off
}

-- Colour options (hex strings with '#')
state.COLOR_FIELDS = {
	{ key = "background", default = "#1E40AF" },
	{ key = "backgroundGradient", default = "#155CFB" },
	{ key = "foreground", default = "#FFFFFF" },
	{ key = "batteryActive", default = "#4ADE80" },
	{ key = "batteryLow", default = "#F87171" },
}

-- Application (non-theme) state
--- Main-menu tiles that fit the device, the way the stock SPRUCE theme is laid out.
---
--- PyUI draws the main menu as mainMenuRowCount (default 1) rows of mainMenuColCount (default
--- int(4 * width_multiplier): 4 on every supported panel except 16:9, where it is 5) and drops
--- tiles that do not fit. SPRUCE overrides that grid on some panels (MAIN_MENU_GRID); elsewhere we
--- follow PyUI's own rule rather than invent one. Games, Apps and Settings are always on, so the
--- spare slots go to Favorites first, then Recents, then Collections -- SPRUCE's own set on a
--- 4-wide row, all six on the Zero 40's 2x3. A list scrolls, so it shows everything.

-- SPRUCE's config_<WxH>.json grids that differ from one PyUI row (checked against 4.6.1)
state.MAIN_MENU_GRID = {
	["480x800"] = { cols = 2, rows = 3, textYOffset = -16 }, -- Zero 40 portrait (SPRUCE since 09-25)
}

--- cols, rows (and SPRUCE's multiRowGridTextYOffset, if any) of the main menu on a WxH panel
function state.mainMenuGrid(w, h)
	w, h = w or 640, h or 480
	local g = state.MAIN_MENU_GRID[string.format("%dx%d", w, h)]
	if g then
		return g.cols, g.rows, g.textYOffset
	end
	if w <= 0 or h <= 0 then
		return 4, 1
	end
	local scaleW, scaleH = w / 640, h / 480
	local widthMultiplier = scaleW > scaleH and (((scaleW - scaleH) / scaleH) + 1) or 1
	return math.max(4, math.min(5, math.floor(4 * widthMultiplier))), 1
end

--- Tiles that fit on this device's main menu (columns x rows)
function state.mainMenuSlots()
	local cols, rows = state.mainMenuGrid(state.screenWidth, state.screenHeight)
	return cols * rows
end

--- Set the three optional tiles to this layout's defaults. Called on first run and whenever the
--- home screen layout changes, so the rows always show what the layout will actually produce.
function state.applyMainMenuDefaults()
	if state.homeScreenLayout == "List" then
		state.showRecents, state.showCollections, state.showFavorites = true, true, true
		return
	end
	local spare = state.mainMenuSlots() - 3 -- Games, Apps and Settings are always shown
	state.showFavorites = spare >= 1
	state.showRecents = spare >= 2
	state.showCollections = spare >= 3
end

state.applicationName = "Aesthetic Spruce"
state.screenWidth = 0 -- set in main.lua
state.screenHeight = 0 -- set in main.lua
state.isDevMode = isDevMode
state.previousScreen = "main_menu" -- screen to return to after the colour picker
state.themeApplied = false -- set once the theme has been written as the active theme
state.source = "user" -- where the current settings came from ("user" | "built-in")
state.activeColorContext = "background"
state.allResolutions = false -- generate every resolution set instead of base + native

for _, f in ipairs(state.THEME_FIELDS) do
	state[f.key] = f.default
end
state.colorContexts = {}
for _, c in ipairs(state.COLOR_FIELDS) do
	state.colorContexts[c.key] = createColorContext(c.default)
end

function state.getColorContext(contextKey)
	if not state.colorContexts[contextKey] then
		return fail("Color context '" .. tostring(contextKey) .. "' does not exist")
	end
	return state.colorContexts[contextKey]
end

function state.getColorValue(contextKey)
	local context = state.getColorContext(contextKey)
	return context and context.currentColor or "#000000"
end

--- Set a colour (hex string with '#') and refresh the picker state derived from it
function state.setColorValue(contextKey, colorValue)
	if type(colorValue) ~= "string" or colorValue:sub(1, 1) ~= "#" then
		return fail("Only hex colour strings starting with '#' are supported, got: " .. tostring(colorValue))
	end
	local context = state.getColorContext(contextKey)
	if not context then
		return nil
	end
	context.currentColor = colorValue
	context.hex.input = colorValue:sub(2)
	local r, g, b = colorUtils.hexToRgb(colorValue)
	local h, s, v = colorUtils.rgbToHsv(r, g, b)
	context.hsv.hue = h * 360
	context.hsv.sat = s
	context.hsv.val = v
	return colorValue
end

--- Plain-table snapshot of the theme model (what settings and presets store)
function state.exportTheme()
	local t = {}
	for _, f in ipairs(state.THEME_FIELDS) do
		t[f.key] = state[f.key]
	end
	t.colors = {}
	for _, c in ipairs(state.COLOR_FIELDS) do
		t.colors[c.key] = state.getColorValue(c.key)
	end
	return t
end

-- Older preset/settings files (upstream Aesthetic) used nested colour tables and other names
local LEGACY = {
	glyphsEnabled = "systemIcons",
	font = "fontFamily",
}

local function legacyColor(t, key)
	local v = t[key]
	if type(v) == "table" then
		return v.value
	end
	return v
end

--- Apply a snapshot; missing or invalid fields fall back to the defaults (lenient on purpose so a
--- preset from another version still loads). Returns the number of fields that were rejected.
function state.importTheme(t)
	if type(t) ~= "table" then
		return fail("Theme data is not a table")
	end
	local rejected = 0
	for _, f in ipairs(state.THEME_FIELDS) do
		local v = t[f.key]
		if v == nil then
			for old, new in pairs(LEGACY) do
				if new == f.key and t[old] ~= nil then
					v = t[old]
				end
			end
		end
		if v ~= nil and type(v) == f.type then
			state[f.key] = v
		else
			if v ~= nil then
				rejected = rejected + 1
				logger.warning("Ignoring field '" .. f.key .. "' of type " .. type(v))
			end
			state[f.key] = f.default
		end
	end
	-- No tile flag at all (every built-in preset): size the main menu to this device and the
	-- snapshot's layout, as on first run; a snapshot naming any of them keeps its own choice
	if t.showRecents == nil and t.showCollections == nil and t.showFavorites == nil then
		state.applyMainMenuDefaults()
	end
	local colors = type(t.colors) == "table" and t.colors or {}
	for _, c in ipairs(state.COLOR_FIELDS) do
		local v = colors[c.key]
		if v == nil then
			v = legacyColor(t, c.key)
		end
		if type(v) ~= "string" or not state.setColorValue(c.key, v) then
			if v ~= nil then
				rejected = rejected + 1
			end
			state.setColorValue(c.key, c.default)
		end
	end
	-- upstream stored the background type inside the background colour table
	if type(t.background) == "table" and type(t.background.type) == "string" and t.backgroundType == nil then
		state.backgroundType = t.background.type
	end
	if type(t.backgroundGradient) == "table" and type(t.backgroundGradient.direction) == "string" and t.backgroundGradientDirection == nil then
		state.backgroundGradientDirection = t.backgroundGradient.direction
	end
	if type(t.source) == "string" then
		state.source = t.source
	end
	return true, rejected
end

function state.resetToDefaults()
	logger.debug("Resetting theme configuration to defaults")
	for _, f in ipairs(state.THEME_FIELDS) do
		state[f.key] = f.default
	end
	for _, c in ipairs(state.COLOR_FIELDS) do
		state.setColorValue(c.key, c.default)
	end
	state.source = "user"
end

return state
