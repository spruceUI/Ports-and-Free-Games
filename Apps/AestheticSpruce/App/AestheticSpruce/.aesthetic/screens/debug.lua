--- Debug screen for development purposes
local love = require("love")

local colors = require("colors")
local input = require("input")
local screens = require("screens")

local background = require("ui.background")
local fonts = require("ui.fonts")
local Header = require("ui.components.header")

local logger = require("utils.logger")
local controls = require("control_hints").ControlHints
local controlHintsInstance

local InputManager = require("ui.controllers.input_manager")

-- Module table to export public functions
local debug = {}

local headerInstance = Header:new({ title = "Debug" })

-- Function to check if the debug button combo is pressed
local function isDebugComboPressed(virtualJoystick)
	return virtualJoystick.isButtonCombinationPressed({ "guide", "y" })
end

-- Function to get text height with padding
local function getTextHeight(padding)
	padding = padding or 5
	local font = love.graphics.getFont()
	return font:getHeight() + padding
end

function debug.draw()
	-- Draw background and header
	background.draw()
	headerInstance:draw()

	-- Set default body font
	love.graphics.setFont(fonts.loaded.body)
	local lineHeight = getTextHeight()

	-- Get joystick information
	local joysticks = love.joystick.getJoysticks()

	-- Draw joystick diagnostic info
	local textY = headerInstance:getContentStartY()
	love.graphics.setColor(colors.ui.foreground)

	-- Get the physical joystick
	local physicalJoystick = joysticks[1]

	if physicalJoystick then
		-- Draw D-pad states
		textY = textY + lineHeight
		love.graphics.setColor(colors.ui.red)
		love.graphics.print("D-Pad States:", 20, textY)
		textY = textY + lineHeight

		local labelX = 30

		-- Check for D-pad buttons via gamepad API
		local upPressed = false
		local rightPressed = false
		local downPressed = false
		local leftPressed = false

		-- Try to get button states, with error handling
		local dpad_success, dpad_error = pcall(function()
			upPressed = physicalJoystick:isGamepadDown("dpup")
			rightPressed = physicalJoystick:isGamepadDown("dpright")
			downPressed = physicalJoystick:isGamepadDown("dpdown")
			leftPressed = physicalJoystick:isGamepadDown("dpleft")

		end)

		if not dpad_success then
			logger.error("Error getting D-pad button states: " .. tostring(dpad_error))
		end

		-- Up
		if upPressed then
			love.graphics.setColor(colors.ui.green) -- Green for active
		else
			love.graphics.setColor(colors.ui.surface_bright) -- Gray for inactive
		end
		love.graphics.print("Up", labelX + 30, textY)
		textY = textY + lineHeight

		-- Right
		if rightPressed then
			love.graphics.setColor(colors.ui.green)
		else
			love.graphics.setColor(colors.ui.surface_bright)
		end
		love.graphics.print("Right", labelX + 30, textY)
		textY = textY + lineHeight

		-- Down
		if downPressed then
			love.graphics.setColor(colors.ui.green)
		else
			love.graphics.setColor(colors.ui.surface_bright)
		end
		love.graphics.print("Down", labelX + 30, textY)
		textY = textY + lineHeight

		-- Left
		if leftPressed then
			love.graphics.setColor(colors.ui.green)
		else
			love.graphics.setColor(colors.ui.surface_bright)
		end
		love.graphics.print("Left", labelX + 30, textY)
		textY = textY + lineHeight * 1.5

		-- Draw raw button state (direct button access)
		love.graphics.setColor(colors.ui.accent)
		love.graphics.print("Raw Button States:", 20, textY)
		textY = textY + lineHeight

		local buttonCount = physicalJoystick:getButtonCount()
		local col1Y = textY
		local col2Y = textY

		for i = 1, buttonCount do
			local y = i <= buttonCount / 2 and col1Y or col2Y
			local x = i <= buttonCount / 2 and 30 or 200

			local isDown = false
			-- Try to get button state, with error handling
			pcall(function()
				isDown = physicalJoystick:isDown(i - 1) -- Joystick buttons are 0-indexed
			end)

			-- Set color to green if button is pressed, otherwise normal color
			if isDown then
				love.graphics.setColor(colors.ui.green) -- Green for pressed buttons
			else
				love.graphics.setColor(colors.ui.subtext) -- Gray for unpressed buttons
			end

			love.graphics.print("Button " .. (i - 1), x, y)

			if i <= buttonCount / 2 then
				col1Y = col1Y + lineHeight
			else
				col2Y = col2Y + lineHeight
			end
		end
	end

	-- Show instructions to exit
	local instructionsY = love.graphics.getHeight() - lineHeight * 2
	love.graphics.setColor(colors.ui.subtext)
	love.graphics.print("Press Menu + Y to return to main menu", 20, instructionsY)

	local controlsList = {
		{ button = "menu", text = "+ Y: Exit" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function debug.update(dt)
	-- Return to main menu with the button combination
	if isDebugComboPressed(input.virtualJoystick) then
		screens.switchTo("main_menu")
	end
end

function debug.onEnter()
	-- Reset when entering
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function debug.onExit()
	-- Clean up when exiting the screen
end

return debug
