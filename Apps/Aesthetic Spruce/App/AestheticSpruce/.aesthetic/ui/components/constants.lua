local colors = require("colors")

local SCROLLBAR = {
	WIDTH = 6, -- Standard width for all scrollbars
	PADDING = 10, -- Padding from edge/content (palette uses 10, scrollable uses 6, use 10 for consistency)
	HANDLE_MIN_HEIGHT = 30, -- Minimum handle height (palette)
	CORNER_RADIUS = 4, -- Corner radius for handle and track
	HANDLE_COLOR = colors.ui.scrollbar, -- Handle color (from colors.lua)
	BACKGROUND_COLOR = { colors.ui.surface[1], colors.ui.surface[2], colors.ui.surface[3], 0.3 }, -- Track background (matches scrollable.lua)
}

return {
	SCROLLBAR = SCROLLBAR,
}
