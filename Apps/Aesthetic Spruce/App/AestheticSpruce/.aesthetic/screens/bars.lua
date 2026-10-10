--- Bars screen: the PyUI top and bottom bar elements a theme can switch on or off
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

local bars = {}

local menuList = nil
local headerInstance = Header:new({ title = "Bars" })
local controlHintsInstance

local OPTIONS = { "Hidden", "Shown" }

-- Shrink a list to exactly the height its items need (List computes this from its own metrics)
local function fitList(list)
	list.height = list:getContentHeight()
	return list
end

bars.TOGGLES = {
	{ key = "showTopBarText", text = "Title" },
	{ key = "showClock", text = "Clock" },
	{ key = "showBattery", text = "Battery" },
	{ key = "showBottomBar", text = "Button Hints" },
}

local function createButtons()
	local buttons = {}
	for _, t in ipairs(bars.TOGGLES) do
		buttons[#buttons + 1] = Button:new({
			text = t.text,
			type = ButtonTypes.INDICATORS,
			options = OPTIONS,
			currentOptionIndex = state[t.key] and 2 or 1,
			screenWidth = state.screenWidth,
			context = t.key,
		})
	end
	return buttons
end

local function handleOptionCycle(button, direction)
	if not button.context then
		return false
	end
	if not button:cycleOption(direction) then
		return false
	end
	state[button.context] = (button:getCurrentOption() == "Shown")
	return true
end

function bars.draw()
	background.draw()
	headerInstance:draw()
	love.graphics.setFont(fonts.loaded.body)
	if menuList then
		menuList:draw()
	end
	local listBottom = menuList and (menuList.y + menuList.height) or headerInstance:getContentStartY()
	local areaH = state.screenHeight - listBottom - controls.calculateHeight() - 12
	if areaH > 40 then
		local x, y, w, h = themePreview.fitRect(40, listBottom, state.screenWidth - 80, areaH)
		themePreview.draw(x, y, w, h)
	end
	controlHintsInstance:setControlsList({
		{ button = "d_pad", text = "Toggle" },
		{ button = "b", text = "Back" },
	})
	controlHintsInstance:draw()
end

function bars.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, nil)
		menuList:update(dt)
		-- read every toggle back from its button (see home_screen_layout.lua)
		for _, button in ipairs(menuList.items) do
			if button.context and button.getCurrentOption then
				state[button.context] = (button:getCurrentOption() == "Shown")
			end
		end
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function bars.onEnter()
	local items = createButtons()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight,
		items = items,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})
	fitList(menuList)
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function bars.onExit() end

return bars
