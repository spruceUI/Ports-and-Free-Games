--- Modal UI module
--- This file contains code for drawing modal dialogs throughout the application
local love = require("love")
local colors = require("colors")
local Component = require("ui.component").Component
local InputManager = require("ui.controllers.input_manager")
local constants = require("ui.components.constants")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local FocusManager = require("ui.controllers.focus_manager")

local Modal = setmetatable({}, { __index = Component })
Modal.__index = Modal

-- Configurable button horizontal padding (space between modal edge and button)
local BUTTON_HORIZONTAL_PADDING = 32
-- Configurable space outside single button in single-button modals
local SINGLE_BUTTON_SIDE_SPACE = 16

function Modal:new(config)
	local instance = Component.new(self, config or {})
	instance.visible = false
	instance.message = ""
	instance.progressMessage = ""
	instance.progressHistory = {} -- Store multiple progress messages
	instance.buttons = {}
	instance.focusManager = FocusManager:new()
	instance.font = config and config.font or love.graphics.getFont()
	instance.onButtonPress = config and config.onButtonPress or nil
	instance.showAnimation = false
	instance.isProgressModal = false
	instance.useFixedWidth = false
	instance.fixedWidth = 0
	instance.animationTime = 0
	return instance
end

function Modal:show(message, buttons, options)
	self.visible = true
	self.message = message and message:match("^%s*(.-)%s*$") or ""
	self.buttons = {}
	self.focusManager = FocusManager:new()
	if buttons and #buttons > 0 then
		for i, btnConfig in ipairs(buttons) do
			local btn = Button:new({
				text = btnConfig.text,
				onClick = btnConfig.onSelect,
				type = ButtonTypes.ACCENTED, -- Always use ACCENTED type
				fullWidth = true,
			})
			table.insert(self.buttons, btn)
			self.focusManager:registerComponent(btn)
		end
		-- Focus the first button, or the 'Exit' button if present
		local focusIndex = 1
		for i, btn in ipairs(self.buttons) do
			if btn.text and tostring(btn.text):lower() == "exit" then
				focusIndex = i
				break
			end
		end
		self.focusManager:setFocused(self.buttons[focusIndex])
	end
	self.scrollPosition = 0
	options = options or {}
	self.isProgressModal = (#self.buttons == 0)
		and not options.forceSimple
		and (
			string.find(self.message:lower(), "creating")
			or string.find(self.message:lower(), "applying")
			or string.find(self.message:lower(), "installing")
			or string.find(self.message:lower(), "loading")
			or string.find(self.message:lower(), "preparing")
			or string.find(self.message:lower(), "download")
			or string.find(self.message:lower(), "connecting")
		)
	if not self.isProgressModal then
		self.progressMessage = ""
		self.progressHistory = {}
	else
		self.progressHistory = {}
	end
	self.showAnimation = self.isProgressModal
	if self.showAnimation then
		self.animationTime = 0
	end
end

function Modal:updateProgress(progressText, _percent)
	if self.isProgressModal and progressText then
		self.progressMessage = progressText

		-- Add to history and maintain maximum of 4 lines
		table.insert(self.progressHistory, progressText)
		if #self.progressHistory > 4 then
			table.remove(self.progressHistory, 1) -- Remove oldest message
		end
	elseif progressText then
		-- Force progress modal mode if it wasn't detected
		self.isProgressModal = true
		self.showAnimation = true
		self.progressMessage = progressText
		table.insert(self.progressHistory, progressText)
	end
end

-- Function to set fixed width (height will be auto-calculated)
function Modal:setFixedWidth(width)
	self.useFixedWidth = true
	self.fixedWidth = width
end

function Modal:hide()
	self.visible = false
	self.showAnimation = false
	self.animationTime = 0
	self.progressMessage = ""
	self.progressHistory = {}
	self.isProgressModal = false
	-- Reset fixed width when hiding the modal
	self.useFixedWidth = false
	self.fixedWidth = 0
end

function Modal:isVisible()
	return self.visible
end

function Modal:getButtons()
	return self.buttons
end

function Modal:getMessage()
	return self.message
end

function Modal:update(dt)
	if self.showAnimation then
		self.animationTime = self.animationTime + dt
	end
	-- Update all buttons (for animation, etc.)
	for _, button in ipairs(self.buttons) do
		if button.update then
			button:update(dt)
		end
	end
end

function Modal:handleInput(input)
	if not self.visible then
		return false
	end

	local screenWidth, screenHeight = love.graphics.getDimensions()
	local controls = require("control_hints").ControlHints
	local fonts = require("ui.fonts")
	local controlsHeight = controls.calculateHeight()
	local padding = 40
	local maxWidth = screenWidth * 0.9
	local currentFont = self.font or love.graphics.getFont()
	local useErrorFont = false
	if self.message and type(self.message) == "string" then
		local msg = self.message:lower()
		if msg:find("error") or msg:find("failed") then
			useErrorFont = true
		end
	end
	if useErrorFont and fonts.loaded and fonts.loaded.error then
		currentFont = fonts.loaded.error
	end
	local estimatedTextWidth = math.min(screenWidth * 0.8, maxWidth) - (padding * 2)
	local _, mainMessageLines = currentFont:getWrap(self.message, estimatedTextWidth)
	local mainMessageHeight = #mainMessageLines * currentFont:getHeight()
	local contentHeight = mainMessageHeight
	if self.isProgressModal then
		local progressBoxPadding = 12
		local consoleFont = fonts.loaded and fonts.loaded.console or currentFont
		local lineHeight = consoleFont:getHeight()
		local minConsoleLines = 4
		local progressMessageHeight = lineHeight * minConsoleLines
		local progressBoxHeight = progressMessageHeight + (progressBoxPadding * 2)
		contentHeight = contentHeight + 20 + progressBoxHeight
	end
	local maxTextHeight = screenHeight * 0.6
	local modalWidth, modalHeight
	if self.useFixedWidth and self.fixedWidth > 0 then
		modalWidth = self.fixedWidth
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = 0
		if #self.buttons > 0 then
			buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		end
		modalHeight = contentHeight + (padding * 2) + buttonsExtraHeight
		local maxAvailableHeight = screenHeight - controlsHeight - 20
		if modalHeight > maxAvailableHeight then
			modalHeight = maxAvailableHeight
		end
	else
		local minWidth = math.min(screenWidth * 0.8, maxWidth)
		if #self.buttons == 0 then
			minWidth = math.min(currentFont:getWidth(self.message) + (padding * 2), maxWidth)
		end
		local visibleHeight = math.min(maxTextHeight, contentHeight)
		modalWidth = minWidth
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = 0
		if #self.buttons > 0 then
			buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		end
		modalHeight = visibleHeight + (padding * 2) + buttonsExtraHeight
		local maxAvailableHeight = screenHeight - controlsHeight - 20
		if modalHeight > maxAvailableHeight then
			modalHeight = maxAvailableHeight
		end
	end
	local availableTextWidth = modalWidth - (padding * 2)
	local visibleHeight = modalHeight - (padding * 2)
	if #self.buttons > 0 then
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		visibleHeight = visibleHeight - buttonsExtraHeight
	end
	local isScrollable, maxScrollPosition = self:isContentScrollable(visibleHeight, currentFont, availableTextWidth)

	if isScrollable then
		if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_UP) then
			self:scroll(-40, maxScrollPosition)
			return true
		elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_DOWN) then
			self:scroll(40, maxScrollPosition)
			return true
		end
	end

	if #self.buttons > 0 then
		local navDir = nil
		if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_UP) then
			navDir = "up"
		elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_DOWN) then
			navDir = "down"
		end
		if navDir then
			self.focusManager:handleInput(navDir, input)
			return true
		end
		local focused = self.focusManager:getFocused()
		if InputManager.isActionJustPressed(InputManager.ACTIONS.CONFIRM) then
			if focused and focused.onClick then
				focused:onClick()
			end
			if self.onButtonPress then
				self.onButtonPress(focused)
			end
			return true
		end
	end
	return false
end

-- Helper method to determine if content is scrollable and max scroll position
function Modal:isContentScrollable(visibleHeight, font, wrapWidth)
	font = font or love.graphics.getFont()
	wrapWidth = wrapWidth or 0
	local _, mainMessageLines = font:getWrap(self.message, wrapWidth)
	local contentHeight = #mainMessageLines * font:getHeight()
	visibleHeight = visibleHeight or 0
	local maxScrollPosition = math.max(0, contentHeight - visibleHeight)
	return contentHeight > visibleHeight, maxScrollPosition, contentHeight
end

-- Helper method to handle scrolling
function Modal:scroll(amount, maxScrollPosition)
	self.scrollPosition = self.scrollPosition + amount
	maxScrollPosition = maxScrollPosition or 0
	self.scrollPosition = math.max(0, math.min(self.scrollPosition, maxScrollPosition))
end

function Modal:draw(screenWidth, screenHeight, font)
	if not self.visible then
		return
	end

	local controls = require("control_hints").ControlHints
	local fonts = require("ui.fonts")
	local controlsHeight = controls.calculateHeight()
	local padding = 40
	local maxWidth = screenWidth * 0.9

	-- Use error font for error/failure messages
	local useErrorFont = false
	if self.message and type(self.message) == "string" then
		local msg = self.message:lower()
		if msg:find("error") or msg:find("failed") then
			useErrorFont = true
		end
	end
	local currentFont = font or self.font or love.graphics.getFont()
	if useErrorFont and fonts.loaded.error then
		currentFont = fonts.loaded.error
	end

	love.graphics.push("all")
	love.graphics.setFont(currentFont)

	local estimatedTextWidth = math.min(screenWidth * 0.8, maxWidth) - (padding * 2)
	local _, mainMessageLines = currentFont:getWrap(self.message, estimatedTextWidth)
	local mainMessageHeight = #mainMessageLines * currentFont:getHeight()

	local progressBoxHeight = 0
	local progressBoxPadding = 12
	if self.isProgressModal then
		local consoleFont = fonts.loaded.console or currentFont
		local lineHeight = consoleFont:getHeight()
		local minConsoleLines = 4
		local progressMessageHeight = lineHeight * minConsoleLines
		progressBoxHeight = progressMessageHeight + (progressBoxPadding * 2)
	end

	local contentHeight = mainMessageHeight
	if self.isProgressModal then
		contentHeight = contentHeight + 20
		contentHeight = contentHeight + progressBoxHeight
	end

	local maxTextHeight = screenHeight * 0.6
	local modalWidth, modalHeight
	if self.useFixedWidth and self.fixedWidth > 0 then
		modalWidth = self.fixedWidth
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = 0
		if #self.buttons > 0 then
			buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		end
		modalHeight = contentHeight + (padding * 2) + buttonsExtraHeight
		local maxAvailableHeight = screenHeight - controlsHeight - 20
		if modalHeight > maxAvailableHeight then
			modalHeight = maxAvailableHeight
		end
	else
		local minWidth = math.min(screenWidth * 0.8, maxWidth)
		if #self.buttons == 0 then
			minWidth = math.min(currentFont:getWidth(self.message) + (padding * 2), maxWidth)
		end
		local visibleHeight = math.min(maxTextHeight, contentHeight)
		modalWidth = minWidth
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = 0
		if #self.buttons > 0 then
			buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		end
		modalHeight = visibleHeight + (padding * 2) + buttonsExtraHeight
		local maxAvailableHeight = screenHeight - controlsHeight - 20
		if modalHeight > maxAvailableHeight then
			modalHeight = maxAvailableHeight
		end
	end

	local availableTextWidth = modalWidth - (padding * 2)
	local visibleHeight = modalHeight - (padding * 2)
	if #self.buttons > 0 then
		local buttonHeight = 40
		local buttonSpacing = 20
		local buttonsExtraHeight = (#self.buttons * buttonHeight) + ((#self.buttons - 1) * buttonSpacing) + padding
		visibleHeight = visibleHeight - buttonsExtraHeight
	end

	local x = (screenWidth - modalWidth) / 2
	local y = (screenHeight - modalHeight - controlsHeight) / 2

	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 0.9)
	love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
	love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1)
	love.graphics.rectangle("fill", x, y, modalWidth, modalHeight, 10)
	love.graphics.setColor(colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 1)
	love.graphics.setLineWidth(2)
	love.graphics.rectangle("line", x, y, modalWidth, modalHeight, 10)

	-- Use new scrollable logic
	local isScrollable, maxScrollPosition, actualContentHeight =
		self:isContentScrollable(visibleHeight, currentFont, availableTextWidth)
	self.scrollPosition = math.max(0, math.min(self.scrollPosition, maxScrollPosition))

	if isScrollable then
		local textAreaX = x + padding
		local textAreaY = y + padding
		local textAreaWidth = availableTextWidth
		love.graphics.setScissor(textAreaX, textAreaY, textAreaWidth, visibleHeight)
		love.graphics.push()
		love.graphics.translate(0, -self.scrollPosition)
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
		love.graphics.printf(self.message, textAreaX, textAreaY, textAreaWidth, "left")
		love.graphics.pop()
		love.graphics.setScissor()

		local scrollbarHeight = visibleHeight
		local scrollbarX = x + modalWidth - constants.SCROLLBAR.WIDTH - constants.SCROLLBAR.PADDING
		local scrollbarY = y + padding
		local trackHeight = scrollbarHeight
		local handleHeight =
			math.max(constants.SCROLLBAR.HANDLE_MIN_HEIGHT, (visibleHeight / actualContentHeight) * trackHeight)
		local maxScroll = math.max(1, actualContentHeight - visibleHeight)
		local handleY = scrollbarY + ((self.scrollPosition / maxScroll) * (trackHeight - handleHeight))
		love.graphics.setColor(constants.SCROLLBAR.BACKGROUND_COLOR)
		love.graphics.rectangle(
			"fill",
			scrollbarX,
			scrollbarY,
			constants.SCROLLBAR.WIDTH,
			trackHeight,
			constants.SCROLLBAR.CORNER_RADIUS
		)
		love.graphics.setColor(constants.SCROLLBAR.HANDLE_COLOR)
		love.graphics.rectangle(
			"fill",
			scrollbarX,
			handleY,
			constants.SCROLLBAR.WIDTH,
			handleHeight,
			constants.SCROLLBAR.CORNER_RADIUS
		)
	end

	if not isScrollable then
		local textY = y + padding
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
		love.graphics.printf(self.message, x + padding, textY, availableTextWidth, "center")
		if self.isProgressModal then
			local progressY = textY + mainMessageHeight + 20
			local consoleFont = fonts.loaded.console or currentFont
			local progressBoxX = x + padding
			local progressBoxWidth = availableTextWidth
			local actualProgressBoxHeight = progressBoxHeight
			love.graphics.setColor(
				colors.ui.background[1] * 0.7,
				colors.ui.background[2] * 0.7,
				colors.ui.background[3] * 0.7,
				1
			)
			love.graphics.rectangle("fill", progressBoxX, progressY, progressBoxWidth, actualProgressBoxHeight, 5)
			love.graphics.setFont(consoleFont)
			love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
			local lineHeight = consoleFont:getHeight()
			local minConsoleLines = 4
			local startY = progressY + progressBoxPadding

			local wrapWidth = progressBoxWidth - progressBoxPadding * 2
			local allLines = {}
			for _, historyMessage in ipairs(self.progressHistory) do
				local _, lines = consoleFont:getWrap(historyMessage, wrapWidth)
				for _, line in ipairs(lines) do
					table.insert(allLines, line)
				end
			end
			local N = minConsoleLines
			local displayLines = {}
			local totalLines = #allLines
			if totalLines >= N then
				for i = totalLines - N + 1, totalLines do
					table.insert(displayLines, allLines[i])
				end
			else
				for i = 1, N - totalLines do
					table.insert(displayLines, "")
				end
				for i = 1, totalLines do
					table.insert(displayLines, allLines[i])
				end
			end
			for i = 1, N do
				local line = displayLines[i]
				local y = startY + (i - 1) * lineHeight
				love.graphics.printf(line, progressBoxX + progressBoxPadding, y, wrapWidth, "left")
			end
			love.graphics.setFont(currentFont)
		end
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], 1)
	end

	if #self.buttons == 0 then
		love.graphics.pop()
		return
	end

	local buttonInset = 40 -- Space between button and modal edge
	local buttonWidth = modalWidth - (buttonInset * 2)
	local buttonX = x + buttonInset
	local startButtonY
	if isScrollable then
		startButtonY = y + padding + visibleHeight + padding
	else
		startButtonY = y + padding + contentHeight + padding
	end
	local buttonHeight = 40
	local buttonSpacing = 20
	for i, button in ipairs(self.buttons) do
		local buttonY = startButtonY + ((i - 1) * (buttonHeight + buttonSpacing))
		button.x = buttonX
		button.y = buttonY
		button.width = buttonWidth
		button.height = buttonHeight
		button:draw()
	end
	love.graphics.pop()
end

return {
	Modal = Modal,
}
