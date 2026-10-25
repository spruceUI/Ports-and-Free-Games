--- Gradient preview component for displaying color gradients
local love = require("love")

local colors = require("colors")

local Component = require("ui.component").Component

local colorUtils = require("utils.color")
local imageGenerator = require("utils.image_generator")

-- GradientPreview class
local GradientPreview = setmetatable({}, { __index = Component })
GradientPreview.__index = GradientPreview

function GradientPreview:new(config)
	local instance = Component.new(self, config or {})
	instance.startColor = config and config.startColor or "#000000"
	instance.stopColor = config and config.stopColor or "#FFFFFF"
	instance.direction = config and config.direction or "Vertical"
	instance.cornerRadius = config and config.cornerRadius or 0
	instance.gradientMesh = nil
	return instance
end

function GradientPreview:updateMesh(startColor, stopColor, direction)
	local startRgb = colorUtils.hexToLove(startColor or self.startColor)
	local stopRgb = colorUtils.hexToLove(stopColor or self.stopColor)
	self.gradientMesh = imageGenerator.createGradientMesh(direction or self.direction, startRgb, stopRgb)
	return self.gradientMesh
end

function GradientPreview:draw(x, y, width, height, startColor, stopColor, direction, cornerRadius)
	-- Use instance state if args not provided
	x = x or self.x
	y = y or self.y
	width = width or self.width
	height = height or self.height
	startColor = startColor or self.startColor
	stopColor = stopColor or self.stopColor
	direction = direction or self.direction
	cornerRadius = cornerRadius or self.cornerRadius

	if
		not self.gradientMesh
		or startColor ~= self.startColor
		or stopColor ~= self.stopColor
		or direction ~= self.direction
	then
		self:updateMesh(startColor, stopColor, direction)
		self.startColor = startColor
		self.stopColor = stopColor
		self.direction = direction
	end

	if not self.gradientMesh then
		return
	end

	love.graphics.push("all")

	-- Create stencil function for rounded corners if needed
	if cornerRadius and cornerRadius > 0 then
		love.graphics.stencil(function()
			love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
		end, "replace", 1)

		-- Use stencil
		love.graphics.setStencilTest("greater", 0)
	end

	-- Draw gradient preview
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(self.gradientMesh, x, y, 0, width, height)

	-- Reset stencil test and restore state
	if cornerRadius and cornerRadius > 0 then
		love.graphics.setStencilTest()
	end

	-- Draw border with corner radius if specified (draw after fill, at same position/size)
	love.graphics.setColor(colors.ui.foreground)
	if cornerRadius and cornerRadius > 0 then
		love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
	else
		love.graphics.rectangle("line", x, y, width, height)
	end
	love.graphics.pop()
end

-- Create a small square preview
function GradientPreview:drawSquare(x, y, size, startColor, stopColor, direction, cornerRadius)
	self:draw(x, y, size, size, startColor, stopColor, direction, cornerRadius)
end

-- Function to get the current mesh
function GradientPreview:getMesh()
	return self.gradientMesh
end

return GradientPreview
