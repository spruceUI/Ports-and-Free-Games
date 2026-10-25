--- Main application entry point

--[[
  LÖVE Graphics State Best Practices
  - Always use `love.graphics.push("all")` and `love.graphics.pop()` in top-level screen draw functions to avoid state
    leakage.
  - Each component should also manage its own graphics state if it changes color, scissor, stencil, etc.
  - Unbalanced `push`/`pop` or early returns can cause subtle rendering bugs after screen transitions.
]]

--[[
                         _                _
    /\              _   | |          _   (_)
   /  \   ____  ___| |_ | | _   ____| |_  _  ____
  / /\ \ / _  )/___)  _)| || \ / _  )  _)| |/ ___)
 | |__| ( (/ /|___ | |__| | | ( (/ /| |__| ( (___
 |______|\____|___/ \___)_| |_|\____)\___)_|\____)
--]]

local love = require("love")

local colors = require("colors")
local input = require("input")
local state = require("state")

local autobuild = require("autobuild")
local tour = require("tour")
local display = require("display")
local fonts = require("ui.fonts")
local InputManager = require("ui.controllers.input_manager")
local FocusManager = require("ui.controllers.focus_manager")

local logger = require("utils.logger")
local settings = require("utils.settings")
local system = require("utils.system")

local focusManager = nil

-- Screens module will be initialized after loading
local screens = nil

-- Fade duration for screen transitions
local fadeDuration = 0.5

local function getInitialScreen()
	local envScreen = os.getenv("INIT_SCREEN")
	if envScreen and #envScreen > 0 then
		return envScreen
	end
	return nil
end

-- Crash handling: LÖVE's default error screen has no gamepad exit, which would strand a handheld
-- until it is power-cycled. Log the traceback (session log + userdata/last_crash.txt), show it
-- for a few seconds, then exit so principal.sh brings PyUI back.
local function crashHandler(msg)
	msg = tostring(msg)
	local trace = debug.traceback(msg, 3)
	print("CRASH " .. trace)
	if autobuild.enabled() then
		print("AUTOBUILD FAIL " .. msg)
	end
	io.stdout:flush()
	local rootDir = os.getenv("ROOT_DIR")
	if rootDir then
		local f = io.open(rootDir .. "/userdata/last_crash.txt", "w")
		if f then
			f:write(os.date("%Y-%m-%d %H:%M:%S") .. "\n" .. trace .. "\n")
			f:close()
		end
	end
	if autobuild.enabled() or os.getenv("AESTHETIC_TOUR") == "1" then
		os.exit(1)
	end
	pcall(function()
		love.graphics.reset()
		love.graphics.setCanvas()
		local font = love.graphics.newFont(16)
		love.graphics.setFont(font)
		local t0 = love.timer.getTime()
		while love.timer.getTime() - t0 < 8 do
			love.event.pump()
			for name in love.event.poll() do
				if name == "quit" or name == "keypressed" or name == "gamepadpressed" or name == "joystickpressed" then
					return
				end
			end
			love.graphics.clear(0.35, 0.06, 0.06)
			love.graphics.setColor(1, 1, 1)
			love.graphics.printf(
				"Aesthetic Spruce hit an error and will return to the menu.\n\n" .. msg
					.. "\n\nFull trace: App/AestheticSpruce/userdata/last_crash.txt",
				20, 20, love.graphics.getWidth() - 40)
			love.graphics.present()
			love.timer.sleep(0.05)
		end
	end)
	os.exit(1)
end

function love.errorhandler(msg)
	crashHandler(msg)
end

function love.load()
	state.screenWidth = tonumber(system.getEnvironmentVariable("WIDTH"))
	state.screenHeight = tonumber(system.getEnvironmentVariable("HEIGHT"))
	logger.info("Screen dimensions: " .. state.screenWidth .. "x" .. state.screenHeight)
	logger.info("Gamepad layout: " .. require("gamepad_layout").describe())

	state.isDevMode = os.getenv("DEV") == "true"

	display.load()
	fonts.initializeFonts(state.screenWidth, state.screenHeight)
	input.load()
	settings.loadFromFile()

	-- Load UI components that require initialization
	screens = require("screens")
	screens.load() -- Register all screens

	-- Explicitly load the splash screen since it's the first screen and needs immediate resources
	local splashScreen = require("screens.splash")
	splashScreen.load()
	splashScreen._loadedLazily = true -- Mark as already loaded to prevent double loading

	-- Determine which screen to start with
	local initialScreen = getInitialScreen() or "splash"
	if not screens.isRegistered(initialScreen) then
		print("Error: Initial screen '" .. tostring(initialScreen) .. "' is not registered. Exiting.")
		love.event.quit()
		return
	end
	screens.switchTo(initialScreen)

	if autobuild.enabled() then
		autobuild.start()
	end

	-- Fade effect will be handled after splash screen completes
	state.fading = false


	local focusManager = FocusManager:new()
end

-- Function to handle window resize
function love.resize(width, height)
	logger.debug("Window resized to: " .. width .. "x" .. height)
	state.screenWidth, state.screenHeight = width, height

	-- Recalculate and reload fonts
	fonts.initializeFonts(state.screenWidth, state.screenHeight)

	-- Reload the current screen to update layout
	local currentScreen = screens.getCurrentScreen()
	logger.debug("Reloading screen: " .. currentScreen)
	screens.switchTo(currentScreen)
end

-- AESTHETIC_SCREENSHOT=/abs/path.png: capture the physical window after ~1 s and quit (review aid)
local screenshotPath = os.getenv("AESTHETIC_SCREENSHOT")
local screenshotTimer = 0

function love.update(dt)
	-- Called only once per frame.
	-- All other modules must not call it again to avoid errors from invalid `dt` values.
	if autobuild.enabled() then
		autobuild.update()
	end
	if tour.enabled() then
		tour.update(dt)
	end
	if screenshotPath then
		screenshotTimer = screenshotTimer + dt
		if screenshotTimer > 1.0 then
			screenshotPath, screenshotTimer = nil, 0
			love.graphics.captureScreenshot(function(imageData)
				local png = imageData:encode("png")
				system.writeFile(os.getenv("AESTHETIC_SCREENSHOT"), png:getString())
				print("SCREENSHOT " .. os.getenv("AESTHETIC_SCREENSHOT"))
				love.event.quit(0)
			end)
		end
	end
	InputManager.update(dt)
	if focusManager then
		focusManager:update(dt)
	end

	screens.update(dt)

	if state.fading then
		state.fadeTimer = state.fadeTimer + dt
		if state.fadeTimer >= fadeDuration then
			state.fadeTimer = fadeDuration
			state.fading = false
		end
	end
end

function love.draw()
	display.beginFrame()
	screens.draw()

	-- Apply the fade-in overlay
	if state.fading then
		local fadeProgress = state.fadeTimer / fadeDuration
		local fadeAlpha = 1 - fadeProgress
		love.graphics.setColor(colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], fadeAlpha)
		love.graphics.rectangle("fill", 0, 0, state.screenWidth, state.screenHeight)
	end
	display.endFrame()
end

-- Handle application exit
function love.quit()
	logger.debug("Exiting application")
	if tour.enabled() then
		return -- a smoke test must not persist the values it poked
	end
	settings.saveToFile()

	-- On spruceOS the frontend restarts itself: principal.sh relaunches PyUI when this process
	-- exits, and PyUI reads the "theme" key we wrote. Nothing to do here.
end

return state
