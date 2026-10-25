--- Base UI Component
--- Provides common functionality for all UI components
--
-- To create a class that inherits from Component, for example, Header, use:
--   local Header = setmetatable({}, { __index = Component })
--   Header.__index = Header
-- This sets up Header so that any missing methods or properties are looked up in Component.
-- The second line ensures that instances of Header use Header's methods first, then fall back to Component.

local component = {}

-- Component base class
local Component = {}
Component.__index = Component

function Component:new(config)
	local instance = setmetatable({}, self)

	-- Core properties
	instance.id = config.id or tostring(instance)
	instance.x = config.x or 0
	instance.y = config.y or 0
	instance.width = config.width or 0
	instance.height = config.height or 0
	instance.visible = config.visible ~= false
	instance.enabled = config.enabled ~= false

	-- State
	instance.focused = false
	instance.pressed = false
	instance.hovered = false

	-- Callbacks
	instance.onFocus = config.onFocus
	instance.onBlur = config.onBlur
	instance.onClick = config.onClick
	instance.onUpdate = config.onUpdate

	return instance
end

function Component:setPosition(x, y)
	self.x = x or self.x
	self.y = y or self.y
end

function Component:setSize(width, height)
	self.width = width or self.width
	self.height = height or self.height
end

function Component:setFocused(focused)
	if self.focused ~= focused then
		self.focused = focused
		if focused and self.onFocus then
			self.onFocus(self)
		elseif not focused and self.onBlur then
			self.onBlur(self)
		end
	end
end

function Component:isPointInside(x, y)
	return x >= self.x and x < self.x + self.width and y >= self.y and y < self.y + self.height
end

function Component:update(dt)
	if self.onUpdate then
		self.onUpdate(self, dt)
	end
end

function Component:getHeight()
	return self.height
end

function Component.draw(_self)
	-- Override in subclasses
end

function Component.handleInput(_self, _direction, _input)
	-- Override in subclasses
	return false
end

-- Draws a focus background with gradient and outline
function Component:drawBackground(options)
	options = options or {}
	local colors = require("colors")
	local love = require("love")
	local x = self.x
	local y = self.y
	local width = self.width
	local height = self:getHeight()
	local cornerRadius = options.cornerRadius or 8
	love.graphics.push("all")
	if self.focused then
		-- `love.graphics.setColor()` sets a global color multiplier that affects everything drawn afterward including
		-- meshes. Setting a non-white color before the mesh is drawn will dim the mesh.
		love.graphics.setColor(1, 1, 1, 1)
		local topColor = colors.ui.surface_focus_start
		local bottomColor = colors.ui.surface_focus_stop
		-- Create mesh for vertical gradient
		local mesh = love.graphics.newMesh({
			{ x, y, 0, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 },
			{ x + width, y, 1, 0, topColor[1], topColor[2], topColor[3], topColor[4] or 1 },
			{ x + width, y + height, 1, 1, bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1 },
			{ x, y + height, 0, 1, bottomColor[1], bottomColor[2], bottomColor[3], bottomColor[4] or 1 },
		}, "fan", "static")

		-- Use stencil to clip mesh to rounded rectangle
		love.graphics.stencil(function()
			love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)
		end, "replace", 1)
		love.graphics.setStencilTest("equal", 1)

		love.graphics.draw(mesh)

		love.graphics.setStencilTest() -- Disable stencil

		love.graphics.setColor(colors.ui.surface_focus_outline)
		love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
	end
	love.graphics.pop()
end

-- Export the base component
component.Component = Component

return component
