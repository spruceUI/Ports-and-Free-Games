--- Home Screen Layout: PyUI main menu as a grid of tiles or a text list
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
local themePreview = require("ui.theme_preview")

local homeScreenLayout = {}

local menuList = nil
local headerInstance = Header:new({ title = "Home Screen Layout" })
local controlHintsInstance

-- Shrink a list to exactly the height its items need (List computes this from its own metrics)
local function fitList(list)
	list.height = list:getContentHeight()
	return list
end

local function createLayoutButton()
	return Button:new({
		text = "Layout",
		type = ButtonTypes.INDICATORS,
		options = { "List", "Grid" },
		currentOptionIndex = (state.homeScreenLayout == "Grid" and 2) or 1,
		screenWidth = state.screenWidth,
		context = "homeScreenLayout",
	})
end

local function handleOptionCycle(button, direction)
	if button.context ~= "homeScreenLayout" or not button:cycleOption(direction) then
		return false
	end
	state.homeScreenLayout = button:getCurrentOption()
	return true
end

function homeScreenLayout.draw()
	background.draw()
	headerInstance:draw()
	love.graphics.setFont(fonts.loaded.body)
	if menuList then
		menuList:draw()
	end
	local top = menuList and (menuList.y + menuList.height) or headerInstance:getContentStartY()
	local areaH = state.screenHeight - top - controls.calculateHeight() - 12
	if areaH > 50 then
		local x, y, w, h = themePreview.fitRect(40, top, state.screenWidth - 80, areaH)
		themePreview.draw(x, y, w, h, { layout = state.homeScreenLayout })
	end
	controlHintsInstance:setControlsList({
		{ button = "d_pad", text = "Change" },
		{ button = "b", text = "Back" },
	})
	controlHintsInstance:draw()
end

function homeScreenLayout.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, nil)
		menuList:update(dt)
		-- The focused Button cycles its own option before the list's cycle callback can run, so the
		-- state is read back from the button rather than written from the callback.
		local button = menuList.items[1]
		if button and button.getCurrentOption then
			state.homeScreenLayout = button:getCurrentOption()
		end
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function homeScreenLayout.onExit() end

function homeScreenLayout.onEnter()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight,
		items = { createLayoutButton() },
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})
	fitList(menuList)
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

return homeScreenLayout
