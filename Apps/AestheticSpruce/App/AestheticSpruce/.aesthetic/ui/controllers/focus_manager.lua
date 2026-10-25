--- Focus Manager

--[[
Responsible for managing which UI component is currently focused and for handling navigation between focusable
components.
Provides methods to register/unregister components, set/get focus, and navigate spatially (up, down, left, right)
between components.

Typical usage:
- Register all focusable UI components (e.g., lists, buttons) with FocusManager.
- On each frame, pass navigation input (e.g., 'up', 'down') to FocusManager:handleInput().
- FocusManager will delegate input to the currently focused component and, if navigation reaches the edge
  (e.g., end of a list), will automatically move focus to the next logical component.
]]

local FocusManager = {}
FocusManager.__index = FocusManager

local NavigationUtils = require("ui.controllers.navigation_utils")

local logger = require("utils.logger")

function FocusManager:new()
	local instance = setmetatable({}, self)
	instance.focusedComponent = nil
	instance.focusableComponents = {}
	instance.navigationHistory = {}
	instance.wrapNavigation = false -- Should navigation wrap around edges
	return instance
end

-- Register a component as focusable
function FocusManager:registerComponent(component)
	if not component or not component.enabled then
		return
	end
	for _, existing in ipairs(self.focusableComponents) do
		if existing == component then
			return
		end
	end
	table.insert(self.focusableComponents, component)

	-- If no component is focused, focus this one
	if not self.focusedComponent and component.visible then
		self:setFocused(component)
	end
end

-- Unregister a component
function FocusManager:unregisterComponent(component)
	for i, existing in ipairs(self.focusableComponents) do
		if existing == component then
			table.remove(self.focusableComponents, i)
			break
		end
	end

	-- If this was the focused component, find a new one
	if self.focusedComponent == component then
		self:findNextFocusableComponent()
	end
end

-- Set focus to a specific component
function FocusManager:setFocused(component, direction)
	if self.focusedComponent == component then
		return
	end

	-- Remove focus from current component
	if self.focusedComponent then
		self.focusedComponent:setFocused(false)
	end

	-- Set new focused component
	self.focusedComponent = component
	if component.setFocused then
		component:setFocused(true, direction)
	end
	-- Add to navigation history
	table.insert(self.navigationHistory, component)
	if #self.navigationHistory > 10 then -- Limit history size
		table.remove(self.navigationHistory, 1)
	end
end

-- Get all valid focus candidates
function FocusManager:getFocusableCandidates()
	local candidates = {}
	for _, component in ipairs(self.focusableComponents) do
		if component ~= self.focusedComponent and component.visible and component.enabled then
			table.insert(candidates, component)
		end
	end
	return candidates
end

-- Find next focusable component (fallback when current focus is lost)
function FocusManager:findNextFocusableComponent()
	for _, component in ipairs(self.focusableComponents) do
		if component.visible and component.enabled then
			self:setFocused(component)
			return
		end
	end
	self.focusedComponent = nil
end

-- Handle wrapping navigation (for circular navigation)
function FocusManager:findWrappingCandidate(direction)
	local candidates = self:getFocusableCandidates()
	if #candidates == 0 then
		return nil
	end

	-- For wrapping, find the component on the opposite edge
	if direction == "up" then
		return NavigationUtils.findBottomMostComponent(candidates)
	elseif direction == "down" then
		return NavigationUtils.findTopMostComponent(candidates)
	elseif direction == "left" then
		return NavigationUtils.findRightMostComponent(candidates)
	elseif direction == "right" then
		return NavigationUtils.findLeftMostComponent(candidates)
	end
	return nil
end

-- Navigate in a specific direction (up, down, left, right)
function FocusManager:navigateDirection(direction)
	if not self.focusedComponent then
		self:findNextFocusableComponent()
		return
	end
	local candidates = self:getFocusableCandidates()
	local nextComponent = NavigationUtils.findBestCandidate(self.focusedComponent, candidates, direction)
	if nextComponent then
		self:setFocused(nextComponent, direction)
		return true
	elseif self.wrapNavigation then
		nextComponent = self:findWrappingCandidate(direction)
		if nextComponent then
			self:setFocused(nextComponent, direction)
			return true
		end
	end
	return false
end

-- Get currently focused component
function FocusManager:getFocused()
	return self.focusedComponent
end

-- Clear all focus
function FocusManager:clearFocus()
	if self.focusedComponent then
		self.focusedComponent:setFocused(false)
		self.focusedComponent = nil
	end
end

-- Update focus manager (call this each frame)
function FocusManager:update(dt)
	for i = #self.focusableComponents, 1, -1 do
		local component = self.focusableComponents[i]
		if not component or not component.enabled then
			table.remove(self.focusableComponents, i)
		end
	end

	if self.focusedComponent and (not self.focusedComponent.visible or not self.focusedComponent.enabled) then
		-- Skip components that are not visible or enabled
		self:findNextFocusableComponent()
	end
end

-- Handle input and manage focus navigation
---
-- Handles navigation input for the currently focused component.
--
-- @param direction (string): Navigation direction, e.g., 'up', 'down', 'left', 'right'.
-- @param input (table): Optional input state or context to pass to the focused component's handleInput.
-- @return (boolean): True if input was handled (including focus change), false otherwise.
--
-- If the focused component's handleInput returns 'end' (for down/right edge) or 'start' (for up/left edge),
-- FocusManager will automatically move focus to the next component in that direction.
function FocusManager:handleInput(direction, input)
	if not self.focusedComponent or not direction then
		return false
	end
	if self.focusedComponent.handleInput then
		local result = self.focusedComponent:handleInput(direction, input)
		if result == "end" then
			self:navigateDirection("down")
			return true
		elseif result == "start" then
			self:navigateDirection("up")
			return true
		elseif result == true then
			return true
		end
	end
	-- If not handled, always try to navigate in the given direction
	self:navigateDirection(direction)
	return true
end

return FocusManager
