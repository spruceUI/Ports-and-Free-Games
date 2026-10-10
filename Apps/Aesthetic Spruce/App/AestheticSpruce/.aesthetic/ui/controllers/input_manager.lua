--[[
InputManager.lua

Centralized input event manager for UI navigation and actions.

# Inputs vs. Actions

- Inputs are the raw physical signals from the device, such as keyboard keys or gamepad buttons.
- Actions are logical, UI-friendly events mapped from one or more physical inputs.
- Actions abstract away the hardware, allowing UI code to respond to intent ("move up", "confirm", "cancel") rather than
  specific buttons ("dpadup", "a", "b").
- The mapping from inputs to actions is configurable (see `InputConfig.lua`).

# Navigation Input

- Navigation input should only be handled at the top-level using `InputManager.getNavigationDirection`, which includes\
  built-in repeat/delay logic for held input.
- UI components (e.g., lists) should not poll raw input directly using `InputManager.isActionPressed` for navigation.
  Instead, components should expose methods like `handleInput(direction)` and rely on the parent UI to pass down logical
  navigation events.

# Action Pressses

- To prevent input spamming, especially in UI components,use isActionJustPressed instead of isActionPressed for
  directional navigation (e.g., d-pad left/right).
- This ensures that actions such as option cycling only occur once per button press, rather than every frame the button
  is held.

  ]]
--

local gamepadLayout = require("gamepad_layout")
local InputConfig = require("ui.controllers.input_config")

local InputManager = {}

-- Exported logical actions
local ACTIONS = {
	NAVIGATE_UP = "navigate_up",
	NAVIGATE_DOWN = "navigate_down",
	NAVIGATE_LEFT = "navigate_left",
	NAVIGATE_RIGHT = "navigate_right",
	CONFIRM = "confirm",
	CANCEL = "cancel",
	UNDO = "undo",
	CLEAR = "clear",
	SWAP_CURSOR = "swap_cursor",
	TAB_LEFT = "tab_left",
	TAB_RIGHT = "tab_right",
	OPEN_MENU = "open_menu",
	HIDDEN = "hidden",
}
InputManager.ACTIONS = ACTIONS

local instance = nil

-- Private constructor
local function createInputManager()
	local self = {}

	self.initialRepeatDelaySeconds = 0.4
	self.repeatIntervalSeconds = 0.15
	self._repeatTimers = {}
	self._heldActions = {}

	local actionStates = {}
	local prevActionStates = {}
	local navigationDirection = nil

	-- Allow overriding repeat timing
	function self:setRepeatTiming(initialDelay, interval)
		self.initialRepeatDelaySeconds = initialDelay or 0.4
		self.repeatIntervalSeconds = interval or 0.15
	end

	-- Internal: Map LÖVE input to logical actions
	local navOrder -- built on first update, reused every frame

	local function mapInputToActions()
		local actions = {}
		local joysticks = love.joystick.getJoysticks() -- once per frame, not once per button
		for action, mapping in pairs(InputConfig.current) do
			-- Keyboard
			if mapping.keyboard then
				for _, key in ipairs(mapping.keyboard) do
					if love.keyboard.isDown(key) then
						actions[action] = true
					end
				end
			end
			-- Gamepad
			if mapping.gamepad then
				for _, button in ipairs(mapping.gamepad) do
					local sdlButton = gamepadLayout.sdlButton(button)
					for _, joy in ipairs(joysticks) do
						if joy:isGamepadDown(sdlButton) then
							actions[action] = true
						end
					end
				end
			end
		end
		return actions
	end

	-- Update input states and navigation direction
	function self:update(dt)
		prevActionStates = {}
		for k, v in pairs(actionStates) do
			prevActionStates[k] = v
		end
		actionStates = mapInputToActions()

		-- Handle repeat logic for navigation actions
		if not navOrder then
			navOrder = {
				{ ACTIONS.NAVIGATE_UP, "up" },
				{ ACTIONS.NAVIGATE_DOWN, "down" },
				{ ACTIONS.NAVIGATE_LEFT, "left" },
				{ ACTIONS.NAVIGATE_RIGHT, "right" },
			}
		end
		navigationDirection = nil
		for _, nav in ipairs(navOrder) do
			local action, dir = nav[1], nav[2]
			if actionStates[action] then
				if not self._heldActions[action] then
					self._heldActions[action] = true
					self._repeatTimers[action] = self.initialRepeatDelaySeconds
					navigationDirection = dir
				else
					self._repeatTimers[action] = self._repeatTimers[action] - dt
					if self._repeatTimers[action] <= 0 then
						self._repeatTimers[action] = self.repeatIntervalSeconds
						navigationDirection = dir
					end
				end
			else
				self._heldActions[action] = false
				self._repeatTimers[action] = nil
			end
		end
	end

	-- Returns true if action is currently held
	function self:isActionPressed(action)
		return actionStates[action] or false
	end

	-- Returns true if action was just pressed this frame
	function self:isActionJustPressed(action)
		return (actionStates[action] and not prevActionStates[action]) or false
	end

	-- Returns navigation direction as "up", "down", "left", "right", or nil
	function self:getNavigationDirection()
		return navigationDirection
	end

	return self
end

-- Singleton accessor
function InputManager.getInstance()
	if not instance then
		instance = createInputManager()
	end
	return instance
end

-- >>> Start: Convenience static methods
function InputManager.update(dt)
	InputManager.getInstance():update(dt)
end

function InputManager.isActionPressed(action)
	return InputManager.getInstance():isActionPressed(action)
end

function InputManager.isActionJustPressed(action)
	return InputManager.getInstance():isActionJustPressed(action)
end

function InputManager.getNavigationDirection()
	return InputManager.getInstance():getNavigationDirection()
end
-- <<< End: Convenience static methods

return InputManager
