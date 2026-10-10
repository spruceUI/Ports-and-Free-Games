--- Screen manager module
--- This module manages application screens, handling screen registration, switching, and lifecycle methods
--- (load, enter, exit, update, draw).
--- It automatically loads screens from the `screens` directory and supports returning value passing between screens.
--- The function `screens.load` must be called explicitly by the application after initializing state and fonts.
--- This function discovers and registers all screen modules in the screens directory.
--- Screen resources are loaded lazily when screens are first accessed via switchTo(),
--- except for critical screens that should be loaded explicitly in main.lua (e.g., splash screen).
local love = require("love")

local logger = require("utils.logger")

local screens = {}

-- Private state
local currentScreen = "main_menu" -- Default screen
local registeredScreens = {}
local returnValue = nil -- Store return values from screens

-- Input cooldown state
local inputCooldownTimer = 0
local INPUT_COOLDOWN_DURATION = 0.3

-- Register a screen module
function screens.register(screenName, screenModule)
	if not screenName then
		error("Screen name cannot be nil")
	end

	registeredScreens[screenName] = screenModule
end

function screens.isRegistered(screenName)
	return registeredScreens[screenName] ~= nil
end

function screens.getCurrentScreen()
	return currentScreen
end

function screens.switchTo(screenName, tabName, retVal)
	-- Validate screen name
	if not registeredScreens[screenName] then
		error("Attempting to switch to invalid screen: " .. screenName)
	end

	-- Call exit handler on current screen if it exists
	local currentModule = registeredScreens[currentScreen]
	if currentModule and currentModule.onExit then
		currentModule.onExit()
	end

	-- Store return value
	returnValue = retVal

	-- Switch screens
	currentScreen = screenName

	-- Reset input cooldown timer when switching screens
	inputCooldownTimer = INPUT_COOLDOWN_DURATION

	-- Lazy load resources if the screen hasn't been loaded yet
	local newModule = registeredScreens[currentScreen]
	if newModule then
		-- Check if screen needs lazy loading (has load function but hasn't been loaded)
		if newModule.load and not newModule._loadedLazily then
			logger.debug("Lazy loading resources for screen: " .. tostring(screenName))
			newModule.load()
			newModule._loadedLazily = true
		end

		-- Call enter handler on new screen if it exists
		if newModule.onEnter then
			newModule.onEnter(tabName, returnValue)
		end
	end

	-- Set default font to ensure consistent rendering across screens
	local fonts = require("ui.fonts")
	fonts.setDefault()

	return returnValue
end

function screens.getReturnValue()
	return returnValue
end

function screens.draw()
	-- love.graphics.push("all")
	local currentModule = registeredScreens[currentScreen]
	if currentModule and currentModule.draw then
		currentModule.draw()
	end
	-- love.graphics.pop()
end

function screens.update(dt)
	-- Decrement input cooldown timer
	if inputCooldownTimer > 0 then
		inputCooldownTimer = inputCooldownTimer - dt
	end

	local currentModule = registeredScreens[currentScreen]
	if currentModule and currentModule.update then
		-- Only call update once the screen-transition input cooldown is over
		if inputCooldownTimer <= 0 then
			currentModule.update(dt)
		end
	end
end

function screens.load()
	-- Auto-load screens from the screen directory
	local screenFiles = love.filesystem.getDirectoryItems("screens")

	for _, file in ipairs(screenFiles) do
		-- Remove the .lua extension to get the screen name
		local screenName = file:match("^(.+)%.lua$")
		if screenName then
			local screenModule = require("screens." .. screenName)
			screens.register(screenName, screenModule)
		end
	end
end

return screens
