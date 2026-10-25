--- Settings screen: presets, reset, about
local love = require("love")

local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local List = require("ui.components.list").List
local Modal = require("ui.components.modal").Modal

local presets = require("utils.presets")

local settings = {}

local menuList = nil
local modalInstance = nil
local headerInstance = Header:new({ title = "Settings" })
local controlHintsInstance

local function closeButton()
	return {
		text = "Close",
		onSelect = function()
			modalInstance:hide()
		end,
	}
end

local function createMenuButtons()
	return {
		Button:new({
			text = "Save Theme Preset",
			type = "icon",
			iconName = "arrow-down-to-line",
			onClick = function()
				screens.switchTo("virtual_keyboard", {
					title = "Theme Preset Name",
					returnScreen = "settings",
					inputValue = "",
				})
			end,
		}),
		Button:new({
			text = "Load Theme Preset",
			type = "icon",
			iconName = "arrow-up-from-line",
			onClick = function()
				screens.switchTo("load_preset")
			end,
		}),
		Button:new({
			text = "Reset to Defaults",
			type = "icon",
			iconName = "list-restart",
			onClick = function()
				modalInstance:show("This will clear your customizations. Reset to defaults?", {
					{
						text = "Cancel",
						onSelect = function()
							modalInstance:hide()
						end,
					},
					{
						text = "Confirm",
						onSelect = function()
							state.resetToDefaults()
							modalInstance:show("Reset to defaults successfully!", { closeButton() })
						end,
					},
				})
			end,
		}),
		Button:new({
			text = "About",
			type = "icon",
			iconName = "info",
			onClick = function()
				screens.switchTo("about")
			end,
		}),
	}
end

function settings.draw()
	background.draw()
	headerInstance:draw()
	love.graphics.setFont(fonts.loaded.body)
	if menuList then
		menuList:draw()
	end
	if modalInstance and modalInstance:isVisible() then
		modalInstance:draw(state.screenWidth, state.screenHeight, fonts.loaded.body)
	end
	controlHintsInstance:setControlsList({
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	})
	controlHintsInstance:draw()
end

function settings.update(dt)
	if modalInstance and modalInstance:isVisible() then
		modalInstance:handleInput(nil)
		modalInstance:update(dt)
		return
	end
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, nil)
		menuList:update(dt)
	end
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("main_menu")
	end
end

function settings.onEnter(params)
	modalInstance = Modal:new({ font = fonts.loaded.body })
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - 60,
		items = createMenuButtons(),
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		wrap = false,
	})

	-- Returning from the virtual keyboard with a preset name
	if params and params.inputValue and params.inputValue ~= "" then
		if presets.savePreset(params.inputValue) then
			modalInstance:show("Theme preset saved successfully!", { closeButton() })
		else
			modalInstance:show("Failed to save theme preset", { closeButton() })
		end
	end

	if not controlHintsInstance then
		controlHintsInstance = controls:new({})
	end
end

function settings.onExit()
	if modalInstance then
		modalInstance:hide()
	end
end

return settings
