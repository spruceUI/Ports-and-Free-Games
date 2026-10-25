--- Renders the PyUI skin/ assets for one resolution from the editor state
local love = require("love")
local state = require("state")
local paths = require("paths")
local colorUtils = require("utils.color")
local imageGenerator = require("utils.image_generator")
local svg = require("utils.svg")
local system = require("utils.system")
local fail = require("utils.fail")
local skinSpec = require("spruce.skin_spec")
local assets = require("spruce.pyui_assets")

local skinRenderer = {}

local function colorFor(key)
	return colorUtils.hexToLove(state.getColorValue(key or "foreground"))
end

local function withAlpha(c, a)
	return { c[1], c[2], c[3], a or 1 }
end

-- Draw the theme background (solid or gradient) into the current canvas
function skinRenderer.drawBackground(width, height)
	local bg = colorFor("background")
	if state.backgroundType == "Gradient" then
		local mesh = imageGenerator.createGradientMesh(
			state.backgroundGradientDirection or "Vertical",
			bg,
			colorFor("backgroundGradient")
		)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(mesh, 0, 0, 0, width, height)
	else
		love.graphics.setColor(bg)
		love.graphics.rectangle("fill", 0, 0, width, height)
	end
end

local function roundedRect(mode, w, h, radius, inset)
	inset = inset or 0
	local r = math.min(radius or 0, math.floor(math.min(w, h) / 2))
	love.graphics.rectangle(mode, inset, inset, w - inset * 2, h - inset * 2, r, r)
end

local function iconPath(icon)
	return paths.UI_ICON_PNG_DIR .. "/" .. icon .. ".png"
end

-- Draw one asset into a w x h canvas. `scale` is the resolution scale (1.0 at 640x480).
local function drawAsset(name, spec, w, h, scale)
	local fg = colorFor("foreground")
	local bg = colorFor("background")
	local kind = spec.kind
	love.graphics.setBlendMode("alpha")
	love.graphics.setLineStyle("smooth")

	if kind == "background" then
		skinRenderer.drawBackground(w, h)
	elseif kind == "bar" then
		-- a bar is a subtle foreground tint over the background so its text stays readable
		if state[spec.visible] then
			love.graphics.setColor(withAlpha(fg, 0.18))
			love.graphics.rectangle("fill", 0, 0, w, h)
		end
	elseif kind == "plate" then
		love.graphics.setColor(withAlpha(fg, spec.alpha or 1))
		roundedRect("fill", w, h, (spec.radius or 8) * scale)
	elseif kind == "frame" then
		local lw = (spec.width or 2) * scale
		love.graphics.setLineWidth(lw)
		love.graphics.setColor(withAlpha(fg, spec.alpha or 1))
		roundedRect("line", w, h, (spec.radius or 8) * scale, lw / 2)
	elseif kind == "panel" then
		love.graphics.setColor(withAlpha(bg, 1))
		roundedRect("fill", w, h, (spec.radius or 12) * scale)
		local lw = 2 * scale
		love.graphics.setLineWidth(lw)
		love.graphics.setColor(withAlpha(fg, 1))
		roundedRect("line", w, h, (spec.radius or 12) * scale, lw / 2)
	elseif kind == "pictogram" then
		local size = math.min(w, h) * (spec.scale or 0.8)
		local color = withAlpha(colorFor(spec.color), spec.alpha or 1)
		love.graphics.setColor(color)
		local ok, err = svg.drawImageOnCanvas(iconPath(spec.icon), size, w / 2, h / 2, color, false)
		if not ok then
			return false, err
		end
		if spec.alpha and spec.alpha < 1 then
			-- drawImageOnCanvas draws opaque; re-apply the requested alpha with a second pass
			love.graphics.setBlendMode("multiply", "premultiplied")
			love.graphics.setColor(1, 1, 1, spec.alpha)
			love.graphics.rectangle("fill", 0, 0, w, h)
			love.graphics.setBlendMode("alpha")
		end
	elseif kind == "tile" then
		-- square plate in the top of the image; the band below is PyUI's label area
		local side = math.min(w, h)
		local radius = 16 * scale
		local lw = 2 * scale
		local px0 = (w - side) / 2
		if spec.focused then
			love.graphics.setColor(fg)
			love.graphics.rectangle("fill", px0, 0, side, side, radius, radius)
		else
			love.graphics.setLineWidth(lw)
			love.graphics.setColor(withAlpha(fg, 0.6))
			love.graphics.rectangle("line", px0 + lw / 2, lw / 2, side - lw, side - lw, radius, radius)
		end
		local tint = spec.focused and bg or fg
		local size = side * 0.5
		local ok, err = svg.drawImageOnCanvas(iconPath(spec.icon), size, w / 2, side / 2, tint, false)
		if not ok then
			return false, err
		end
	elseif kind == "empty" then
		-- transparent
	else
		return false, "Unknown asset kind for " .. name .. ": " .. tostring(kind)
	end
	return true
end

-- Encode the current canvas to a PNG file (straight alpha; see imageGenerator.unpremultiply)
local function saveCanvas(canvas, path, opaque, bleed)
	local pngData = imageGenerator.encodeCanvas(canvas, opaque, bleed)
	if not pngData then
		return fail("Failed to encode PNG for " .. path)
	end
	return system.writeFile(path, pngData:getString())
end

-- Render one named asset to outDir/<name>.png at the size the reference theme uses
function skinRenderer.renderAsset(name, resolution, outDir, scale)
	local spec = assets[name]
	local w, h
	if spec.full then
		w, h = resolution:match("(%d+)x(%d+)")
		w, h = tonumber(w), tonumber(h)
	elseif spec.dims then
		w, h = math.floor(spec.dims[1] * scale + 0.5), math.floor(spec.dims[2] * scale + 0.5)
	else
		local dims = skinSpec.skin[resolution] and skinSpec.skin[resolution][spec.like or name]
		if not dims then
			return fail("No reference dimensions for " .. name .. " at " .. resolution)
		end
		w, h = dims[1], dims[2]
	end
	local canvas = love.graphics.newCanvas(w, h)
	local previousCanvas = love.graphics.getCanvas()
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	local ok, err = drawAsset(name, spec, w, h, scale)
	love.graphics.setCanvas(previousCanvas)
	love.graphics.pop()
	if not ok then
		return fail(err)
	end
	-- transparent pixels take the shape's own colour so scaling never fringes dark
	local bleed = spec.kind == "panel" and colorFor("background") or colorFor(spec.color)
	local saved, saveErr = saveCanvas(canvas, outDir .. "/" .. name .. ".png", spec.kind == "background", bleed)
	canvas:release()
	return saved, saveErr
end

-- Ordered asset list so progress is deterministic
function skinRenderer.assetNames()
	local names = {}
	for name in pairs(assets) do
		names[#names + 1] = name
	end
	table.sort(names)
	return names
end

-- Render every asset for a resolution. `progress(name)` is called before each asset so a
-- coroutine caller can yield between files.
function skinRenderer.renderSkin(width, height, outDir, progress)
	local resolution = string.format("%dx%d", width, height)
	if not skinSpec.skin[resolution] then
		return fail("Unsupported theme resolution: " .. resolution)
	end
	if not system.ensurePath(outDir .. "/") then
		return fail("Failed to create skin directory: " .. outDir)
	end
	local scale = math.min(width / 640, height / 480)
	for _, name in ipairs(skinRenderer.assetNames()) do
		if progress then
			progress(name)
		end
		local ok, err = skinRenderer.renderAsset(name, resolution, outDir, scale)
		if not ok then
			return false, err or ("Failed to render " .. name)
		end
	end
	return true
end

return skinRenderer
