local love = require("love")

local colors = require("colors")
local controls = require("control_hints").ControlHints
local paths = require("paths")
local screens = require("screens")
local state = require("state")
local version = require("version")
local compat = require("spruce.compat")
local InputManager = require("ui.controllers.input_manager")

local background = require("ui.background")
local fonts = require("ui.fonts")
local Header = require("ui.components.header")

local about = {}

-- Constants
local PADDING = 20
local MENU_SCREEN = "settings"
-- This is an independent fork. Keep the original author's attribution and Ko-fi intact;
-- direct support to them, not to this fork.
local ABOUT_TEXT_PART1 = "Unofficial fork of Aesthetic (not affiliated)."
local GITHUB_LINK = "https://github.com/CatalyticArkun/aesthetic-spruce"
local ABOUT_TEXT_PART2 = [[

Original app by Jonathan Avila:
https://github.com/joneavila/aesthetic
@joneavila (GitHub), @mxdamp (muOS forum)

Made for spruceOS ]] .. compat.supportedFamiliesText() .. ", running " .. tostring(compat.currentVersion() or "unknown")
local KOFI_TEXT = "Support the original author via Ko-fi"

-- Store screen switching function
local qrCodeImage = nil
local controlHintsInstance

function about.onEnter()
	-- Load QR code image
	qrCodeImage = love.graphics.newImage(paths.UI_KOFI_QR_CODE_IMAGE)
	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function about.draw()
	-- Set background
	background.draw()

	local contentWidth = state.screenWidth - (PADDING * 2)
	local font = fonts.loaded.body

	-- Draw header using header module
	local headerInstance = Header:new({
		title = state.applicationName .. " " .. version.getVersionString(),
	})
	headerInstance:draw()
	local headerHeight = headerInstance:getContentStartY()

	-- Calculate Y positions for text
	local bodyY = headerHeight + PADDING

	love.graphics.setFont(font)

	-- Draw Part 1
	love.graphics.setColor(colors.ui.foreground)
	love.graphics.printf(ABOUT_TEXT_PART1, PADDING, bodyY, contentWidth, "left")

	-- Draw GitHub link
	local part1Lines = 1
	love.graphics.setColor(colors.ui.accent)
	love.graphics.printf(GITHUB_LINK, PADDING, bodyY + font:getHeight() * part1Lines, contentWidth, "left")

	-- Draw Part 2
	love.graphics.setColor(colors.ui.foreground)
	-- Count lines in ABOUT_TEXT_PART2
	local about2Lines = 0
	for _ in ABOUT_TEXT_PART2:gmatch("\n") do
		about2Lines = about2Lines + 1
	end
	about2Lines = about2Lines + 1 -- for the last line
	love.graphics.printf(ABOUT_TEXT_PART2, PADDING, bodyY + font:getHeight() * (part1Lines + 1), contentWidth, "left")

	-- Calculate total lines above QR code
	local totalLines = part1Lines + 1 + about2Lines
	local qrY = bodyY + font:getHeight() * totalLines + PADDING

	if qrCodeImage then
		love.graphics.setColor(1, 1, 1, 1)
		local availableHeight = state.screenHeight - qrY - font:getHeight() - PADDING * 2
		local imageWidth = qrCodeImage:getWidth()
		local imageHeight = qrCodeImage:getHeight()
		local scale = math.min(1, availableHeight / imageHeight)
		local scaledWidth = imageWidth * scale
		local qrX = (state.screenWidth - scaledWidth) / 2
		love.graphics.draw(qrCodeImage, qrX, qrY, 0, scale, scale)
		love.graphics.setColor(colors.ui.foreground)
		love.graphics.setFont(font)
		love.graphics.printf(KOFI_TEXT, PADDING, qrY + (imageHeight * scale) + PADDING, contentWidth, "center")
	end

	-- Draw controls
	local controlsList = {
		{ button = "b", text = "Back" },
	}
	controlHintsInstance:setControlsList(controlsList)
	controlHintsInstance:draw()
end

function about.update(dt)
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo(MENU_SCREEN)
	end
end

return about
