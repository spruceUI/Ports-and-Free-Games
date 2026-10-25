--- Load preset screen
local love = require("love")

local controls = require("control_hints").ControlHints
local screens = require("screens")
local state = require("state")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local List = require("ui.components.list").List
local InputManager = require("ui.controllers.input_manager")

local logger = require("utils.logger")
local presets = require("utils.presets")

-- Module table to export public functions
local loadPreset = {}

-- Local variables for this module
local menuList

-- Preset items list
local presetItems = {}

local header = Header:new({ title = "Load Theme Preset" })
local controlHints

-- Helper function to load presets and verify they are valid
local function loadPresetsList()
	presetItems = {}
	local seen = {}
	local availablePresets = {}
	for _, presetName in ipairs(presets.listPresets()) do
		if not seen[presetName] then
			seen[presetName] = true
			availablePresets[#availablePresets + 1] = presetName
		end
	end
	local presetDetails = {}
	for _, presetName in ipairs(availablePresets) do
		local isValid, presetData = presets.validatePreset(presetName)
		local createdTime = 0
		local displayName = presetName
		local source = "user"
		if presetData then
			if presetData.created then
				createdTime = presetData.created
			end
			if presetData.themeName then
				displayName = presetData.themeName
			end
			if presetData.source then
				source = presetData.source
			end
		end
		table.insert(presetDetails, {
			name = presetName,
			displayName = displayName,
			isValid = isValid,
			created = createdTime,
			source = source,
		})
	end
	-- User presets first, newest first; built-ins have no timestamp, so order those by name
	table.sort(presetDetails, function(a, b)
		if a.created ~= b.created then
			return a.created > b.created
		end
		return tostring(a.displayName):lower() < tostring(b.displayName):lower()
	end)
	for _, detail in ipairs(presetDetails) do
		table.insert(
			presetItems,
			Button:new({
				text = detail.displayName,
				screenWidth = state.screenWidth,
				isValid = detail.isValid,
				onClick = function()
					if detail.isValid then
						local success = presets.loadPreset(detail.name)
						if success then
							screens.switchTo("main_menu")
						else
							logger.error("Failed to load preset: " .. detail.name)
						end
					else
						logger.warning("Attempted to load invalid preset: " .. detail.name)
					end
				end,
			})
		)
	end
end

function loadPreset.draw()
	background.draw()
	header:draw()
	love.graphics.setFont(fonts.loaded.body)

	-- Draw message if no presets found
	if #presetItems == 0 then
		love.graphics.setFont(fonts.loaded.body)
		love.graphics.print("No presets found", 16, header:getContentStartY())

		-- Draw controls
		local controlsList = {
			{ button = "b", text = "Back" },
		}
		controlHints:setControlsList(controlsList)
		controlHints:draw()
		return
	end

	-- Draw the list of presets using the list component
	if menuList then
		menuList:draw()
	end

	-- Draw controls
	local controlsList = {
		{ button = "a", text = "Select" },
		{ button = "b", text = "Back" },
	}
	controlHints:setControlsList(controlsList)
	controlHints:draw()
end

function loadPreset.update(dt)
	if menuList then
		local navDir = InputManager.getNavigationDirection()
		menuList:handleInput(navDir, nil)
		menuList:update(dt)
	end
	if InputManager.isActionPressed(InputManager.ACTIONS.CANCEL) then
		screens.switchTo("settings")
	end
end

function loadPreset.onEnter()
	loadPresetsList()

	-- Calculate available height for the list (full space between header and controls)
	local availableHeight = state.screenHeight - header:getContentStartY() - controls.calculateHeight()

	-- Create menu list
	menuList = List:new({
		x = 0,
		y = header:getContentStartY(),
		width = state.screenWidth,
		height = availableHeight,
		items = presetItems,
		onItemSelect = function(item)
			if item.onClick then
				item.onClick()
			end
		end,
		wrap = false,
	})

	if not controlHints then
		controlHints = controls:new({})
	end
end

-- Clean up resources when leaving the screen
function loadPreset.onExit() end

return loadPreset
