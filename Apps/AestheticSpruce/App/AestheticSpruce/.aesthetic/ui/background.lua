--- Background UI component
-- This module provides consistent background rendering for screens

local love = require("love")

local colors = require("colors")

local background = {}

-- Draw a standard background for screens
function background.draw()
	-- love.graphics.push("all")
	love.graphics.clear(colors.ui.background)
	-- love.graphics.pop()
end

return background
