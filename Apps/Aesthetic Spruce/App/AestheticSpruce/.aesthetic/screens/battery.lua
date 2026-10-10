--- Battery screen: charging and low colours, with a live preview
local love = require("love")

local colors = require("colors")
local controlHints = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local List = require("ui.components.list").List
local colorUtils = require("utils.color")
local svg = require("utils.svg")

local battery = {}

local menuList = nil
local headerInstance = Header:new({ title = "Battery" })
local controlHintsInstance


-- Shrink a list to exactly the height its items need (List computes this from its own metrics)
local function fitList(list)
	list.height = list:getContentHeight()
	return list
end

local ICON_SET = "assets/icons/material_symbols/"
local ICON_ACTIVE = "battery_android_5_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24"
local ICON_LOW = "battery_android_1_24dp_E3E3E3_FILL0_wght400_GRAD0_opsz24"

local function createItems()
	local function colorButton(text, contextKey)
		return Button:new({
			text = text,
			type = ButtonTypes.COLOR,
			hexColor = state.getColorValue(contextKey),
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				state.activeColorContext = contextKey
				state.previousScreen = "battery"
				screens.switchTo("color_picker")
			end,
		})
	end
	return { colorButton("Charging Color", "batteryActive"), colorButton("Low Color", "batteryLow") }
end

function battery.draw()
	background.draw()
	headerInstance:draw()
	love.graphics.setFont(fonts.loaded.body)
	if menuList then
		menuList:draw()
	end

	-- preview: the two icons on the theme background
	local previewY = (menuList and (menuList.y + menuList.height) or headerInstance:getContentStartY()) + 12
	local previewHeight = 100
	local previewWidth = state.screenWidth - 80
	local previewX = 40
	love.graphics.setColor(colorUtils.hexToLove(state.getColorValue("background")))
	love.graphics.rectangle("fill", previewX, previewY, previewWidth, previewHeight, 8, 8)
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", previewX, previewY, previewWidth, previewHeight, 8, 8)

	local iconSize = 48
	local iconSpacing = 36
	local centerX = previewX + previewWidth / 2
	local centerY = previewY + previewHeight / 2
	local activeIcon = svg.loadIcon(ICON_ACTIVE, iconSize, ICON_SET)
	local lowIcon = svg.loadIcon(ICON_LOW, iconSize, ICON_SET)
	if activeIcon then
		svg.drawIcon(activeIcon, centerX - iconSpacing, centerY, colorUtils.hexToLove(state.getColorValue("batteryActive")))
	end
	if lowIcon then
		svg.drawIcon(lowIcon, centerX + iconSpacing, centerY, colorUtils.hexToLove(state.getColorValue("batteryLow")))
	end

	controlHintsInstance:setControlsList({
		{ button = "b", text = "Back" },
		{ button = "a", text = "Select" },
	})
	controlHintsInstance:draw()
end

function battery.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, nil)
		menuList:update(dt)
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function battery.onEnter()
	local items = createItems()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight,
		items = items,
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
	})
	fitList(menuList)
	if not controlHintsInstance then
		controlHintsInstance = controlHints:new({})
	end
end

return battery
