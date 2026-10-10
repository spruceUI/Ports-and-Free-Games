--- Logical-to-physical display mapping
---
--- spruceOS devices with a portrait panel used in landscape (Miniloong Pocket 1, RG28XX, Zero28,
--- A30) expose a rotated framebuffer to SDL: on the Miniloong LÖVE sees 720x960 while the UI is
--- 960x720. PyUI handles this by rendering a logical canvas and rotating it by
--- Device.screen_rotation() with SDL_RenderCopyEx (App/PyUI/main-ui/display/display.py). This
--- module does the same for the app: every frame is drawn onto a WIDTHxHEIGHT canvas, then the
--- canvas is drawn rotated about the centre of the physical window.
local love = require("love")
local state = require("state")
local logger = require("utils.logger")

local display = {}

local canvas = nil
local rotation = 0

function display.load()
	rotation = tonumber(os.getenv("ROTATION") or "0") or 0
	rotation = rotation % 360
	if rotation ~= 0 then
		canvas = love.graphics.newCanvas(state.screenWidth, state.screenHeight)
		local pw, ph = love.graphics.getDimensions()
		logger.info(string.format("Rotated display: logical %dx%d, physical %dx%d, rotation %d",
			state.screenWidth, state.screenHeight, pw, ph, rotation))
	end
end

function display.getRotation()
	return rotation
end

-- Begin drawing a frame in logical coordinates
function display.beginFrame()
	if canvas then
		love.graphics.setCanvas({ canvas, stencil = true })
		love.graphics.clear(0, 0, 0, 1)
	end
end

-- Present the logical frame on the physical window
function display.endFrame()
	if not canvas then
		return
	end
	love.graphics.setCanvas()
	local pw, ph = love.graphics.getDimensions()
	love.graphics.push("all")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setBlendMode("alpha", "premultiplied")
	-- Same convention as PyUI: rotate about the centre; SDL angles are clockwise, as is
	-- love.graphics.rotate in screen space.
	love.graphics.draw(canvas, pw / 2, ph / 2, math.rad(rotation), 1, 1, state.screenWidth / 2, state.screenHeight / 2)
	love.graphics.pop()
end

return display
