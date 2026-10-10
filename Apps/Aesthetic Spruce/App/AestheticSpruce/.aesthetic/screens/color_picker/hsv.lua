--- Color picker screen
local love = require("love")

local colors = require("colors")
local screens = require("screens")
local state = require("state")
local tween = require("tween")

local colorUtils = require("utils.color")

local background = require("ui.background")
local fonts = require("ui.fonts")

local hsv = {}

local shared = require("screens.color_picker.shared")

local controls = require("control_hints").ControlHints
local controlHintsInstance

local InputManager = require("ui.controllers.input_manager")

-- Constants
local HUE_SLIDER_WIDTH = 32
local ELEMENT_SPACING = 10
local PREVIEW_SQUARE_SPACING = 30
local PREVIEW_HEIGHT = nil -- Will be calculated in load()
local OPACITY_UNFOCUSED = 0.2

local CURSOR = {
	CIRCLE_RADIUS = 10,
	CIRCLE_LINE_WIDTH = 1,
	HUE_HEIGHT = 16,
	TRIANGLE_HEIGHT = 20,
	TRIANGLE_HORIZONTAL_OFFSET = 12,
	TRIANGLE_SPACING = 1,
	CORNER_RADIUS = 4,
	TWEEN_DURATION = 0.25,
}
local STICK_DEAD_ZONE = 0.25 -- analog sticks rest off-centre on handhelds; ignore drift
local CACHE_RESOLUTION_DIVIDER = 4
local HUE_UPDATE_THRESHOLD = 5 -- Only regenerate SV texture when hue changes by 5 degrees or more

-- State
local pickerState = {
	squareSize = nil, -- Will be calculated in load()
	sliderWidth = 40,
	startX = nil, -- Will be calculated in load()
	startY = nil, -- Will be calculated in load()
	contentHeight = nil,
	-- Tween objects
	tweens = {
		svCursor = nil,
		hueCursor = nil,
	},
	-- Cache for gradient textures to avoid regenerating every frame
	cache = {
		svSquare = nil, -- Stores the saturation/value gradient
		hueSlider = nil, -- Stores the hue gradient
	},
	lastRenderedHue = 0, -- Track last rendered hue to limit texture updates
	-- Animation state for wiggle effect
	animation = {
		wiggleOffset = 0,
		wiggleTween = nil,
		lastFocusSquare = false, -- Track previous focus state
	},
}

-- Helper function to get current HSV state from central state manager
local function getCurrentHsvState()
	local colorType = state.activeColorContext
	local context = state.getColorContext(colorType)
	return context.hsv -- Return the HSV specific state for this color context
end

-- Texture initialization
local function initializeCachedTextures()
	-- Get current color type state
	local currentState = getCurrentHsvState()

	local cacheWidth = math.ceil(pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	local cacheHeight = math.ceil(pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)

	-- Generate the SV square texture
	local svImageData = love.image.newImageData(cacheWidth, cacheHeight)
	for y = 0, cacheHeight - 1 do
		for x = 0, cacheWidth - 1 do
			local s = x / (cacheWidth - 1)
			local v = 1 - (y / (cacheHeight - 1))
			local r, g, b = colorUtils.hsvToRgb(currentState.hue, s, v)
			svImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	if pickerState.cache.svSquare then
		pickerState.cache.svSquare:release() -- previous texture is never reused
	end
	pickerState.cache.svSquare = love.graphics.newImage(svImageData)
	pickerState.lastRenderedHue = currentState.hue

	-- Generate the hue slider texture
	local hueImageData = love.image.newImageData(HUE_SLIDER_WIDTH, cacheHeight)
	for y = 0, cacheHeight - 1 do
		local h = (1 - y / (cacheHeight - 1)) * 360
		local r, g, b = colorUtils.hsvToRgb(h, 1, 1)
		for x = 0, HUE_SLIDER_WIDTH - 1 do
			hueImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	pickerState.cache.hueSlider = love.graphics.newImage(hueImageData)
end

local function startWiggleAnimation()
	-- Cancel any existing wiggle animation
	if pickerState.animation.wiggleTween then
		pickerState.animation.wiggleTween:set(pickerState.animation.wiggleTween.duration)
	end

	-- Create a sequence of positions for the wiggle
	local sequence = {
		[0.00] = 0, -- Start position
		[0.05] = 5, -- Right/down
		[0.15] = -4, -- Left/up
		[0.25] = 3, -- Right/down
		[0.35] = -2, -- Left/up
		[0.45] = 1, -- Right/down
		[0.55] = 0, -- Back to center
	}

	-- Create the wiggle tween
	local duration = 0.6
	local initial = {
		offset = sequence[0.05], -- Start at first peak of wiggle
	}

	pickerState.animation.wiggleOffset = initial.offset -- Set initial offset
	pickerState.animation.wiggleTween = tween.new(duration, pickerState.animation, {
		wiggleOffset = 0,
	}, "outElastic")
end

function hsv.draw()
	background.draw()

	-- Get current color type state
	local currentState = getCurrentHsvState()

	-- Draw current color preview
	local hexColor = state.getColorValue(state.activeColorContext)
	local r, g, b = colorUtils.hexToRgb(hexColor)

	love.graphics.push("all")

	-- Align previews block so top of 'Old' is flush with SV square/hue slider
	local previewsY = pickerState.startY

	love.graphics.setColor(r, g, b, 1)
	love.graphics.rectangle(
		"fill",
		pickerState.previewX,
		previewsY,
		pickerState.previewWidth,
		PREVIEW_HEIGHT,
		CURSOR.CORNER_RADIUS
	)

	-- Draw current color border using Relative Luminance Border Algorithm
	local borderR, borderG, borderB = colorUtils.calculateContrastingColor(r, g, b)
	love.graphics.setColor({ borderR, borderG, borderB })
	love.graphics.setLineWidth(1)
	love.graphics.rectangle(
		"line",
		pickerState.previewX,
		previewsY,
		pickerState.previewWidth,
		PREVIEW_HEIGHT,
		CURSOR.CORNER_RADIUS
	)

	-- Draw "Old" label just below the 'Old' preview
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(fonts.loaded.caption)
	love.graphics.printf(
		"Old",
		pickerState.previewX,
		previewsY + PREVIEW_HEIGHT + 5,
		pickerState.previewWidth,
		"center"
	)

	local labelHeight = pickerState.labelHeight
	local labelPadding = pickerState.labelPadding
	local previewSpacing = pickerState.previewSpacing

	-- Draw new color preview below the 'Old' label and spacing
	r, g, b = colorUtils.hsvToRgb(currentState.hue, currentState.sat, currentState.val)
	love.graphics.setColor(r, g, b, 1)
	love.graphics.rectangle(
		"fill",
		pickerState.previewX,
		previewsY + PREVIEW_HEIGHT + labelHeight + labelPadding + previewSpacing,
		pickerState.previewWidth,
		PREVIEW_HEIGHT,
		CURSOR.CORNER_RADIUS
	)

	-- Draw new color border using Relative Luminance Border Algorithm
	local newBorderR, newBorderG, newBorderB = colorUtils.calculateContrastingColor(r, g, b)
	love.graphics.setColor(newBorderR, newBorderG, newBorderB, 1)
	love.graphics.setLineWidth(1)

	love.graphics.rectangle(
		"line",
		pickerState.previewX,
		previewsY + PREVIEW_HEIGHT + labelHeight + labelPadding + previewSpacing,
		pickerState.previewWidth,
		PREVIEW_HEIGHT,
		CURSOR.CORNER_RADIUS
	)

	-- Draw "New" label just below the 'New' preview, flush with the bottom of the SV square/hue slider
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf(
		"New",
		pickerState.previewX,
		previewsY + PREVIEW_HEIGHT + labelHeight + labelPadding + previewSpacing + PREVIEW_HEIGHT + 5,
		pickerState.previewWidth,
		"center"
	)

	local wiggleOffset = pickerState.animation.wiggleOffset

	-- Draw Hue slider with wiggle
	local hueX = pickerState.hueSliderX
	if not currentState.focusSquare then
		hueX = hueX + wiggleOffset
	end

	-- Vertically center hue slider and SV square within blockHeight
	local svY = pickerState.startY

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.draw(
		pickerState.cache.hueSlider,
		hueX,
		svY,
		0,
		1,
		CACHE_RESOLUTION_DIVIDER
	)

	-- Draw Hue slider outline
	love.graphics.setColor(
		colors.ui.foreground[1],
		colors.ui.foreground[2],
		colors.ui.foreground[3],
		currentState.focusSquare and OPACITY_UNFOCUSED or 1
	)
	love.graphics.setLineWidth(not currentState.focusSquare and shared.OUTLINE_WIDTH_FOCUS or 1)

	love.graphics.rectangle("line", hueX, svY, HUE_SLIDER_WIDTH, pickerState.squareSize, CURSOR.CORNER_RADIUS)

	-- Draw hue selection triangles
	if not currentState.focusSquare then
		love.graphics.setColor(colors.ui.foreground)
	else
		love.graphics.setColor(
			colors.ui.foreground[1],
			colors.ui.foreground[2],
			colors.ui.foreground[3],
			OPACITY_UNFOCUSED
		)
	end

	-- Left triangle
	love.graphics.polygon(
		"fill",
		hueX - CURSOR.TRIANGLE_HORIZONTAL_OFFSET - CURSOR.TRIANGLE_SPACING,
		currentState.cursor.hueY - CURSOR.TRIANGLE_HEIGHT / 2,
		hueX - CURSOR.TRIANGLE_HORIZONTAL_OFFSET - CURSOR.TRIANGLE_SPACING,
		currentState.cursor.hueY + CURSOR.TRIANGLE_HEIGHT / 2,
		hueX - CURSOR.TRIANGLE_SPACING,
		currentState.cursor.hueY
	)

	-- Right triangle
	love.graphics.polygon(
		"fill",
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_HORIZONTAL_OFFSET + CURSOR.TRIANGLE_SPACING,
		currentState.cursor.hueY - CURSOR.TRIANGLE_HEIGHT / 2,
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_HORIZONTAL_OFFSET + CURSOR.TRIANGLE_SPACING,
		currentState.cursor.hueY + CURSOR.TRIANGLE_HEIGHT / 2,
		hueX + HUE_SLIDER_WIDTH + CURSOR.TRIANGLE_SPACING,
		currentState.cursor.hueY
	)

	-- Draw SV square with wiggle
	local svX = pickerState.startX
	if currentState.focusSquare then
		svX = svX + wiggleOffset
	end

	-- Use stencil to mask SV square with rounded corners
	love.graphics.stencil(function()
		love.graphics.rectangle("fill", svX, svY, pickerState.squareSize, pickerState.squareSize, CURSOR.CORNER_RADIUS)
	end, "replace", 1)
	love.graphics.setStencilTest("equal", 1)

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.draw(
		pickerState.cache.svSquare,
		svX,
		svY,
		0,
		CACHE_RESOLUTION_DIVIDER,
		CACHE_RESOLUTION_DIVIDER
	)

	love.graphics.setStencilTest() -- Disable stencil after drawing

	-- Draw SV square outline
	love.graphics.setColor(1, 1, 1, currentState.focusSquare and 1 or OPACITY_UNFOCUSED)
	love.graphics.setLineWidth(currentState.focusSquare and shared.OUTLINE_WIDTH_FOCUS or 1)

	love.graphics.rectangle("line", svX, svY, pickerState.squareSize, pickerState.squareSize, CURSOR.CORNER_RADIUS)

	-- Draw SV cursor
	if currentState.focusSquare then
		love.graphics.setColor(colors.ui.foreground)
	else
		love.graphics.setColor(
			colors.ui.foreground[1],
			colors.ui.foreground[2],
			colors.ui.foreground[3],
			OPACITY_UNFOCUSED
		)
	end
	love.graphics.setLineWidth(CURSOR.CIRCLE_LINE_WIDTH)
	love.graphics.circle("line", currentState.cursor.svX, currentState.cursor.svY, CURSOR.CIRCLE_RADIUS)

	love.graphics.pop()

	-- Draw controls
	local controlsList = {
		{ button = "y", text = "H/SV" },
		{ button = "a", text = "Select" },
		{ button = { "leftshoulder", "rightshoulder" }, text = "Switch Tabs" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

-- Only regenerates the texture when necessary and at reduced resolution
local function updateSVSquare()
	-- Get current color type state
	local currentState = getCurrentHsvState()

	-- Skip updates if hue hasn't changed enough to be noticeable
	-- This prevents unnecessary texture regeneration
	local hueDiff = math.abs(currentState.hue - pickerState.lastRenderedHue)
	if hueDiff < HUE_UPDATE_THRESHOLD then
		return
	end

	local cacheWidth = math.ceil(pickerState.squareSize / CACHE_RESOLUTION_DIVIDER)
	local cacheHeight = math.ceil(pickerState.contentHeight / CACHE_RESOLUTION_DIVIDER)

	local svImageData = love.image.newImageData(cacheWidth, cacheHeight)
	for y = 0, cacheHeight - 1 do
		for x = 0, cacheWidth - 1 do
			local s = x / (cacheWidth - 1)
			local v = 1 - (y / (cacheHeight - 1))
			local r, g, b = colorUtils.hsvToRgb(currentState.hue, s, v)
			svImageData:setPixel(x, y, r, g, b, 1)
		end
	end
	if pickerState.cache.svSquare then
		pickerState.cache.svSquare:release() -- previous texture is never reused
	end
	pickerState.cache.svSquare = love.graphics.newImage(svImageData)
	pickerState.lastRenderedHue = currentState.hue
end

-- Helper function to update all active tweens
local function updateTweens(dt)
	if pickerState.tweens.svCursor then
		pickerState.tweens.svCursor:update(dt)
	end
	if pickerState.tweens.hueCursor then
		pickerState.tweens.hueCursor:update(dt)
	end
end

-- Helper function to update wiggle animation
local function updateWiggleAnimation(dt)
	if pickerState.animation.wiggleTween then
		pickerState.animation.wiggleTween:update(dt)
	end
end

function hsv.update(dt)
	-- Get current color type state
	local currentState = getCurrentHsvState()

	-- Update tweens
	updateTweens(dt)

	-- Update wiggle animation
	updateWiggleAnimation(dt)

	local moved = false

	-- Handle Y button for cursor swapping
	if InputManager.isActionJustPressed(InputManager.ACTIONS.SWAP_CURSOR) then
		currentState.focusSquare = not currentState.focusSquare
		startWiggleAnimation() -- Start animation immediately after focus change
		moved = true
	end

	-- Get left stick values if joystick is connected
	local leftX, leftY = 0, 0
	local joystick = love.joystick.getJoysticks()[1]
	if joystick and joystick:isConnected() then
		-- Gamepad axes are typically:
		-- leftx = axis 1, lefty = axis 2
		if joystick:isGamepad() then
			leftX = joystick:getGamepadAxis("leftx")
			leftY = joystick:getGamepadAxis("lefty")
		else
			-- Fallback for non-gamepad joysticks
			leftX = joystick:getAxis(1)
			leftY = joystick:getAxis(2)
		end
	end

	-- --- HELD DPAD SUPPORT START ---
	local navDir = InputManager.getNavigationDirection()

	if currentState.focusSquare then
		-- Handle SV square navigation
		local step = 0.03
		local newSat, newVal = currentState.sat, currentState.val

		-- Held D-pad controls
		if navDir == "left" then
			newSat = math.max(0, newSat - step)
			moved = true
		elseif navDir == "right" then
			newSat = math.min(1, newSat + step)
			moved = true
		end
		if navDir == "up" then
			newVal = math.min(1, newVal + step)
			moved = true
		elseif navDir == "down" then
			newVal = math.max(0, newVal - step)
			moved = true
		end

		-- Joystick controls (unchanged)
		if math.abs(leftX) < STICK_DEAD_ZONE then
			leftX = 0
		end
		if math.abs(leftY) < STICK_DEAD_ZONE then
			leftY = 0
		end
		if leftX ~= 0 then
			newSat = math.max(0, math.min(1, newSat + leftX * step))
			moved = true
		end
		if leftY ~= 0 then
			newVal = math.max(0, math.min(1, newVal - leftY * step))
			moved = true
		end

		if moved then
			currentState.sat = newSat
			currentState.val = newVal

			-- Create new tween for SV cursor
			local targetX = pickerState.startX + (newSat * pickerState.squareSize)
			local targetY = pickerState.startY + ((1 - newVal) * pickerState.contentHeight)
			pickerState.tweens.svCursor = tween.new(CURSOR.TWEEN_DURATION, currentState.cursor, {
				svX = targetX,
				svY = targetY,
			}, "linear")
		end
	else
		-- Handle Hue slider navigation
		local step = 6
		local newHue = currentState.hue
		local hueChanged = false

		-- Held D-pad UP/DOWN for hue
		if navDir == "up" then
			newHue = (newHue + step) % 360
			hueChanged = true
		elseif navDir == "down" then
			newHue = (newHue - step) % 360
			hueChanged = true
		end

		if hueChanged then
			currentState.hue = newHue
			-- Update the SV square when hue changes
			updateSVSquare()

			-- Calculate new cursor Y position
			local baseY = pickerState.startY + ((360 - newHue) / 360 * pickerState.contentHeight)
			local sliderBottom = pickerState.startY + pickerState.contentHeight

			-- Handle wrapping when cursor goes halfway off either end
			if baseY < pickerState.startY - (CURSOR.HUE_HEIGHT / 2) then
				-- Wrap from top to bottom
				baseY = sliderBottom - (CURSOR.HUE_HEIGHT / 2)
			elseif baseY > sliderBottom + (CURSOR.HUE_HEIGHT / 2) then
				-- Wrap from bottom to top
				baseY = pickerState.startY + (CURSOR.HUE_HEIGHT / 2)
			end

			-- Create new tween for hue cursor
			pickerState.tweens.hueCursor = tween.new(CURSOR.TWEEN_DURATION, currentState.cursor, {
				hueY = baseY,
			}, "linear")
		end

		-- Joystick Y-axis controls for hue (unchanged)
		if math.abs(leftY) < STICK_DEAD_ZONE then
			leftY = 0
		end
		if leftY ~= 0 then
			newHue = (newHue - leftY * step) % 360

			currentState.hue = newHue
			-- Update the SV square when hue changes
			updateSVSquare()

			-- Calculate new cursor Y position
			local baseY = pickerState.startY + ((360 - newHue) / 360 * pickerState.contentHeight)
			local sliderBottom = pickerState.startY + pickerState.contentHeight

			-- Handle wrapping when cursor goes halfway off either end
			if baseY < pickerState.startY - (CURSOR.HUE_HEIGHT / 2) then
				-- Wrap from top to bottom
				baseY = sliderBottom - (CURSOR.HUE_HEIGHT / 2)
			elseif baseY > sliderBottom + (CURSOR.HUE_HEIGHT / 2) then
				-- Wrap from bottom to top
				baseY = pickerState.startY + (CURSOR.HUE_HEIGHT / 2)
			end

			-- Create new tween for hue cursor
			pickerState.tweens.hueCursor = tween.new(CURSOR.TWEEN_DURATION, currentState.cursor, {
				hueY = baseY,
			}, "linear")
		end
	end
	-- --- HELD DPAD SUPPORT END ---

	-- Handle selection
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CONFIRM) then
		local r, g, b = colorUtils.hsvToRgb(currentState.hue, currentState.sat, currentState.val)

		-- Create hex code using the utility function
		local hexCode = colorUtils.rgbToHex(r, g, b)

		-- Store in the central state
		local context = state.getColorContext(state.activeColorContext)
		context.currentColor = hexCode

		-- Set the color value in state
		state.setColorValue(state.activeColorContext, hexCode)

		screens.switchTo(state.previousScreen)
	end
end

function hsv.onEnter()
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end

	-- Initialize layout if not already done
	if not pickerState.squareSize then
		local contentArea = shared.calculateContentArea()

		-- Calculate available space
		local availableHeight = contentArea.height - (shared.PADDING * 2)
		local availableWidth = contentArea.width - (shared.PADDING * 2)

		-- Reserve at least 160px for hue slider and previews
		local MIN_REMAINING_WIDTH = 160
		local maxSquareByWidth = availableWidth - MIN_REMAINING_WIDTH
		local squareSize = math.min(availableHeight, maxSquareByWidth)
		pickerState.squareSize = squareSize

		-- Calculate total width needed for SV square and hue slider with triangles and spacing
		local totalFixedWidth = pickerState.squareSize -- SV square
			+ HUE_SLIDER_WIDTH -- Hue slider
			+ (CURSOR.TRIANGLE_HEIGHT * 2) -- Space for triangles on both sides of hue slider
			+ (ELEMENT_SPACING * 2) -- Spacing between elements

		pickerState.previewWidth = availableWidth - totalFixedWidth
		pickerState.sliderWidth = HUE_SLIDER_WIDTH
		pickerState.contentHeight = availableHeight

		-- Calculate preview heights so that previews + spacing + labels = squareSize
		local labelHeight = 20
		local labelPadding = 15
		local previewSpacing = PREVIEW_SQUARE_SPACING
		local totalLabelHeight = labelHeight * 2 + labelPadding
		local previewHeight = (squareSize - previewSpacing - totalLabelHeight) / 2
		PREVIEW_HEIGHT = previewHeight

		-- Calculate total height of all vertically stacked elements (should now match squareSize)
		local previewsBlockHeight = (PREVIEW_HEIGHT * 2) + previewSpacing + totalLabelHeight
		local blockHeight = squareSize
		local blockStartY = contentArea.y + ((contentArea.height - blockHeight) / 2)

		-- Preview squares position (leftmost)
		local previewX = shared.PADDING
		-- Hue slider position (after preview)
		local hueSliderX = previewX + pickerState.previewWidth + ELEMENT_SPACING + CURSOR.TRIANGLE_HEIGHT
		-- SV square position (rightmost, ensuring consistent right edge padding)
		pickerState.startX = contentArea.width - shared.PADDING - pickerState.squareSize
		-- Store all positions
		pickerState.startY = blockStartY
		pickerState.hueSliderX = hueSliderX
		pickerState.previewX = previewX

		-- Store for use in draw (for vertical alignment of previews)
		pickerState.previewsBlockHeight = previewsBlockHeight
		pickerState.blockHeight = blockHeight
		pickerState.blockStartY = blockStartY
		pickerState.labelHeight = labelHeight
		pickerState.labelPadding = labelPadding
		pickerState.previewSpacing = previewSpacing

		initializeCachedTextures()
	end

	-- Get current color type state
	local currentState = getCurrentHsvState()

	-- Initialize cursor positions
	currentState.cursor.svX = pickerState.startX + (currentState.sat * pickerState.squareSize)
	currentState.cursor.svY = pickerState.startY + ((1 - currentState.val) * pickerState.squareSize)
	currentState.cursor.hueY = pickerState.startY + ((360 - currentState.hue) / 360 * pickerState.squareSize)

	-- Update the SV square texture based on the current hue
	updateSVSquare()

	-- Start with a wiggle animation on the appropriate control based on focus
	startWiggleAnimation()
end

return hsv
