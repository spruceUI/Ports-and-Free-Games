--- Button component

local love = require("love")

local colors = require("colors")
local tween = require("tween")

local Component = require("ui.component").Component
local fonts = require("ui.fonts")
local GradientPreview = require("ui.components.gradient_preview")
local InputManager = require("ui.controllers.input_manager")

local colorUtils = require("utils.color")
local logger = require("utils.logger")
local svg = require("utils.svg")

local gradientPreviewInstance = GradientPreview:new({})

-- Button constants
local BUTTON_CONFIG = {
	VERTICAL_PADDING = 12,
	HORIZONTAL_PADDING = 14,
	EDGE_MARGIN = 16,
	CORNER_RADIUS = 8,
	SPACING = 12,
}

local ICON_SIZE = 14
local ICON_BUTTON_ICON_SIZE = 24
local COLOR_DISPLAY_SIZE = 30
local CHEVRON_PADDING = 16

-- Button types
local BUTTON_TYPES = {
	BASIC = "basic",
	COLOR = "color",
	GRADIENT = "gradient",
	TEXT_PREVIEW = "text_preview",
	INDICATORS = "indicators",
	ACCENTED = "accented",
	DUAL_COLOR = "dual_color",
	KEY = "key",
	ICON = "icon",
	CHECKBOX = "checkbox", -- Added checkbox type
}

-- Preload icons for checkboxes
local SQUARE = svg.loadIcon("square", 24)
local SQUARE_CHECK_ICON = svg.loadIcon("square-check", 24)
local CHEVRON_LEFT = svg.loadIcon("chevron-left", ICON_SIZE)
local CHEVRON_RIGHT = svg.loadIcon("chevron-right", ICON_SIZE)

-- Button class
local Button = setmetatable({}, { __index = Component })
Button.__index = Button

-- Pulse animation config
local PULSE_SCALE_MIN = 1.0
local PULSE_SCALE_MAX = 1.02
local PULSE_DURATION = 1.1

function Button:new(config)
	-- Initialize base component
	local instance = Component.new(self, config)

	-- Button-specific properties
	instance.text = config.text or ""
	instance.type = config.type or BUTTON_TYPES.BASIC
	instance.disabled = config.disabled or false

	-- Visual properties
	instance.hexColor = config.hexColor
	instance.displayText = config.displayText
	instance.color1Hex = config.color1Hex
	instance.color2Hex = config.color2Hex
	instance.startColor = config.startColor
	instance.stopColor = config.stopColor
	instance.direction = config.direction or "Vertical"
	instance.previewText = config.previewText
	instance.monoFont = config.monoFont
	instance.iconName = config.iconName
	instance.iconSize = config.iconSize or ICON_SIZE
	instance.accent = config.accent or false -- Accent property for KEY type

	-- Options for cycling
	instance.options = config.options
	instance.currentOptionIndex = config.currentOptionIndex or 1

	-- Context for state management
	instance.context = config.context

	-- Layout
	instance.screenWidth = config.screenWidth or love.graphics.getWidth()
	instance.fullWidth = config.fullWidth ~= false

	-- Custom size support
	instance.height = config.height -- may be nil
	instance.width = config.width -- may be nil

	-- Calculate dimensions (will use custom height/width if set)
	instance:calculateDimensions()

	-- Animation state for pulsing
	instance._pulseScale = 1.0
	instance._pulseTween = nil
	instance._pulseDirection = 1 -- 1: up, -1: down

	return instance
end

function Button:calculateDimensions()
	local font = love.graphics.getFont()
	if self.fullWidth then
		if not self.height then
			self.height = font:getHeight() + (BUTTON_CONFIG.VERTICAL_PADDING * 2)
		end
		self.width = self.screenWidth - (BUTTON_CONFIG.EDGE_MARGIN * 2)
		self.x = BUTTON_CONFIG.EDGE_MARGIN
	else
		-- For fullWidth == false, do not override x, y, width, height
		-- If width/height are not set, fallback to minimum size
		if not self.width then
			self.width = font:getWidth(self.text) + (BUTTON_CONFIG.HORIZONTAL_PADDING * 2)
		end
		if not self.height then
			self.height = font:getHeight() + (BUTTON_CONFIG.VERTICAL_PADDING * 2)
		end
	end
end

function Button:setFocused(focused)
	Component.setFocused(self, focused)
	if self.type == BUTTON_TYPES.ACCENTED then
		if focused and not self._pulseTween then
			self:_startPulseTween(1)
		elseif not focused and self._pulseTween then
			self:_stopPulseTween()
			self._pulseScale = 1.0
		end
	end
end

function Button:_startPulseTween(direction)
	self._pulseDirection = direction or 1
	local toScale = (self._pulseDirection == 1) and PULSE_SCALE_MAX or PULSE_SCALE_MIN
	self._pulseTween = tween.new(PULSE_DURATION / 2, self, { _pulseScale = toScale }, "inOutSine")
end

function Button:_stopPulseTween()
	self._pulseTween = nil
end

function Button:update(dt)
	if self.type == BUTTON_TYPES.ACCENTED and self.focused and self._pulseTween then
		local complete = self._pulseTween:update(dt)
		if complete then
			-- Reverse direction and start again for continuous pulse
			self:_startPulseTween(-self._pulseDirection)
		end
	end
	Component.update(self, dt)
end

function Button:getText()
	return self.text
end

function Button:setText(text)
	self.text = text or ""
end

function Button:getPreviewText()
	return self.previewText
end

function Button:setPreviewText(text)
	self.previewText = text
end

function Button:getCurrentOption()
	if self.options and self.currentOptionIndex then
		return self.options[self.currentOptionIndex]
	end
	return nil
end

function Button:cycleOption(direction)
	if not self.options or #self.options == 0 then
		return false
	end

	local newIndex = self.currentOptionIndex + direction
	if newIndex > #self.options then
		newIndex = 1
	elseif newIndex < 1 then
		newIndex = #self.options
	end

	if newIndex ~= self.currentOptionIndex then
		self.currentOptionIndex = newIndex
		return true
	end

	return false
end

function Button:handleInput(input)
	if not self.enabled or self.disabled then
		return false
	end

	local handled = false

	-- Handle option cycling for indicator buttons
	if self.type == BUTTON_TYPES.INDICATORS and self.focused then
		if InputManager.isActionPressed(InputManager.ACTIONS.NAVIGATE_LEFT) then
			handled = self:cycleOption(-1)
		elseif InputManager.isActionPressed(InputManager.ACTIONS.NAVIGATE_RIGHT) then
			handled = self:cycleOption(1)
		end
	end

	-- Handle selection
	if InputManager.isActionPressed(InputManager.ACTIONS.CONFIRM) and self.focused then
		if self.onClick then
			self.onClick(self)
		end
		handled = true
	end

	return handled
end

function Button:drawBackground()
	Component.drawBackground(self)
end

function Button:drawText()
	local font = love.graphics.getFont()
	local textHeight = font:getHeight()
	local opacity = self.disabled and 0.3 or 1

	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(self.text, self.x + BUTTON_CONFIG.HORIZONTAL_PADDING, self.y + (self.height - textHeight) / 2)
end

function Button:drawBasic()
	self:drawBackground()
	self:drawText()
end

function Button:drawTextPreview()
	self:drawBackground()
	self:drawText()

	if self.previewText then
		local font = love.graphics.getFont()
		local textWidth = font:getWidth(self.previewText)
		local textY = self.y + (self.height - font:getHeight()) / 2
		local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING

		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(self.previewText, rightEdge - textWidth, textY)
	end
end

function Button:drawIndicators()
	self:drawBackground()
	self:drawText()

	local valueText = self:getCurrentOption()
	if self.displayText then
		valueText = self.displayText(valueText) -- e.g. 0 -> "Disabled"
	end
	valueText = tostring(valueText)
	if not valueText then
		return
	end

	local font = love.graphics.getFont()
	local textWidth = font:getWidth(valueText)
	local totalWidth = textWidth + (ICON_SIZE + CHEVRON_PADDING) * 2
	local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING
	local valueX = rightEdge - totalWidth
	local iconY = self.y + self.height / 2
	local opacity = self.disabled and 0.3 or 1

	local leftChevron, rightChevron = CHEVRON_LEFT, CHEVRON_RIGHT

	-- Draw value text
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(valueText, valueX + ICON_SIZE + CHEVRON_PADDING, self.y + (self.height - font:getHeight()) / 2)

	-- Draw chevron icons
	if leftChevron then
		svg.drawIcon(leftChevron, valueX + ICON_SIZE / 2, iconY, colors.ui.foreground, opacity)
	end
	if rightChevron then
		svg.drawIcon(rightChevron, rightEdge - ICON_SIZE / 2, iconY, colors.ui.foreground, opacity)
	end
end

function Button:drawColor()
	self:drawBackground()
	self:drawText()

	if not self.hexColor then
		return
	end

	local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING
	local colorX = rightEdge - COLOR_DISPLAY_SIZE
	local colorY = self.y + (self.height - COLOR_DISPLAY_SIZE) / 2
	local opacity = self.disabled and 0.5 or 1

	-- Draw color square
	local r, g, b = colorUtils.hexToRgb(self.hexColor)
	love.graphics.setColor(r, g, b, opacity)
	love.graphics.rectangle(
		"fill",
		colorX,
		colorY,
		COLOR_DISPLAY_SIZE,
		COLOR_DISPLAY_SIZE,
		BUTTON_CONFIG.CORNER_RADIUS / 2
	)

	-- Draw border
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle(
		"line",
		colorX,
		colorY,
		COLOR_DISPLAY_SIZE,
		COLOR_DISPLAY_SIZE,
		BUTTON_CONFIG.CORNER_RADIUS / 2
	)

	-- Draw hex code
	local originalFont = love.graphics.getFont()
	if self.monoFont then
		love.graphics.setFont(self.monoFont)
	end

	local hexWidth = love.graphics.getFont():getWidth(self.hexColor)
	love.graphics.print(
		self.hexColor,
		colorX - hexWidth - 10,
		self.y + (self.height - love.graphics.getFont():getHeight()) / 2
	)

	love.graphics.setFont(originalFont)
end

function Button:drawGradient()
	self:drawBackground()
	self:drawText()

	if not (self.startColor and self.stopColor) then
		return
	end

	local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING
	local colorX = rightEdge - COLOR_DISPLAY_SIZE
	local colorY = self.y + (self.height - COLOR_DISPLAY_SIZE) / 2
	local opacity = self.disabled and 0.5 or 1

	-- Draw gradient square
	local cornerRadius = BUTTON_CONFIG.CORNER_RADIUS / 2
	gradientPreviewInstance:drawSquare(
		colorX,
		colorY,
		COLOR_DISPLAY_SIZE,
		self.startColor,
		self.stopColor,
		self.direction,
		cornerRadius
	)

	-- Draw gradient text
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)

	local originalFont = love.graphics.getFont()
	if self.monoFont then
		love.graphics.setFont(self.monoFont)
	end

	local gradientText = self.startColor .. " → " .. self.stopColor
	local textWidth = love.graphics.getFont():getWidth(gradientText)
	love.graphics.print(
		gradientText,
		colorX - textWidth - 10,
		self.y + (self.height - love.graphics.getFont():getHeight()) / 2
	)

	love.graphics.setFont(originalFont)
end

function Button:drawAccented()
	local font = fonts.loaded.body
	love.graphics.setFont(font)
	local textWidth = font:getWidth(self.text)
	local buttonWidth = self.width -- Use modal-provided width
	local buttonX = self.x -- Use modal-provided x
	local scale = (self.focused and self._pulseScale) or 1.0
	local cx = buttonX + buttonWidth / 2
	local cy = self.y + self.height / 2

	if self.focused then
		love.graphics.push("all")
		-- Draw vertical gradient mesh
		local topColor = colors.ui.accent_start
		local bottomColor = colors.ui.accent_stop
		local cornerRadius = BUTTON_CONFIG.CORNER_RADIUS
		local mesh = love.graphics.newMesh({
			{ 0, 0, 0, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 },
			{ buttonWidth, 0, 1, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 },
			{ buttonWidth, self.height, 1, 1, bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1 },
			{ 0, self.height, 0, 1, bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1 },
		}, "fan", "static")

		love.graphics.translate(cx, cy)
		love.graphics.scale(scale, scale)
		love.graphics.translate(-buttonWidth / 2, -self.height / 2)

		-- Use stencil to clip mesh to rounded rectangle
		love.graphics.stencil(function()
			love.graphics.rectangle("fill", 0, 0, buttonWidth, self.height, cornerRadius, cornerRadius)
		end, "replace", 1)
		love.graphics.setStencilTest("equal", 1)

		love.graphics.draw(mesh)

		love.graphics.setStencilTest()

		-- Draw outline
		love.graphics.setColor(colors.ui.accent_outline)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", 0, 0, buttonWidth, self.height, cornerRadius, cornerRadius)

		-- Draw text
		love.graphics.setColor(colors.ui.foreground)
		local textX = math.floor((buttonWidth - textWidth) / 2)
		local textY = math.floor((self.height - font:getHeight()) / 2)
		love.graphics.print(self.text, textX, textY)
		love.graphics.pop()
	else
		-- Not focused: fallback to old style
		love.graphics.push("all")
		love.graphics.setColor(colors.ui.surface_bright)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", buttonX, self.y, buttonWidth, self.height, BUTTON_CONFIG.CORNER_RADIUS)
		love.graphics.setColor(colors.ui.foreground)
		local textX = math.floor(buttonX + (buttonWidth - textWidth) / 2)
		local textY = math.floor(self.y + (self.height - font:getHeight()) / 2)
		love.graphics.print(self.text, textX, textY)
		love.graphics.pop()
	end
end

function Button:drawDualColor()
	self:drawBackground()
	self:drawText()

	if not (self.color1Hex and self.color2Hex) then
		return
	end

	local font = love.graphics.getFont()
	local originalFont = font
	if self.monoFont then
		love.graphics.setFont(self.monoFont)
		font = self.monoFont
	end

	local colorBoxWidth = COLOR_DISPLAY_SIZE
	local colorBoxHeight = COLOR_DISPLAY_SIZE
	local colorBoxSpacing = 10
	local hexSpacing = 10

	local hex1 = self.color1Hex
	local hex2 = self.color2Hex
	local hex1Width = font:getWidth(hex1)
	local hex2Width = font:getWidth(hex2)
	local previewY = self.y + (self.height - colorBoxHeight) / 2
	local hexY = self.y + (self.height - font:getHeight()) / 2
	local opacity = self.disabled and 0.5 or 1

	-- Calculate total width for right alignment
	local totalWidth = hex1Width + colorBoxWidth + hexSpacing + hex2Width + colorBoxWidth + colorBoxSpacing * 2
	local rightEdge = self.x + self.width - BUTTON_CONFIG.HORIZONTAL_PADDING
	local x = rightEdge - totalWidth

	-- Draw hex1
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(hex1, x, hexY)
	x = x + hex1Width + hexSpacing

	-- Draw color1 preview
	local r1, g1, b1 = colorUtils.hexToRgb(self.color1Hex)
	love.graphics.setColor(r1, g1, b1, opacity)
	love.graphics.rectangle("fill", x, previewY, colorBoxWidth, colorBoxHeight, BUTTON_CONFIG.CORNER_RADIUS / 2)
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", x, previewY, colorBoxWidth, colorBoxHeight, BUTTON_CONFIG.CORNER_RADIUS / 2)
	x = x + colorBoxWidth + colorBoxSpacing

	-- Draw hex2
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(hex2, x, hexY)
	x = x + hex2Width + hexSpacing

	-- Draw color2 preview
	local r2, g2, b2 = colorUtils.hexToRgb(self.color2Hex)
	love.graphics.setColor(r2, g2, b2, opacity)
	love.graphics.rectangle("fill", x, previewY, colorBoxWidth, colorBoxHeight, BUTTON_CONFIG.CORNER_RADIUS / 2)
	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.setLineWidth(1)
	love.graphics.rectangle("line", x, previewY, colorBoxWidth, colorBoxHeight, BUTTON_CONFIG.CORNER_RADIUS / 2)

	love.graphics.setFont(originalFont)
end

function Button:drawKey()
	love.graphics.push("all")
	local keyFont = fonts.loaded.body
	love.graphics.setFont(keyFont)
	if self.focused then
		if self.accent then
			-- Draw vertical accent gradient background (like ACCENTED)
			local buttonWidth = self.width
			local buttonHeight = self.height
			local x = self.x
			local y = self.y
			local topColor = colors.ui.accent_start
			local bottomColor = colors.ui.accent_stop
			local cornerRadius = BUTTON_CONFIG.CORNER_RADIUS
			local mesh = love.graphics.newMesh({
				{ 0, 0, 0, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 },
				{ buttonWidth, 0, 1, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 },
				{
					buttonWidth,
					buttonHeight,
					1,
					1,
					bottomColor[1],
					bottomColor[2],
					bottomColor[3],
					bottomColor[4] or 1,
				},
				{ 0, buttonHeight, 0, 1, bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1 },
			}, "fan", "static")
			love.graphics.push("all")
			love.graphics.translate(x, y)
			-- Use stencil to clip mesh to rounded rectangle
			love.graphics.stencil(function()
				love.graphics.rectangle("fill", 0, 0, buttonWidth, buttonHeight, cornerRadius, cornerRadius)
			end, "replace", 1)
			love.graphics.setStencilTest("equal", 1)
			love.graphics.draw(mesh)
			love.graphics.setStencilTest()
			-- Draw outline
			love.graphics.setColor(colors.ui.accent_outline)
			love.graphics.setLineWidth(2)
			love.graphics.rectangle("line", 0, 0, buttonWidth, buttonHeight, cornerRadius, cornerRadius)
			love.graphics.pop()
		else
			self:drawBackground()
		end
	else
		love.graphics.setColor(colors.ui.background_dim)
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 8)
	end
	local opacity = self.disabled and 0.3 or 1
	if self.iconName then
		local icon = svg.loadIcon(self.iconName, self.iconSize or ICON_SIZE)
		if icon then
			local centerX = self.x + self.width / 2
			local centerY = self.y + self.height / 2
			love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
			svg.drawIcon(icon, centerX, centerY, colors.ui.foreground, opacity)
		end
	else
		local textWidth = keyFont:getWidth(self.text)
		local textHeight = keyFont:getHeight()
		local textX = self.x + (self.width - textWidth) / 2
		local textY = self.y + (self.height - textHeight) / 2
		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
		love.graphics.print(self.text, textX, textY)
	end
	love.graphics.pop()
end

function Button:drawIconButton()
	self:drawBackground()
	local font = love.graphics.getFont()
	local textHeight = font:getHeight()
	local opacity = self.disabled and 0.3 or 1

	local iconName = self.iconName
	local iconSize = ICON_BUTTON_ICON_SIZE
	local iconPadding = 8
	local iconX = self.x + BUTTON_CONFIG.HORIZONTAL_PADDING
	local iconY = self.y + (self.height - iconSize) / 2
	local textX = iconX + iconSize + iconPadding
	local textY = self.y + (self.height - textHeight) / 2

	if iconName then
		local icon = svg.loadIcon(iconName, iconSize)
		if icon then
			local drawX = math.floor(iconX + iconSize / 2)
			local drawY = math.floor(iconY + iconSize / 2)
			svg.drawIcon(icon, drawX, drawY, colors.ui.foreground, opacity)
		end
	end

	love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], opacity)
	love.graphics.print(self.text, textX, textY)
end

function Button:drawCheckbox()
	local font = love.graphics.getFont()
	local boxSize = 28
	local padding = 16
	local textPadding = 12

	self:drawBackground()

	-- Calculate positions
	local boxX = self.x + padding
	local boxY = self.y + (self.height - boxSize) / 2
	local textX = boxX + boxSize + textPadding
	local textY = self.y + (self.height - font:getHeight()) / 2

	-- Draw checkbox
	if self.checked then
		if SQUARE_CHECK_ICON then
			local iconColor = colors.ui.foreground
			svg.drawIcon(SQUARE_CHECK_ICON, boxX + boxSize / 2, boxY + boxSize / 2, iconColor)
		end
	else
		if SQUARE then
			local iconColor = colors.ui.foreground
			svg.drawIcon(SQUARE, boxX + boxSize / 2, boxY + boxSize / 2, iconColor)
		end
	end

	-- Draw text
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.setFont(font)
	love.graphics.print(self.text, textX, textY)
end

function Button:draw()
	if not self.visible then
		return
	end
	love.graphics.push("all")
	if self.type == BUTTON_TYPES.BASIC then
		self:drawBasic()
	elseif self.type == BUTTON_TYPES.TEXT_PREVIEW then
		self:drawTextPreview()
	elseif self.type == BUTTON_TYPES.INDICATORS then
		self:drawIndicators()
	elseif self.type == BUTTON_TYPES.COLOR then
		self:drawColor()
	elseif self.type == BUTTON_TYPES.GRADIENT then
		self:drawGradient()
	elseif self.type == BUTTON_TYPES.ACCENTED then
		self:drawAccented()
	elseif self.type == BUTTON_TYPES.DUAL_COLOR then
		self:drawDualColor()
	elseif self.type == BUTTON_TYPES.KEY then
		self:drawKey()
	elseif self.type == BUTTON_TYPES.ICON then
		self:drawIconButton()
	elseif self.type == BUTTON_TYPES.CHECKBOX then
		self:drawCheckbox()
	else
		self:drawBasic()
	end
	love.graphics.pop()
end

-- Module exports
local button = {}
button.Button = Button
button.TYPES = BUTTON_TYPES
return button
