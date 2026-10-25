--- New Main Menu Screen
--- Uses the new component system for better maintainability
local love = require("love")

local controls = require("control_hints").ControlHints
local errorHandler = require("error_handler")
local screens = require("screens")
local state = require("state")
local themeCreator = require("theme_creator")

local background = require("ui.background")
local Button = require("ui.components.button").Button
local ButtonTypes = require("ui.components.button").TYPES
local Container = require("ui.layouts.container").Container
local fonts = require("ui.fonts")
local Header = require("ui.components.header")
local InputManager = require("ui.controllers.input_manager")
local List = require("ui.components.list").List
local Modal = require("ui.components.modal").Modal
local FocusManager = require("ui.controllers.focus_manager")

local logger = require("utils.logger")
local compat = require("spruce.compat")
local autobuild = require("autobuild")

local menu = {}

-- UI Components
local menuList = nil
local actionButton = nil
local input = nil
local modal = nil
local headerInstance = Header:new({ title = "Main Menu" })
local controlHintsInstance = controls:new({})
local rootContainer = nil
local focusManager = nil

-- Constants
local CONTROLS_HEIGHT = controls.calculateHeight()
local ACTION_BUTTON_HEIGHT = 50
local ACTION_BUTTON_SPACING = 8
local TOTAL_BOTTOM_AREA_HEIGHT = CONTROLS_HEIGHT + ACTION_BUTTON_HEIGHT + ACTION_BUTTON_SPACING
local ACTION_BUTTON_WIDTH_RATIO = 0.9

-- IO operation states
local waitingState = "none"
local waitingThemePath = nil
local createdThemePath = nil

-- Coroutine handling
local activeCoroutine = nil

-- Fixed modal width (80% of screen width)
local function getFixedModalWidth()
	return math.floor(state.screenWidth * 0.8)
end

-- Helper function to truncate long theme names for display
local function truncateThemeName(name)
	local MAX_NAME_LENGTH = 20
	if #name > MAX_NAME_LENGTH then
		return string.sub(name, 1, MAX_NAME_LENGTH - 3) .. "..."
	end
	return name
end

-- Create all the menu buttons
local function createMenuButtons()
	local buttons = {}

	-- Home screen layout button
	table.insert(
		buttons,
		Button:new({
			text = "Home Screen Layout",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.homeScreenLayout,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("home_screen_layout")
			end,
		})
	)

	-- Background button
	table.insert(
		buttons,
		Button:new({
			text = "Background",
			type = state.backgroundType == "Gradient" and ButtonTypes.GRADIENT or ButtonTypes.COLOR,
			hexColor = state.backgroundType ~= "Gradient" and state.getColorValue("background") or nil,
			startColor = state.backgroundType == "Gradient" and state.getColorValue("background") or nil,
			stopColor = state.backgroundType == "Gradient" and state.getColorValue("backgroundGradient") or nil,
			direction = state.backgroundGradientDirection or "Vertical",
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("background")
			end,
		})
	)

	-- Foreground button
	table.insert(
		buttons,
		Button:new({
			text = "Foreground",
			type = ButtonTypes.COLOR,
			hexColor = state.getColorValue("foreground"),
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				state.activeColorContext = "foreground"
				state.previousScreen = "main_menu"
				screens.switchTo("color_picker")
			end,
		})
	)

	-- Battery button
	table.insert(
		buttons,
		Button:new({
			text = "Battery",
			type = ButtonTypes.DUAL_COLOR,
			color1Hex = state.getColorValue("batteryActive"),
			color2Hex = state.getColorValue("batteryLow"),
			monoFont = fonts.loaded.monoBody,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("battery")
			end,
		})
	)

	-- Font Family button
	table.insert(
		buttons,
		Button:new({
			text = "Font Family",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.fontFamily,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("font_family")
			end,
		})
	)

	-- Icons button
	table.insert(
		buttons,
		Button:new({
			text = "Icons",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.systemIcons and state.systemIconStyle or "Disabled",
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("icons")
			end,
		})
	)

	-- Bars button (top bar title, clock, battery, bottom bar hints)
	local function getBarsPreviewText()
		local shown = 0
		for _, key in ipairs({ "showTopBarText", "showClock", "showBattery", "showBottomBar" }) do
			if state[key] then
				shown = shown + 1
			end
		end
		return shown .. " of 4 shown"
	end

	table.insert(
		buttons,
		Button:new({
			text = "Bars",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = getBarsPreviewText(),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("bars")
			end,
		})
	)

	-- spruceOS Options button (PyUI view types and tiles)
	table.insert(
		buttons,
		Button:new({
			text = "spruceOS Options",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.gameListView,
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("spruce_options")
			end,
		})
	)

	-- Box Art Width button
	table.insert(
		buttons,
		Button:new({
			text = "Box Art Width",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = state.boxArtWidth == 0 and "Disabled" or tostring(state.boxArtWidth),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("box_art_width")
			end,
		})
	)

	-- Theme Name button
	table.insert(
		buttons,
		Button:new({
			text = "Theme Name",
			type = ButtonTypes.TEXT_PREVIEW,
			previewText = truncateThemeName(state.themeName),
			screenWidth = state.screenWidth,
			onClick = function()
				screens.switchTo("virtual_keyboard", {
					returnScreen = "main_menu",
					title = "Theme Name",
				})
			end,
		})
	)

	return buttons
end

-- Create the action button
local function createActionButton()
	local width = math.floor(state.screenWidth * ACTION_BUTTON_WIDTH_RATIO)
	local x = math.floor((state.screenWidth - width) / 2)
	return Button:new({
		text = "Build Theme",
		type = ButtonTypes.ACCENTED,
		x = x,
		width = width,
		height = ACTION_BUTTON_HEIGHT,
		screenWidth = state.screenWidth,
		onClick = function()
			waitingState = "show_create_modal"
		end,
	})
end

-- Handle option cycling for buttons with context
local function handleOptionCycle(button, direction)
	if not button.context then
		return false
	end

	local changed = button:cycleOption(direction)
	if not changed then
		return false
	end

	return true
end

-- Handle theme creation process using coroutines
local function handleThemeCreation()
	if not activeCoroutine then
		-- Start the coroutine
		activeCoroutine = themeCreator.createThemeCoroutine()

		-- Show initial modal with main message and set fixed size
		modal:show("Building Theme")
		focusManager:clearFocus()
		if getFixedModalWidth() > 0 then
			modal:setFixedWidth(getFixedModalWidth())
		end
	end

	-- Resume the coroutine
	local ok, isSuccess, pathOrError = coroutine.resume(activeCoroutine)

	if not ok then
		-- Coroutine error
		activeCoroutine = nil
		waitingState = "none"
		local errorMessage = pathOrError or errorHandler.getError() or "Unknown error"
		local modalText = "Error building theme: " .. errorMessage
		modal:show(modalText, { { text = "Exit", selected = true, type = ButtonTypes.ACCENTED } })
		modal.onButtonPress = menu._modalButtonHandler
		focusManager:clearFocus()
		return
	end

	if coroutine.status(activeCoroutine) == "dead" then
		-- Coroutine completed
		activeCoroutine = nil
		waitingState = "none"

		if isSuccess and type(pathOrError) == "string" then
			createdThemePath = pathOrError
			modal:show("Built theme successfully!", {
				{ text = "Activate Now", selected = true },
				{ text = "Keep Editing", selected = false },
			})
			modal.onButtonPress = menu._modalButtonHandler
			focusManager:clearFocus()
		else
			-- Failure
			local errorMessage = pathOrError or errorHandler.getError() or "Unknown error"
			local modalText = "Error building theme: " .. errorMessage
			modal:show(modalText, { { text = "Exit", selected = true, type = ButtonTypes.ACCENTED } })
			modal.onButtonPress = menu._modalButtonHandler
			focusManager:clearFocus()
		end
	else
		-- Coroutine yielded with progress message
		if type(isSuccess) == "string" then
			modal:updateProgress(isSuccess)
		end
	end
end

-- Handle theme installation process using coroutines
local function handleThemeInstallation()
	logger.debug(
		"handleThemeInstallation called. activeCoroutine="
			.. tostring(activeCoroutine)
			.. ", waitingThemePath="
			.. tostring(waitingThemePath)
	)
	if not activeCoroutine then
		local filename_only = waitingThemePath and waitingThemePath:gsub("/+$", ""):match("([^/\\]+)$")
		logger.debug("handleThemeInstallation: filename_only=" .. tostring(filename_only))
		if not filename_only then
			logger.debug("handleThemeInstallation: No valid filename, aborting.")
			modal:show("Failed to apply theme (no valid filename).", { { text = "Close", selected = true } })
			focusManager:clearFocus()
			waitingState = "none"
			return
		end

		-- Start the coroutine
		activeCoroutine = themeCreator.installThemeCoroutine(filename_only)
		logger.debug("Started installThemeCoroutine for " .. tostring(filename_only))
		-- Show initial modal with main message and set fixed size
		modal:show("Activating Theme")
		focusManager:clearFocus()
		if getFixedModalWidth() > 0 then
			modal:setFixedWidth(getFixedModalWidth())
		end
	end

	-- Resume the coroutine
	local success, result, _ = coroutine.resume(activeCoroutine)
	logger.debug("coroutine.resume result: success=" .. tostring(success) .. ", result=" .. tostring(result))

	if not success then
		logger.debug("Coroutine error in handleThemeInstallation: " .. tostring(result))
		-- Coroutine error
		activeCoroutine = nil
		waitingState = "none"
		waitingThemePath = nil
		local errorMessage = errorHandler.getError() or result or "Unknown error"
		modal:show("Failed to apply theme: " .. errorMessage, { { text = "Close", selected = true } })
		focusManager:clearFocus()
		return
	end

	if coroutine.status(activeCoroutine) == "dead" then
		logger.debug("Theme install coroutine completed. Result: " .. tostring(result))
		-- Coroutine completed
		activeCoroutine = nil
		waitingState = "none"
		waitingThemePath = nil
		state.themeApplied = true

		modal:show(
			result and "Activated theme successfully!"
				or ("Failed to apply theme: " .. (errorHandler.getError() or "Unknown error")),
			{ { text = "Close", selected = true } }
		)
		focusManager:clearFocus()
	else
		-- Coroutine yielded with progress message
		if type(result) == "string" then
			logger.debug("Theme install coroutine yielded: " .. tostring(result))
			modal:updateProgress(result)
		end
	end
end

function menu.draw()
	love.graphics.push("all")
	background.draw()

	-- Draw all UI via root container
	if rootContainer then
		rootContainer:draw()
	end

	-- Draw modal if active (overlays UI)
	if modal and modal:isVisible() then
		modal:draw(state.screenWidth, state.screenHeight, fonts.loaded.body)
	end
	love.graphics.pop()
end

function menu.update(dt)
	local modalHandled = false
	if modal and modal:isVisible() then
		modalHandled = modal:handleInput(input)
		modal:update(dt)
	end

	-- Handle IO operations (coroutine progress, etc.)
	if waitingState == "show_create_modal" then
		waitingState = "create_theme"
		return
	elseif waitingState == "create_theme" then
		handleThemeCreation()
		return
	elseif waitingState == "install_theme" then
		handleThemeInstallation()
		return
	end

	if modalHandled then
		return
	end

	if focusManager then
		focusManager:update(dt)
	end

	-- Update all UI via root container
	if rootContainer then
		rootContainer:update(dt)
	end

	-- Focus navigation
	local navDir = InputManager.getNavigationDirection()
	if focusManager then
		focusManager:handleInput(navDir, input)
	end

	-- Handle confirm/select (A button) input
	if InputManager.isActionJustPressed(InputManager.ACTIONS.CONFIRM) then
		if focusManager then
			local focused = focusManager:getFocused()
			if focused == menuList then
				local selectedItem = menuList:getSelectedItem()
				if selectedItem and menuList.onItemSelect then
					menuList.onItemSelect(selectedItem, menuList.selectedIndex)
				end
			elseif focused == actionButton then
				if actionButton.onClick then
					actionButton.onClick(actionButton)
				end
			end
		end
	end

	-- Handle Start button to open settings
	if InputManager.isActionJustPressed(InputManager.ACTIONS.OPEN_MENU) then
		screens.switchTo("settings")
	end

	-- Handle B button to exit application
	if
		InputManager.isActionJustPressed(InputManager.ACTIONS.CANCEL)
		and (waitingState == "none")
		and not (modal and modal:isVisible())
	then
		love.event.quit()
	end
end

-- Store the current focus state when exiting
local lastFocusState = { actionButtonFocused = false, selectedIndex = 1 }

function menu.onExit()
	-- Remember the current focus state
	if focusManager then
		local focused = focusManager:getFocused()
		lastFocusState.actionButtonFocused = (focused == actionButton)
	end
	if menuList then
		lastFocusState.selectedIndex = menuList.selectedIndex or 1
	end
end

function menu.onEnter(data)
	-- Create modal component
	local function modalButtonHandler(button)
		if button and button.text == "Apply theme later" then
			modal:hide()
			focusManager:setFocused(actionButton)
		elseif button and button.text == "Activate Now" then
			if state.isDevMode then
				modal:show("You can't install a theme in dev mode!", { { text = "Close", selected = true } })
				modal.onButtonPress = modalButtonHandler
				focusManager:clearFocus()
				return
			end
			if type(createdThemePath) == "string" and createdThemePath ~= "" then
				waitingThemePath = createdThemePath
				logger.debug("Set waitingThemePath=" .. tostring(waitingThemePath))
				modal:show("Activating theme...")
				modal.onButtonPress = modalButtonHandler
				focusManager:clearFocus()
				waitingState = "install_theme"
				logger.debug("Set waitingState=install_theme")
			else
				logger.debug("No theme path to apply.")
				modal:show("No theme path to apply.", { { text = "Close", selected = true } })
				modal.onButtonPress = modalButtonHandler
				focusManager:clearFocus()
			end
		elseif button and button.text == "Continue" then
			modal:hide()
			focusManager:setFocused(menuList)
		elseif button and button.text == "Quit" then
			love.event.quit()
		elseif button and button.text == "Exit" then
			logger.debug("Modal: Exit pressed")
			modal:hide()
			focusManager:setFocused(actionButton)
		else
			logger.debug("Modal: Other button pressed")
			modal:hide()
			focusManager:setFocused(actionButton)
		end
	end
	menu._modalButtonHandler = modalButtonHandler
	modal = Modal:new({
		font = fonts.loaded.body,
		onButtonPress = modalButtonHandler,
	})

	-- Create UI components with current state
	local buttons = createMenuButtons()
	menuList = List:new({
		x = 0,
		y = headerInstance:getContentStartY(),
		width = state.screenWidth,
		height = state.screenHeight - headerInstance:getContentStartY() - TOTAL_BOTTOM_AREA_HEIGHT - 8,
		items = buttons,
		onItemSelect = function(item, _index)
			if item.onClick then
				item.onClick()
			end
		end,
		onItemOptionCycle = handleOptionCycle,
		wrap = false,
	})

	-- Calculate action button width and x based on list's content area
	local listContentX = menuList.x + menuList.paddingX
	local listContentWidth = menuList.width - menuList.paddingX * 2
	local actionButtonWidth = math.floor(listContentWidth * ACTION_BUTTON_WIDTH_RATIO)
	local actionButtonX = listContentX + math.floor((listContentWidth - actionButtonWidth) / 2)

	actionButton = createActionButton()
	actionButton.x = actionButtonX
	actionButton.width = actionButtonWidth

	-- Focus manager setup
	focusManager = FocusManager:new()
	focusManager.wrapNavigation = true
	focusManager:registerComponent(menuList)
	focusManager:registerComponent(actionButton)

	-- Restore focus state properly
	if lastFocusState.actionButtonFocused then
		focusManager:setFocused(actionButton)
		menuList:setSelectedIndex(0)
	else
		focusManager:setFocused(menuList)
		local validIndex = math.min(math.max(lastFocusState.selectedIndex, 1), #buttons)
		menuList:setSelectedIndex(validIndex)
	end

	-- spruceOS compatibility warning, once per session (never in headless runs). Needs the focus
	-- manager above: the modal takes focus from it.
	if not menu._compatChecked and not autobuild.enabled() then
		menu._compatChecked = true
		local result = compat.check()
		if result.level ~= "ok" then
			logger.warning("Compatibility: " .. result.message:gsub("\n", " "))
			modal:show(result.message, {
				{ text = "Continue", selected = true },
				{ text = "Quit", selected = false },
			})
			focusManager:clearFocus()
		end
	end

	-- Control hints setup
	controlHintsInstance:setControlsList({
		{ button = "start", text = "Settings" },
		{ button = "a", text = "Select" },
		{ button = "b", text = "Exit" },
	})
	controlHintsInstance.y = state.screenHeight - CONTROLS_HEIGHT
	controlHintsInstance.x = 0
	controlHintsInstance.width = state.screenWidth
	controlHintsInstance.height = CONTROLS_HEIGHT

	-- Action button position
	actionButton.y = state.screenHeight - CONTROLS_HEIGHT - ACTION_BUTTON_HEIGHT - ACTION_BUTTON_SPACING

	-- Header position
	headerInstance.x = 0
	headerInstance.y = 0
	headerInstance.width = state.screenWidth

	-- Create root container and add children
	rootContainer = Container:new({
		x = 0,
		y = 0,
		width = state.screenWidth,
		height = state.screenHeight,
		backgroundColor = nil, -- background is drawn separately
	})
	rootContainer:clearChildren() -- For when returning to main menu
	rootContainer:addChild(headerInstance)
	rootContainer:addChild(menuList)
	rootContainer:addChild(actionButton)
	rootContainer:addChild(controlHintsInstance)

	-- Check for returned data from virtual_keyboard
	if data and type(data) == "table" and data.inputValue then
		if data.returnScreen == "main_menu" and data.title == "Theme Name" then
			local cleanThemeName = data.inputValue:gsub("^%s*(.-)%s*$", "%1")
			state.themeName = "Aesthetic Spruce"
			if cleanThemeName ~= "" then
				state.themeName = cleanThemeName
			end

			-- Update the theme name button
			local themeNameButton = nil
			for _, button in ipairs(menuList.items) do
				if button.text == "Theme Name" then
					themeNameButton = button
					break
				end
			end

			if themeNameButton then
				themeNameButton:setPreviewText(truncateThemeName(state.themeName))
			end
		end
	end

	-- Update buttons' preview text
	for _, button in ipairs(menuList.items) do
		if button.text == "Home Screen Layout" then
			button:setPreviewText(state.homeScreenLayout)
		elseif button.text == "Icons" then
			button:setPreviewText(state.systemIcons and state.systemIconStyle or "Disabled")
		elseif button.text == "Bars" then
			local shown = 0
			for _, key in ipairs({ "showTopBarText", "showClock", "showBattery", "showBottomBar" }) do
				if state[key] then
					shown = shown + 1
				end
			end
			button:setPreviewText(shown .. " of 4 shown")
		elseif button.text == "spruceOS Options" then
			button:setPreviewText(state.gameListView)
		elseif button.text == "Battery" then
			button.color1Hex = state.getColorValue("batteryActive")
			button.color2Hex = state.getColorValue("batteryLow")
		end
	end
end

return menu
