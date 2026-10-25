--- Splash screen animation (terminal-style typing effect)
local love = require("love")

local colors = require("colors")
local screens = require("screens")
local state = require("state")

local fonts = require("ui.fonts")

local logger = require("utils.logger")

local splash = {}

function splash.load()
	-- Animation settings
	splash.title = state.applicationName
	splash.typingDelay = 0.07 -- Delay between revealing each character
	splash.cursorBlinkRate = 0.25 -- How fast the cursor blinks
	splash.cursorChar = "_" -- Character used to represent the cursor
	splash.holdDuration = 1.2 -- Duration to display the complete text before fading out
	splash.fadeOutDuration = 0.05 -- Duration of the fade out animation

	-- Initialize animation state
	splash.currentIndex = 0 -- How many letters have been revealed
	splash.letterTimer = 0 -- Timer for next letter
	splash.cursorTimer = 0 -- Timer for cursor blink
	splash.showCursor = true -- Whether cursor is currently visible
	splash.alpha = 1 -- Overall opacity for fade out
	splash.holdTimer = 0 -- Timer for hold phase
	splash.fadeTimer = 0 -- Timer for fade phase

	-- Use the mono title font
	splash.font = fonts.loaded.monoTitle

	-- Dimensions for positioning
	splash.cursorWidth = splash.font:getWidth(splash.cursorChar)
	splash.textHeight = splash.font:getHeight()

	-- Wrap on whole words once, up front: a narrow portrait panel (the Zero 40 is 480 wide) cannot
	-- fit the title on one line, and wrapping per frame would reflow it as it types. The limit
	-- leaves room for the cursor so it never wraps as text.
	local pad = math.max(8, math.floor(state.screenWidth * 0.04))
	local limit = state.screenWidth - pad * 2 - splash.cursorWidth
	local _, lines = splash.font:getWrap(splash.title, limit)
	splash.lines = (lines and #lines > 0) and lines or { splash.title }
	splash.lineX = {}
	splash.totalChars = 0
	for i, line in ipairs(splash.lines) do
		splash.lineX[i] = math.floor(state.screenWidth / 2 - splash.font:getWidth(line) / 2)
		splash.totalChars = splash.totalChars + #line
	end
	splash.startY = math.floor(state.screenHeight / 2 - (#splash.lines * splash.textHeight) / 2)

	-- State machine: controls the animation phase (waiting, typing, holding, fading, done)
	splash.state = "waiting"

	-- Background settings
	splash.background = {
		color = { colors.ui.background[1], colors.ui.background[2], colors.ui.background[3], 1 },
	}
end

function splash.onEnter()
	-- Reset animation state when entering the screen
	splash.currentIndex = 0
	splash.letterTimer = 0
	splash.cursorTimer = 0
	splash.showCursor = true
	splash.alpha = 1
	splash.holdTimer = 0
	splash.fadeTimer = 0
	splash.state = "waiting"
end

-- The line currently being typed and how many of its characters are revealed
function splash.typedPosition()
	local remaining = splash.currentIndex
	for i, line in ipairs(splash.lines) do
		if remaining <= #line then
			return i, remaining
		end
		remaining = remaining - #line
	end
	local last = math.max(1, #splash.lines)
	return last, #(splash.lines[last] or "")
end

function splash.draw()
	local ok, err = pcall(function()
		love.graphics.clear(splash.background.color)
		if not splash.font then
			return
		end
		love.graphics.push("all")
		love.graphics.setFont(splash.font)

		love.graphics.setColor(colors.ui.foreground[1], colors.ui.foreground[2], colors.ui.foreground[3], splash.alpha)

		-- Draw every finished line, then the part of the line being typed
		local activeLine, activeShown = splash.typedPosition()
		for i = 1, activeLine do
			local shown = (i == activeLine) and activeShown or #splash.lines[i]
			if shown > 0 then
				local text = string.sub(splash.lines[i], 1, shown)
				love.graphics.print(text, splash.lineX[i], splash.startY + (i - 1) * splash.textHeight)
			end
		end

		-- Draw cursor after the last revealed character if it should be visible
		if (splash.state == "typing" or splash.state == "holding") and splash.showCursor then
			local typed = string.sub(splash.lines[activeLine], 1, activeShown)
			local cursorX = math.floor(splash.lineX[activeLine] + splash.font:getWidth(typed))
			love.graphics.print(splash.cursorChar, cursorX, splash.startY + (activeLine - 1) * splash.textHeight)
		end
		love.graphics.pop()
	end)
	if not ok then
		logger.error("Error in splash.draw: " .. tostring(err))
	end
end

function splash.update(dt)
	if not dt then
		logger.error("dt is nil in splash.update")
		return
	end

	if splash.state == "done" then
		return
	end

	splash.cursorTimer = splash.cursorTimer + dt
	if splash.cursorTimer >= splash.cursorBlinkRate then
		splash.cursorTimer = 0
		splash.showCursor = not splash.showCursor
	end

	-- State machine
	if splash.state == "waiting" then
		splash.letterTimer = splash.letterTimer + dt
		if splash.letterTimer >= 0.3 then
			splash.state = "typing"
			splash.letterTimer = 0
		end
	elseif splash.state == "typing" then
		splash.letterTimer = splash.letterTimer + dt
		if splash.letterTimer >= splash.typingDelay then
			splash.letterTimer = 0
			splash.currentIndex = splash.currentIndex + 1
			if splash.currentIndex >= splash.totalChars then
				splash.state = "holding"
				splash.holdTimer = splash.holdDuration
			end
		end
	elseif splash.state == "holding" then
		splash.holdTimer = splash.holdTimer - dt
		if splash.holdTimer <= 0 then
			splash.state = "fading"
		end
	elseif splash.state == "fading" then
		splash.fadeTimer = splash.fadeTimer + dt
		splash.alpha = math.max(0, 1 - (splash.fadeTimer / splash.fadeOutDuration))
		if splash.alpha <= 0 then
			splash.state = "done"
			state.fading = true
			state.fadeTimer = 0
			screens.switchTo("main_menu")
		end
	end
end

return splash
