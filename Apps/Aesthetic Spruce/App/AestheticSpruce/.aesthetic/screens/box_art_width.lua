--- Box art settings screen
local love = require("love")

local colors = require("colors")
local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")
local tween = require("tween")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local List = require("ui.components.list").List
local InputManager = require("ui.controllers.input_manager")

-- Module table to export public functions
local box_art_width = {}

-- Screen switching
local MENU_SCREEN = "main_menu"

-- Box art width options will be generated dynamically in load()
local BOX_ART_WIDTH_OPTIONS = { 0 }

local WARNING_TEXT_FONT = fonts.loaded.caption

-- Display constants
local EDGE_PADDING = 10
-- Horizontal padding of the preview area
local RECTANGLE_SPACING = 20
local CORNER_RADIUS = 12

-- Animation variables
local animatedLeftWidth = 0
local animatedRightWidth = 0
local currentTween = nil
local ANIMATION_DURATION = 0.25
local tweenObj = { leftWidth = 0, rightWidth = 0 }

-- List handling variables
local menuList = nil

-- Create Header instance
local headerInstance = Header:new({ title = "Box Art Width" })

-- Control hints instance
local controlHintsInstance

-- Function to get display text for a box art width value
local function getDisplayText(width)
	if width == 0 then
		return "Disabled"
	else
		return tostring(width)
	end
end

-- Generate width options from 220 to half screen width in steps of 20
local function generateWidthOptions()
	-- Clear existing numeric options but keep 0
	while #BOX_ART_WIDTH_OPTIONS > 1 do
		table.remove(BOX_ART_WIDTH_OPTIONS)
	end

	-- Calculate half of screen width and round to nearest multiple of 20
	local halfWidth = state.screenWidth / 2
	local roundedHalfWidth = math.floor(halfWidth / 20) * 20

	-- Collect numeric options in a temporary table
	local numericOptions = {}
	for width = 220, roundedHalfWidth, 20 do
		table.insert(numericOptions, width)
	end

	-- Reverse the numeric options
	for i = #numericOptions, 1, -1 do
		table.insert(BOX_ART_WIDTH_OPTIONS, numericOptions[i])
	end
end

local function createMenuButtons()
	return {
		Button:new({
			text = "Box art width",
			type = ButtonTypes.INDICATORS,
			options = BOX_ART_WIDTH_OPTIONS,
			currentOptionIndex = (function()
				for i, option in ipairs(BOX_ART_WIDTH_OPTIONS) do
					if option == state.boxArtWidth then
						return i
					end
				end
				return 1
			end)(),
			screenWidth = state.screenWidth,
			displayText = getDisplayText,
			context = "boxArtWidth",
		}),
	}
end

local function handleOptionCycle(button, direction)
	if button.context == "boxArtWidth" then
		local changed = button:cycleOption(direction)
		if changed then
			state.boxArtWidth = button:getCurrentOption()
			local boxArtWidth = state.boxArtWidth
			local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
			local targetLeftWidth = previewWidth - boxArtWidth - (boxArtWidth > 0 and RECTANGLE_SPACING or 0)
			local targetRightWidth = boxArtWidth > 0 and boxArtWidth or 0
			local target = { leftWidth = targetLeftWidth, rightWidth = targetRightWidth }
			currentTween = tween.new(ANIMATION_DURATION, tweenObj, target, "inOutQuad")
		end
		return changed
	end
	return false
end

function box_art_width.draw()
	background.draw()
	headerInstance:draw()

	-- Draw information text below header
	local infoText =
		'Width of the box art shown next to the game list (PyUI listGameSelectImgWidth). Disabled keeps the PyUI default.'
	love.graphics.setFont(WARNING_TEXT_FONT)
	love.graphics.setColor(colors.ui.subtext)
	local infoY = headerInstance:getContentStartY() + 2
	local infoWidth = state.screenWidth - EDGE_PADDING * 2
	love.graphics.printf(infoText, EDGE_PADDING, infoY, infoWidth, "left")
	love.graphics.setFont(fonts.loaded.body)
	love.graphics.setColor(colors.ui.foreground)

	-- Calculate dynamic height for info text (measured with the font it was drawn in)
	local _, wrappedLines = WARNING_TEXT_FONT:getWrap(infoText, infoWidth)
	local infoHeight = #wrappedLines * WARNING_TEXT_FONT:getHeight()
	if menuList then
		menuList.y = headerInstance:getContentStartY() + infoHeight
		menuList:draw()
	end

	-- Calculate the bottom Y of the last button in the menuList
	local previewY = headerInstance:getContentStartY() + infoHeight + 40
	if menuList then
		local listBottom = menuList.y + menuList:getContentHeight()
		previewY = listBottom + 40
	end

	local outlineWidth = 1
	local leftColor = colors.ui.blue
	local rightColor = colors.ui.violet
	local outlineColorAdjustment = 0.1

	local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
	local currentValue = state.boxArtWidth
	local previewHeight = 100
	local boxArtWidth = currentValue
	love.graphics.setColor(leftColor)
	love.graphics.rectangle(
		"fill",
		EDGE_PADDING,
		previewY,
		animatedLeftWidth,
		previewHeight,
		CORNER_RADIUS,
		CORNER_RADIUS
	)
	-- Draw outline for left rectangle
	local outlineColor = colors.adjustColor(leftColor, outlineColorAdjustment)
	love.graphics.setColor(outlineColor)
	love.graphics.setLineWidth(outlineWidth)
	love.graphics.rectangle(
		"line",
		EDGE_PADDING,
		previewY,
		animatedLeftWidth,
		previewHeight,
		CORNER_RADIUS,
		CORNER_RADIUS
	)
	if animatedRightWidth > 0 then
		love.graphics.setColor(rightColor)
		love.graphics.rectangle(
			"fill",
			EDGE_PADDING + animatedLeftWidth + RECTANGLE_SPACING,
			previewY,
			animatedRightWidth,
			previewHeight,
			CORNER_RADIUS,
			CORNER_RADIUS
		)
		-- Draw outline for right rectangle
		outlineColor = colors.adjustColor(rightColor, outlineColorAdjustment)
		love.graphics.setColor(outlineColor)
		love.graphics.setLineWidth(outlineWidth)
		love.graphics.rectangle(
			"line",
			EDGE_PADDING + animatedLeftWidth + RECTANGLE_SPACING,
			previewY,
			animatedRightWidth,
			previewHeight,
			CORNER_RADIUS,
			CORNER_RADIUS
		)
	end
	if boxArtWidth > 0 then
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.printf(
			"Text",
			EDGE_PADDING,
			previewY + previewHeight / 2 - WARNING_TEXT_FONT:getHeight() / 2,
			animatedLeftWidth,
			"center"
		)
		if boxArtWidth >= 70 then
			love.graphics.setColor(colors.ui.foreground)
			love.graphics.printf(
				"Box art",
				EDGE_PADDING + animatedLeftWidth + RECTANGLE_SPACING,
				previewY + previewHeight / 2 - WARNING_TEXT_FONT:getHeight() / 2,
				animatedRightWidth,
				"center"
			)
		end
	else
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.printf(
			"Text",
			EDGE_PADDING,
			previewY + previewHeight / 2 - WARNING_TEXT_FONT:getHeight() / 2,
			previewWidth,
			"center"
		)
	end

	-- Draw controls
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function box_art_width.update(dt)
	if currentTween then
		local completed = currentTween:update(dt)
		if completed then
			currentTween = nil
		end
		animatedLeftWidth = tweenObj.leftWidth
		animatedRightWidth = tweenObj.rightWidth
	end

	if menuList then
		menuList:handleInput(InputManager.getNavigationDirection(), nil)
		menuList:update(dt)
		local boxArtButton = menuList.items[1]
		if boxArtButton and boxArtButton.getCurrentOption then
			local newValue = boxArtButton:getCurrentOption()
			if state.boxArtWidth ~= newValue then
				local boxArtWidth = newValue
				local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
				local targetLeftWidth = previewWidth - boxArtWidth - (boxArtWidth > 0 and RECTANGLE_SPACING or 0)
				local targetRightWidth = boxArtWidth > 0 and boxArtWidth or 0
				local target = { leftWidth = targetLeftWidth, rightWidth = targetRightWidth }
				currentTween = tween.new(ANIMATION_DURATION, tweenObj, target, "inOutQuad")
				state.boxArtWidth = newValue
			end
		end
	end
	-- Handle B button to return to main menu
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo(MENU_SCREEN)
		return
	end
end

function box_art_width.onEnter()
	generateWidthOptions()

	-- Create menu list
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 60,
		items = createMenuButtons(),
		onItemSelect = function(_item)
			-- No-op for this screen
		end,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})

	-- Initialize animation state
	local boxArtWidth = state.boxArtWidth
	local previewWidth = state.screenWidth - (EDGE_PADDING * 2)
	tweenObj.leftWidth = previewWidth - boxArtWidth - (boxArtWidth > 0 and RECTANGLE_SPACING or 0)
	tweenObj.rightWidth = boxArtWidth > 0 and boxArtWidth or 0
	animatedLeftWidth = tweenObj.leftWidth
	animatedRightWidth = tweenObj.rightWidth

	-- Initialize control hints instance if needed
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function box_art_width.onExit() end

return box_art_width
