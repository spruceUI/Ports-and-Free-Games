--- Image component for displaying images with rounded corners and outline
local love = require("love")
local colors = require("colors")
local logger = require("utils.logger")
local Component = require("ui.component").Component

local DEFAULT_CORNER_RADIUS = 8 -- Matches default button corner radius
local OUTLINE_COLOR = colors.ui.surface_focus_outline

local Image = setmetatable({}, { __index = Component })
Image.__index = Image

function Image:new(config)
	local instance = Component.new(self, config)
	instance.image = config.image
	instance.cornerRadius = config.cornerRadius or DEFAULT_CORNER_RADIUS
	return instance
end

--- Draws an image with rounded corners and outline
function Image:drawWithOutline()
	local x, y, width, height = self.x, self.y, self.width, self.height
	local cornerRadius = self.cornerRadius or DEFAULT_CORNER_RADIUS
	local image = self.image
	if not image then
		logger.debug("drawWithOutline: image is nil, returning early")
		return
	end

	love.graphics.push("all")
	-- Create stencil for rounded corners
	if cornerRadius and cornerRadius > 0 then
		love.graphics.stencil(function()
			love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
		end, "replace", 1)
		love.graphics.setStencilTest("greater", 0)
	end

	-- Draw the image
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, x, y, 0, width / image:getWidth(), height / image:getHeight())

	if cornerRadius and cornerRadius > 0 then
		love.graphics.setStencilTest()
	end

	-- Draw outline
	love.graphics.setColor(OUTLINE_COLOR)
	if cornerRadius and cornerRadius > 0 then
		love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
	else
		love.graphics.rectangle("line", x, y, width, height)
	end

	love.graphics.pop()
end

function Image:draw()
	return self:drawWithOutline()
end

return { Image = Image }
