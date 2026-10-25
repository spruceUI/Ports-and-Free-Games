--- Slider UI component (Component-based)
local love = require("love")
local colors = require("colors")
local tween = require("tween")
local component = require("ui.component")
local InputManager = require("ui.controllers.input_manager")

local Slider = setmetatable({}, { __index = component.Component })
Slider.__index = Slider

Slider.HEIGHT = 30
Slider.PADDING = 18
Slider.TRACK_HEIGHT = 8
Slider.HANDLE_WIDTH = 14
Slider.HANDLE_HEIGHT = 32
Slider.CORNER_RADIUS = 8
Slider.TICK_HEIGHT = 10
Slider.TICK_WIDTH = 2
Slider.LABEL_GAP = 8 -- vertical gap between label and track

-- Focus background constants
Slider.FOCUS_BACKGROUND_TOP_MARGIN = 12
Slider.FOCUS_BACKGROUND_BOTTOM_MARGIN = 12

-- Label positioning constants
Slider.LABEL_LEFT_PADDING = 12

-- Handle shadow constants
Slider.HANDLE_SHADOW_OFFSET_X = 1
Slider.HANDLE_SHADOW_OFFSET_Y = 1

-- Tick positioning constants
Slider.TICK_VERTICAL_OFFSET = 2

-- Component padding constants
Slider.BOTTOM_PADDING = 10

Slider.TWEEN_DURATION = 0.1 -- Duration in seconds for slider animation
Slider.TWEEN_EASING = "outQuad" -- Easing function for slider animation

function Slider.new(_, config)
	local instance = setmetatable(component.Component:new(config), Slider)
	instance.x = config.x or 0
	instance.y = config.y or 0
	instance.width = config.width or 200
	instance.values = config.values or { 0, 100 }
	instance.valueIndex = config.valueIndex or 1
	instance.label = config.label
	instance.onValueChanged = config.onValueChanged
	instance.valueFormatter = config.valueFormatter -- Custom formatter function
	instance.animatedValue = instance.valueIndex
	instance.currentTween = nil
	instance.height = instance:getHeight()
	return instance
end

function Slider:setValueIndex(idx, animate)
	idx = math.max(1, math.min(#self.values, idx))
	if animate then
		if math.abs(self.animatedValue - idx) > 0.01 then
			self.currentTween = tween.new(Slider.TWEEN_DURATION, self, { animatedValue = idx }, Slider.TWEEN_EASING)
			self._pendingValueIndex = idx -- Store for callback after animation
		else
			self.animatedValue = idx
			self.currentTween = nil
			self.valueIndex = idx
			if self.onValueChanged then
				self.onValueChanged(self.values[self.valueIndex], self.valueIndex)
			end
		end
	else
		self.animatedValue = idx
		self.currentTween = nil
		self.valueIndex = idx
		if self.onValueChanged then
			self.onValueChanged(self.values[self.valueIndex], self.valueIndex)
		end
	end
end

function Slider:update(dt)
	if self.currentTween then
		local completed = self.currentTween:update(dt)
		if completed then
			self.currentTween = nil
			if self._pendingValueIndex then
				self.valueIndex = self._pendingValueIndex
				self._pendingValueIndex = nil
				if self.onValueChanged then
					self.onValueChanged(self.values[self.valueIndex], self.valueIndex)
				end
			end
		end
	end
end

function Slider:getHeight()
	local labelHeight = love.graphics.getFont():getHeight()
	return Slider.FOCUS_BACKGROUND_TOP_MARGIN
		+ labelHeight
		+ Slider.LABEL_GAP
		+ math.max(Slider.HANDLE_HEIGHT, Slider.TRACK_HEIGHT)
		+ Slider.TICK_VERTICAL_OFFSET
		+ Slider.TICK_HEIGHT
		+ Slider.BOTTOM_PADDING
		+ Slider.FOCUS_BACKGROUND_BOTTOM_MARGIN
end

function Slider:draw()
	if not self.values or #self.values == 0 then
		return
	end
	love.graphics.push("all")
	if self.focused then
		self:drawBackground({
			cornerRadius = Slider.CORNER_RADIUS,
		})
	end
	local clampedCurrentIndex = math.max(1, math.min(self.valueIndex, #self.values))
	local font = love.graphics.getFont()
	local labelHeight = font:getHeight()
	local currentY = self.y + Slider.FOCUS_BACKGROUND_TOP_MARGIN
	-- Draw label (left) and value (right)
	if self.label then
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.print(self.label, self.x + Slider.LABEL_LEFT_PADDING, currentY)
	end
	local currentValue = self.values[clampedCurrentIndex]
	local valueText = self.valueFormatter and self.valueFormatter(currentValue) or tostring(currentValue)
	local textWidth = font:getWidth(valueText)
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.print(valueText, self.x + self.width - Slider.PADDING - textWidth, currentY)
	currentY = currentY + labelHeight + Slider.LABEL_GAP
	-- Draw track
	local trackX = self.x + Slider.PADDING
	local trackY = currentY + (math.max(Slider.HANDLE_HEIGHT, Slider.TRACK_HEIGHT) - Slider.TRACK_HEIGHT) / 2
	local trackWidth = self.width - (Slider.PADDING * 2)
	local trackBackgroundColor = self.focused and colors.ui.overlay or colors.ui.surface
	love.graphics.setColor(trackBackgroundColor)
	love.graphics.rectangle("fill", trackX, trackY, trackWidth, Slider.TRACK_HEIGHT, Slider.TRACK_HEIGHT / 2)
	-- Draw ticks
	love.graphics.setColor(colors.ui.overlay)
	for i = 1, #self.values do
		local tickX = trackX + ((i - 1) / math.max(1, #self.values - 1)) * trackWidth - (Slider.TICK_WIDTH / 2)
		local tickY = trackY + Slider.TRACK_HEIGHT + Slider.TICK_VERTICAL_OFFSET
		love.graphics.rectangle("fill", tickX, tickY, Slider.TICK_WIDTH, Slider.TICK_HEIGHT, 1)
	end
	-- Draw fill
	local rawPercent = (self.animatedValue - 1) / math.max(1, #self.values - 1)
	local percent = math.max(0, math.min(1, rawPercent))
	local fillWidth = trackWidth * percent
	love.graphics.setColor(colors.ui.accent)
	love.graphics.rectangle("fill", trackX, trackY, fillWidth, Slider.TRACK_HEIGHT, Slider.TRACK_HEIGHT / 2)
	-- Draw handle
	local handlePercent = (self.animatedValue - 1) / math.max(1, #self.values - 1)
	local clampedHandlePercent = math.max(0, math.min(1, handlePercent))
	local handleX = trackX + trackWidth * clampedHandlePercent - (Slider.HANDLE_WIDTH / 2)
	local handleY = currentY + (math.max(Slider.HANDLE_HEIGHT, Slider.TRACK_HEIGHT) - Slider.HANDLE_HEIGHT) / 2
	love.graphics.setColor(0, 0, 0, 0.3)
	love.graphics.rectangle(
		"fill",
		handleX + Slider.HANDLE_SHADOW_OFFSET_X,
		handleY + Slider.HANDLE_SHADOW_OFFSET_Y,
		Slider.HANDLE_WIDTH,
		Slider.HANDLE_HEIGHT,
		Slider.CORNER_RADIUS
	)
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.rectangle("fill", handleX, handleY, Slider.HANDLE_WIDTH, Slider.HANDLE_HEIGHT, Slider.CORNER_RADIUS)
	love.graphics.pop()
end

function Slider:handleInput(input)
	if self.currentTween then
		return false -- Ignore input while animating
	end
	if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_LEFT) then
		self:setValueIndex(self.valueIndex - 1, true)
		return true
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_RIGHT) then
		self:setValueIndex(self.valueIndex + 1, true)
		return true
	end
	return false
end


return {
	Slider = Slider,
}
