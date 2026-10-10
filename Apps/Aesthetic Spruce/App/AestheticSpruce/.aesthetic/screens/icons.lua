--- Icons screen: whether the theme ships system icons (icons/) or stays text-only
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

local icons = {}

local menuList = nil
local headerInstance = Header:new({ title = "Icons" })
local controlHintsInstance

-- Shrink a list to exactly the height its items need (List computes this from its own metrics)
local function fitList(list)
	list.height = list:getContentHeight()
	return list
end

local ICON_STYLES = { "Glyph", "Letter", "SPRUCE Art", "SPRUCE Mono" }

local function iconStyleIndex()
	for i, style in ipairs(ICON_STYLES) do
		if style == state.systemIconStyle then
			return i
		end
	end
	return 1
end

local function createButtons()
	return {
		Button:new({
			text = "System Icons",
			type = ButtonTypes.INDICATORS,
			options = { "Disabled", "Enabled" },
			currentOptionIndex = state.systemIcons and 2 or 1,
			screenWidth = state.screenWidth,
			context = "systemIcons",
		}),
		Button:new({
			text = "Icon Style",
			type = ButtonTypes.INDICATORS,
			options = ICON_STYLES,
			currentOptionIndex = iconStyleIndex(),
			screenWidth = state.screenWidth,
			context = "systemIconStyle",
		}),
	}
end

local function handleOptionCycle(button, direction)
	if button.context ~= "systemIcons" or not button:cycleOption(direction) then
		return false
	end
	state.systemIcons = (button:getCurrentOption() == "Enabled")
	return true
end

function icons.draw()
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
		themePreview.draw(x, y, w, h, { icons = state.systemIcons })
	end
	controlHintsInstance:setControlsList({
		{ button = "d_pad", text = "Change" },
		{ button = "b", text = "Back" },
	})
	controlHintsInstance:draw()
end

function icons.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, nil)
		menuList:update(dt)
		-- read the options back from the buttons (see home_screen_layout.lua)
		for _, button in ipairs(menuList.items) do
			if button.context == "systemIcons" then
				state.systemIcons = (button:getCurrentOption() == "Enabled")
			elseif button.context == "systemIconStyle" then
				state.systemIconStyle = button:getCurrentOption()
			end
		end
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function icons.onExit() end

function icons.onEnter()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight,
		items = createButtons(),
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})
	fitList(menuList)
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

return icons
