--- Font selection screen
local love = require("love")

local colors = require("colors")
local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local List = require("ui.components.list").List
local InputManager = require("ui.controllers.input_manager")

-- Module table to export public functions
local font = {}

-- Local variables for this module
local menuList
local input

local headerInstance = Header:new({ title = "Font Family" })

-- Constants specific to the font preview
local FONT_PREVIEW = {
	PREVIEW_TEXT = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890!@#$%^&*()_+-=[]{}|;':\",./<>?",
	PREVIEW_BG_CORNER_RADIUS = 10,
	PREVIEW_BOTTOM_MARGIN = 15, -- Margin between preview box and controls
	FONT_SIZE = 22, -- Use a consistent font size for all preview fonts
	PADDING = 12, -- Padding around the preview text
}

-- Font cache for previewing (to avoid recreating fonts every frame)
local previewFontCache = {}

-- Store the maximum preview height once calculated
local maxPreviewHeight = nil

local controlHintsInstance

-- Helper function to get a consistent preview font
local function getPreviewFont(fontName)
	-- Determine preview font size, adjusting for specific fonts as needed
	local previewFontSize = FONT_PREVIEW.FONT_SIZE
	-- 'Retro Pixel' has a smaller x-height, so increase its preview size for better visual parity with other fonts
	if fontName == "Retro Pixel" then
		previewFontSize = previewFontSize + 2
	end

	-- Check if we already have this font in our cache with the correct size
	local cacheKey = fontName .. "_" .. tostring(previewFontSize)
	if previewFontCache[cacheKey] then
		return previewFontCache[cacheKey]
	end

	local previewFont

	-- Find the font info from fonts.themeDefinitions
	local fontInfo = nil
	for _, choice in ipairs(fonts.themeDefinitions) do
		if choice.name == fontName then
			fontInfo = choice
			break
		end
	end

	if fontInfo and fontInfo.ttf then
		previewFont = love.graphics.newFont(fontInfo.ttf, previewFontSize)
	else
		-- Fallback to the state's font loading for unknown fonts
		previewFont = fonts.getByName(fontName)
	end

	-- Cache the font for future use
	previewFontCache[cacheKey] = previewFont
	return previewFont
end

-- Helper function to calculate the preview height for a specific font
local function calculatePreviewHeight(fontName)
	if not fontName then
		return 0
	end

	local previewFont = getPreviewFont(fontName)
	local _, textLines =
		previewFont:getWrap(FONT_PREVIEW.PREVIEW_TEXT, state.screenWidth - (32 * 2) - (FONT_PREVIEW.PADDING * 2))
	local height = #textLines * previewFont:getHeight() + (FONT_PREVIEW.PADDING * 2)
	return height
end

-- Helper function to calculate the maximum preview height across all fonts
local function calculateMaxPreviewHeight()
	if maxPreviewHeight then
		return maxPreviewHeight
	end

	local maxHeight = 0
	for _, fontChoice in ipairs(fonts.themeDefinitions) do
		local height = calculatePreviewHeight(fontChoice.name)
		maxHeight = math.max(maxHeight, height)
	end

	maxPreviewHeight = maxHeight
	return maxHeight
end

local function createMenuButtons()
	local buttons = {}
	for _, fontItem in ipairs(fonts.themeDefinitions) do
		table.insert(
			buttons,
			Button:new({
				text = fontItem.name,
				screenWidth = state.screenWidth,
				onClick = function()
					state.fontFamily = fontItem.name
					screens.switchTo("main_menu")
				end,
			})
		)
	end
	return buttons
end

function font.draw()
	background.draw()

	headerInstance:draw()

	-- Make sure we restore the default UI font for the button list
	love.graphics.setFont(fonts.loaded.body)

	-- Ensure controls HEIGHT is calculated
	controls.calculateHeight()

	-- Use the currently focused font for preview
	local hoveredFontName = nil
	if menuList and menuList.selectedIndex and menuList.items[menuList.selectedIndex] then
		hoveredFontName = menuList.items[menuList.selectedIndex].text
	end

	-- Calculate the maximum preview height for fixed positioning
	local calculatedMaxPreviewHeight = calculateMaxPreviewHeight()
	local previewY = state.screenHeight
		- controls.calculateHeight()
		- calculatedMaxPreviewHeight
		- FONT_PREVIEW.PREVIEW_BOTTOM_MARGIN

	-- Draw the list using our list component
	if menuList then
		-- Use fixed list height based on maximum preview height
		menuList.height = previewY - headerInstance:getContentStartY() - 8
		menuList:calculateDimensions()
		menuList:draw()
	end

	-- Always draw preview background with maximum height for consistency
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle(
		"fill",
		32,
		previewY,
		state.screenWidth - (32 * 2),
		calculatedMaxPreviewHeight,
		FONT_PREVIEW.PREVIEW_BG_CORNER_RADIUS
	)

	-- Draw preview text if we have a font selected
	if hoveredFontName then
		-- Get the font for preview
		local previewFont = getPreviewFont(hoveredFontName)

		-- Draw the actual preview with the selected font
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setFont(previewFont)
		love.graphics.printf(
			FONT_PREVIEW.PREVIEW_TEXT,
			32 + FONT_PREVIEW.PADDING,
			previewY + FONT_PREVIEW.PADDING,
			state.screenWidth - (32 * 2) - (FONT_PREVIEW.PADDING * 2),
			"left"
		)
	end

	-- Draw controls
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()

	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle(
		"line",
		32,
		previewY,
		state.screenWidth - (32 * 2),
		calculatedMaxPreviewHeight,
		FONT_PREVIEW.PREVIEW_BG_CORNER_RADIUS
	)
end

function font.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, input)
		menuList:update(dt)
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function font.onEnter()
	-- Create menu list
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 120,
		items = createMenuButtons(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
	})

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function font.onExit()
	-- No-op for now
end

return font
