--- Font definitions for the application
-- This module contains all font definitions and utilities used across the application

local love = require("love")
local logger = require("utils.logger")

local fonts = {}

-- Loaded font objects container
fonts.loaded = {}

-- Font name to font key mapping for easy lookup
fonts.nameToKey = {}

-- Theme font choices
fonts.themeDefinitions = {
	{
		name = "Inter",
		ttf = "assets/fonts/inter/inter_24pt_semibold.ttf",
	},
	{
		name = "Montserrat",
		ttf = "assets/fonts/montserrat/montserrat_semibold.ttf",
	},
	{
		name = "Nunito",
		ttf = "assets/fonts/nunito/nunito_bold.ttf",
	},
	{
		name = "JetBrains Mono",
		ttf = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
	},
	{
		name = "Cascadia Code",
		ttf = "assets/fonts/cascadia_code/cascadia_code_bold.ttf",
	},
	{
		name = "Retro Pixel",
		ttf = "assets/fonts/retro_pixel/retro_pixel_thick.ttf",
	},
	{
		name = "Bitter",
		ttf = "assets/fonts/bitter/bitter_semibold.ttf",
	},
}

-- Font definitions mapping
local bodySize = 22
fonts.uiDefinitions = {
	header = { name = "Inter", ttf = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 16 },
	body = { name = "Inter", ttf = "assets/fonts/inter/inter_24pt_semibold.ttf", size = bodySize },
	bodyBold = { name = "Inter", ttf = "assets/fonts/inter/inter_24pt_extrabold.ttf", size = bodySize },
	caption = { name = "Inter", ttf = "assets/fonts/inter/inter_24pt_semibold.ttf", size = 18 },
	monoTitle = { name = "JetBrains Mono", ttf = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 48 },
	monoHeader = {
		name = "JetBrains Mono",
		ttf = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
		size = 32,
	},
	monoBody = {
		name = "JetBrains Mono",
		ttf = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
		size = 21,
	},
	console = {
		name = "JetBrains Mono",
		ttf = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf",
		size = 16,
	},
	error = { name = "JetBrains Mono", ttf = "assets/fonts/jetbrains_mono/jetbrains_mono_bold.ttf", size = 16 },
	nunito = { name = "Nunito", ttf = "assets/fonts/nunito/nunito_bold.ttf", size = 24 },
	retroPixel = { name = "Retro Pixel", ttf = "assets/fonts/retro_pixel/retro_pixel_thick.ttf", size = bodySize },
	cascadiaCode = {
		name = "Cascadia Code",
		ttf = "assets/fonts/cascadia_code/cascadia_code_bold.ttf",
		size = bodySize,
	},
}

-- Initialize font size options with dynamic calculation
fonts.themeFontSizeOptions = {} -- Will be populated in the init function

-- Function to set fonts based on screen dimensions
fonts.initializeFonts = function()
	-- Dynamic UI font scaling
	-- Use fontScalingMultiplier to adjust the intensity of font scaling on non-reference resolutions.
	-- 1.0 = default scaling, < 1.0 reduces scaling, > 1.0 increases it.
	-- e.g., 0.8 makes fonts on larger screens 80% of their default scaled size.
	-- This does not affect font sizes on the 640x480 reference screen.
	local fontScalingMultiplier = 1.0

	local width, height = love.graphics.getDimensions()
	local refWidth, refHeight = 640, 480
	local refDiagonal = math.sqrt(refWidth * refWidth + refHeight * refHeight)
	local currentDiagonal = math.sqrt(width * width + height * height)
	local scalingFactor = currentDiagonal / refDiagonal
	local adaptiveScalingFactor = math.max(0.5, math.min(scalingFactor ^ 0.8, 3.0))

	-- Adjust the scaling intensity with the multiplier
	adaptiveScalingFactor = 1.0 + (adaptiveScalingFactor - 1.0) * fontScalingMultiplier

	fonts.themeFontSizeOptions = {
		["Default"] = 24,
		["Large"] = 28,
		["Extra Large"] = 32,
	}

	for key, def in pairs(fonts.themeDefinitions) do
		fonts.nameToKey[def.name] = key
	end

	-- Load theme fonts into fonts.loaded using font name as key
	for _, def in ipairs(fonts.themeDefinitions) do
		local success, result = pcall(function()
			return love.graphics.newFont(def.ttf, fonts.themeFontSizeOptions["Default"] or 24)
		end)
		if success then
			fonts.loaded[def.name] = result
		else
			logger.error("Failed to load theme font: " .. def.name .. " - " .. tostring(result))
		end
	end

	for key, def in pairs(fonts.uiDefinitions) do
		local scaledSize = math.floor(def.size * adaptiveScalingFactor + 0.5)
		local success, result = pcall(function()
			return love.graphics.newFont(def.ttf, scaledSize)
		end)

		if success then
			fonts.loaded[key] = result
		else
			logger.error("Failed to load font: " .. key .. " - " .. tostring(result))
		end
	end

	fonts.setDefault()
end

-- Helper function to get a font by name
fonts.getByName = function(fontName)
	local font = fonts.loaded[fontName]
	if font then
		return font
	else
		-- Fallback to the default body font if the requested font is not found
		logger.warning("Font '" .. tostring(fontName) .. "' not found, using default body font.")
		return fonts.loaded.body
	end
end

-- Helper function to set the default font
fonts.setDefault = function()
	if love and fonts.loaded.body then
		love.graphics.setFont(fonts.loaded.body)
	else
		logger.error("Failed to set default font - body font not loaded")
	end
end

return fonts
