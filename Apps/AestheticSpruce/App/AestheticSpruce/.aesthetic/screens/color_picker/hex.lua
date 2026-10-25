--- Hex color picker screen
local love = require("love")

local colors = require("colors")
local controls = require("control_hints").ControlHints
local screens = require("screens")
local shared = require("screens.color_picker.shared")

local state = require("state")

local background = require("ui.background")
local fonts = require("ui.fonts")

local colorUtils = require("utils.color")
local svg = require("utils.svg")
local tween = require("tween")
local InputManager = require("ui.controllers.input_manager")
local Button = require("ui.components.button").Button
local BUTTON_TYPES = require("ui.components.button").TYPES
local Header = require("ui.components.header")
local TabBar = require("ui.components.tab_bar")

local hex = {}

local TOP_PADDING = 10
local PREVIEW_HEIGHT = 80
local GRID_PADDING = 10
local KEYBOARD_TOP_PADDING = 16 -- Padding between preview and keyboard
local KEYBOARD_BOTTOM_PADDING = 16 -- Padding between keyboard and control hints
local BUTTON_CORNER_RADIUS = 8
local INPUT_RECT_WIDTH = 30
local INPUT_RECT_HEIGHT = 40
local INPUT_RECT_SPACING = 5
local ICON_SIZE = 24
local ANIMATION_SCALE = 0.1
local ANIMATION_DURATION = 0.4 -- Duration for each phase (expand/contract) in seconds
-- State
local hexState = {
	maxInputLength = 6,
	confirmButtonTween = nil,
	confirmButtonScale = 1,
	confirmButtonFlash = 0,
	lastValidInput = "",
	animationPhase = "idle", -- "expanding", "contracting", "idle"
}

local controlHintsInstance

-- Helper function to get current hex state from central state manager
local function getCurrentHexState()
	local colorType = state.activeColorContext
	local context = state.getColorContext(colorType)
	return context.hex -- Return the hex specific state for this color context
end

-- Button grid layout (3x6)
local buttonLabels = {
	{ "0", "1", "2", "3", "4", "5" },
	{ "6", "7", "8", "9", "A", "B" },
	{ "C", "D", "E", "F", "BACKSPACE", "CONFIRM" },
}

-- Button objects grid
local buttonGrid = {}

-- One Header used only to measure the content start (drawn nowhere)
local measureHeader = Header:new({ title = "" })

-- Helper to get manual content area for the color picker screen
local function getManualContentArea()
	local screenWidth = state.screenWidth
	local screenHeight = state.screenHeight

	local headerContentStartY = measureHeader:getContentStartY()
	local tabBarHeight = TabBar.getHeight()
	local controlsHeight = controls.calculateHeight(fonts.loaded.caption)
	local contentTopPadding = 8

	local y = headerContentStartY + tabBarHeight + contentTopPadding
	local height = screenHeight - (headerContentStartY + tabBarHeight) - controlsHeight - TOP_PADDING

	return {
		x = 0,
		y = y,
		width = screenWidth,
		height = height,
	}
end

local function getButtonDimensions()
	local contentArea = getManualContentArea()

	-- Calculate available width and height for the grid
	local gridAvailableWidth = contentArea.width - (2 * shared.PADDING)
	-- Subtract extra padding from available height
	local gridAvailableHeight = contentArea.height
		- TOP_PADDING
		- PREVIEW_HEIGHT
		- KEYBOARD_TOP_PADDING
		- KEYBOARD_BOTTOM_PADDING

	local numRows = #buttonLabels
	local numCols = #buttonLabels[1]

	-- Calculate max height and width for each button
	local maxButtonHeight = (gridAvailableHeight - ((numRows - 1) * GRID_PADDING)) / numRows
	local maxButtonWidth = (gridAvailableWidth - ((numCols - 1) * GRID_PADDING)) / numCols

	local buttonSize = math.min(maxButtonHeight, maxButtonWidth)
	return buttonSize, buttonSize
end

local function createButton(row, col, label)
	local isConfirm = label == "CONFIRM"
	local isBackspace = label == "BACKSPACE"
	local iconName = isBackspace and "delete" or (isConfirm and "check" or nil)
	local accent = isConfirm
	local buttonWidth, buttonHeight = getButtonDimensions()
	return Button:new({
		text = (not iconName) and label or nil,
		type = BUTTON_TYPES.KEY,
		iconName = iconName,
		iconSize = ICON_SIZE,
		accent = accent,
		width = buttonWidth,
		height = buttonHeight,
	})
end

-- Initialize buttonGrid
for row = 1, #buttonLabels do
	buttonGrid[row] = {}
	for col = 1, #buttonLabels[row] do
		buttonGrid[row][col] = createButton(row, col, buttonLabels[row][col])
	end
end

-- Helper function to check if hex input is valid
local function isValidHex(input)
	if #input ~= 6 then
		return false
	end

	for i = 1, 6 do
		local char = input:sub(i, i):upper()
		if not (char:match("[0-9]") or (char >= "A" and char <= "F")) then
			return false
		end
	end

	return true
end

local function getGridStartPosition()
	local contentArea = getManualContentArea()
	local buttonWidth, buttonHeight = getButtonDimensions()

	local numRows = #buttonLabels
	local numCols = #buttonLabels[1]

	local totalGridWidth = (buttonWidth * numCols) + (GRID_PADDING * (numCols - 1))
	local totalGridHeight = (buttonHeight * numRows) + (GRID_PADDING * (numRows - 1))

	local availableWidth = contentArea.width
	local availableHeight = contentArea.height
		- TOP_PADDING
		- PREVIEW_HEIGHT
		- KEYBOARD_TOP_PADDING
		- KEYBOARD_BOTTOM_PADDING

	local startX = (availableWidth - totalGridWidth) / 2
	local startY = contentArea.y
		+ TOP_PADDING
		+ PREVIEW_HEIGHT
		+ KEYBOARD_TOP_PADDING
		+ (availableHeight - totalGridHeight) / 2

	return startX, startY
end

-- Helper function to get button position
local function getButtonPosition(row, col)
	local buttonWidth, buttonHeight = getButtonDimensions()
	local startX, startY = getGridStartPosition()

	local x = startX + (col - 1) * (buttonWidth + GRID_PADDING)
	local y = startY + (row - 1) * (buttonHeight + GRID_PADDING)

	return x, y, buttonWidth, buttonHeight
end

-- Helper function to start confirm button wobble animation
local function startConfirmButtonWobble()
	if hexState.confirmButtonTween then
		return -- Animation already running
	end

	-- Reset animation values
	hexState.confirmButtonScale = 1
	hexState.confirmButtonFlash = 0
	hexState.animationPhase = "expanding"

	-- Create expand phase: animate from 1 to 1 + ANIMATION_SCALE
	hexState.confirmButtonTween = tween.new(ANIMATION_DURATION, hexState, {
		confirmButtonScale = 1 + ANIMATION_SCALE,
		confirmButtonFlash = 1,
	}, tween.easing.outQuad)
end

function hex.draw()
	background.draw()

	love.graphics.push("all")

	local contentArea = getManualContentArea()

	-- Get current color type state
	local currentState = getCurrentHexState()

	-- Draw color preview rectangle
	local previewX = shared.PADDING
	local previewY = contentArea.y + TOP_PADDING
	local previewWidth = contentArea.width - (2 * shared.PADDING)

	-- Variables for input display
	local inputStartX = previewX + (previewWidth - ((INPUT_RECT_WIDTH * 6) + (INPUT_RECT_SPACING * 5))) / 2
	local inputY = previewY + (PREVIEW_HEIGHT - INPUT_RECT_HEIGHT) / 2
	local textColor = colors.ui.foreground -- Default text color

	-- Fill with color if input is valid
	if isValidHex(currentState.input) then
		local r, g, b = colorUtils.hexToRgb(currentState.input)
		love.graphics.setColor(r, g, b)
		love.graphics.rectangle("fill", previewX, previewY, previewWidth, PREVIEW_HEIGHT, 8, 8)

		-- Calculate contrasting color for text
		local contrastR, contrastG, contrastB = colorUtils.calculateContrastingColor(r, g, b)
		textColor = { contrastR, contrastG, contrastB }

		-- Draw preview rectangle outline with text color (matches text color)
		love.graphics.setColor(textColor)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", previewX, previewY, previewWidth, PREVIEW_HEIGHT, 8, 8)
	end

	-- Get fonts
	local monoHeaderFont = fonts.loaded.monoHeader
	local bodyFont = fonts.loaded.body

	-- Draw # symbol
	love.graphics.setColor(textColor)
	if monoHeaderFont then
		love.graphics.setFont(monoHeaderFont)
		local hashWidth = monoHeaderFont:getWidth("#")
		love.graphics.print(
			"#",
			inputStartX - hashWidth - 10,
			inputY + (INPUT_RECT_HEIGHT - monoHeaderFont:getHeight()) / 2
		)

		-- Draw input characters or underscores for empty positions
		for i = 1, 6 do
			local rectX = inputStartX + (i - 1) * (INPUT_RECT_WIDTH + INPUT_RECT_SPACING)
			local charY = inputY + (INPUT_RECT_HEIGHT - monoHeaderFont:getHeight()) / 2

			-- Draw character if entered, otherwise draw underscore
			local char = (i <= #currentState.input) and currentState.input:sub(i, i):upper() or "_"
			local charWidth = monoHeaderFont:getWidth(char)
			local charX = rectX + (INPUT_RECT_WIDTH - charWidth) / 2

			love.graphics.setColor(textColor)
			love.graphics.print(char, charX, charY)
		end
	end

	-- Draw button grid using Button components
	for row = 1, #buttonGrid do
		for col = 1, #buttonGrid[row] do
			local btn = buttonGrid[row][col]
			local x, y, width, height = getButtonPosition(row, col)
			btn.x = x
			btn.y = y
			btn.width = width
			btn.height = height
			btn:draw()
		end
	end

	love.graphics.pop()

	-- Draw controls
	local controlsList = {
		{ button = "x", text = "Clear" },
		{ button = "a", text = "Select" },
		{ button = { "leftshoulder", "rightshoulder" }, text = "Switch Tabs" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)

	controlHintsInstance:draw()
end

function hex.update(dt)
	-- Get current color type state
	local currentState = getCurrentHexState()

	for row = 1, #buttonGrid do
		for col = 1, #buttonGrid[row] do
			local btn = buttonGrid[row][col]
			local label = buttonLabels[row][col]
			btn.focused = (currentState.selectedButton.row == row and currentState.selectedButton.col == col)
			if label == "CONFIRM" then
				btn.disabled = not isValidHex(currentState.input)
			end
		end
	end

	-- Update confirm button animation
	if hexState.confirmButtonTween then
		local isComplete = hexState.confirmButtonTween:update(dt)
		if isComplete then
			if hexState.animationPhase == "expanding" then
				-- Start contracting phase
				hexState.animationPhase = "contracting"
				hexState.confirmButtonTween = tween.new(ANIMATION_DURATION, hexState, {
					confirmButtonScale = 1,
					confirmButtonFlash = 0,
				}, tween.easing.inQuad)
			else
				-- Animation fully complete
				hexState.confirmButtonTween = nil
				hexState.confirmButtonScale = 1
				hexState.confirmButtonFlash = 0
				hexState.animationPhase = "idle"
			end
		end
	end

	-- Start wobble animation only once when hex becomes valid
	if isValidHex(currentState.input) then
		-- Only trigger animation if this is a new valid input
		if currentState.input ~= hexState.lastValidInput and not hexState.confirmButtonTween then
			startConfirmButtonWobble()
			hexState.lastValidInput = currentState.input
		end
	else
		-- Reset animation and tracking if input becomes invalid
		if hexState.confirmButtonTween then
			hexState.confirmButtonTween = nil
			hexState.confirmButtonScale = 1
			hexState.confirmButtonFlash = 0
			hexState.animationPhase = "idle"
		end
		hexState.lastValidInput = ""
	end

	-- Handle D-pad navigation
	if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_UP) then
		currentState.selectedButton.row = math.max(1, currentState.selectedButton.row - 1)
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_DOWN) then
		currentState.selectedButton.row = math.min(#buttonGrid, currentState.selectedButton.row + 1)
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_LEFT) then
		currentState.selectedButton.col = currentState.selectedButton.col - 1
		if currentState.selectedButton.col < 1 then
			currentState.selectedButton.col = #buttonGrid[currentState.selectedButton.row]
		end
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_RIGHT) then
		currentState.selectedButton.col = currentState.selectedButton.col + 1
		if currentState.selectedButton.col > #buttonGrid[currentState.selectedButton.row] then
			currentState.selectedButton.col = 1
		end
	end

	-- Handle Y button for clear
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CLEAR) then
		-- Clear all input
		currentState.input = ""
	end

	-- Handle button press (A button)
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CONFIRM) then
		local btn = buttonGrid[currentState.selectedButton.row][currentState.selectedButton.col]
		local label = buttonLabels[currentState.selectedButton.row][currentState.selectedButton.col]

		if btn.disabled then
			return
		end

		if label == "BACKSPACE" then
			-- Backspace - remove last character
			if #currentState.input > 0 then
				currentState.input = currentState.input:sub(1, -2)
			end
		elseif label == "CONFIRM" then
			if not isValidHex(currentState.input) then
				return
			end
			-- Confirm - only if input is valid
			local hexCode = "#" .. currentState.input:upper()

			-- Store in central state
			local context = state.getColorContext(state.activeColorContext)
			context.currentColor = hexCode

			-- Return to menu and apply the color
			screens.switchTo(state.previousScreen)
			state.setColorValue(state.activeColorContext, hexCode)
		else
			-- Add character if not at max length
			if #currentState.input < hexState.maxInputLength then
				currentState.input = currentState.input .. label
			end
		end
	end
end

-- Function to be called when entering this screen
function hex.onEnter()
	-- Preload icons if not already done
	if not svg.isIconLoaded("delete") or not svg.isIconLoaded("check") then
		svg.preloadIcons({ "delete", "check" }, ICON_SIZE)
	end

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

return hex
