--- Background color/gradient screen with Solid/Gradient options
local love = require("love")

local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")
local colors = require("colors")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local fonts = require("ui.fonts")
local GradientPreview = require("ui.components.gradient_preview")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local List = require("ui.components.list").List
local colorUtils = require("utils.color")

local backgroundColor = {}

local menuList = nil
local input = nil
local headerInstance = Header:new({ title = "Background" })
local controlHintsInstance

-- Global button instances
local typeButton, colorButton, colorStartButton, colorStopButton, directionButton

-- Gradient preview instance
local gradientPreviewInstance = GradientPreview:new({})

-- Store the current list position when exiting
local lastFocusState = { selectedIndex = 1 }

-- Function to update gradient preview mesh
local function updateGradientPreview()
	if state.backgroundType == "Gradient" then
		local bgColor = state.getColorValue("background")
		local gradientColor = state.getColorValue("backgroundGradient")
		local direction = state.backgroundGradientDirection or "Vertical"
		gradientPreviewInstance:updateMesh(bgColor, gradientColor, direction)
	end
end

-- Function to build buttons list
local function createButtons()
	typeButton = Button:new({
		text = "Type",
		type = ButtonTypes.INDICATORS,
		options = { "Solid", "Gradient" },
		currentOptionIndex = (state.backgroundType == "Gradient" and 2) or 1,
		screenWidth = state.screenWidth,
		context = "typeToggle",
	})
	colorButton = Button:new({
		text = "Color",
		type = ButtonTypes.COLOR,
		hexColor = state.getColorValue("background"),
		monoFont = fonts.loaded.monoBody,
		screenWidth = state.screenWidth,
		onClick = function()
			state.activeColorContext = "background"
			screens.switchTo("color_picker")
		end,
	})
	colorStartButton = Button:new({
		text = "Start Color",
		type = ButtonTypes.COLOR,
		hexColor = state.getColorValue("background"),
		monoFont = fonts.loaded.monoBody,
		screenWidth = state.screenWidth,
		onClick = function()
			state.activeColorContext = "background"
			state.previousScreen = "background"
			screens.switchTo("color_picker")
		end,
	})
	colorStopButton = Button:new({
		text = "End Color",
		type = ButtonTypes.COLOR,
		hexColor = state.getColorValue("backgroundGradient"),
		monoFont = fonts.loaded.monoBody,
		screenWidth = state.screenWidth,
		onClick = function()
			state.activeColorContext = "backgroundGradient"
			state.previousScreen = "background"
			screens.switchTo("color_picker")
		end,
	})
	directionButton = Button:new({
		text = "Direction",
		type = ButtonTypes.INDICATORS,
		options = { "Vertical", "Horizontal" },
		currentOptionIndex = (state.backgroundGradientDirection == "Horizontal" and 2) or 1,
		screenWidth = state.screenWidth,
		context = "directionToggle",
	})
end

local function getMenuItems()
	local items = { typeButton }
	if state.backgroundType == "Gradient" then
		table.insert(items, colorStartButton)
		table.insert(items, colorStopButton)
		table.insert(items, directionButton)
	else
		table.insert(items, colorButton)
	end
	return items
end

function backgroundColor.draw()
	-- Draw the background first
	background.draw()

	-- Draw header
	headerInstance:draw()

	love.graphics.setFont(fonts.loaded.body)

	if menuList then
		menuList:draw()
	end

	-- --- PREVIEW SIZING LOGIC ---
	local originalType = state.backgroundType
	local previewHeight, previewWidth, previewX, previewY
	local controlsHeight = controls.calculateHeight()
	local margin = 10
	local previewX_margin = 20
	local listBottom

	if originalType == "Solid" then
		-- Simulate a menu list as if in Gradient mode
		local gradientMenuItems = { typeButton, colorStartButton, colorStopButton, directionButton }
		local tempMenuList = List:new({
			x = 0,
			y = headerInstance:getContentStartY(),
			width = state.screenWidth,
			height = state.screenHeight - headerInstance:getContentStartY() - 60,
			items = gradientMenuItems,
		})
		listBottom = tempMenuList.y + tempMenuList:getContentHeight()
	else
		listBottom = menuList and (menuList.y + menuList:getContentHeight()) or 0
	end

	previewY = listBottom + margin
	local previewAreaHeight = state.screenHeight - previewY - controlsHeight - margin
	local previewAreaWidth = state.screenWidth - previewX_margin * 2
	previewHeight = previewAreaHeight
	previewWidth = previewHeight * 4 / 3
	if previewWidth > previewAreaWidth then
		previewWidth = previewAreaWidth
		previewHeight = previewWidth * 3 / 4
	end
	previewX = (state.screenWidth - previewWidth) / 2
	-- --- END PREVIEW SIZING LOGIC ---

	if originalType == "Gradient" then
		if previewHeight >= 40 then
			gradientPreviewInstance:draw(
				previewX,
				previewY,
				previewWidth,
				previewHeight,
				state.getColorValue("background"),
				state.getColorValue("backgroundGradient"),
				state.backgroundGradientDirection,
				8
			)
		end
	elseif originalType == "Solid" then
		if previewHeight >= 40 then
			local cornerRadius = 8
			love.graphics.setColor(colorUtils.hexToLove(state.getColorValue("background")))
			love.graphics.rectangle("fill", previewX, previewY, previewWidth, previewHeight, cornerRadius, cornerRadius)
			-- Draw outline to match GradientPreview
			love.graphics.setColor(colors.ui.foreground)
			love.graphics.setLineWidth(1)
			love.graphics.rectangle("line", previewX, previewY, previewWidth, previewHeight, cornerRadius, cornerRadius)
			love.graphics.setColor(1, 1, 1, 1)
		end
	end

	-- Draw controls
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Save" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function backgroundColor.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, input)
		menuList:update(dt)
		-- Sync state from button values
		if typeButton and typeButton.getCurrentOption then
			state.backgroundType = typeButton:getCurrentOption()
		end
		if directionButton and directionButton.getCurrentOption then
			state.backgroundGradientDirection = directionButton:getCurrentOption()
		end
		-- Rebuild menu items if needed
		menuList:setItems(getMenuItems())
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
		return
	end
end

function backgroundColor.onEnter()
	createButtons()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 60,
		items = getMenuItems(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
	})
	-- Restore last selected index
	local validIndex = math.min(math.max(lastFocusState.selectedIndex or 1, 1), #menuList.items)
	menuList:setSelectedIndex(validIndex)
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function backgroundColor.onExit()
	if menuList then
		lastFocusState.selectedIndex = menuList.selectedIndex or 1
	end
end

return backgroundColor
