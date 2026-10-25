--- Presets: named theme snapshots. Built-in presets live in THEME_PRESETS_DIR (read-only),
--- user presets in USERDATA_THEME_PRESETS_DIR; a user preset shadows a built-in of the same name.
local logger = require("utils.logger")
local paths = require("paths")
local state = require("state")
local system = require("utils.system")
local themeFile = require("utils.theme_file")
local fail = require("utils.fail")

local presets = {}

local function presetDirectories()
	return { paths.USERDATA_THEME_PRESETS_DIR, paths.THEME_PRESETS_DIR }
end

local function fileNameFor(presetName)
	return tostring(presetName):gsub("[%s%p]", "_") .. ".lua"
end

local function findPresetFile(presetName)
	for _, dir in ipairs(presetDirectories()) do
		for _, candidate in ipairs({ dir .. "/" .. presetName .. ".lua", dir .. "/" .. fileNameFor(presetName) }) do
			if system.isFile(candidate) then
				return candidate
			end
		end
	end
	return nil
end

--- (true, data) when the preset exists and parses, (false, nil) otherwise
function presets.validatePreset(presetName)
	local path = presetName and findPresetFile(presetName)
	if not path then
		return false, nil
	end
	local data = themeFile.read(path)
	if not data then
		return false, nil
	end
	return true, data
end

--- Save the current theme model as a user preset
function presets.savePreset(presetName)
	presetName = presetName and presetName ~= "" and presetName or "preset1"
	local dir = paths.USERDATA_THEME_PRESETS_DIR
	if not system.ensurePath(dir .. "/") then
		return fail("Failed to create presets directory: " .. dir)
	end
	local t = state.exportTheme()
	t.displayName = presetName
	t.source = "user"
	t.created = os.time()
	return themeFile.write(dir .. "/" .. fileNameFor(presetName), t, "Aesthetic Spruce preset file")
end

--- Load a preset into the theme model (missing fields fall back to defaults)
function presets.loadPreset(presetName)
	local path = presetName and findPresetFile(presetName)
	if not path then
		logger.error("Preset not found: " .. tostring(presetName))
		return false
	end
	local t = themeFile.read(path)
	if not t then
		return false
	end
	local ok, rejected = state.importTheme(t)
	if ok and (rejected or 0) > 0 then
		logger.warning("Preset " .. presetName .. ": " .. rejected .. " field(s) ignored")
	end
	logger.info("Loaded preset: " .. presetName)
	return ok
end

--- Names of all presets (user first, then built-in), unique
function presets.listPresets()
	local seen, list = {}, {}
	for _, dir in ipairs(presetDirectories()) do
		if system.isDir(dir) then
			for _, name in ipairs(system.listFiles(dir, "*.lua")) do
				local presetName = name:match("^(.+)%.lua$")
				if presetName and not seen[presetName] then
					seen[presetName] = true
					list[#list + 1] = presetName
				end
			end
		end
	end
	return list
end

return presets
