--- Theme creation (spruceOS / PyUI output)
---
--- Output layout (see DEVELOPMENT.md §1 and §5):
---   <Themes>/<Name>/config.json + skin/ + icons/            base set, always 640x480
---   <Themes>/<Name>/config_<W>x<H>.json + skin_<W>x<H>/ + icons_<W>x<H>/   per extra resolution
---   <Themes>/<Name>/<font>.ttf, preview.png, README.md
--- The theme is assembled in WORKING_THEME_DIR and moved into place at the end so PyUI never
--- lists a half-written theme. Activation writes the folder name into the "theme" key of the
--- device system json; PyUI restarts itself when this app exits (principal.sh) and loads it.
local love = require("love")

local json = require("json_lua.json")
local paths = require("paths")
local state = require("state")
local commands = require("utils.commands")
local imageGenerator = require("utils.image_generator")
local iconRenderer = require("utils.icon_renderer")
local logger = require("utils.logger")
local pyuiConfig = require("utils.pyui_config")
local skinRenderer = require("utils.skin_renderer")
local system = require("utils.system")
local fail = require("utils.fail")
local skinSpec = require("spruce.skin_spec")

local themeCreator = {}

-- Folder name safe for FAT/exFAT cards and for jq/json on the shell side
function themeCreator.sanitizeName(name)
	local cleaned = tostring(name or ""):gsub('[\\/:%*%?"<>|]', ""):gsub("^%s+", ""):gsub("%s+$", "")
	if cleaned == "" then
		cleaned = "Aesthetic Spruce"
	end
	return cleaned
end

-- Which resolution sets to generate: always the base set, plus the device's own size when it
-- differs and SPRUCE gives reference sizes for it, plus everything when state.allResolutions is
-- set. A size SPRUCE has no set for (the Zero40's 480x800 portrait panel) gets the base set only,
-- which PyUI's ThemePatcher scales on the device, as it does for SPRUCE itself.
function themeCreator.targetResolutions()
	local native = string.format("%dx%d", state.screenWidth, state.screenHeight)
	local list = { paths.BASE_RESOLUTION }
	if state.allResolutions then
		for _, res in ipairs(paths.SUPPORTED_THEME_RESOLUTIONS) do
			if res ~= paths.BASE_RESOLUTION then
				list[#list + 1] = res
			end
		end
	elseif native ~= paths.BASE_RESOLUTION then
		if skinSpec.skin[native] and skinSpec.icons[native] then
			list[#list + 1] = native
		else
			logger.info("No SPRUCE reference set for " .. native .. "; building the base set only")
		end
	end
	return list
end

local function resetGraphicsState()
	love.graphics.setBlendMode("alpha")
	love.graphics.setCanvas()
	love.graphics.setColor(1, 1, 1, 1)
end

local function copyFont()
	local fontFile, ttfPath = pyuiConfig.fontFile()
	if not fontFile then
		return fail("Selected font not found: " .. tostring(state.fontFamily))
	end
	return system.copy(paths.SOURCE_DIR .. "/" .. ttfPath, paths.WORKING_THEME_DIR .. "/" .. fontFile)
end

local function writeCredits()
	local content = table.concat({
		"# " .. state.themeName,
		"",
		"Generated on-device by Aesthetic Spruce (unofficial fork): https://github.com/CatalyticArkun/aesthetic-spruce",
		"Based on Aesthetic for muOS by Jonathan Avila: https://github.com/joneavila/aesthetic",
		"",
		"Font: " .. tostring(state.fontFamily) .. " (see the licence next to the font in the app's assets/fonts)",
		"Icons: Lucide (ISC), Kenney Input Prompts (CC0)",
		(state.systemIcons and (state.systemIconStyle == "SPRUCE Art" or state.systemIconStyle == "SPRUCE Mono"))
				and (
					"System icons: art from spruceOS's SPRUCE theme by tenlevels (MIT), recoloured in "
					.. (state.systemIconStyle == "SPRUCE Mono" and "one colour\n" or "two tones\n")
				)
			or "",
	}, "\n")
	return system.createTextFile(paths.THEME_CREDITS, content)
end

-- Returns a free directory path under the Themes dir for this theme name
local function finalThemeDir(name)
	local candidate = paths.SPRUCE_THEMES_DIR .. "/" .. name
	if not system.isDir(candidate) then
		return candidate
	end
	for i = 1, 100 do
		local next = string.format("%s (%d)", candidate, i)
		if not system.isDir(next) then
			return next
		end
	end
	return nil
end

-- Coroutine-based theme creation; yields progress strings, returns (true, themeDir) or (false, err)
function themeCreator.createThemeCoroutine()
	return coroutine.create(function()
		local status, result, errMsg = xpcall(function()
			coroutine.yield("Preparing...")
			system.removeDir(paths.WORKING_THEME_DIR)
			if not system.ensurePath(paths.WORKING_THEME_DIR .. "/") then
				return false, "Failed to create working directory"
			end
			if not system.ensurePath(paths.SPRUCE_THEMES_DIR .. "/") then
				return false, "Failed to create themes directory: " .. tostring(paths.SPRUCE_THEMES_DIR)
			end

			local resolutions = themeCreator.targetResolutions()
			for _, res in ipairs(resolutions) do
				local width, height = res:match("(%d+)x(%d+)")
				width, height = tonumber(width), tonumber(height)

				coroutine.yield("Rendering skin " .. res .. "...")
				local skinDir = paths.getThemeSkinDir(width, height)
				local ok, err = skinRenderer.renderSkin(width, height, skinDir, function(name)
					coroutine.yield("Skin " .. res .. ": " .. name)
				end)
				resetGraphicsState()
				if not ok then
					return false, err
				end

				if state.systemIcons then
					coroutine.yield("Rendering icons " .. res .. "...")
					local iconsDir = paths.getThemeIconsDir(width, height)
					ok, err = iconRenderer.renderIcons(width, height, iconsDir, function(name)
						coroutine.yield("Icons " .. res .. ": " .. name)
					end)
					resetGraphicsState()
					if not ok then
						return false, err
					end
				end

				coroutine.yield("Writing config " .. res .. "...")
				ok, err = pyuiConfig.write(paths.getThemeConfigPath(width, height), width, height)
				if not ok then
					return false, err
				end
			end

			coroutine.yield("Copying font...")
			local ok, err = copyFont()
			if not ok then
				return false, err
			end

			coroutine.yield("Creating preview...")
			ok, err = imageGenerator.createPreviewImage(paths.THEME_PREVIEW, 640, 480, state.themeName)
			resetGraphicsState()
			if not ok then
				return false, err
			end

			coroutine.yield("Writing credits...")
			if not writeCredits() then
				return false, "Failed to write theme README"
			end

			coroutine.yield("Installing theme folder...")
			local name = themeCreator.sanitizeName(state.themeName)
			local dest = finalThemeDir(name)
			if not dest then
				return false, "Could not find a free theme folder name for " .. name
			end
			local mv = string.format('mv "%s" "%s"', paths.WORKING_THEME_DIR, dest)
			if commands.executeCommand(mv) ~= 0 then
				return false, "Failed to move theme into place: " .. dest
			end
			commands.executeCommand("sync")
			resetGraphicsState()
			return dest
		end, debug.traceback)

		if not status then
			resetGraphicsState()
			logger.error("Coroutine error: " .. tostring(result))
			return false, tostring(result)
		end
		if not result then
			resetGraphicsState()
			local errorMessage = errMsg or "Theme creation failed"
			logger.error("Theme creation failed: " .. errorMessage)
			return false, errorMessage
		end
		return true, result
	end)
end

-- Write the "theme" key of the device system json atomically (temp file + rename), like
-- PyUI's DeviceUserConfig does. The value is the theme FOLDER NAME, not a path. Only that value
-- is edited, in place: re-encoding the whole file would turn PyUI's empty objects
-- ("button_mapping": {}) into arrays PyUI cannot read back, drop null keys, and lose the
-- one-key-per-line layout spruce's shell helpers parse.
function themeCreator.activateTheme(themeFolderName)
	local jsonPath = paths.SPRUCE_SYSTEM_JSON
	if not jsonPath then
		return fail("No system json path (SPRUCE_SYSTEM_JSON) to record the active theme")
	end
	-- Only a file that does not exist may be created fresh; one we cannot read is never replaced
	local content = ""
	local file, openErr, errno = io.open(jsonPath, "r")
	if file then
		content = file:read("*a")
		file:close()
		if not content then
			return fail("Could not read " .. jsonPath)
		end
	elseif errno ~= 2 then -- ENOENT
		return fail("Could not read " .. jsonPath .. ": " .. tostring(openErr))
	end
	if content:match("%S") then
		local ok, decoded = pcall(json.decode, content)
		if not ok or type(decoded) ~= "table" then
			return fail("System json is not valid JSON: " .. jsonPath)
		end
	end
	local quoted = json.encode(themeFolderName)
	local replacement = quoted:gsub("%%", "%%%%")
	local encoded
	if content:find('"theme"%s*:%s*"') then
		encoded = content:gsub('("theme"%s*:%s*)"[^"]*"', "%1" .. replacement, 1)
	elseif content:find('"theme"%s*:%s*null') then
		-- PyUI reads null as "not set"
		encoded = content:gsub('("theme"%s*:%s*)null', "%1" .. replacement, 1)
	elseif content:find('"theme"%s*:') then
		-- a non-string value; inserting a second key would leave PyUI reading either one
		return fail("System json has a theme value that is not a string: " .. jsonPath)
	elseif not content:match("%S") or content:match("^%s*{%s*}%s*$") then
		encoded = "{\n        \"theme\": " .. quoted .. "\n}\n"
	else
		encoded = content:gsub("{", "{\n        \"theme\": " .. replacement .. ",", 1)
	end
	local parsed, check = pcall(json.decode, encoded)
	if not parsed or type(check) ~= "table" or check.theme ~= themeFolderName then
		return fail("Could not set the theme in " .. jsonPath .. " without changing anything else")
	end
	local tmp = jsonPath .. ".aesthetic.tmp"
	if not system.writeFile(tmp, encoded) then
		return fail("Failed to write " .. tmp)
	end
	local renamed, renameErr = os.rename(tmp, jsonPath)
	if not renamed then
		os.remove(tmp)
		return fail("Failed to replace system json: " .. tostring(renameErr))
	end
	commands.executeCommand("sync")
	logger.info("Active theme set to '" .. themeFolderName .. "' in " .. jsonPath)
	return true
end

-- Coroutine-based activation; PyUI picks the theme up when the app exits
function themeCreator.installThemeCoroutine(themeFolderName)
	return coroutine.create(function()
		local status, result, errMsg = xpcall(function()
			coroutine.yield("Activating theme...")
			local ok, err = themeCreator.activateTheme(themeFolderName)
			if not ok then
				return false, err or "Activation failed"
			end
			return true
		end, debug.traceback)
		if not status then
			return false, "Activation failed: " .. tostring(result)
		end
		if not result then
			return false, errMsg or "Unknown error"
		end
		return true
	end)
end

return themeCreator
