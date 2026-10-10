--- New Header Component
--- A header component using the new component system
local love = require("love")
local colors = require("colors")
local fonts = require("ui.fonts")
local Component = require("ui.component").Component

-- Header constants
local HEADER_CONFIG = {
	VERTICAL_PADDING = 8,
	BOTTOM_MARGIN = 8,
}

-- Header class
local Header = setmetatable({}, { __index = Component })
Header.__index = Header

function Header:new(config)
	local instance = Component.new(self, config)

	instance.title = config.title or ""
	instance.x = 0
	instance.y = 0
	instance.width = love.graphics.getWidth()
	instance.height = instance:calculateHeight()

	return instance
end

function Header.calculateHeight(_self)
	return fonts.loaded.body:getHeight() + (HEADER_CONFIG.VERTICAL_PADDING * 2)
end

function Header:draw()
	if not self.visible then
		return
	end
	love.graphics.push("all")
	local displayTitle = self.title
	-- Draw background
	love.graphics.setColor(colors.ui.background_dim)
	love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)

	-- Draw line under header
	love.graphics.setColor(colors.ui.background_outline)
	love.graphics.rectangle("line", self.x, self.y + self.height, self.width, 1)

	-- Draw header title
	love.graphics.setColor(colors.ui.foreground_dim)
	love.graphics.setFont(fonts.loaded.body)
	local titleWidth = fonts.loaded.body:getWidth(displayTitle)
	local titleX = (self.width - titleWidth) / 2
	love.graphics.print(displayTitle, titleX, HEADER_CONFIG.VERTICAL_PADDING)
	love.graphics.pop()
end

function Header:getHeight()
	return fonts.loaded.body:getHeight() + (HEADER_CONFIG.VERTICAL_PADDING * 2)
end

function Header:getWidth()
	return self.width
end

function Header:getContentStartY()
	return self:getHeight() + HEADER_CONFIG.BOTTOM_MARGIN
end

function Header:setTitle(title)
	self.title = title or ""
end

return Header
