--- Icon drawing utilities (PNG-backed)
--
-- Historically this module rendered SVG files at runtime through TÖVE (libTove.so). That native
-- library needs glibc 2.38, which is newer than every spruceOS device except the Flip and the
-- Miniloong, so the fork pre-rasterises the icon set on the host instead
-- (utils/generate_ui_icon_pngs.py -> assets/icons/png/<set>/<name>.png) and tints the PNGs here
-- with love.graphics.setColor. The public API is unchanged so call sites did not have to move:
--   loadIcon(name, size, basePath) -> icon handle (cached per name/size/basePath)
--   drawIcon(icon, x, y, color, opacity) draws the icon CENTRED on (x, y), like TÖVE did.
-- The PNGs are white-on-transparent masks rendered at 128 px and scaled down at draw time.
local love = require("love")
local fail = require("utils.fail")
local logger = require("utils.logger")

local svg = {}

local DEFAULT_BASE_PATH = "assets/icons/lucide/ui/"

-- Icon cache keyed by basePath .. name .. size
local iconCache = {}
-- Image cache keyed by PNG path so several sizes share one texture
local imageCache = {}

-- Map an SVG base path (relative "assets/icons/<set>/" or absolute ".../assets/icons/<set>/")
-- to the rasterised PNG tree "assets/icons/png/<set>/".
local function pngPathFor(name, basePath)
	local dir = basePath
	if not dir:find("assets/icons/png/", 1, true) then
		dir = dir:gsub("assets/icons/", "assets/icons/png/", 1)
	end
	return dir .. name .. ".png"
end

-- love.graphics.newImage only accepts love.filesystem paths (relative to the game directory);
-- absolute OS paths (paths.UI_ICON_PNG_DIR on device, or a dev checkout) go through io.open.
local function newImageFromPath(pngPath)
	if pngPath:sub(1, 1) ~= "/" then
		return love.graphics.newImage(pngPath)
	end
	local f, err = io.open(pngPath, "rb")
	if not f then
		error(err or ("cannot open " .. pngPath))
	end
	local bytes = f:read("*a")
	f:close()
	local fileData = love.filesystem.newFileData(bytes, pngPath:match("[^/]+$"))
	return love.graphics.newImage(love.image.newImageData(fileData))
end

local function loadImage(pngPath)
	if imageCache[pngPath] == nil then
		local ok, image = pcall(newImageFromPath, pngPath)
		if ok and image then
			image:setFilter("linear", "linear")
			imageCache[pngPath] = image
		else
			imageCache[pngPath] = false
			logger.error("Failed to load icon PNG: " .. pngPath .. " (" .. tostring(image) .. ")")
		end
	end
	return imageCache[pngPath] or nil
end

-- Check if an icon is loaded in the cache
function svg.isIconLoaded(name, size, basePath)
	basePath = basePath or DEFAULT_BASE_PATH
	size = size or 24
	return iconCache[basePath .. name .. "_" .. size] ~= nil
end

-- Load an icon; returns a handle { image, size, scale, ox, oy } or false, err
function svg.loadIcon(name, size, basePath)
	basePath = basePath or DEFAULT_BASE_PATH
	size = size or 24
	local cacheKey = basePath .. name .. "_" .. size
	local icon = iconCache[cacheKey]
	if icon then
		return icon
	end
	local pngPath = pngPathFor(name, basePath)
	local image = loadImage(pngPath)
	if not image then
		return fail("Failed to load icon: " .. pngPath)
	end
	local w, h = image:getDimensions()
	icon = {
		image = image,
		size = size,
		scale = size / math.max(w, h),
		ox = w / 2,
		oy = h / 2,
	}
	iconCache[cacheKey] = icon
	return icon
end

-- Draw an icon centred on (x, y) tinted with color {r, g, b} at the given opacity
function svg.drawIcon(icon, x, y, color, opacity)
	if not icon or not icon.image then
		return icon
	end
	local prevBlendMode, prevAlphaMode = love.graphics.getBlendMode()
	local prevR, prevG, prevB, prevA = love.graphics.getColor()

	love.graphics.setBlendMode("alpha")
	local r, g, b = 1, 1, 1
	if color then
		r, g, b = color[1], color[2], color[3]
	end
	love.graphics.setColor(r, g, b, opacity or 1.0)
	love.graphics.draw(icon.image, x, y, 0, icon.scale, icon.scale, icon.ox, icon.oy)

	love.graphics.setBlendMode(prevBlendMode, prevAlphaMode)
	love.graphics.setColor(prevR, prevG, prevB, prevA)
	return icon
end

-- Draw a PNG icon (by path) centred on (x, y) onto the current canvas.
-- Kept for the theme renderer, which draws tinted pictograms into skin assets.
function svg.drawImageOnCanvas(pngPath, size, x, y, color, restoreBlendMode)
	love.graphics.setBlendMode("alpha")
	local image = loadImage(pngPath)
	if not image then
		return fail("Failed to load icon: " .. tostring(pngPath))
	end
	local w, h = image:getDimensions()
	local scale = size / math.max(w, h)
	local r, g, b = 1, 1, 1
	if color then
		r, g, b = color[1], color[2], color[3]
	end
	love.graphics.setColor(r, g, b, 1.0)
	love.graphics.draw(image, x, y, 0, scale, scale, w / 2, h / 2)
	if restoreBlendMode then
		love.graphics.setBlendMode("alpha", "premultiplied")
	end
	return image
end

-- Draw an icon by name directly from the default asset path
function svg.drawNamedIcon(name, x, y, color, size, opacity)
	local icon = svg.loadIcon(name, size)
	if icon then
		svg.drawIcon(icon, x, y, color, opacity)
	end
	return icon
end

-- Preload commonly used icons to prevent loading delays
function svg.preloadIcons(iconNames, size, basePath)
	for _, name in ipairs(iconNames) do
		svg.loadIcon(name, size, basePath)
	end
end

return svg
