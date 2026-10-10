local love = require("love")

local colors = require("colors")
local paths = require("paths")
local state = require("state")

local svg = require("utils.svg")

local Component = require("ui.component").Component
local fonts = require("ui.fonts")

-- Constants
local CONTROL_SPACING = 12 -- Horizontal spacing between different control groups
local SCREEN_EDGE_PADDING = 16 -- Padding from edge of screen
local BUTTON_TEXT_SPACING = 2 -- Spacing used for separator between multiple buttons
local BUTTON_HORIZONTAL_PADDING = 4 -- Horizontal padding inside button background
local BUTTON_VERTICAL_PADDING = 2 -- Vertical padding inside button background
local ACTION_TEXT_SPACING = 2 -- Space between button and action text
local CONTROL_BAR_TOP_PADDING = 0 -- Top padding for the control bar
local CONTROL_BAR_BOTTOM_PADDING = 4 -- Bottom padding for the control bar
local DEFAULT_ALIGNMENT = "right" -- Controls alignment: "left" or "right"
local ICON_SIZE = 20 -- Size for control hint icons'
local FONT = fonts.loaded.caption

local BUTTON_ICONS = {
	a = "steam_button_a",
	b = "steam_button_b",
	x = "steam_button_x",
	y = "steam_button_y",
	start = "steam_button_start_custom",
	d_pad = "playstation_dpad_all",
	leftshoulder = "playstation_trigger_l1",
	rightshoulder = "playstation_trigger_r1",
	menu = "steamdeck_button_menu_custom",
}

local iconsByButton = {}
local function getButtonIcon(buttonKey)
	local icon = iconsByButton[buttonKey]
	if icon == nil then
		local iconName = BUTTON_ICONS[buttonKey]
		icon = iconName and svg.loadIcon(iconName, ICON_SIZE, paths.CONTROL_HINTS_SOURCE_DIR .. "/") or false
		iconsByButton[buttonKey] = icon
	end
	return icon or nil
end

local ControlHints = setmetatable({}, { __index = Component })
ControlHints.__index = ControlHints

function ControlHints:new(config)
	config = config or {}
	local instance = Component.new(self, config)
	instance.controls_list = config.controls_list or {}
	instance.alignment = config.alignment or DEFAULT_ALIGNMENT
	instance.font = FONT
	instance.height = ControlHints.calculateHeight(instance.font)
	return instance
end

function ControlHints:setControlsList(controls_list)
	self.controls_list = controls_list or {}
end

function ControlHints:setAlignment(alignment)
	self.alignment = alignment or DEFAULT_ALIGNMENT
end

function ControlHints:getHeight()
	return self.height
end

function ControlHints:draw()
	if not self.visible then
		return
	end
	love.graphics.push("all")
	local controls_list = self.controls_list
	local alignment = self.alignment
	local color = colors.ui.subtext

	-- Calculate total width needed for all controls
	local totalWidth = 0
	for i, control in ipairs(controls_list) do
		local textWidth = self.font:getWidth(control.text)
		local buttonsWidth = 0

		if type(control.button) == "table" then
			for btn, buttonKey in ipairs(control.button) do
				local icon = getButtonIcon(buttonKey)
				if icon then
					buttonsWidth = buttonsWidth + ICON_SIZE + (BUTTON_HORIZONTAL_PADDING * 2)
				end
				if btn < #control.button then
					buttonsWidth = buttonsWidth + self.font:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			local icon = getButtonIcon(control.button)
			if icon then
				buttonsWidth = ICON_SIZE + (BUTTON_HORIZONTAL_PADDING * 2)
			end
		end

		totalWidth = totalWidth + buttonsWidth + ACTION_TEXT_SPACING + textWidth
		if i < #controls_list then
			totalWidth = totalWidth + CONTROL_SPACING
		end
	end

	-- Set starting X position based on alignment
	local x = SCREEN_EDGE_PADDING
	if alignment == "right" then
		x = state.screenWidth - totalWidth - SCREEN_EDGE_PADDING
	end

	local y = state.screenHeight - self.height + (self.height - self.font:getHeight()) / 2

	for i, control in ipairs(controls_list) do
		if type(control.button) == "table" then
			for btn, buttonKey in ipairs(control.button) do
				local icon = getButtonIcon(buttonKey)
				svg.drawIcon(icon, x + BUTTON_HORIZONTAL_PADDING + ICON_SIZE / 2, y + ICON_SIZE / 2, color)
				x = x + ICON_SIZE + (BUTTON_HORIZONTAL_PADDING * 2)
				if btn < #control.button then
					love.graphics.setColor(color)
					love.graphics.setFont(self.font)
					love.graphics.print("/", x + BUTTON_TEXT_SPACING, y)
					x = x + self.font:getWidth("/") + BUTTON_TEXT_SPACING * 2
				end
			end
		else
			local icon = getButtonIcon(control.button)
			svg.drawIcon(icon, x + BUTTON_HORIZONTAL_PADDING + ICON_SIZE / 2, y + ICON_SIZE / 2, color)
			x = x + ICON_SIZE + (BUTTON_HORIZONTAL_PADDING * 2)
		end

		love.graphics.setColor(color)
		love.graphics.setFont(self.font)
		x = x + ACTION_TEXT_SPACING
		love.graphics.print(control.text, x, y - 2)
		x = x + self.font:getWidth(control.text)

		if i < #controls_list then
			x = x + CONTROL_SPACING
		end
	end
	love.graphics.pop()
end

function ControlHints.calculateHeight(fontArg)
	local fontHeight = (fontArg or FONT):getHeight()
	return fontHeight + (BUTTON_VERTICAL_PADDING * 2) + CONTROL_BAR_TOP_PADDING + CONTROL_BAR_BOTTOM_PADDING
end

return { ControlHints = ControlHints }
