--- Input handling module
---
--- Global input delay: All input events are throttled by a default delay via isGamepadPressedWithDelay(button, delay)
--- to ensure consistent input handling across all screens. Use this function for all navigation and action input
--- checks. To override, pass a custom delay as the second argument.
local love = require("love")
local gamepadLayout = require("gamepad_layout")

local input = {}

local joystick
local virtualJoystick = {}

-- Default global input delay (seconds)
local DEFAULT_INPUT_DELAY = 0.2
-- Table to track last press time for each button
local lastButtonPress = {}
-- Table to track last press time for button combinations
local lastCombinationPress = {}

-- Virtual joystick key mappings
-- Useful for testing application while developing
local keyToButton = {
	["return"] = "start", -- Start
	["space"] = "back", -- Back (Select)
	["escape"] = "guide", -- Guide (M)
	["c"] = "leftstick", -- Left Stick
	["v"] = "rightstick", -- Right Stick
	["q"] = "leftshoulder", -- L1
	["w"] = "rightshoulder", -- R1
	["e"] = "lefttrigger", -- L2
	["r"] = "righttrigger", -- R2
	["up"] = "dpup", -- D-Pad Up
	["down"] = "dpdown", -- D-Pad Down
	["left"] = "dpleft", -- D-Pad Left
	["right"] = "dpright", -- D-Pad Right
	["z"] = "a", -- A
	["x"] = "b", -- B
	["a"] = "x", -- X
	["s"] = "y", -- Y
}

-- Check if a gamepad button is pressed, enforcing a global or custom delay
function virtualJoystick.isGamepadPressedWithDelay(button, delay)
	delay = delay or DEFAULT_INPUT_DELAY
	local now = love.timer.getTime()

	-- Check if the button is currently pressed (physical gamepad or keyboard mapping)
	local isButtonDown = false

	-- Check if button parameter is valid
	if not button then
		error("Button parameter cannot be nil")
	elseif type(button) ~= "string" then
		error("Button parameter must be a string, got " .. type(button))
	end

	-- Check physical gamepad
	if joystick and joystick:isGamepadDown(gamepadLayout.sdlButton(button)) then
		isButtonDown = true
	else
		-- Check keyboard mappings
		for key, mappedButton in pairs(keyToButton) do
			if mappedButton == button and love.keyboard.isDown(key) then
				isButtonDown = true
				break
			end
		end
	end

	-- Apply delay logic
	if isButtonDown then
		if not lastButtonPress[button] or now - lastButtonPress[button] >= delay then
			lastButtonPress[button] = now
			return true
		end
	else
		lastButtonPress[button] = nil -- Reset on release
	end
	return false
end

-- Function for checking button combinations with delay
-- Accepts an array of button names that must all be pressed simultaneously
-- Returns true once per delay interval when the combination is pressed
function virtualJoystick.isButtonCombinationPressed(buttons, delay)
	delay = delay or DEFAULT_INPUT_DELAY
	local now = love.timer.getTime()

	-- Check if buttons parameter is valid
	if not buttons or type(buttons) ~= "table" or #buttons == 0 then
		error("Buttons parameter must be a non-empty table")
	end

	-- Create a unique key for this combination
	local combinationKey = table.concat(buttons, "+")

	-- Check if all buttons are currently pressed
	local allButtonsPressed = true
	for _, button in ipairs(buttons) do
		local isPressed = false

		-- Check physical gamepad
		if joystick and joystick:isGamepadDown(gamepadLayout.sdlButton(button)) then
			isPressed = true
		else
			-- Check keyboard mappings
			for key, mappedButton in pairs(keyToButton) do
				if mappedButton == button and love.keyboard.isDown(key) then
					isPressed = true
					break
				end
			end
		end

		if not isPressed then
			allButtonsPressed = false
			break
		end
	end

	-- Apply delay logic
	if allButtonsPressed then
		if not lastCombinationPress[combinationKey] or now - lastCombinationPress[combinationKey] >= delay then
			lastCombinationPress[combinationKey] = now
			return true
		end
	else
		lastCombinationPress[combinationKey] = nil -- Reset on release
	end

	return false
end

function input.load()
	-- Load gamepad mappings before initializing joystick
	local joysticks = love.joystick.getJoysticks()
	-- If there is at least one joystick connected, use the first one
	if #joysticks > 0 then
		joystick = joysticks[1]
	end
end

function input.update(_dt)
	-- Check for global exit shortcut using button combination
	if virtualJoystick.isButtonCombinationPressed({ "leftshoulder", "rightshoulder" }) then
		love.event.quit()
	end
end

-- Expose the virtual joystick for use in other modules
input.virtualJoystick = virtualJoystick

return input
