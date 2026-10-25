--- LÖVE configuration file
local love = require("love")

function love.conf(t)
	local dev_mode = os.getenv("DEV") == "true"
	t.window.width = tonumber(os.getenv("WIDTH")) or 640
	t.window.height = tonumber(os.getenv("HEIGHT")) or 480
	t.window.resizable = false
	t.window.msaa = 0 -- MSAA is not worth the fill rate on Mali; shapes are drawn with smooth edges
	t.window.title = "Aesthetic Spruce"
	-- Portrait panels used in landscape (ROTATION 90/270): the physical window is HEIGHTxWIDTH;
	-- src/display.lua renders the logical WIDTHxHEIGHT frame rotated into it.
	local rotation = tonumber(os.getenv("ROTATION") or "0") or 0
	if rotation % 180 ~= 0 then
		t.window.width, t.window.height = t.window.height, t.window.width
	end
	t.version = "11.5"
	t.accelerometerjoystick = false
	t.window.fullscreen = not dev_mode
	t.window.fullscreentype = "desktop" -- matches the probe run on TSPS/Miniloong (mode = desktop size)
	t.window.borderless = true
	t.gammacorrect = true -- Enable gamma correction (when supported) for better color accuracy
	-- "Setting unused modules to false is encouraged when you release your game. It reduces startup time slightly
	-- (especially if the joystick module is disabled) and reduces memory usage (slightly)."
	-- https://www.love2d.org/wiki/Config_Files
	t.modules.mouse = false
	t.modules.physics = false
	t.modules.touch = false
	t.modules.video = false
end
