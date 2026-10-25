--- spruceOS Options: PyUI-specific view types and toggles a theme carries
local love = require("love")

local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local List = require("ui.components.list").List

local spruceOptions = {}

local menuList = nil
local headerInstance = Header:new({ title = "spruceOS Options" })
local controlHintsInstance

local SHOWN = { "Hidden", "Shown" }
local SCREENSAVER = { "Off", "1 min", "5 min", "10 min", "30 min" }
local SCREENSAVER_MINUTES = { 0, 1, 5, 10, 30 }

-- Each row: state key, label, option strings, and how the option maps to/from the state value
spruceOptions.ROWS = {
	{ key = "gameListView", text = "Game List", options = { "Text", "Text + Box Art", "Full Screen Grid", "Carousel" } },
	{ key = "systemsView", text = "Systems", options = { "Grid", "Text", "Carousel" } },
	{ key = "appsView", text = "Apps", options = { "Icons + Details", "Text" } },
	{ key = "showRecents", text = "Recents Tile", options = SHOWN, bool = true },
	{ key = "showCollections", text = "Collections Tile", options = SHOWN, bool = true },
	{ key = "showFavorites", text = "Favorites Tile", options = SHOWN, bool = true },
	{ key = "showIndex", text = "Index Counter", options = SHOWN, bool = true },
	{ key = "screensaverMinutes", text = "Screensaver", options = SCREENSAVER, minutes = true },
}

local function optionIndexFor(row)
	local value = state[row.key]
	if row.bool then
		return value and 2 or 1
	elseif row.minutes then
		for i, m in ipairs(SCREENSAVER_MINUTES) do
			if m == value then
				return i
			end
		end
		return 2
	end
	for i, option in ipairs(row.options) do
		if option == value then
			return i
		end
	end
	return 1
end

local function stateValueFor(row, option)
	if row.bool then
		return option == "Shown"
	elseif row.minutes then
		for i, label in ipairs(SCREENSAVER) do
			if label == option then
				return SCREENSAVER_MINUTES[i]
			end
		end
		return 1
	end
	return option
end

local function createButtons()
	local buttons = {}
	for _, row in ipairs(spruceOptions.ROWS) do
		buttons[#buttons + 1] = Button:new({
			text = row.text,
			type = ButtonTypes.INDICATORS,
			options = row.options,
			currentOptionIndex = optionIndexFor(row),
			screenWidth = state.screenWidth,
			context = row.key,
		})
	end
	return buttons
end

function spruceOptions.draw()
	background.draw()
	headerInstance:draw()
	love.graphics.setFont(fonts.loaded.body)
	if menuList then
		menuList:draw()
	end
	controlHintsInstance:setControlsList({
		{ button = "d_pad", text = "Change" },
		{ button = "b", text = "Back" },
	})
	controlHintsInstance:draw()
end

function spruceOptions.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, nil)
		menuList:update(dt)
		-- read every option back from its button (the focused Button cycles itself)
		for _, button in ipairs(menuList.items) do
			if button.context and button.getCurrentOption then
				for _, row in ipairs(spruceOptions.ROWS) do
					if row.key == button.context then
						state[row.key] = stateValueFor(row, button:getCurrentOption())
					end
				end
			end
		end
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function spruceOptions.onEnter()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - controls.calculateHeight() - 8,
		items = createButtons(),
		wrap = false,
	})
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function spruceOptions.onExit() end

return spruceOptions
