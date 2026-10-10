-- Shared utilities for color_picker subscreens
local Header = require("ui.components.header")
local controls = require("control_hints").ControlHints

local headerInstance = Header:new({ title = "" })
local controlHintsInstance = controls:new({})
local TabBar = require("ui.components.tab_bar")

local shared = {}

shared.PADDING = 16
shared.OUTLINE_WIDTH_FOCUS = 3

function shared.calculateContentArea()
	local state = require("state")
	local headerContentStartY = headerInstance:getContentStartY()
	local tabBarHeight = TabBar.getHeight()
	local controlsHeight = controlHintsInstance:getHeight()
	local contentTopPadding = 8
	return {
		x = 0,
		y = headerContentStartY + tabBarHeight + contentTopPadding,
		width = state.screenWidth,
		height = state.screenHeight - (headerContentStartY + tabBarHeight) - controlsHeight,
	}
end

return shared
