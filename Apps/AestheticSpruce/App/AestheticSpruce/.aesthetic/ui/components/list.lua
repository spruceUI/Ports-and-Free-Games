--- New List Component
--- A clean, reusable scrollable list component
local love = require("love")

local colors = require("colors")

local Component = require("ui.component").Component
local slider = require("ui.components.slider")
local InputManager = require("ui.controllers.input_manager")

local constants = require("ui.components.constants")

-- List constants
local LIST_CONFIG = {
	ITEM_SPACING = 14,
}

-- List class
local List = setmetatable({}, { __index = Component })
List.__index = List

function List:new(config)
	-- Initialize base component
	local instance = Component.new(self, config)

	-- List-specific properties
	instance.items = config.items or {}
	instance.selectedIndex = config.selectedIndex or 1
	instance.scrollPosition = config.scrollPosition or 0
	instance.itemHeight = config.itemHeight or 50
	instance.spacing = config.spacing or LIST_CONFIG.ITEM_SPACING
	instance.visibleCount = 0
	instance.wrap = config.wrap ~= false -- Default true
	instance.paddingX = config.paddingX or 12
	instance.paddingY = config.paddingY or 8

	-- Height redistribution properties
	instance.adjustedItemHeight = instance.itemHeight
	instance.adjustedSpacing = instance.spacing
	instance.shouldRedistribute = false

	-- Callbacks
	instance.onItemSelect = config.onItemSelect
	instance.onItemOptionCycle = config.onItemOptionCycle

	-- Remember last selected index for focus restoration
	instance._lastSelectedIndex = instance.selectedIndex or 1

	-- Calculate dimensions
	instance:calculateDimensions()
	instance:updateSelection()

	return instance
end

function List:calculateDimensions()
	if #self.items > 0 then
		-- Gather item heights
		self._itemHeights = {}
		local totalItemHeight = 0
		for i, item in ipairs(self.items) do
			local h = (item.itemHeight or (item.getHeight and item:getHeight()) or self.itemHeight)
			table.insert(self._itemHeights, h)
			totalItemHeight = totalItemHeight + h
		end

		local availableHeight = self.height - self.paddingY * 2
		-- Find how many items can fit fully (no cut-off)
		local visibleCount = 0
		local usedHeight = 0
		for i = 1, #self._itemHeights do
			if usedHeight + self._itemHeights[i] + (i > 1 and self.spacing or 0) <= availableHeight + 0.0001 then
				usedHeight = usedHeight + self._itemHeights[i] + (i > 1 and self.spacing or 0)
				visibleCount = visibleCount + 1
			else
				break
			end
		end
		self.visibleCount = math.max(1, math.min(visibleCount, #self.items))

		-- Redistribute spacing if needed
		local totalVisibleHeight = 0
		for i = 1, self.visibleCount do
			totalVisibleHeight = totalVisibleHeight + self._itemHeights[i]
		end
		local remainingHeight = availableHeight - totalVisibleHeight
		self.shouldRedistribute = (#self.items > self.visibleCount)
		if self.shouldRedistribute and self.visibleCount > 1 then
			self.adjustedSpacings = {}
			local spacing = remainingHeight / (self.visibleCount - 1)
			for i = 1, self.visibleCount - 1 do
				table.insert(self.adjustedSpacings, spacing)
			end
		else
			self.adjustedSpacings = {}
			for i = 1, self.visibleCount - 1 do
				table.insert(self.adjustedSpacings, self.spacing)
			end
		end
	else
		self.visibleCount = 0
		self.shouldRedistribute = false
		self._itemHeights = nil
		self.adjustedSpacings = nil
	end
end

function List:setItems(items)
	self.items = items or {}
	if self.selectedIndex > #self.items then
		self.selectedIndex = math.max(1, #self.items)
	end
	self:updateSelection()
	self:calculateDimensions()
end

function List:addItem(item)
	table.insert(self.items, item)
	self:calculateDimensions()
end

function List:removeItem(index)
	if index >= 1 and index <= #self.items then
		table.remove(self.items, index)
		if self.selectedIndex > #self.items and #self.items > 0 then
			self.selectedIndex = #self.items
		elseif #self.items == 0 then
			self.selectedIndex = 1
		end
		self:updateSelection()
		self:calculateDimensions()
	end
end

function List:getSelectedItem()
	if self.selectedIndex >= 1 and self.selectedIndex <= #self.items then
		return self.items[self.selectedIndex]
	end
	return nil
end

function List:getSelectedIndex()
	return self.selectedIndex
end

function List:setSelectedIndex(index)
	if (index == 0) or (index >= 1 and index <= #self.items) then
		self.selectedIndex = index
		self:updateSelection()
		if index > 0 then
			self:adjustScrollPosition()
		end
	end
end

function List:updateSelection()
	-- Update focused state for all items (works for any component with setFocused)
	for i, item in ipairs(self.items) do
		if item.setFocused then
			item:setFocused(i == self.selectedIndex and self.selectedIndex > 0)
		elseif item.focused ~= nil then
			item.focused = (i == self.selectedIndex and self.selectedIndex > 0)
		end
	end
end

function List:navigate(direction)
	if #self.items == 0 then
		return false
	end

	local oldIndex = self.selectedIndex
	local newIndex = self.selectedIndex + direction

	if self.wrap then
		if newIndex < 1 then
			newIndex = #self.items
		elseif newIndex > #self.items then
			newIndex = 1
		end
	else
		if newIndex < 1 then
			newIndex = 1
		elseif newIndex > #self.items then
			newIndex = #self.items
		end
	end

	if newIndex ~= oldIndex then
		self.selectedIndex = newIndex
		self:updateSelection()
		self:adjustScrollPosition(direction)
		return true
	end

	return false
end

function List:adjustScrollPosition(direction)
	if not self._itemHeights or #self.items <= self.visibleCount then
		self.scrollPosition = 0
		return
	end
	direction = direction or 0
	local maxScrollPosition = math.max(0, #self.items - self.visibleCount)
	if direction == 1 and self.selectedIndex == 1 and self.scrollPosition > 0 then
		self.scrollPosition = 0
		return
	end
	if direction == -1 and self.selectedIndex == #self.items then
		self.scrollPosition = maxScrollPosition
		return
	end
	local firstVisible = math.floor(self.scrollPosition) + 1
	local lastVisible = firstVisible + self.visibleCount - 1
	if self.selectedIndex < firstVisible then
		self.scrollPosition = self.selectedIndex - 1
	elseif self.selectedIndex > lastVisible then
		self.scrollPosition = self.selectedIndex - self.visibleCount
	end
	self.scrollPosition = math.max(0, math.min(self.scrollPosition, maxScrollPosition))
end

function List:handleInput(direction, input)
	if not self.enabled or #self.items == 0 then
		return false
	end

	local handled = false

	-- Handle navigation only if direction is provided by parent
	if direction == "up" then
		if not self.wrap and self.selectedIndex == 1 then
			return "start"
		elseif not self.wrap and self.selectedIndex == 0 then
			return false
		end
		handled = self:navigate(-1)
	elseif direction == "down" then
		if not self.wrap and self.selectedIndex == #self.items then
			return "end"
		elseif not self.wrap and self.selectedIndex == 0 then
			return false
		end
		handled = self:navigate(1)
	end

	-- If navigation was handled, don't process other inputs
	if handled then
		return true
	end

	local selectedItem = self:getSelectedItem()
	-- If the selected item is a Slider, let it handle all input (left/right, etc.)
	if selectedItem and selectedItem.handleInput and selectedItem.__index and selectedItem.__index == slider.Slider then
		if selectedItem:handleInput(input) then
			return true
		end
	end

	-- Handle item selection
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CONFIRM) then
		if selectedItem and self.onItemSelect then
			self.onItemSelect(selectedItem, self.selectedIndex)
			handled = true
		end
	end

	-- Handle option cycling - left and right separately (for non-slider items)
	if InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_LEFT) then
		if
			selectedItem
			and selectedItem.handleInput
			and not (selectedItem.__index and selectedItem.__index == slider.Slider)
			and selectedItem:handleInput(input)
		then
			handled = true
		elseif self.onItemOptionCycle then
			local changed = self.onItemOptionCycle(selectedItem, -1)
			if changed then
				handled = true
			end
		end
	elseif InputManager.isActionJustPressed(InputManager.ACTIONS.NAVIGATE_RIGHT) then
		if
			selectedItem
			and selectedItem.handleInput
			and not (selectedItem.__index and selectedItem.__index == slider.Slider)
			and selectedItem:handleInput(input)
		then
			handled = true
		elseif self.onItemOptionCycle then
			local changed = self.onItemOptionCycle(selectedItem, 1)
			if changed then
				handled = true
			end
		end
	end

	return handled
end

function List:draw()
	if not self.visible or #self.items == 0 then
		return
	end
	if not self._itemHeights or #self._itemHeights ~= #self.items then
		self:calculateDimensions()
	end
	love.graphics.push("all")
	local firstVisible = math.floor(self.scrollPosition) + 1
	local lastVisible = math.min(firstVisible + self.visibleCount - 1, #self.items)
	local needsScrollbar = #self.items > self.visibleCount
	local scrollbarWidth = constants.SCROLLBAR.WIDTH
	local effectiveRightPadding = self.paddingX
	if needsScrollbar then
		effectiveRightPadding = self.paddingX + scrollbarWidth
	end
	love.graphics.intersectScissor(self.x, self.y, self.width, self.height)
	local yCursor = self.y + self.paddingY
	for i = firstVisible, lastVisible do
		local item = self.items[i]
		if item then
			local itemH = (item.itemHeight or (item.getHeight and item:getHeight()) or self.itemHeight)
			local itemX = self.x + self.paddingX
			local itemW = self.width - self.paddingX - effectiveRightPadding
			if item.setPosition then
				item:setPosition(itemX, yCursor)
			else
				item.x = itemX
				item.y = yCursor
			end
			if item.setSize then
				item:setSize(itemW, itemH)
			elseif item.width == nil or item.height == nil then
				item.width = itemW
				item.height = itemH
			end
			if item.draw then
				love.graphics.push("all")
				item:draw()
				love.graphics.pop()
			end
			yCursor = yCursor + itemH
			if i - firstVisible + 1 <= (self.adjustedSpacings and #self.adjustedSpacings or 0) then
				yCursor = yCursor + self.adjustedSpacings[i - firstVisible + 1]
			end
		end
	end
	love.graphics.setScissor()
	if needsScrollbar then
		local barX = self.x + self.width - scrollbarWidth
		local rx = constants.SCROLLBAR.CORNER_RADIUS
		local ry = rx
		local barHeight = (self.height - self.paddingY * 2) * (self.visibleCount / #self.items)
		local barY = self.y
			+ self.paddingY
			+ ((self.height - self.paddingY * 2) - barHeight)
				* (self.scrollPosition / (#self.items - self.visibleCount))
		love.graphics.setColor(constants.SCROLLBAR.HANDLE_COLOR)
		love.graphics.rectangle("fill", barX, barY, scrollbarWidth, barHeight, rx, ry)
	end
	love.graphics.pop()
end

function List:update(dt)
	Component.update(self, dt)

	-- Update all items
	for _, item in ipairs(self.items) do
		if item.update then
			item:update(dt)
		end
	end
end

function List:getContentHeight()
	if not self._itemHeights or #self.items == 0 then
		return 0
	end
	local total = self.paddingY
	for i = 1, #self._itemHeights do
		total = total + self._itemHeights[i]
		if i < #self._itemHeights then
			total = total + (self.adjustedSpacings and self.adjustedSpacings[i] or self.spacing)
		end
	end
	total = total + self.paddingY
	return total
end

-- Override setFocused to remember/restore selection
function List:setFocused(focused, direction)
	if focused then
		if direction == "up" then
			if #self.items > 0 then
				self:setSelectedIndex(#self.items)
			end
		elseif direction == "down" then
			if #self.items > 0 then
				self:setSelectedIndex(1)
			end
		elseif self._lastSelectedIndex and #self.items > 0 then
			self:setSelectedIndex(math.min(self._lastSelectedIndex, #self.items))
		end
	else
		-- Remember where focus was so it can be restored; a repeated blur must not clobber it with 0
		if (self.selectedIndex or 0) > 0 then
			self._lastSelectedIndex = self.selectedIndex
		end
		self:setSelectedIndex(0) -- Remove highlight when not focused
	end
	Component.setFocused(self, focused)
end

-- Module exports
local list = {}
list.List = List

return list
