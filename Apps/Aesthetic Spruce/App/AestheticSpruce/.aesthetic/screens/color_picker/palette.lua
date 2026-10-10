--- Color picker palette screen

local love = require("love")

local colors = require("colors")
local state = require("state")
local tween = require("tween")
local controls = require("control_hints").ControlHints
local colorUtils = require("utils.color")
local screens = require("screens")
local shared = require("screens.color_picker.shared")

local palette = {}
local controlHintsInstance

-- Constants
local VERTICAL_PADDING = 20
local SQUARE_SPACING = 20

local SCROLLBAR = {
	WIDTH = 6,
	PADDING = 10,
	CORNER_RADIUS = 4,
	HANDLE_MIN_HEIGHT = 30,
}

local BORDER = {
	CORNER_RADIUS = 10,
}

local ANIMATION = {
	SCALE = 1.25,
	DURATION = 0.15,
}

-- Pulse animation config (mirroring button.lua)
local PULSE_SCALE_MIN = ANIMATION.SCALE -- Start pulse at the end of the initial animation
local PULSE_SCALE_MAX = ANIMATION.SCALE + 0.07 -- Pulse to a larger scale
local PULSE_DURATION = 1.1

-- Helper function to get current palette state from central state manager
local function getCurrentPaletteState()
	local colorType = state.activeColorContext
	local context = state.getColorContext(colorType)
	return context.palette -- Return the palette specific state for this color context
end

-- Helper function to get all palette colors (ordered)
local function getPaletteColors()
	return colors.palette
end

-- Helper function to calculate grid dimensions
local function calculateGridSize()
	local totalColors = #getPaletteColors()
	local cols = 8
	local rows = math.ceil(totalColors / cols)
	return {
		cols = cols,
		rows = rows,
	}
end

-- Helper function to convert grid position to linear index
local function gridPosToIndex(row, col, grid)
	return row * grid.cols + col + 1
end

-- Helper function to check if a grid position has a color
local function hasColorAt(row, col, grid, totalColors)
	local index = gridPosToIndex(row, col, grid)
	return index <= totalColors
end

-- Helper function to calculate grid dimensions and layout
local function calculateGridDimensions()
	local paletteColors = getPaletteColors()
	local gridSize = calculateGridSize()

	local contentArea = shared.calculateContentArea()

	-- Calculate available space accounting for padding
	local availableHeight = contentArea.height - (VERTICAL_PADDING * 2)
	local availableWidth = contentArea.width - (shared.PADDING * 2) - SCROLLBAR.WIDTH - SCROLLBAR.PADDING

	-- Calculate square size based on available width and number of columns
	local squareSize = math.floor((availableWidth - (SQUARE_SPACING * (gridSize.cols - 1))) / gridSize.cols)

	-- Calculate number of visible rows that can fit in the available height
	local visibleRows = math.floor((availableHeight - squareSize) / (squareSize + SQUARE_SPACING)) + 1
	visibleRows = math.min(visibleRows, gridSize.rows)

	-- Recalculate vertical spacing so the last row is flush with the bottom
	local totalSquaresHeight = visibleRows * squareSize
	local remainingHeight = availableHeight - totalSquaresHeight
	local verticalSpacing = visibleRows > 1 and (remainingHeight / (visibleRows - 1)) or 0

	-- Calculate total grid dimensions
	local totalWidth = (gridSize.cols * squareSize) + (gridSize.cols - 1) * SQUARE_SPACING
	local totalGridHeight = (gridSize.rows * squareSize) + (gridSize.rows - 1) * verticalSpacing
	local visibleGridHeight = (visibleRows * squareSize) + (visibleRows - 1) * verticalSpacing

	-- Center the grid horizontally in the content area
	local offsetX = math.floor((contentArea.width - totalWidth - SCROLLBAR.WIDTH - SCROLLBAR.PADDING) / 2)

	-- Position grid vertically starting from the content area's top edge
	local offsetY = math.floor(contentArea.y + VERTICAL_PADDING)

	return {
		paletteColors = paletteColors,
		gridSize = gridSize,
		squareSize = squareSize,
		visibleRows = visibleRows,
		totalGridHeight = totalGridHeight,
		visibleGridHeight = visibleGridHeight,
		offsetX = offsetX,
		offsetY = offsetY,
		verticalSpacing = verticalSpacing,
	}
end

local paletteState = {
	paletteColors = getPaletteColors(),
	gridSize = nil,
	squareSize = 0,
	currentScale = 1,
	scaleTween = nil,
	-- Pulse animation state
	pulseScale = 1.0,
	pulseTween = nil,
	pulseDirection = 1, -- 1: up, -1: down
	offsetX = 0,
	offsetY = 0,
	visibleRows = 0,
	totalGridHeight = 0,
	visibleGridHeight = 0,
	verticalSpacing = 0,
}

-- Helper function to draw the scrollbar
local function drawScrollbar()
	local contentArea = shared.calculateContentArea()
	local scrollbarHeight = contentArea.height - (VERTICAL_PADDING * 2)
	local scrollbarX = state.screenWidth - SCROLLBAR.WIDTH - SCROLLBAR.PADDING
	local scrollbarY = contentArea.y + VERTICAL_PADDING

	-- Calculate handle position and size
	local contentRatio = paletteState.visibleGridHeight / paletteState.totalGridHeight
	local handleHeight = math.max(SCROLLBAR.HANDLE_MIN_HEIGHT, scrollbarHeight * contentRatio)
	local scrollRatio = 0
	local currentState = getCurrentPaletteState()
	if paletteState.totalGridHeight > paletteState.visibleGridHeight then
		scrollRatio = currentState.scrollY / (paletteState.totalGridHeight - paletteState.visibleGridHeight)
	end

	local handleY = scrollbarY + (scrollbarHeight - handleHeight) * scrollRatio

	-- Draw handle (no background, match list.lua)
	love.graphics.setColor(colors.ui.scrollbar)
	love.graphics.rectangle("fill", scrollbarX, handleY, SCROLLBAR.WIDTH, handleHeight, SCROLLBAR.CORNER_RADIUS)
end

function palette.draw()
	love.graphics.push("all")

	-- Set background
	love.graphics.setColor(colors.ui.background)
	love.graphics.clear(colors.ui.background)

	local currentState = getCurrentPaletteState()
	local firstVisibleRow = math.floor(currentState.scrollY / (paletteState.squareSize + paletteState.verticalSpacing))

	-- Calculate the last visible row based on the visible grid height
	local contentArea = shared.calculateContentArea()
	local visibleBottom = contentArea.y + contentArea.height
	local lastVisibleRow = firstVisibleRow + paletteState.visibleRows
	lastVisibleRow = math.min(lastVisibleRow, paletteState.gridSize.rows - 1)

	-- Draw color grid (only visible rows)
	for row = firstVisibleRow, lastVisibleRow do
		for col = 0, paletteState.gridSize.cols - 1 do
			local colorIndex = gridPosToIndex(row, col, paletteState.gridSize)
			if colorIndex <= #paletteState.paletteColors then
				local x = paletteState.offsetX + col * (paletteState.squareSize + SQUARE_SPACING)
				local rowIndex = row - firstVisibleRow
				local y = paletteState.offsetY + rowIndex * (paletteState.squareSize + paletteState.verticalSpacing)

				-- Check if this square would be visible (not overlapping with controls)
				if y + paletteState.squareSize <= visibleBottom then
					local scale = 1
					local offset = 0
					if row == currentState.selectedRow and col == currentState.selectedCol then
						if paletteState.pulseTween then
							scale = paletteState.pulseScale
						else
							scale = paletteState.currentScale
						end
						offset = (paletteState.squareSize * (scale - 1)) / 2
					end
					local colorTable = paletteState.paletteColors[colorIndex]
					love.graphics.setColor(colorTable[1], colorTable[2], colorTable[3], colorTable[4] or 1)
					love.graphics.rectangle(
						"fill",
						x - offset,
						y - offset,
						paletteState.squareSize * scale,
						paletteState.squareSize * scale,
						BORDER.CORNER_RADIUS
					)

					-- Draw border
					love.graphics.setColor(colors.ui.foreground)
					if row == currentState.selectedRow and col == currentState.selectedCol then
						love.graphics.setLineWidth(shared.OUTLINE_WIDTH_FOCUS)
					else
						love.graphics.setLineWidth(1)
					end
					love.graphics.rectangle(
						"line",
						x - offset,
						y - offset,
						paletteState.squareSize * scale,
						paletteState.squareSize * scale,
						BORDER.CORNER_RADIUS
					)
				end
			end
		end
	end
	drawScrollbar()
	local controlsList = {
		{ button = "a", text = "Confirm" },
		{ button = { "leftshoulder", "rightshoulder" }, text = "Switch Tabs" },
		{ button = "b", text = "Back" },
	}
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()

	love.graphics.pop()
end

function palette.update(dt)
	-- Update scale tween if it exists
	if paletteState.scaleTween then
		local complete = paletteState.scaleTween:update(dt)
		if complete then
			paletteState.scaleTween = nil
			-- Start pulse tween after scale up
			paletteState.pulseScale = PULSE_SCALE_MIN
			paletteState.pulseDirection = 1
			paletteState.pulseTween =
				tween.new(PULSE_DURATION / 2, paletteState, { pulseScale = PULSE_SCALE_MAX }, "inOutSine")
		end
	end
	-- Update pulse tween if it exists
	if paletteState.pulseTween then
		local complete = paletteState.pulseTween:update(dt)
		if complete then
			-- Reverse direction for continuous pulse
			paletteState.pulseDirection = -paletteState.pulseDirection
			local toScale = (paletteState.pulseDirection == 1) and PULSE_SCALE_MAX or PULSE_SCALE_MIN
			paletteState.pulseTween = tween.new(PULSE_DURATION / 2, paletteState, { pulseScale = toScale }, "inOutSine")
		end
	end

	local virtualJoystick = require("input").virtualJoystick
	local currentState = getCurrentPaletteState()
	local newRow, newCol = currentState.selectedRow, currentState.selectedCol

	-- Handle directional input
	if virtualJoystick.isGamepadPressedWithDelay("dpup") then
		if currentState.selectedRow > 0 then
			newRow = currentState.selectedRow - 1
		end
	elseif virtualJoystick.isGamepadPressedWithDelay("dpdown") then
		if currentState.selectedRow < paletteState.gridSize.rows - 1 then
			newRow = currentState.selectedRow + 1
		end
	elseif virtualJoystick.isGamepadPressedWithDelay("dpleft") then
		if currentState.selectedCol > 0 then
			newCol = currentState.selectedCol - 1
		end
	elseif virtualJoystick.isGamepadPressedWithDelay("dpright") then
		if currentState.selectedCol < paletteState.gridSize.cols - 1 then
			newCol = currentState.selectedCol + 1
		end
	end

	-- Clamp newRow to the last row that actually has a color
	local maxRow = math.ceil(#paletteState.paletteColors / paletteState.gridSize.cols) - 1
	if newRow > maxRow then
		newRow = maxRow
	end

	if hasColorAt(newRow, newCol, paletteState.gridSize, #paletteState.paletteColors) then
		if newRow ~= currentState.selectedRow or newCol ~= currentState.selectedCol then
			currentState.selectedRow = newRow
			currentState.selectedCol = newCol

			-- Immediately reset all animation state for snappy focus change
			paletteState.currentScale = 1
			paletteState.scaleTween = nil
			paletteState.pulseTween = nil
			paletteState.pulseScale = ANIMATION.SCALE
			paletteState.pulseDirection = 1

			-- Start new hover animation
			paletteState.scaleTween = tween.new(ANIMATION.DURATION, paletteState, {
				currentScale = ANIMATION.SCALE,
			}, "outQuad")

			-- Handle scrolling when selection moves out of view
			local rowPosition = currentState.selectedRow * (paletteState.squareSize + paletteState.verticalSpacing)

			-- Calculate the visible area boundaries
			local visibleTop = currentState.scrollY
			local visibleBottom = visibleTop + paletteState.visibleGridHeight - paletteState.squareSize

			-- Scroll up if selection is above visible area
			if rowPosition < visibleTop then
				currentState.scrollY = rowPosition
			end

			-- Scroll down if selection is below visible area
			if rowPosition > visibleBottom then
				currentState.scrollY = rowPosition
					- paletteState.visibleGridHeight
					+ paletteState.squareSize
					+ paletteState.verticalSpacing
			end

			-- Ensure scroll position doesn't go out of bounds
			currentState.scrollY = math.max(
				0,
				math.min(currentState.scrollY, paletteState.totalGridHeight - paletteState.visibleGridHeight)
			)
		end
	end

	-- Handle select
	if virtualJoystick.isGamepadPressedWithDelay("a") then
		local selectedIndex = gridPosToIndex(currentState.selectedRow, currentState.selectedCol, paletteState.gridSize)
		local colorTable = paletteState.paletteColors[selectedIndex]
		if colorTable then
			local hexCode = colorUtils.rgbToHex(colorTable[1], colorTable[2], colorTable[3])
			if hexCode then
				local context = state.getColorContext(state.activeColorContext)
				context.currentColor = hexCode
				state.setColorValue(state.activeColorContext, hexCode)
				screens.switchTo(state.previousScreen)
			end
		end
	end
end

-- Helper function to find the closest color in the palette to a given hex value
function palette.findClosestColor(hexColor)
	local targetR, targetG, targetB = colorUtils.hexToRgb(hexColor)
	local minDistance = math.huge
	local closestIndex = nil
	local closestRow = 0
	local closestCol = 0
	local paletteColors = getPaletteColors()
	local gridSize = calculateGridSize()
	for i, colorTable in ipairs(paletteColors) do
		local row = math.floor((i - 1) / gridSize.cols)
		local col = (i - 1) % gridSize.cols
		local r, g, b = colorTable[1], colorTable[2], colorTable[3]
		local distance = math.sqrt((r - targetR) ^ 2 + (g - targetG) ^ 2 + (b - targetB) ^ 2)
		if distance < minDistance then
			minDistance = distance
			closestIndex = i
			closestRow = row
			closestCol = col
		end
	end
	return {
		index = closestIndex,
		row = closestRow,
		col = closestCol,
	}
end

-- Function to initialize palette state for the current color
function palette.initializePaletteState()
	local currentContext = state.activeColorContext
	local hexColor = state.getColorValue(currentContext)

	-- Find the closest color in the palette
	local closestInfo = palette.findClosestColor(hexColor)
	if closestInfo and closestInfo.index then
		local currentPaletteState = getCurrentPaletteState()
		currentPaletteState.selectedRow = closestInfo.row
		currentPaletteState.selectedCol = closestInfo.col
		local dimensions = calculateGridDimensions()
		local squareSize = dimensions.squareSize
		local spacing = dimensions.verticalSpacing

		-- Calculate scroll position to center the selected color
		currentPaletteState.scrollY = (closestInfo.row * (squareSize + spacing))
			- (dimensions.visibleRows / 2 * (squareSize + spacing))

		-- Clamp scroll position
		currentPaletteState.scrollY = math.max(0, currentPaletteState.scrollY)
		currentPaletteState.scrollY = math.min(
			(dimensions.gridSize.rows * (squareSize + spacing)) - dimensions.visibleGridHeight,
			currentPaletteState.scrollY
		)
	end
end

function palette.onEnter()
	local dimensions = calculateGridDimensions()
	paletteState.paletteColors = dimensions.paletteColors
	paletteState.gridSize = dimensions.gridSize
	paletteState.squareSize = dimensions.squareSize
	paletteState.visibleRows = dimensions.visibleRows
	paletteState.totalGridHeight = dimensions.totalGridHeight
	paletteState.visibleGridHeight = dimensions.visibleGridHeight
	paletteState.offsetX = dimensions.offsetX
	paletteState.offsetY = dimensions.offsetY
	paletteState.verticalSpacing = dimensions.verticalSpacing
	palette.initializePaletteState()
	local currentState = getCurrentPaletteState()

	-- Validate that the selected position is still valid after grid size changes
	-- and adjust if necessary
	if currentState.selectedRow >= paletteState.gridSize.rows then
		currentState.selectedRow = paletteState.gridSize.rows - 1
	end
	if currentState.selectedCol >= paletteState.gridSize.cols then
		currentState.selectedCol = paletteState.gridSize.cols - 1
	end

	-- Ensure the selected position has a color
	if
		not hasColorAt(
			currentState.selectedRow,
			currentState.selectedCol,
			paletteState.gridSize,
			#paletteState.paletteColors
		)
	then
		-- If not, reset to the first color
		currentState.selectedRow = 0
		currentState.selectedCol = 0
	end

	-- Ensure scroll position is still valid
	if paletteState.totalGridHeight > paletteState.visibleGridHeight then
		currentState.scrollY =
			math.max(0, math.min(currentState.scrollY, paletteState.totalGridHeight - paletteState.visibleGridHeight))
	else
		currentState.scrollY = 0
	end

	-- Start hover animation for the selected color
	paletteState.currentScale = 1
	paletteState.scaleTween = tween.new(ANIMATION.DURATION, paletteState, {
		currentScale = ANIMATION.SCALE,
	}, "outQuad")

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

return palette
