local love = require("love")
local state = require("state")
local colors = require("colors")
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local controls = require("control_hints").ControlHints
local background = require("ui.background")
local screens = require("screens")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local InputManager = require("ui.controllers.input_manager")

-- Virtual keyboard screen module
-- Its layout follows the original app's virtual keyboard
local virtual_keyboard = {}

local headerInstance = Header:new({ title = "Input" })
local controlHintsInstance

--[[
Navigation behavior:
- D-pad up/down/left/right navigates the keyboard grid
- When moving down from Row 4 to Row 5:
  * z/x keys → ABC key (layer switch)
  * c/v/b/n/m keys → SPACE key
  * ./,/ keys → OK key
- When moving up from Row 5 to Row 4, the keyboard returns to the last key position that was selected in Row 4
- If there's no remembered position, fallback mappings are used
]]

-- Screen state
local inputValue = ""
local headerTitle = "Input"
local selectedX = 1
local selectedY = 1
local returnScreen = nil
local lastRow4X = nil -- Track the last X position in Row 4
local currentLayer = 1 -- Track current keyboard layer (1, 2, or 3)

-- Key dimensions and layout
local keySpacing = 10
local inputFieldHeight = 50
local inputFieldPadding = 10
local screenPadding = 10 -- Padding from screen edges

-- Cursor blink variables
local cursorVisible = true
local cursorBlinkTimer = 0
local CURSOR_BLINK_INTERVAL = 0.5 -- seconds

-- Keyboard layouts for different layers
local keyboardLayouts = {
	-- Layer 1: Lowercase
	{
		-- Row 1: Digits
		{
			{ label = "1", units = 1 },
			{ label = "2", units = 1 },
			{ label = "3", units = 1 },
			{ label = "4", units = 1 },
			{ label = "5", units = 1 },
			{ label = "6", units = 1 },
			{ label = "7", units = 1 },
			{ label = "8", units = 1 },
			{ label = "9", units = 1 },
			{ label = "0", units = 1 },
		},
		-- Row 2: QWERTY
		{
			{ label = "q", units = 1 },
			{ label = "w", units = 1 },
			{ label = "e", units = 1 },
			{ label = "r", units = 1 },
			{ label = "t", units = 1 },
			{ label = "y", units = 1 },
			{ label = "u", units = 1 },
			{ label = "i", units = 1 },
			{ label = "o", units = 1 },
			{ label = "p", units = 1 },
		},
		-- Row 3: ASDF
		{
			{ label = "a", units = 1 },
			{ label = "s", units = 1 },
			{ label = "d", units = 1 },
			{ label = "f", units = 1 },
			{ label = "g", units = 1 },
			{ label = "h", units = 1 },
			{ label = "j", units = 1 },
			{ label = "k", units = 1 },
			{ label = "l", units = 1 },
			{ label = "-", units = 1 },
		},
		-- Row 4: ZXCV
		{
			{ label = "z", units = 1 },
			{ label = "x", units = 1 },
			{ label = "c", units = 1 },
			{ label = "v", units = 1 },
			{ label = "b", units = 1 },
			{ label = "n", units = 1 },
			{ label = "m", units = 1 },
			{ label = "(", units = 1 },
			{ label = ")", units = 1 },
			{ label = "_", units = 1 },
		},
		-- Row 5: Special keys (ABC, SPACE, OK)
		{
			{ label = "ABC", units = 2 },
			{ label = "", units = 5 },
			{ label = "OK", units = 3 },
		},
	},
	-- Layer 2: Uppercase
	{
		-- Row 1: Digits
		{
			{ label = "1", units = 1 },
			{ label = "2", units = 1 },
			{ label = "3", units = 1 },
			{ label = "4", units = 1 },
			{ label = "5", units = 1 },
			{ label = "6", units = 1 },
			{ label = "7", units = 1 },
			{ label = "8", units = 1 },
			{ label = "9", units = 1 },
			{ label = "0", units = 1 },
		},
		-- Row 2: QWERTY uppercase
		{
			{ label = "Q", units = 1 },
			{ label = "W", units = 1 },
			{ label = "E", units = 1 },
			{ label = "R", units = 1 },
			{ label = "T", units = 1 },
			{ label = "Y", units = 1 },
			{ label = "U", units = 1 },
			{ label = "I", units = 1 },
			{ label = "O", units = 1 },
			{ label = "P", units = 1 },
		},
		-- Row 3: ASDF uppercase
		{
			{ label = "A", units = 1 },
			{ label = "S", units = 1 },
			{ label = "D", units = 1 },
			{ label = "F", units = 1 },
			{ label = "G", units = 1 },
			{ label = "H", units = 1 },
			{ label = "J", units = 1 },
			{ label = "K", units = 1 },
			{ label = "L", units = 1 },
			{ label = "-", units = 1 },
		},
		-- Row 4: ZXCV uppercase
		{
			{ label = "Z", units = 1 },
			{ label = "X", units = 1 },
			{ label = "C", units = 1 },
			{ label = "V", units = 1 },
			{ label = "B", units = 1 },
			{ label = "N", units = 1 },
			{ label = "M", units = 1 },
			{ label = "(", units = 1 },
			{ label = ")", units = 1 },
			{ label = "_", units = 1 },
		},
		-- Row 5: Special keys (abc, SPACE, OK)
		{
			{ label = "abc", units = 2 },
			{ label = "", units = 5 },
			{ label = "OK", units = 3 },
		},
	},
}

-- Variable to store the current keyboard layout
local keyboard = keyboardLayouts[1]

local keyButtons = nil -- 2D array of Button objects

local function buildKeyButtons()
	keyButtons = {}
	for y, row in ipairs(keyboard) do
		keyButtons[y] = {}
		for x, key in ipairs(row) do
			local button = Button:new({
				type = ButtonTypes.KEY,
				text = key.label,
				visible = true,
				enabled = true,
				fullWidth = false,
				monoFont = fonts.loaded.body, -- Use body font for key buttons
			})
			keyButtons[y][x] = button
		end
	end
end

-- Update positions and sizes for all key buttons (called in draw)
local function updateKeyButtonLayout(unitSize, keyboardX, keyboardY)
	for y, row in ipairs(keyboard) do
		local xOffset = 0
		for x, key in ipairs(row) do
			local keyUnits = key.units or 1
			local actualKeyWidth = unitSize * keyUnits + keySpacing * (keyUnits - 1)
			local posX = keyboardX + xOffset
			local posY = keyboardY + (y - 1) * (unitSize + keySpacing)
			local button = keyButtons[y][x]
			button.x = posX
			button.y = posY
			button.width = actualKeyWidth
			button.height = unitSize
			xOffset = xOffset + actualKeyWidth + keySpacing
		end
	end
end

-- Function to switch keyboard layer
local function switchKeyboardLayer()
	currentLayer = currentLayer % 2 + 1 -- Cycle through layers
	keyboard = keyboardLayouts[currentLayer]
	buildKeyButtons()
end

-- Handle screen entry
function virtual_keyboard.onEnter(params)
	params = params or {}
	headerInstance.title = params.title or "Input"

	-- Reset state
	inputValue = ""
	selectedX = 1
	selectedY = 1
	lastRow4X = nil -- Reset last Row 4 position
	currentLayer = 1 -- Reset to first layer
	keyboard = keyboardLayouts[currentLayer]

	-- Store parameters
	if params then
		headerTitle = params.title or "Input"
		returnScreen = params.returnScreen
		-- Set initial input value if provided
		if params.inputValue then
			inputValue = params.inputValue
		end
	end

	buildKeyButtons()

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

-- Handle screen exit
function virtual_keyboard.onExit()
	-- Clean up if needed
end

-- Handle key selection
local function handleKeySelection()
	local selectedKey = keyboard[selectedY][selectedX]
	local keyLabel = selectedKey.label

	if keyLabel == "OK" then
		-- Pass the necessary data: preventImmediateInput, inputValue, title, and returnScreen
		screens.switchTo(returnScreen, {
			preventImmediateInput = true,
			inputValue = inputValue,
			title = headerTitle,
			returnScreen = returnScreen,
		})
	elseif keyLabel == "" then
		-- Space key (empty text)
		inputValue = inputValue .. " "
	elseif keyLabel == "ABC" or keyLabel == "abc" then
		switchKeyboardLayer()
	elseif keyLabel ~= "" then
		inputValue = inputValue .. keyLabel
	end
end

-- Handle user input
function virtual_keyboard.update(dt)
	-- Cursor blinking logic
	cursorBlinkTimer = cursorBlinkTimer + (dt or 0)
	if cursorBlinkTimer >= CURSOR_BLINK_INTERVAL then
		cursorBlinkTimer = cursorBlinkTimer - CURSOR_BLINK_INTERVAL
		cursorVisible = not cursorVisible
	end

	-- D-pad navigation
	if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_UP) then
		if selectedY == 5 then
			-- Moving up from the bottom row (special keys)
			if lastRow4X and lastRow4X >= 1 and lastRow4X <= #keyboard[4] then
				-- Return to previously selected position in Row 4 if valid
				selectedY = 4
				selectedX = lastRow4X
			else
				-- Fallback to default mapping if no previous position
				if selectedX == 1 then -- ABC/layer switch key
					selectedY = 4
					selectedX = 1 -- Jump to "z"
				elseif selectedX == 2 then -- SPACE
					selectedY = 4
					selectedX = 5 -- Jump to "b" (center of c,v,b,n,m)
				elseif selectedX == 3 then -- OK
					selectedY = 4
					selectedX = 9 -- Jump to "," (center of .,/)
				end
			end
		else
			-- Regular up movement for other rows
			selectedY = math.max(1, selectedY - 1)
		end
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_DOWN) then
		if selectedY == 4 then
			-- Save current position in Row 4 before moving to Row 5
			lastRow4X = selectedX

			-- Moving down from the letter/number rows to special keys
			if selectedX <= 2 then -- "z" or "x"
				selectedY = 5
				selectedX = 1 -- ABC/layer switch key
			elseif selectedX >= 3 and selectedX <= 7 then -- "c", "v", "b", "n", "m"
				selectedY = 5
				selectedX = 2 -- SPACE
			elseif selectedX >= 8 then -- ".", ",", "/"
				selectedY = 5
				selectedX = 3 -- OK
			end
		else
			-- Regular down movement for other rows
			selectedY = math.min(#keyboard, selectedY + 1)
		end
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_LEFT) then
		selectedX = math.max(1, selectedX - 1)

		-- Reset lastRow4X when moving horizontally in Row 5
		if selectedY == 5 then
			lastRow4X = nil
		end
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_RIGHT) then
		local maxX = #keyboard[selectedY]
		selectedX = math.min(maxX, selectedX + 1)

		-- Reset lastRow4X when moving horizontally in Row 5
		if selectedY == 5 then
			lastRow4X = nil
		end
	end

	-- Ensure selectedX is valid for the current row
	if selectedX > #keyboard[selectedY] then
		selectedX = #keyboard[selectedY]
	end

	-- Button actions
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CONFIRM) then
		handleKeySelection()
	end

	-- B button - go back
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CANCEL) then
		if returnScreen then
			screens.switchTo(returnScreen)
		end
	end

	-- Y button - backspace
	if InputManager.isActionJustPressed(InputManager.ACTIONS.UNDO) then
		if #inputValue > 0 then
			inputValue = string.sub(inputValue, 1, -2)
		end
	end
end

-- Helper: Check that all rows have the same total units
local function checkKeyboardRowUnits(layout)
	local expectedUnits = nil
	for rowIdx, row in ipairs(layout) do
		local rowUnits = 0
		for _, key in ipairs(row) do
			rowUnits = rowUnits + (key.units or 1)
		end
		if not expectedUnits then
			expectedUnits = rowUnits
		elseif rowUnits ~= expectedUnits then
			print(
				"[virtual_keyboard] Error: Row "
					.. rowIdx
					.. " has "
					.. rowUnits
					.. " units, expected "
					.. expectedUnits
			)
			assert(false, "All keyboard rows must have the same total units")
		end
	end
	return expectedUnits
end

-- Draw the virtual keyboard
function virtual_keyboard.draw()
	background.draw()

	if not headerInstance then
		headerInstance = Header:new({ title = headerTitle })
	end
	headerInstance.title = headerTitle
	headerInstance:draw()

	-- Calculate input field position and size to match keyboard edge padding
	local inputFieldX = screenPadding
	local inputFieldWidth = state.screenWidth - (screenPadding * 2)
	local inputFieldY = headerInstance:getContentStartY() + 10

	love.graphics.push("all")

	-- Draw input field background and outline
	love.graphics.setColor(colors.ui.surface_focus)
	love.graphics.rectangle("fill", inputFieldX, inputFieldY, inputFieldWidth, inputFieldHeight, 5, 5)
	love.graphics.setColor(colors.ui.surface_focus_outline)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", inputFieldX, inputFieldY, inputFieldWidth, inputFieldHeight, 5, 5)

	-- Draw input text with blinking cursor
	love.graphics.setColor(colors.ui.foreground)
	local bodyFont = fonts.loaded.body
	love.graphics.setFont(bodyFont)
	local textX = inputFieldX + inputFieldPadding
	local textY = inputFieldY + (inputFieldHeight - bodyFont:getHeight()) / 2
	local textWidth = state.screenWidth - (screenPadding * 2) - (inputFieldPadding * 2)

	-- Calculate max number of characters that fit (minus one for cursor)
	local sampleChar = "W" -- Use a wide char for safety
	local charWidth = bodyFont:getWidth(sampleChar)
	local maxChars = math.floor(textWidth / charWidth)
	if maxChars > 0 then
		maxChars = maxChars - 1
	end -- always leave space for cursor

	local displayValue = inputValue
	if #displayValue > maxChars then
		displayValue = string.sub(displayValue, -maxChars)
	end

	-- Draw input text
	love.graphics.printf(displayValue, textX, textY, textWidth, "left")

	-- Draw blinking cursor immediately after the text
	if cursorVisible then
		local cursorXoffset = -2 -- Bring cursor closer to the left
		local cursorX = textX + bodyFont:getWidth(displayValue) + cursorXoffset
		love.graphics.print("|", cursorX, textY)
	end

	-- Check keyboard row units before drawing
	local totalUnits = checkKeyboardRowUnits(keyboard)
	local numRows = #keyboard

	-- Calculate available width and height for the keyboard grid
	local availableWidth = state.screenWidth - (screenPadding * 2)
	local availableHeight = state.screenHeight - (inputFieldY + inputFieldHeight + 30) - screenPadding

	-- Determine the size of a unit so that keys are square and fit the grid
	local unitWidth = (availableWidth - ((totalUnits - 1) * keySpacing)) / totalUnits
	local unitHeight = (availableHeight - ((numRows - 1) * keySpacing)) / numRows
	local unitSize = math.floor(math.min(unitWidth, unitHeight))

	-- Update keyboardX and keyboardY to center the keyboard grid
	local keyboardGridWidth = totalUnits * unitSize + (totalUnits - 1) * keySpacing
	local keyboardGridHeight = numRows * unitSize + (numRows - 1) * keySpacing
	local keyboardX = math.floor((state.screenWidth - keyboardGridWidth) / 2)
	local keyboardY = inputFieldY + inputFieldHeight + math.floor((availableHeight - keyboardGridHeight) / 2)

	updateKeyButtonLayout(unitSize, keyboardX, keyboardY)

	-- Draw keyboard
	for y, row in ipairs(keyboard) do
		for x, _ in ipairs(row) do
			local button = keyButtons[y][x]
			button:setFocused(x == selectedX and y == selectedY)
			button:draw()
		end
	end
	love.graphics.pop()

	-- Draw controls
	local controlsList = {
		{ button = "y", text = "Backspace" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

return virtual_keyboard
