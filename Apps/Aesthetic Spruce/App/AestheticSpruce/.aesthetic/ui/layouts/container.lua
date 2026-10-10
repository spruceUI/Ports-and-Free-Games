--- Container Component
--- Manages child components and provides layout capabilities
local love = require("love")
local Component = require("ui.component").Component
local logger = require("utils.logger")

local Container = setmetatable({}, { __index = Component })
Container.__index = Container

function Container:new(config)
	local instance = Component.new(self, config)

	local defaultPadding = {
		top = 0,
		right = 0,
		bottom = 0,
		left = 0,
	}

	-- Container-specific properties
	instance.children = {}
	instance.childrenById = {}

	-- Layout properties

	if config.padding then
		instance.padding = {
			top = config.padding and config.padding.top or 0,
			right = config.padding and config.padding.right or 0,
			bottom = config.padding and config.padding.bottom or 0,
			left = config.padding and config.padding.left or 0,
		}
	else
		instance.padding = defaultPadding
	end

	-- Clipping (whether to clip children to container bounds)
	instance.clipChildren = config.clipChildren ~= false

	-- Background properties
	instance.backgroundColor = config.backgroundColor
	instance.borderColor = config.borderColor
	instance.borderWidth = config.borderWidth or 0

	return instance
end

-- Child Management
function Container:addChild(child, index)
	if not child then
		error("Cannot add nil child to container")
	end

	-- Remove from previous parent if exists
	if child.parent then
		child.parent:removeChild(child)
	end

	-- Set parent relationship
	child.parent = self

	-- Add to children list
	if index then
		table.insert(self.children, index, child)
	else
		table.insert(self.children, child)
	end

	-- Add to lookup table if child has ID
	if child.id then
		self.childrenById[child.id] = child
	end

	-- Update child's absolute position
	self:updateChildPosition(child)

	return child
end

function Container:removeChild(child)
	if not child then
		return false
	end

	-- Remove from children list
	for i, c in ipairs(self.children) do
		if c == child then
			table.remove(self.children, i)
			break
		end
	end

	-- Remove from lookup table
	if child.id then
		self.childrenById[child.id] = nil
	end

	-- Clear parent relationship
	child.parent = nil

	return true
end

function Container:removeChildById(id)
	local child = self:getChildById(id)
	if child then
		return self:removeChild(child)
	end
	return false
end

function Container:getChildById(id)
	return self.childrenById[id]
end

function Container:getChildAt(index)
	return self.children[index]
end

function Container:getChildCount()
	return #self.children
end

function Container:clearChildren()
	-- Clear parent relationships
	for _, child in ipairs(self.children) do
		child.parent = nil
	end

	self.children = {}
	self.childrenById = {}
end

-- Position and Layout
function Container:setPosition(x, y)
	local oldX, oldY = self.x, self.y
	Component.setPosition(self, x, y)

	-- Update all children positions if container moved
	if self.x ~= oldX or self.y ~= oldY then
		self:updateChildrenPositions()
	end
end

function Container:updateChildPosition(_child)
	-- Children are positioned in screen space by the screens themselves; nothing to derive here.
end

function Container:updateChildrenPositions()
	for _, child in ipairs(self.children) do
		self:updateChildPosition(child)

		-- Recursively update if child is also a container
		if child.updateChildrenPositions then
			child:updateChildrenPositions()
		end
	end
end

-- Content area calculations
function Container:getContentX()
	return self.x + self.padding.left
end

function Container:getContentY()
	return self.y + self.padding.top
end

function Container:getContentWidth()
	return math.max(0, self.width - self.padding.left - self.padding.right)
end

function Container:getContentHeight()
	return math.max(0, self.height - self.padding.top - self.padding.bottom)
end

-- Padding management
function Container:setPadding(top, right, bottom, left)
	-- Handle different parameter patterns
	if type(top) == "table" then
		self.padding = {
			top = top.top or 0,
			right = top.right or 0,
			bottom = top.bottom or 0,
			left = top.left or 0,
		}
	elseif right == nil then
		-- Single value for all sides
		self.padding = { top = top, right = top, bottom = top, left = top }
	elseif bottom == nil then
		-- Two values: vertical, horizontal
		self.padding = { top = top, right = right, bottom = top, left = right }
	else
		-- Four values: top, right, bottom, left
		self.padding = {
			top = top,
			right = right or top,
			bottom = bottom or top,
			left = left or right or top,
		}
	end

	-- Update children positions after padding change
	self:updateChildrenPositions()
end

-- Event Handling
function Container:update(dt)
	-- Update self first
	Component.update(self, dt)

	-- Update all children
	for _, child in ipairs(self.children) do
		if child.visible and child.enabled then
			child:update(dt)
		end
	end
end

function Container:handleInput(direction, input)
	local handled = false
	for i = #self.children, 1, -1 do
		local child = self.children[i]
		if child.visible and child.enabled then
			handled = child:handleInput(direction, input)
			if handled then
				break
			end
		end
	end
	if not handled then
		handled = Component.handleInput(self, direction, input)
	end
	return handled
end

-- Point-in-bounds testing
function Container:getChildAtPoint(x, y)
	-- Check children in reverse order (topmost first)
	for i = #self.children, 1, -1 do
		local child = self.children[i]
		if child.visible and child:isPointInside(x, y) then
			-- If child is also a container, check its children
			if child.getChildAtPoint then
				local grandchild = child:getChildAtPoint(x, y)
				return grandchild or child
			else
				return child
			end
		end
	end

	-- Return self if point is inside container but not in any child
	if self:isPointInside(x, y) then
		return self
	end

	return nil
end

-- Focus Management
function Container:getFocusableChildren()
	local focusable = {}
	for _, child in ipairs(self.children) do
		if child.visible and child.enabled then
			if child.getFocusableChildren then
				-- Child is a container, get its focusable children
				local childFocusable = child:getFocusableChildren()
				for _, fc in ipairs(childFocusable) do
					table.insert(focusable, fc)
				end
			else
				-- Child is a regular component
				table.insert(focusable, child)
			end
		end
	end
	return focusable
end

function Container:getFirstFocusableChild()
	local focusable = self:getFocusableChildren()
	return focusable[1]
end

function Container:getLastFocusableChild()
	local focusable = self:getFocusableChildren()
	return focusable[#focusable]
end

-- Drawing
function Container:draw()
	love.graphics.push("all")

	-- Draw background if specified
	if self.backgroundColor then
		love.graphics.setColor(self.backgroundColor)
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	-- love.graphics.pop()

	-- Draw focus background
	-- self:drawBackground()

	-- love.graphics.push("all")

	-- Draw border if specified
	if self.borderColor and self.borderWidth > 0 then
		love.graphics.setColor(self.borderColor)
		love.graphics.setLineWidth(self.borderWidth)
		love.graphics.rectangle("line", self.x, self.y, self.width, self.height)
	end

	-- love.graphics.pop()

	-- Set up clipping if enabled
	if self.clipChildren then
		-- love.graphics.push()
		love.graphics.intersectScissor(
			self:getContentX(),
			self:getContentY(),
			self:getContentWidth(),
			self:getContentHeight()
		)
	end

	-- Draw all visible children
	for _, child in ipairs(self.children) do
		if child.visible then
			love.graphics.push("all")
			child:draw()
			love.graphics.pop()
		end
	end

	-- Restore clipping
	if self.clipChildren then
		-- love.graphics.pop()
	end

	love.graphics.pop()
end

-- Utility methods
function Container:bringChildToFront(child)
	self:removeChild(child)
	self:addChild(child)
end

function Container:sendChildToBack(child)
	self:removeChild(child)
	self:addChild(child, 1)
end

function Container:sortChildren(compareFunction)
	table.sort(self.children, compareFunction)
end

-- Debug helpers
function Container:debugPrint(indent)
	indent = indent or 0
	local prefix = string.rep("  ", indent)
	print(
		prefix
			.. "Container: "
			.. (self.id or "unnamed")
			.. " ("
			.. self.x
			.. ","
			.. self.y
			.. " "
			.. self.width
			.. "x"
			.. self.height
			.. ")"
	)

	for _, child in ipairs(self.children) do
		if child.debugPrint then
			child:debugPrint(indent + 1)
		else
			print(prefix .. "  " .. (child.id or "Component"))
		end
	end
end

return { Container = Container }
