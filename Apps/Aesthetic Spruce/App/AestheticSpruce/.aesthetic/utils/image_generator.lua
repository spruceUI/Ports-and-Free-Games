--- Image generation utilities (LÖVE canvases)
--
-- Note on Canvas alpha blending:
-- When drawing content to a Canvas using regular alpha blending in LÖVE,
-- the alpha values get multiplied with RGB values, resulting in premultiplied alpha.
-- See: https://www.love2d.org/wiki/Canvas
--
-- To ensure proper color rendering:
-- 1. Use "alpha" blend mode when drawing TO the canvas
-- 2. Use "alpha", "premultiplied" when displaying the canvas elsewhere
-- 3. Restore original blend mode when finished
--
-- This approach fixes issues where SVG icons appear darker than text when rendered.
local love = require("love")

local state = require("state")

local fonts = require("ui.fonts")

local colorUtils = require("utils.color")
local system = require("utils.system")
local fail = require("utils.fail")

local imageGenerator = {}

-- Create a canvas with background color
function imageGenerator.createCanvas(width, height, bgColor)
	local canvas = love.graphics.newCanvas(width, height)
	local previousCanvas = love.graphics.getCanvas()

	-- Switch to our new canvas for drawing
	love.graphics.setCanvas(canvas)
	love.graphics.clear(bgColor)

	return canvas, previousCanvas
end

-- Finish drawing on canvas and restore previous canvas
function imageGenerator.finishCanvas(previousCanvas)
	-- Restore the previous canvas (important for proper rendering pipeline)
	love.graphics.setCanvas(previousCanvas)
end

-- Undo the premultiplied alpha a canvas leaves in its pixels.
-- Drawing with the default "alphamultiply" blend mode onto a transparent canvas stores
-- colour * alpha; encoded as a PNG and composited as straight alpha (PyUI/SDL_image) every
-- anti-aliased edge pixel then reads darker than the shape, a thin dark seam most visible at
-- rounded corners and on a plate of the same colour. Only pixels with 0 < a < 255 change.
local ffi_ok, ffi = pcall(require, "ffi")
function imageGenerator.unpremultiply(imageData)
	local w, h = imageData:getDimensions()
	if ffi_ok and imageData.getFFIPointer and imageData:getFormat() == "rgba8" then
		local px = ffi.cast("uint8_t*", imageData:getFFIPointer())
		for i = 0, w * h * 4 - 1, 4 do
			local a = px[i + 3]
			if a > 0 and a < 255 then
				local f = 255 / a
				local r, g, b = px[i] * f, px[i + 1] * f, px[i + 2] * f
				px[i] = r > 255 and 255 or r
				px[i + 1] = g > 255 and 255 or g
				px[i + 2] = b > 255 and 255 or b
			end
		end
		return imageData
	end
	imageData:mapPixel(function(_, _, r, g, b, a)
		if a > 0 and a < 1 then
			return math.min(1, r / a), math.min(1, g / a), math.min(1, b / a), a
		end
		return r, g, b, a
	end)
	return imageData
end

-- Give fully transparent pixels the colour of the shape next to them. A canvas leaves them as
-- (0,0,0,0); when PyUI scales the image, SDL's bilinear filter mixes that black into the visible
-- edge, darkest at rounded corners (seen on the Apps list). `color` is a LÖVE colour table.
function imageGenerator.bleedTransparent(imageData, color)
	local w, h = imageData:getDimensions()
	local r8 = math.floor(color[1] * 255 + 0.5)
	local g8 = math.floor(color[2] * 255 + 0.5)
	local b8 = math.floor(color[3] * 255 + 0.5)
	if ffi_ok and imageData.getFFIPointer and imageData:getFormat() == "rgba8" then
		local px = ffi.cast("uint8_t*", imageData:getFFIPointer())
		for i = 0, w * h * 4 - 1, 4 do
			if px[i + 3] == 0 then
				px[i], px[i + 1], px[i + 2] = r8, g8, b8
			end
		end
		return imageData
	end
	imageData:mapPixel(function(_, _, r, g, b, a)
		if a == 0 then
			return color[1], color[2], color[3], 0
		end
		return r, g, b, a
	end)
	return imageData
end

-- Encode a canvas to straight-alpha PNG bytes (see unpremultiply); `opaque` skips the fix-ups,
-- `bleed` (a colour) is written into the transparent pixels
function imageGenerator.encodeCanvas(canvas, opaque, bleed)
	local imageData = canvas:newImageData()
	if not opaque then
		imageGenerator.unpremultiply(imageData)
		if bleed then
			imageGenerator.bleedTransparent(imageData, bleed)
		end
	end
	local pngData = imageData:encode("png")
	imageData:release()
	return pngData
end

-- Create a gradient mesh usable for various UI elements
function imageGenerator.createGradientMesh(direction, ...)
	-- Check for direction
	local isHorizontal = true
	if direction == "Vertical" then
		isHorizontal = false
	elseif direction ~= "Horizontal" then
		error("bad argument #1 to 'createGradientMesh' (invalid value)", 2)
	end

	-- Check for colors
	local colorLen = select("#", ...)
	if colorLen < 2 then
		error("color list is less than two", 2)
	end

	-- Generate mesh
	local meshData = {}
	if isHorizontal then
		for i = 1, colorLen do
			local color = select(i, ...)
			local x = (i - 1) / (colorLen - 1)

			meshData[#meshData + 1] = { x, 1, x, 1, color[1], color[2], color[3], color[4] or 1 }
			meshData[#meshData + 1] = { x, 0, x, 0, color[1], color[2], color[3], color[4] or 1 }
		end
	else
		for i = 1, colorLen do
			local color = select(i, ...)
			local y = (i - 1) / (colorLen - 1)

			meshData[#meshData + 1] = { 1, y, 1, y, color[1], color[2], color[3], color[4] or 1 }
			meshData[#meshData + 1] = { 0, y, 0, y, color[1], color[2], color[3], color[4] or 1 }
		end
	end

	-- Resulting Mesh has 1x1 image size
	return love.graphics.newMesh(meshData, "strip", "static")
end

-- Create the preview.png PyUI shows in its theme picker
function imageGenerator.createPreviewImage(outputPath, width, height, text)
	-- PyUI shows preview.png in its theme picker; SPRUCE ships 640x480
	local previewImageWidth = width or 640
	local previewImageHeight = height or 480

	-- Get colors from state
	local bgColor = colorUtils.hexToLove(state.getColorValue("background"))
	local fgColor = colorUtils.hexToLove(state.getColorValue("foreground"))

	-- Create canvas
	local canvas, previousCanvas = imageGenerator.createCanvas(previewImageWidth, previewImageHeight)

	-- Save current blend mode and graphics state to restore later
	local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()

	-- Clear canvas with transparent color (we'll draw background after)
	love.graphics.clear(0, 0, 0, 0)

	love.graphics.push("all")

	-- Apply background based on background type
	if state.backgroundType == "Gradient" then
		-- Create gradient using gradientMesh function
		local gradientDirection = state.backgroundGradientDirection or "Vertical"
		local gradientColor = colorUtils.hexToLove(state.getColorValue("backgroundGradient"))

		-- Create gradient mesh with background color and gradient color
		local gradientMesh = imageGenerator.createGradientMesh(gradientDirection, bgColor, gradientColor)

		-- Set proper blend mode and color for gradient rendering
		love.graphics.setBlendMode("alpha")
		love.graphics.setColor(1, 1, 1, 1)

		-- Draw gradient filling the entire canvas
		love.graphics.draw(gradientMesh, 0, 0, 0, previewImageWidth, previewImageHeight)
	else
		-- Solid background
		love.graphics.setColor(bgColor)
		love.graphics.rectangle("fill", 0, 0, previewImageWidth, previewImageHeight)
	end

	-- Set font and draw text
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(fgColor)
	local fontFamilyName = state.fontFamily

	local font = fonts.getByName(fontFamilyName)
	love.graphics.setFont(font)

	-- Center text
	local previewImageText = text or state.themeName or "Aesthetic Spruce"
	local textWidth, textHeight = font:getWidth(previewImageText), font:getHeight()
	local textX = (previewImageWidth - textWidth) / 2
	local textY = (previewImageHeight - textHeight) / 2
	love.graphics.print(previewImageText, textX, textY)

	love.graphics.pop()

	-- Restore original blend mode
	love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)

	-- Finish canvas operations
	imageGenerator.finishCanvas(previousCanvas)

	-- Get image data and encode as PNG
	local imageData = canvas:newImageData()
	local pngData = imageData:encode("png")
	if not pngData then
		return fail("Failed to encode preview image to PNG")
	end

	-- Save to file
	return system.writeFile(outputPath, pngData:getString())
end

return imageGenerator
